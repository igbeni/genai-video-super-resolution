# Lambda Functions for Video Super-Resolution Pipeline Orchestration
# This module creates Lambda functions for:
# - Pipeline trigger on video upload
# - Frame extraction job creation
# - Processing status updates
# - Video recomposition job creation
# - Completion notification

# Lambda Function for Pipeline Trigger
resource "aws_lambda_function" "pipeline_trigger" {
  function_name = var.pipeline_trigger_function_name
  description   = "Triggers the video super-resolution pipeline when a new video is uploaded"

  role          = var.lambda_role_arn
  handler       = "pipeline_trigger.lambda_handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  filename      = var.pipeline_trigger_zip_path
  source_code_hash = filebase64sha256(var.pipeline_trigger_zip_path)

  environment {
    variables = {
      SOURCE_BUCKET      = var.source_bucket_name
      PROCESSED_BUCKET   = var.processed_frames_bucket_name
      FINAL_BUCKET       = var.final_videos_bucket_name
      DYNAMODB_TABLE     = var.dynamodb_table_name
      EXTRACT_FRAMES_SNS = aws_sns_topic.extract_frames_topic.arn
    }
  }

  tags = var.tags
}

# S3 Event Notification for Pipeline Trigger
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = var.source_bucket_id

  lambda_function {
    lambda_function_arn = aws_lambda_function.pipeline_trigger.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = var.source_prefix
    filter_suffix       = var.source_suffix
  }
}

# Lambda Permission for S3 Invocation
resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pipeline_trigger.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.source_bucket_arn
}

# SNS Topic for Frame Extraction
resource "aws_sns_topic" "extract_frames_topic" {
  name = var.extract_frames_topic_name
  tags = var.tags
}

# Lambda Function for Frame Extraction
resource "aws_lambda_function" "frame_extraction" {
  function_name = var.frame_extraction_function_name
  description   = "Creates and monitors frame extraction jobs"

  role          = var.lambda_role_arn
  handler       = "frame_extraction.lambda_handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  filename      = var.frame_extraction_zip_path
  source_code_hash = filebase64sha256(var.frame_extraction_zip_path)

  environment {
    variables = {
      SOURCE_BUCKET      = var.source_bucket_name
      PROCESSED_BUCKET   = var.processed_frames_bucket_name
      DYNAMODB_TABLE     = var.dynamodb_table_name
      BATCH_JOB_QUEUE    = var.batch_job_queue
      BATCH_JOB_DEFINITION = var.batch_job_definition
      PROCESSING_SNS     = aws_sns_topic.processing_topic.arn
    }
  }

  tags = var.tags
}

# SNS Subscription for Frame Extraction
resource "aws_sns_topic_subscription" "extract_frames_subscription" {
  topic_arn = aws_sns_topic.extract_frames_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.frame_extraction.arn
}

# Lambda Permission for SNS Invocation
resource "aws_lambda_permission" "allow_sns_extract_frames" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.frame_extraction.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.extract_frames_topic.arn
}

# SNS Topic for Frame Processing
resource "aws_sns_topic" "processing_topic" {
  name = var.processing_topic_name
  tags = var.tags
}

# Lambda Function for Frame Processing
resource "aws_lambda_function" "frame_processing" {
  function_name = var.frame_processing_function_name
  description   = "Creates and monitors frame processing jobs"

  role          = var.lambda_role_arn
  handler       = "frame_processing.lambda_handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  filename      = var.frame_processing_zip_path
  source_code_hash = filebase64sha256(var.frame_processing_zip_path)

  environment {
    variables = {
      PROCESSED_BUCKET   = var.processed_frames_bucket_name
      DYNAMODB_TABLE     = var.dynamodb_table_name
      BATCH_JOB_QUEUE    = var.batch_job_queue
      BATCH_JOB_DEFINITION = var.batch_job_definition
      RECOMPOSITION_SNS  = aws_sns_topic.recomposition_topic.arn
    }
  }

  tags = var.tags
}

# SNS Subscription for Frame Processing
resource "aws_sns_topic_subscription" "processing_subscription" {
  topic_arn = aws_sns_topic.processing_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.frame_processing.arn
}

# Lambda Permission for SNS Invocation
resource "aws_lambda_permission" "allow_sns_processing" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.frame_processing.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.processing_topic.arn
}

# SNS Topic for Video Recomposition
resource "aws_sns_topic" "recomposition_topic" {
  name = var.recomposition_topic_name
  tags = var.tags
}

# Lambda Function for Video Recomposition
resource "aws_lambda_function" "video_recomposition" {
  function_name = var.video_recomposition_function_name
  description   = "Creates and monitors video recomposition jobs"

  role          = var.lambda_role_arn
  handler       = "video_recomposition.lambda_handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  filename      = var.video_recomposition_zip_path
  source_code_hash = filebase64sha256(var.video_recomposition_zip_path)

  environment {
    variables = {
      PROCESSED_BUCKET   = var.processed_frames_bucket_name
      FINAL_BUCKET       = var.final_videos_bucket_name
      DYNAMODB_TABLE     = var.dynamodb_table_name
      BATCH_JOB_QUEUE    = var.batch_job_queue
      BATCH_JOB_DEFINITION = var.batch_job_definition
      NOTIFICATION_SNS   = aws_sns_topic.notification_topic.arn
    }
  }

  tags = var.tags
}

# SNS Subscription for Video Recomposition
resource "aws_sns_topic_subscription" "recomposition_subscription" {
  topic_arn = aws_sns_topic.recomposition_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.video_recomposition.arn
}

# Lambda Permission for SNS Invocation
resource "aws_lambda_permission" "allow_sns_recomposition" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.video_recomposition.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.recomposition_topic.arn
}

# SNS Topic for Completion Notification
resource "aws_sns_topic" "notification_topic" {
  name = var.notification_topic_name
  tags = var.tags
}

# Lambda Function for Completion Notification
resource "aws_lambda_function" "completion_notification" {
  function_name = var.completion_notification_function_name
  description   = "Sends notifications when video processing is complete"

  role          = var.lambda_role_arn
  handler       = "completion_notification.lambda_handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  filename      = var.completion_notification_zip_path
  source_code_hash = filebase64sha256(var.completion_notification_zip_path)

  environment {
    variables = {
      FINAL_BUCKET       = var.final_videos_bucket_name
      DYNAMODB_TABLE     = var.dynamodb_table_name
      EMAIL_SNS_TOPIC    = aws_sns_topic.email_notification_topic.arn
    }
  }

  tags = var.tags
}

# SNS Subscription for Completion Notification
resource "aws_sns_topic_subscription" "notification_subscription" {
  topic_arn = aws_sns_topic.notification_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.completion_notification.arn
}

# Lambda Permission for SNS Invocation
resource "aws_lambda_permission" "allow_sns_notification" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.completion_notification.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.notification_topic.arn
}

# SNS Topic for Email Notifications
resource "aws_sns_topic" "email_notification_topic" {
  name = var.email_notification_topic_name
  tags = var.tags
}

# Optional: SNS Topic Subscription for Email (requires confirmation)
resource "aws_sns_topic_subscription" "email_subscription" {
  count     = var.notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.email_notification_topic.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# Lambda Function for Presigned URL Generation
resource "aws_lambda_function" "presigned_url_generator" {
  function_name = var.presigned_url_generator_function_name
  description   = "Generates presigned S3 URLs for secure file uploads"

  role          = var.lambda_role_arn
  handler       = "presigned_url_generator.lambda_handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  filename      = var.presigned_url_generator_zip_path
  source_code_hash = filebase64sha256(var.presigned_url_generator_zip_path)

  environment {
    variables = {
      SOURCE_BUCKET   = var.source_bucket_name
      URL_EXPIRATION  = "900"  # Default to 15 minutes for security
    }
  }

  tags = var.tags
}

# API Gateway Permission for Lambda Invocation
resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.presigned_url_generator.function_name
  principal     = "apigateway.amazonaws.com"
}

# Lambda Function for Intermediate File Cleanup
resource "aws_lambda_function" "intermediate_file_cleanup" {
  function_name = var.intermediate_file_cleanup_function_name
  description   = "Cleans up intermediate files in the processed frames bucket after a job is completed"

  role          = var.lambda_role_arn
  handler       = "intermediate_file_cleanup.lambda_handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout * 2  # Double timeout for cleanup operations
  memory_size   = var.lambda_memory_size

  filename      = var.intermediate_file_cleanup_zip_path
  source_code_hash = filebase64sha256(var.intermediate_file_cleanup_zip_path)

  environment {
    variables = {
      PROCESSED_BUCKET   = var.processed_frames_bucket_name
      DYNAMODB_TABLE     = var.dynamodb_table_name
      RETENTION_DAYS     = "7"  # Default to 7 days
    }
  }

  tags = var.tags
}

# CloudWatch Event Rule for Intermediate File Cleanup (daily)
resource "aws_cloudwatch_event_rule" "intermediate_file_cleanup_rule" {
  name                = "${var.name_prefix}-intermediate-file-cleanup-rule"
  description         = "Triggers intermediate file cleanup Lambda function daily"
  schedule_expression = "rate(1 day)"

  tags = var.tags
}

# CloudWatch Event Target for Intermediate File Cleanup
resource "aws_cloudwatch_event_target" "intermediate_file_cleanup_target" {
  rule      = aws_cloudwatch_event_rule.intermediate_file_cleanup_rule.name
  target_id = "IntermediateFileCleanup"
  arn       = aws_lambda_function.intermediate_file_cleanup.arn
}

# Lambda Permission for CloudWatch Events
resource "aws_lambda_permission" "allow_cloudwatch_intermediate_file_cleanup" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.intermediate_file_cleanup.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.intermediate_file_cleanup_rule.arn
}

# Lambda Function for Intermediate File Compression
resource "aws_lambda_function" "intermediate_file_compression" {
  function_name = var.intermediate_file_compression_function_name
  description   = "Compresses intermediate files in the processed frames bucket to optimize storage costs"

  role          = var.lambda_role_arn
  handler       = "intermediate_file_compression.lambda_handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout * 2  # Double timeout for compression operations
  memory_size   = var.lambda_memory_size * 2  # Double memory for compression operations

  filename      = var.intermediate_file_compression_zip_path
  source_code_hash = filebase64sha256(var.intermediate_file_compression_zip_path)

  environment {
    variables = {
      PROCESSED_BUCKET   = var.processed_frames_bucket_name
      DYNAMODB_TABLE     = var.dynamodb_table_name
      COMPRESSION_AGE_DAYS = "3"  # Default to 3 days
      ENABLE_COMPRESSION = "true"
    }
  }

  tags = var.tags
}

# CloudWatch Event Rule for Intermediate File Compression (daily)
resource "aws_cloudwatch_event_rule" "intermediate_file_compression_rule" {
  name                = "${var.name_prefix}-intermediate-file-compression-rule"
  description         = "Triggers intermediate file compression Lambda function daily"
  schedule_expression = "rate(1 day)"

  tags = var.tags
}

# CloudWatch Event Target for Intermediate File Compression
resource "aws_cloudwatch_event_target" "intermediate_file_compression_target" {
  rule      = aws_cloudwatch_event_rule.intermediate_file_compression_rule.name
  target_id = "IntermediateFileCompression"
  arn       = aws_lambda_function.intermediate_file_compression.arn
}

# Lambda Permission for CloudWatch Events
resource "aws_lambda_permission" "allow_cloudwatch_intermediate_file_compression" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.intermediate_file_compression.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.intermediate_file_compression_rule.arn
}

# Lambda Function for Idle Instance Shutdown
resource "aws_lambda_function" "idle_instance_shutdown" {
  function_name = var.idle_instance_shutdown_function_name
  description   = "Monitors EC2 instances and shuts down idle instances"

  role          = var.lambda_role_arn
  handler       = "idle_instance_shutdown.lambda_handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  filename      = var.idle_instance_shutdown_zip_path
  source_code_hash = filebase64sha256(var.idle_instance_shutdown_zip_path)

  environment {
    variables = {
      IDLE_THRESHOLD_PERCENT = "10.0"  # Default to 10% CPU utilization
      IDLE_DURATION_MINUTES  = "30"    # Default to 30 minutes
      INSTANCE_TAG_KEY       = "Name"
      INSTANCE_TAG_VALUE     = var.name_prefix
    }
  }

  tags = var.tags
}

# CloudWatch Event Rule for Idle Instance Shutdown (every 15 minutes)
resource "aws_cloudwatch_event_rule" "idle_instance_shutdown_rule" {
  name                = "${var.name_prefix}-idle-instance-shutdown-rule"
  description         = "Triggers idle instance shutdown Lambda function every 15 minutes"
  schedule_expression = "rate(15 minutes)"

  tags = var.tags
}

# CloudWatch Event Target for Idle Instance Shutdown
resource "aws_cloudwatch_event_target" "idle_instance_shutdown_target" {
  rule      = aws_cloudwatch_event_rule.idle_instance_shutdown_rule.name
  target_id = "IdleInstanceShutdown"
  arn       = aws_lambda_function.idle_instance_shutdown.arn
}

# Lambda Permission for CloudWatch Events
resource "aws_lambda_permission" "allow_cloudwatch_idle_instance_shutdown" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.idle_instance_shutdown.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.idle_instance_shutdown_rule.arn
}

# Lambda Function for SageMaker Endpoint Shutdown
resource "aws_lambda_function" "sagemaker_endpoint_shutdown" {
  function_name = var.sagemaker_endpoint_shutdown_function_name
  description   = "Monitors SageMaker endpoints and shuts down idle endpoints"

  role          = var.lambda_role_arn
  handler       = "sagemaker_endpoint_shutdown.lambda_handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  filename      = var.sagemaker_endpoint_shutdown_zip_path
  source_code_hash = filebase64sha256(var.sagemaker_endpoint_shutdown_zip_path)

  environment {
    variables = {
      IDLE_THRESHOLD_INVOCATIONS = "5"     # Default to 5 invocations
      IDLE_DURATION_MINUTES      = "60"    # Default to 60 minutes
      ENDPOINT_NAME_PREFIX       = var.name_prefix
      DYNAMODB_TABLE             = var.dynamodb_table_name
    }
  }

  tags = var.tags
}

# CloudWatch Event Rule for SageMaker Endpoint Shutdown (hourly)
resource "aws_cloudwatch_event_rule" "sagemaker_endpoint_shutdown_rule" {
  name                = "${var.name_prefix}-sagemaker-endpoint-shutdown-rule"
  description         = "Triggers SageMaker endpoint shutdown Lambda function hourly"
  schedule_expression = "rate(1 hour)"

  tags = var.tags
}

# CloudWatch Event Target for SageMaker Endpoint Shutdown
resource "aws_cloudwatch_event_target" "sagemaker_endpoint_shutdown_target" {
  rule      = aws_cloudwatch_event_rule.sagemaker_endpoint_shutdown_rule.name
  target_id = "SageMakerEndpointShutdown"
  arn       = aws_lambda_function.sagemaker_endpoint_shutdown.arn
}

# Lambda Permission for CloudWatch Events
resource "aws_lambda_permission" "allow_cloudwatch_sagemaker_endpoint_shutdown" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sagemaker_endpoint_shutdown.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.sagemaker_endpoint_shutdown_rule.arn
}

# Lambda Function for Resource Leak Monitoring
resource "aws_lambda_function" "resource_leak_monitor" {
  function_name = var.resource_leak_monitor_function_name
  description   = "Monitors for resource leaks and cleans them up"

  role          = var.lambda_role_arn
  handler       = "resource_leak_monitor.lambda_handler"
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout * 2  # Double timeout for cleanup operations
  memory_size   = var.lambda_memory_size

  filename      = var.resource_leak_monitor_zip_path
  source_code_hash = filebase64sha256(var.resource_leak_monitor_zip_path)

  environment {
    variables = {
      ORPHANED_VOLUME_AGE_HOURS   = "24"    # Default to 24 hours
      ORPHANED_SNAPSHOT_AGE_DAYS  = "7"     # Default to 7 days
      SNS_TOPIC_ARN               = aws_sns_topic.resource_leak_topic.arn
    }
  }

  tags = var.tags
}

# SNS Topic for Resource Leak Notifications
resource "aws_sns_topic" "resource_leak_topic" {
  name = "${var.name_prefix}-resource-leak-topic"
  tags = var.tags
}

# CloudWatch Event Rule for Resource Leak Monitoring (daily)
resource "aws_cloudwatch_event_rule" "resource_leak_monitor_rule" {
  name                = "${var.name_prefix}-resource-leak-monitor-rule"
  description         = "Triggers resource leak monitoring Lambda function daily"
  schedule_expression = "rate(1 day)"

  tags = var.tags
}

# CloudWatch Event Target for Resource Leak Monitoring
resource "aws_cloudwatch_event_target" "resource_leak_monitor_target" {
  rule      = aws_cloudwatch_event_rule.resource_leak_monitor_rule.name
  target_id = "ResourceLeakMonitor"
  arn       = aws_lambda_function.resource_leak_monitor.arn
}

# Lambda Permission for CloudWatch Events
resource "aws_lambda_permission" "allow_cloudwatch_resource_leak_monitor" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.resource_leak_monitor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.resource_leak_monitor_rule.arn
}
