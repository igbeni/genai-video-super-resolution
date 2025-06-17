# Main Terraform Configuration for Video Super-Resolution Pipeline

# DynamoDB Table for Job Metadata
module "dynamodb" {
  source = "./modules/dynamodb"

  # Table name
  dynamodb_table_name = var.dynamodb_table_name

  # Tags
  tags = var.default_tags
}

# S3 Buckets for Video Super-Resolution Pipeline
module "s3_buckets" {
  source = "./modules/s3"

  # Bucket names
  source_bucket_name           = var.source_bucket_name
  processed_frames_bucket_name = var.processed_frames_bucket_name
  final_videos_bucket_name     = var.final_videos_bucket_name
  access_logs_bucket_name      = var.access_logs_bucket_name

  # Bucket configuration
  enable_versioning                  = var.enable_versioning
  enable_lifecycle_rules             = var.enable_lifecycle_rules
  intermediate_files_expiration_days = var.intermediate_files_expiration_days

  # Tags
  tags = var.default_tags
}
# IAM Roles and Policies with Least Privilege
module "iam_roles" {
  source = "./modules/iam"

  # Role names
  lambda_role_name        = var.lambda_role_name
  ec2_role_name           = var.ec2_role_name
  batch_service_role_name = var.batch_service_role_name
  batch_job_role_name     = var.batch_job_role_name

  # S3 Bucket ARNs
  source_bucket_arn           = module.s3_buckets.source_bucket_arn
  processed_frames_bucket_arn = module.s3_buckets.processed_frames_bucket_arn
  final_videos_bucket_arn     = module.s3_buckets.final_videos_bucket_arn

  # DynamoDB Table ARN
  dynamodb_table_arn = module.dynamodb.dynamodb_table_arn

  # Tags
  tags = var.default_tags
}

# Lambda Functions for Pipeline Orchestration
module "lambda_functions" {
  source = "./modules/lambda"

  # IAM Role
  lambda_role_arn = module.iam_roles.lambda_role_arn

  # S3 Buckets
  source_bucket_name           = var.source_bucket_name
  source_bucket_id             = module.s3_buckets.source_bucket_id
  source_bucket_arn            = module.s3_buckets.source_bucket_arn
  processed_frames_bucket_name = var.processed_frames_bucket_name
  final_videos_bucket_name     = var.final_videos_bucket_name

  # DynamoDB
  dynamodb_table_name = module.dynamodb.dynamodb_table_name

  # Lambda Function Names
  pipeline_trigger_function_name        = var.pipeline_trigger_function_name
  frame_extraction_function_name        = var.frame_extraction_function_name
  frame_processing_function_name        = var.frame_processing_function_name
  video_recomposition_function_name     = var.video_recomposition_function_name
  completion_notification_function_name = var.completion_notification_function_name

  # Lambda Function Configuration
  lambda_runtime     = var.lambda_runtime
  lambda_timeout     = var.lambda_timeout
  lambda_memory_size = var.lambda_memory_size

  # SNS Topics
  extract_frames_topic_name     = var.extract_frames_topic_name
  processing_topic_name         = var.processing_topic_name
  recomposition_topic_name      = var.recomposition_topic_name
  notification_topic_name       = var.notification_topic_name
  email_notification_topic_name = var.email_notification_topic_name
  notification_email            = var.notification_email

  # AWS Batch (will be created in a future task)
  batch_job_queue      = var.batch_job_queue
  batch_job_definition = var.batch_job_definition

  # Tags
  tags = var.default_tags
}

# SQS Queues for Job Coordination
module "sqs_queues" {
  source = "./modules/sqs"

  # Queue Names
  frame_extraction_queue_name        = var.frame_extraction_queue_name
  frame_processing_queue_name        = var.frame_processing_queue_name
  video_recomposition_queue_name     = var.video_recomposition_queue_name
  completion_notification_queue_name = var.completion_notification_queue_name

  # Queue Configuration
  delay_seconds                 = var.sqs_delay_seconds
  max_message_size              = var.sqs_max_message_size
  message_retention_seconds     = var.sqs_message_retention_seconds
  receive_wait_time_seconds     = var.sqs_receive_wait_time_seconds
  visibility_timeout_seconds    = var.sqs_visibility_timeout_seconds
  max_receive_count             = var.sqs_max_receive_count
  dlq_message_retention_seconds = var.sqs_dlq_message_retention_seconds

  # SNS Topic ARNs
  extract_frames_topic_arn = module.lambda_functions.extract_frames_topic_arn
  processing_topic_arn     = module.lambda_functions.processing_topic_arn
  recomposition_topic_arn  = module.lambda_functions.recomposition_topic_arn
  notification_topic_arn   = module.lambda_functions.notification_topic_arn

  # Tags
  tags = var.default_tags
}

# Step Functions for Pipeline Orchestration
module "step_functions" {
  source = "./modules/step_functions"

  # State Machine Configuration
  state_machine_name = var.state_machine_name

  # Lambda Function ARNs
  frame_extraction_function_arn        = module.lambda_functions.frame_extraction_function_arn
  frame_processing_function_arn        = module.lambda_functions.frame_processing_function_arn
  video_recomposition_function_arn     = module.lambda_functions.video_recomposition_function_arn
  completion_notification_function_arn = module.lambda_functions.completion_notification_function_arn

  # Tags
  tags = var.default_tags
}

# SageMaker Endpoints for AI Model Deployment
module "sagemaker_endpoints" {
  source = "./modules/sagemaker"

  # SageMaker Role
  sagemaker_role_arn = module.iam_roles.sagemaker_role_arn

  # Docker Image URIs
  realesrgan_image_uri = var.realesrgan_image_uri
  swinir_image_uri     = var.swinir_image_uri

  # Model Data URLs (if models are stored in S3)
  realesrgan_model_data_url = var.realesrgan_model_data_url
  swinir_model_data_url     = var.swinir_model_data_url

  # Instance Types
  realesrgan_instance_type = var.realesrgan_instance_type
  swinir_instance_type     = var.swinir_instance_type

  # Instance Counts
  realesrgan_instance_count = var.realesrgan_instance_count
  swinir_instance_count     = var.swinir_instance_count

  # Auto-scaling Configuration
  min_endpoint_capacity  = var.sagemaker_min_capacity
  max_endpoint_capacity  = var.sagemaker_max_capacity
  target_cpu_utilization = var.sagemaker_target_cpu_utilization

  # CloudWatch Alarms
  error_threshold = var.sagemaker_error_threshold
  alarm_actions   = [module.lambda_functions.notification_topic_arn]
  ok_actions      = [module.lambda_functions.notification_topic_arn]

  # Tags
  tags = var.default_tags
}

# Additional resources will be added in future tasks:
# - EC2 Spot Fleet
# - AWS Batch
# - CloudWatch resources
