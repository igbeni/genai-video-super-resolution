# AWS Batch Compute Environments and Job Queues for Video Super-Resolution Pipeline
# This module creates AWS Batch resources for efficient processing of video frames

# AWS Batch Compute Environment for Spot Instances
resource "aws_batch_compute_environment" "spot" {
  compute_environment_name_prefix = "${var.name_prefix}-spot-"
  type                            = "MANAGED"
  state                           = "ENABLED"
  service_role                    = var.batch_service_role_arn

  compute_resources {
    type                = "SPOT"
    allocation_strategy = var.spot_allocation_strategy
    bid_percentage      = var.spot_bid_percentage

    max_vcpus     = var.spot_max_vcpus
    min_vcpus     = var.spot_min_vcpus
    desired_vcpus = var.spot_desired_vcpus

    instance_role = var.batch_instance_profile_arn
    instance_type = var.spot_instance_types

    security_group_ids = var.security_group_ids
    subnets            = var.subnet_ids

    spot_iam_fleet_role = var.spot_fleet_role_arn

    tags = merge(
      var.tags,
      {
        Name = "${var.name_prefix}-batch-spot-compute"
      }
    )
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

# AWS Batch Compute Environment for On-Demand Instances (fallback)
resource "aws_batch_compute_environment" "ondemand" {
  compute_environment_name_prefix = "${var.name_prefix}-ondemand-"
  type                            = "MANAGED"
  state                           = "ENABLED"
  service_role                    = var.batch_service_role_arn

  compute_resources {
    type                = "EC2"
    allocation_strategy = var.ondemand_allocation_strategy

    max_vcpus     = var.ondemand_max_vcpus
    min_vcpus     = var.ondemand_min_vcpus
    desired_vcpus = var.ondemand_desired_vcpus

    instance_role = var.batch_instance_profile_arn
    instance_type = var.ondemand_instance_types

    security_group_ids = var.security_group_ids
    subnets            = var.subnet_ids

    tags = merge(
      var.tags,
      {
        Name = "${var.name_prefix}-batch-ondemand-compute"
      }
    )
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

# AWS Batch Job Queue for Spot Instances (primary)
resource "aws_batch_job_queue" "spot" {
  name     = "${var.name_prefix}-spot-job-queue"
  state    = "ENABLED"
  priority = 1
  compute_environments = [
    aws_batch_compute_environment.spot.arn
  ]

  tags = var.tags
}

# AWS Batch Job Queue for On-Demand Instances (fallback)
resource "aws_batch_job_queue" "ondemand" {
  name     = "${var.name_prefix}-ondemand-job-queue"
  state    = "ENABLED"
  priority = 2
  compute_environments = [
    aws_batch_compute_environment.ondemand.arn
  ]

  tags = var.tags
}

# AWS Batch Job Queue with Both Compute Environments
resource "aws_batch_job_queue" "hybrid" {
  name     = "${var.name_prefix}-hybrid-job-queue"
  state    = "ENABLED"
  priority = 1
  compute_environments = [
    aws_batch_compute_environment.spot.arn,
    aws_batch_compute_environment.ondemand.arn
  ]

  tags = var.tags
}

# AWS Batch Job Definition for Frame Extraction
resource "aws_batch_job_definition" "frame_extraction" {
  name = "${var.name_prefix}-frame-extraction"
  type = "container"
  container_properties = jsonencode({
    image                = var.frame_extraction_image
    vcpus                = var.frame_extraction_vcpus
    memory               = var.frame_extraction_memory
    command              = var.frame_extraction_command
    jobRoleArn           = var.batch_job_role_arn
    executionRoleArn     = var.batch_job_role_arn
    volumes              = var.frame_extraction_volumes
    mountPoints          = var.frame_extraction_mount_points
    environment          = var.frame_extraction_environment
    resourceRequirements = var.frame_extraction_resource_requirements
    linuxParameters      = var.frame_extraction_linux_parameters
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = var.cloudwatch_log_group_name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "frame-extraction"
      }
    }
  })

  retry_strategy {
    attempts = var.job_retry_attempts
  }

  timeout {
    attempt_duration_seconds = var.frame_extraction_timeout
  }

  tags = var.tags
}

# AWS Batch Job Definition for Frame Processing
resource "aws_batch_job_definition" "frame_processing" {
  name = "${var.name_prefix}-frame-processing"
  type = "container"
  container_properties = jsonencode({
    image                = var.frame_processing_image
    vcpus                = var.frame_processing_vcpus
    memory               = var.frame_processing_memory
    command              = var.frame_processing_command
    jobRoleArn           = var.batch_job_role_arn
    executionRoleArn     = var.batch_job_role_arn
    volumes              = var.frame_processing_volumes
    mountPoints          = var.frame_processing_mount_points
    environment          = var.frame_processing_environment
    resourceRequirements = var.frame_processing_resource_requirements
    linuxParameters      = var.frame_processing_linux_parameters
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = var.cloudwatch_log_group_name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "frame-processing"
      }
    }
  })

  retry_strategy {
    attempts = var.job_retry_attempts
  }

  timeout {
    attempt_duration_seconds = var.frame_processing_timeout
  }

  tags = var.tags
}

# AWS Batch Job Definition for Video Recomposition
resource "aws_batch_job_definition" "video_recomposition" {
  name = "${var.name_prefix}-video-recomposition"
  type = "container"
  container_properties = jsonencode({
    image                = var.video_recomposition_image
    vcpus                = var.video_recomposition_vcpus
    memory               = var.video_recomposition_memory
    command              = var.video_recomposition_command
    jobRoleArn           = var.batch_job_role_arn
    executionRoleArn     = var.batch_job_role_arn
    volumes              = var.video_recomposition_volumes
    mountPoints          = var.video_recomposition_mount_points
    environment          = var.video_recomposition_environment
    resourceRequirements = var.video_recomposition_resource_requirements
    linuxParameters      = var.video_recomposition_linux_parameters
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = var.cloudwatch_log_group_name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "video-recomposition"
      }
    }
  })

  retry_strategy {
    attempts = var.job_retry_attempts
  }

  timeout {
    attempt_duration_seconds = var.video_recomposition_timeout
  }

  tags = var.tags
}

# CloudWatch Dashboard for AWS Batch Monitoring
resource "aws_cloudwatch_dashboard" "batch_dashboard" {
  dashboard_name = "${var.name_prefix}-batch-dashboard"

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
            ["AWS/Batch", "JobsSubmitted", "JobQueue", aws_batch_job_queue.spot.name],
            ["AWS/Batch", "JobsSubmitted", "JobQueue", aws_batch_job_queue.ondemand.name],
            ["AWS/Batch", "JobsSubmitted", "JobQueue", aws_batch_job_queue.hybrid.name]
          ]
          period = 300
          stat   = "Sum"
          region = var.region
          title  = "Jobs Submitted"
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
            ["AWS/Batch", "JobsPending", "JobQueue", aws_batch_job_queue.spot.name],
            ["AWS/Batch", "JobsPending", "JobQueue", aws_batch_job_queue.ondemand.name],
            ["AWS/Batch", "JobsPending", "JobQueue", aws_batch_job_queue.hybrid.name]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "Jobs Pending"
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
            ["AWS/Batch", "JobsRunning", "JobQueue", aws_batch_job_queue.spot.name],
            ["AWS/Batch", "JobsRunning", "JobQueue", aws_batch_job_queue.ondemand.name],
            ["AWS/Batch", "JobsRunning", "JobQueue", aws_batch_job_queue.hybrid.name]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "Jobs Running"
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
            ["AWS/Batch", "JobsFailed", "JobQueue", aws_batch_job_queue.spot.name],
            ["AWS/Batch", "JobsFailed", "JobQueue", aws_batch_job_queue.ondemand.name],
            ["AWS/Batch", "JobsFailed", "JobQueue", aws_batch_job_queue.hybrid.name]
          ]
          period = 300
          stat   = "Sum"
          region = var.region
          title  = "Jobs Failed"
        }
      }
    ]
  })
}

# CloudWatch Log Group for Batch Jobs
resource "aws_cloudwatch_log_group" "batch_logs" {
  name              = var.cloudwatch_log_group_name
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# CloudWatch Alarms for Batch Job Failures
resource "aws_cloudwatch_metric_alarm" "job_failures" {
  alarm_name          = "${var.name_prefix}-batch-job-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "JobsFailed"
  namespace           = "AWS/Batch"
  period              = 300
  statistic           = "Sum"
  threshold           = var.failure_alarm_threshold
  alarm_description   = "This alarm monitors AWS Batch job failures"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.ok_actions

  dimensions = {
    JobQueue = aws_batch_job_queue.hybrid.name
  }

  tags = var.tags
}