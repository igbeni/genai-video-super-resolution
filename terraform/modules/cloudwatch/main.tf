# CloudWatch Dashboards, Alarms, and Log Groups for Video Super-Resolution Pipeline
# This module creates CloudWatch resources for monitoring and logging

# Main Dashboard for Video Super-Resolution Pipeline
resource "aws_cloudwatch_dashboard" "main_dashboard" {
  dashboard_name = "${var.name_prefix}-main-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 2
        properties = {
          markdown = "# Video Super-Resolution Pipeline Monitoring\nThis dashboard provides an overview of the entire video super-resolution pipeline."
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 2
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/S3", "NumberOfObjects", "BucketName", var.source_bucket_name, "StorageType", "AllStorageTypes"],
            ["AWS/S3", "NumberOfObjects", "BucketName", var.processed_frames_bucket_name, "StorageType", "AllStorageTypes"],
            ["AWS/S3", "NumberOfObjects", "BucketName", var.final_videos_bucket_name, "StorageType", "AllStorageTypes"]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "S3 Object Count"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 2
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/S3", "BucketSizeBytes", "BucketName", var.source_bucket_name, "StorageType", "StandardStorage"],
            ["AWS/S3", "BucketSizeBytes", "BucketName", var.processed_frames_bucket_name, "StorageType", "StandardStorage"],
            ["AWS/S3", "BucketSizeBytes", "BucketName", var.final_videos_bucket_name, "StorageType", "StandardStorage"]
          ]
          period = 86400
          stat   = "Average"
          region = var.region
          title  = "S3 Bucket Size"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 8
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", var.lambda_function_names["pipeline_trigger"]],
            ["AWS/Lambda", "Invocations", "FunctionName", var.lambda_function_names["frame_extraction"]],
            ["AWS/Lambda", "Invocations", "FunctionName", var.lambda_function_names["frame_processing"]],
            ["AWS/Lambda", "Invocations", "FunctionName", var.lambda_function_names["video_recomposition"]],
            ["AWS/Lambda", "Invocations", "FunctionName", var.lambda_function_names["completion_notification"]]
          ]
          period = 300
          stat   = "Sum"
          region = var.region
          title  = "Lambda Invocations"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 8
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", var.lambda_function_names["pipeline_trigger"]],
            ["AWS/Lambda", "Errors", "FunctionName", var.lambda_function_names["frame_extraction"]],
            ["AWS/Lambda", "Errors", "FunctionName", var.lambda_function_names["frame_processing"]],
            ["AWS/Lambda", "Errors", "FunctionName", var.lambda_function_names["video_recomposition"]],
            ["AWS/Lambda", "Errors", "FunctionName", var.lambda_function_names["completion_notification"]]
          ]
          period = 300
          stat   = "Sum"
          region = var.region
          title  = "Lambda Errors"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 14
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Batch", "JobsSubmitted", "JobQueue", var.batch_job_queue_names["spot"]],
            ["AWS/Batch", "JobsSubmitted", "JobQueue", var.batch_job_queue_names["ondemand"]],
            ["AWS/Batch", "JobsSubmitted", "JobQueue", var.batch_job_queue_names["hybrid"]]
          ]
          period = 300
          stat   = "Sum"
          region = var.region
          title  = "Batch Jobs Submitted"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 14
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Batch", "JobsFailed", "JobQueue", var.batch_job_queue_names["spot"]],
            ["AWS/Batch", "JobsFailed", "JobQueue", var.batch_job_queue_names["ondemand"]],
            ["AWS/Batch", "JobsFailed", "JobQueue", var.batch_job_queue_names["hybrid"]]
          ]
          period = 300
          stat   = "Sum"
          region = var.region
          title  = "Batch Jobs Failed"
        }
      }
    ]
  })
}

# Pipeline Performance Dashboard
resource "aws_cloudwatch_dashboard" "performance_dashboard" {
  dashboard_name = "${var.name_prefix}-performance-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 2
        properties = {
          markdown = "# Video Super-Resolution Pipeline Performance\nThis dashboard provides performance metrics for the video super-resolution pipeline."
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 2
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", var.lambda_function_names["pipeline_trigger"]],
            ["AWS/Lambda", "Duration", "FunctionName", var.lambda_function_names["frame_extraction"]],
            ["AWS/Lambda", "Duration", "FunctionName", var.lambda_function_names["frame_processing"]],
            ["AWS/Lambda", "Duration", "FunctionName", var.lambda_function_names["video_recomposition"]],
            ["AWS/Lambda", "Duration", "FunctionName", var.lambda_function_names["completion_notification"]]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "Lambda Duration"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 2
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", var.ec2_asg_names["spot"]],
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", var.ec2_asg_names["ondemand"]]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "EC2 CPU Utilization"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 8
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "GPUUtilization", "AutoScalingGroupName", var.ec2_asg_names["spot"]],
            ["AWS/EC2", "GPUUtilization", "AutoScalingGroupName", var.ec2_asg_names["ondemand"]]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "EC2 GPU Utilization"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 8
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "NetworkIn", "AutoScalingGroupName", var.ec2_asg_names["spot"]],
            ["AWS/EC2", "NetworkOut", "AutoScalingGroupName", var.ec2_asg_names["spot"]],
            ["AWS/EC2", "NetworkIn", "AutoScalingGroupName", var.ec2_asg_names["ondemand"]],
            ["AWS/EC2", "NetworkOut", "AutoScalingGroupName", var.ec2_asg_names["ondemand"]]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "EC2 Network Traffic"
        }
      }
    ]
  })
}

# Cost Dashboard
resource "aws_cloudwatch_dashboard" "cost_dashboard" {
  dashboard_name = "${var.name_prefix}-cost-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 2
        properties = {
          markdown = "# Video Super-Resolution Pipeline Cost\nThis dashboard provides detailed cost metrics for the video super-resolution pipeline, including service costs, resource-specific costs, and budget tracking."
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 2
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Billing", "EstimatedCharges", "ServiceName", "AmazonEC2"],
            ["AWS/Billing", "EstimatedCharges", "ServiceName", "AmazonS3"],
            ["AWS/Billing", "EstimatedCharges", "ServiceName", "AWSLambda"],
            ["AWS/Billing", "EstimatedCharges", "ServiceName", "AmazonCloudWatch"],
            ["AWS/Billing", "EstimatedCharges", "ServiceName", "AWSBatch"]
          ]
          period  = 86400
          stat    = "Maximum"
          region  = "us-east-1"
          title   = "Estimated Charges by Service"
          view    = "timeSeries"
          stacked = false
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 2
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Billing", "EstimatedCharges", "ServiceName", "AmazonEC2", "UsageType", "BoxUsage:g4dn.xlarge"],
            ["AWS/Billing", "EstimatedCharges", "ServiceName", "AmazonEC2", "UsageType", "BoxUsage:g4dn.2xlarge"],
            ["AWS/Billing", "EstimatedCharges", "ServiceName", "AmazonEC2", "UsageType", "BoxUsage:g5.xlarge"],
            ["AWS/Billing", "EstimatedCharges", "ServiceName", "AmazonEC2", "UsageType", "BoxUsage:g5.2xlarge"],
            ["AWS/Billing", "EstimatedCharges", "ServiceName", "AmazonEC2", "UsageType", "SpotUsage"]
          ]
          period  = 86400
          stat    = "Maximum"
          region  = "us-east-1"
          title   = "EC2 Costs by Instance Type"
          view    = "timeSeries"
          stacked = false
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 8
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Billing", "EstimatedCharges", "ServiceName", "AmazonS3", "StorageType", "StandardStorage"],
            ["AWS/Billing", "EstimatedCharges", "ServiceName", "AmazonS3", "StorageType", "StandardIAStorage"],
            ["AWS/Billing", "EstimatedCharges", "ServiceName", "AmazonS3", "StorageType", "GlacierStorage"],
            ["AWS/Billing", "EstimatedCharges", "ServiceName", "AmazonS3", "UsageType", "DataTransfer-Out-Bytes"]
          ]
          period  = 86400
          stat    = "Maximum"
          region  = "us-east-1"
          title   = "S3 Costs by Storage Class and Data Transfer"
          view    = "timeSeries"
          stacked = false
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 8
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Billing", "EstimatedCharges", "Environment", var.environment],
            ["AWS/Billing", "EstimatedCharges", "Project", var.project_name],
            ["AWS/Billing", "EstimatedCharges", "CostCenter", var.cost_center]
          ]
          period  = 86400
          stat    = "Maximum"
          region  = "us-east-1"
          title   = "Costs by Tag"
          view    = "timeSeries"
          stacked = false
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 14
        width  = 24
        height = 6
        properties = {
          metrics = [
            ["AWS/Billing", "EstimatedCharges", "Environment", var.environment],
            [{
              expression = "FILL(METRICS(), 0)",
              label      = "Total Cost",
              id         = "total"
            }],
            [{
              expression = "IF(total>${var.monthly_budget}*0.8,${var.monthly_budget}*0.8,total)",
              label      = "80% of Budget",
              id         = "warning"
            }],
            [{
              expression = "IF(total>${var.monthly_budget},${var.monthly_budget},total)",
              label      = "Budget Limit",
              id         = "critical"
            }]
          ]
          period  = 86400
          stat    = "Maximum"
          region  = "us-east-1"
          title   = "Budget Tracking"
          view    = "timeSeries"
          stacked = false
          annotations = {
            horizontal = [
              {
                value = var.monthly_budget * 0.8
                label = "80% of Budget"
                color = "#ff9900"
              },
              {
                value = var.monthly_budget
                label = "Budget Limit"
                color = "#d13212"
              }
            ]
          }
        }
      }
    ]
  })
}

# Log Groups
resource "aws_cloudwatch_log_group" "lambda_logs" {
  for_each          = var.lambda_function_names
  name              = "/aws/lambda/${each.value}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "ec2_logs" {
  name              = "/aws/ec2/${var.name_prefix}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# Alarms for Lambda Errors
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each            = var.lambda_function_names
  alarm_name          = "${each.value}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = var.lambda_error_threshold
  alarm_description   = "This alarm monitors Lambda function errors"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.ok_actions

  dimensions = {
    FunctionName = each.value
  }

  tags = var.tags
}

# Alarm for S3 Storage
resource "aws_cloudwatch_metric_alarm" "s3_storage_alarm" {
  for_each            = toset([var.source_bucket_name, var.processed_frames_bucket_name, var.final_videos_bucket_name])
  alarm_name          = "${each.value}-storage-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "BucketSizeBytes"
  namespace           = "AWS/S3"
  period              = 86400
  statistic           = "Average"
  threshold           = var.s3_storage_threshold
  alarm_description   = "This alarm monitors S3 bucket storage size"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.ok_actions

  dimensions = {
    BucketName  = each.value
    StorageType = "StandardStorage"
  }

  tags = var.tags
}

# Alarm for EC2 High CPU
resource "aws_cloudwatch_metric_alarm" "ec2_cpu_alarm" {
  for_each            = var.ec2_asg_names
  alarm_name          = "${each.value}-cpu-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.ec2_cpu_threshold
  alarm_description   = "This alarm monitors EC2 CPU utilization"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.ok_actions

  dimensions = {
    AutoScalingGroupName = each.value
  }

  tags = var.tags
}

# Alarm for EC2 Low CPU (Idle Instances)
resource "aws_cloudwatch_metric_alarm" "ec2_idle_alarm" {
  for_each            = var.ec2_asg_names
  alarm_name          = "${each.value}-idle-alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.idle_evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.ec2_idle_threshold
  alarm_description   = "This alarm detects idle EC2 instances for automatic scaling down"
  alarm_actions       = concat(var.alarm_actions, [aws_sns_topic.idle_instances_topic.arn])

  dimensions = {
    AutoScalingGroupName = each.value
  }

  tags = var.tags
}

# Composite Alarm for Overall Pipeline Health
resource "aws_cloudwatch_composite_alarm" "pipeline_health" {
  alarm_name        = "${var.name_prefix}-pipeline-health"
  alarm_description = "Composite alarm for overall pipeline health"

  alarm_rule = join(" OR ", [
    for name in var.lambda_function_names : "ALARM(${name}-errors)"
  ])

  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions

  tags = var.tags
}

# CloudWatch Event Rule for Pipeline Completion
resource "aws_cloudwatch_event_rule" "pipeline_completion" {
  name        = "${var.name_prefix}-pipeline-completion"
  description = "Capture pipeline completion events"

  event_pattern = jsonencode({
    source      = ["aws.lambda"],
    detail-type = ["Lambda Function Invocation Result - Success"],
    detail = {
      requestContext = {
        functionName = [var.lambda_function_names["completion_notification"]]
      }
    }
  })

  tags = var.tags
}

# CloudWatch Event Target for Pipeline Completion
resource "aws_cloudwatch_event_target" "pipeline_completion_target" {
  rule      = aws_cloudwatch_event_rule.pipeline_completion.name
  target_id = "SendToSNS"
  arn       = var.sns_topic_arns["notification"]
}

# CloudWatch Event Rule for Pipeline Failure
resource "aws_cloudwatch_event_rule" "pipeline_failure" {
  name        = "${var.name_prefix}-pipeline-failure"
  description = "Capture pipeline failure events"

  event_pattern = jsonencode({
    source      = ["aws.lambda"],
    detail-type = ["Lambda Function Invocation Result - Failure"],
    detail = {
      requestContext = {
        functionName = values(var.lambda_function_names)
      }
    }
  })

  tags = var.tags
}

# CloudWatch Event Target for Pipeline Failure
resource "aws_cloudwatch_event_target" "pipeline_failure_target" {
  rule      = aws_cloudwatch_event_rule.pipeline_failure.name
  target_id = "SendToSNS"
  arn       = var.sns_topic_arns["notification"]
}

# SNS Topic for Idle Instances
resource "aws_sns_topic" "idle_instances_topic" {
  name = "${var.name_prefix}-idle-instances-topic"
  tags = var.tags
}

# Lambda Function for Auto Scaling Down Idle Instances
resource "aws_lambda_function" "auto_scale_down" {
  function_name = "${var.name_prefix}-auto-scale-down"
  description   = "Automatically scales down idle EC2 instances"

  role        = var.lambda_role_arn
  handler     = "index.handler"
  runtime     = "nodejs14.x"
  timeout     = 60
  memory_size = 128

  filename = var.auto_scale_down_zip_path

  environment {
    variables = {
      MIN_CAPACITY = "1"
      REGION       = var.region
    }
  }

  tags = var.tags
}

# SNS Topic Subscription for Lambda
resource "aws_sns_topic_subscription" "auto_scale_down_subscription" {
  topic_arn = aws_sns_topic.idle_instances_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.auto_scale_down.arn
}

# Lambda Permission for SNS
resource "aws_lambda_permission" "allow_sns_auto_scale_down" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auto_scale_down.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.idle_instances_topic.arn
}

# AWS Budget for Cost Control
resource "aws_budgets_budget" "monthly_budget" {
  name              = "${var.name_prefix}-monthly-budget"
  budget_type       = "COST"
  limit_amount      = var.monthly_budget
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2023-01-01_00:00"

  cost_filter {
    name = "Service"
    values = [
      "Amazon Elastic Compute Cloud - Compute",
      "Amazon Simple Storage Service",
      "AWS Lambda",
      "AWS Batch",
      "Amazon CloudWatch"
    ]
  }

  cost_filter {
    name = "TagKeyValue"
    values = [
      "user:Project$${var.project_name}"
    ]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_notification_emails
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_notification_emails
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 90
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.budget_notification_emails
  }
}
