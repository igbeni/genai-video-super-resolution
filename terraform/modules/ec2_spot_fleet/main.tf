# EC2 Spot Fleet Configurations for Video Super-Resolution Pipeline
# This module creates EC2 Spot Fleet resources for cost-optimized processing nodes

# Spot Fleet Request
resource "aws_spot_fleet_request" "processing_fleet" {
  iam_fleet_role                      = var.fleet_role_arn
  target_capacity                     = var.target_capacity
  allocation_strategy                 = var.allocation_strategy
  instance_interruption_behavior      = var.instance_interruption_behavior
  terminate_instances_with_expiration = true
  wait_for_fulfillment                = var.wait_for_fulfillment
  excess_capacity_termination_policy  = "Default"
  valid_until                         = timeadd(timestamp(), var.valid_until)
  replace_unhealthy_instances         = true
  on_demand_target_capacity           = var.on_demand_backup_count
  on_demand_allocation_strategy       = "lowestPrice"

  dynamic "launch_specification" {
    for_each = var.instance_types
    content {
      instance_type               = launch_specification.value
      ami                         = var.ami_id
      subnet_id                   = element(var.subnet_ids, launch_specification.key % length(var.subnet_ids))
      vpc_security_group_ids      = var.security_group_ids
      iam_instance_profile        = var.instance_profile_name
      key_name                    = var.key_name
      weighted_capacity           = lookup(var.instance_weights, launch_specification.value, 1)
      availability_zone           = element(var.availability_zones, launch_specification.key % length(var.availability_zones))

      root_block_device {
        volume_size           = var.root_volume_size
        volume_type           = var.root_volume_type
        delete_on_termination = true
        encrypted             = var.encrypt_volumes
      }

      dynamic "ebs_block_device" {
        for_each = var.ebs_block_devices
        content {
          device_name           = ebs_block_device.value.device_name
          volume_size           = ebs_block_device.value.volume_size
          volume_type           = ebs_block_device.value.volume_type
          delete_on_termination = true
          encrypted             = var.encrypt_volumes
        }
      }

      user_data = base64encode(templatefile(var.user_data_template, {
        s3_bucket_name = var.s3_bucket_name
        region         = var.region
        tags           = jsonencode(var.tags)
        spot_instance  = true
      }))

      tags = merge(
        var.tags,
        {
          Name = "${var.name_prefix}-spot-instance-${launch_specification.key}"
          SpotInstance = "true"
        }
      )
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-spot-fleet"
    }
  )
}

# CloudWatch Alarm for Spot Fleet Capacity
resource "aws_cloudwatch_metric_alarm" "spot_capacity_alarm" {
  alarm_name          = "${var.name_prefix}-spot-capacity-alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FulfilledCapacity"
  namespace           = "AWS/EC2Spot"
  period              = 300
  statistic           = "Average"
  threshold           = var.target_capacity * 0.8
  alarm_description   = "This alarm monitors EC2 Spot Fleet fulfilled capacity"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.ok_actions

  dimensions = {
    FleetRequestId = aws_spot_fleet_request.processing_fleet.id
  }

  tags = var.tags
}

# CloudWatch Dashboard for Spot Fleet Monitoring
resource "aws_cloudwatch_dashboard" "spot_fleet_dashboard" {
  dashboard_name = "${var.name_prefix}-spot-fleet-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2Spot", "FulfilledCapacity", "FleetRequestId", aws_spot_fleet_request.processing_fleet.id],
            ["AWS/EC2Spot", "TargetCapacity", "FleetRequestId", aws_spot_fleet_request.processing_fleet.id],
            ["AWS/EC2Spot", "PendingCapacity", "FleetRequestId", aws_spot_fleet_request.processing_fleet.id]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "Spot Fleet Capacity"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", "${var.name_prefix}-spot-fleet"]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "CPU Utilization"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "NetworkIn", "AutoScalingGroupName", "${var.name_prefix}-spot-fleet"],
            ["AWS/EC2", "NetworkOut", "AutoScalingGroupName", "${var.name_prefix}-spot-fleet"]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "Network Traffic"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "EBSReadOps", "AutoScalingGroupName", "${var.name_prefix}-spot-fleet"],
            ["AWS/EC2", "EBSWriteOps", "AutoScalingGroupName", "${var.name_prefix}-spot-fleet"]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "EBS Operations"
        }
      }
    ]
  })
}

# SNS Topic for Spot Instance Interruption Notifications
resource "aws_sns_topic" "spot_interruption_topic" {
  name = "${var.name_prefix}-spot-interruption-topic"
  tags = var.tags
}

# CloudWatch Event Rule for Spot Instance Interruption Warnings
resource "aws_cloudwatch_event_rule" "spot_interruption_warning" {
  name        = "${var.name_prefix}-spot-interruption-warning"
  description = "Capture EC2 Spot Instance Interruption Warnings"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })

  tags = var.tags
}

# CloudWatch Event Target for Spot Instance Interruption Warnings
resource "aws_cloudwatch_event_target" "spot_interruption_target" {
  rule      = aws_cloudwatch_event_rule.spot_interruption_warning.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.spot_interruption_topic.arn
}

# Lambda Function for Handling Spot Instance Interruptions
resource "aws_lambda_function" "spot_interruption_handler" {
  count         = var.create_interruption_handler ? 1 : 0
  function_name = "${var.name_prefix}-spot-interruption-handler"
  description   = "Handles EC2 Spot Instance interruption notifications"

  role          = var.lambda_role_arn
  handler       = "index.handler"
  runtime       = "nodejs14.x"
  timeout       = 60
  memory_size   = 128

  filename      = var.interruption_handler_zip_path

  environment {
    variables = {
      FLEET_ID = aws_spot_fleet_request.processing_fleet.id
      REGION   = var.region
      S3_BUCKET_NAME = var.s3_bucket_name
      TARGET_CAPACITY = tostring(var.target_capacity)
      JOBS_TABLE = var.jobs_table_name
    }
  }

  tags = var.tags
}

# SNS Topic Subscription for Lambda
resource "aws_sns_topic_subscription" "lambda_subscription" {
  count     = var.create_interruption_handler ? 1 : 0
  topic_arn = aws_sns_topic.spot_interruption_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.spot_interruption_handler[0].arn
}

# Lambda Permission for SNS
resource "aws_lambda_permission" "allow_sns" {
  count         = var.create_interruption_handler ? 1 : 0
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.spot_interruption_handler[0].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.spot_interruption_topic.arn
}
