# Root Variables for Video Super-Resolution Pipeline

variable "aws_region" {
  description = "The AWS region to deploy resources into"
  type        = string
  default     = "us-east-1"
}

variable "default_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "Video-Super-Resolution"
    Environment = "dev"
    Terraform   = "true"
  }
}

# S3 Bucket Names
variable "source_bucket_name" {
  description = "Name of the S3 bucket for source videos"
  type        = string
  default     = "video-super-resolution-source"
}

variable "processed_frames_bucket_name" {
  description = "Name of the S3 bucket for processed frames"
  type        = string
  default     = "video-super-resolution-frames"
}

variable "final_videos_bucket_name" {
  description = "Name of the S3 bucket for final videos"
  type        = string
  default     = "video-super-resolution-final"
}

# S3 Bucket Configuration
variable "enable_versioning" {
  description = "Enable versioning for S3 buckets"
  type        = bool
  default     = false
}

variable "enable_lifecycle_rules" {
  description = "Enable lifecycle rules for intermediate artifacts"
  type        = bool
  default     = true
}

variable "intermediate_files_expiration_days" {
  description = "Number of days after which intermediate files will be deleted"
  type        = number
  default     = 7
}

# Optional AWS Assume Role ARN
variable "aws_assume_role_arn" {
  description = "ARN of the IAM role to assume (optional)"
  type        = string
  default     = ""
}

# IAM Role Names
variable "lambda_role_name" {
  description = "Name of the IAM role for Lambda functions"
  type        = string
  default     = "video-super-resolution-lambda-role"
}

variable "ec2_role_name" {
  description = "Name of the IAM role for EC2 processing instances"
  type        = string
  default     = "video-super-resolution-ec2-role"
}

variable "batch_service_role_name" {
  description = "Name of the IAM role for AWS Batch service"
  type        = string
  default     = "video-super-resolution-batch-service-role"
}

variable "batch_job_role_name" {
  description = "Name of the IAM role for AWS Batch jobs"
  type        = string
  default     = "video-super-resolution-batch-job-role"
}

# DynamoDB Table ARN (will be created in a future task)
variable "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table for job metadata"
  type        = string
  default     = ""
}

# DynamoDB Table Name (will be created in a future task)
variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for job metadata"
  type        = string
  default     = "video-super-resolution-jobs"
}

# Lambda Function Names
variable "pipeline_trigger_function_name" {
  description = "Name of the Lambda function that triggers the pipeline"
  type        = string
  default     = "video-super-resolution-pipeline-trigger"
}

variable "frame_extraction_function_name" {
  description = "Name of the Lambda function that handles frame extraction"
  type        = string
  default     = "video-super-resolution-frame-extraction"
}

variable "frame_processing_function_name" {
  description = "Name of the Lambda function that handles frame processing"
  type        = string
  default     = "video-super-resolution-frame-processing"
}

variable "video_recomposition_function_name" {
  description = "Name of the Lambda function that handles video recomposition"
  type        = string
  default     = "video-super-resolution-video-recomposition"
}

variable "completion_notification_function_name" {
  description = "Name of the Lambda function that sends completion notifications"
  type        = string
  default     = "video-super-resolution-completion-notification"
}

# Lambda Function Configuration
variable "lambda_runtime" {
  description = "Runtime for Lambda functions"
  type        = string
  default     = "python3.9"
}

variable "lambda_timeout" {
  description = "Timeout for Lambda functions in seconds"
  type        = number
  default     = 300
}

variable "lambda_memory_size" {
  description = "Memory size for Lambda functions in MB"
  type        = number
  default     = 256
}

# SNS Topics
variable "extract_frames_topic_name" {
  description = "Name of the SNS topic for frame extraction"
  type        = string
  default     = "video-super-resolution-extract-frames"
}

variable "processing_topic_name" {
  description = "Name of the SNS topic for frame processing"
  type        = string
  default     = "video-super-resolution-processing"
}

variable "recomposition_topic_name" {
  description = "Name of the SNS topic for video recomposition"
  type        = string
  default     = "video-super-resolution-recomposition"
}

variable "notification_topic_name" {
  description = "Name of the SNS topic for completion notifications"
  type        = string
  default     = "video-super-resolution-notification"
}

variable "email_notification_topic_name" {
  description = "Name of the SNS topic for email notifications"
  type        = string
  default     = "video-super-resolution-email-notification"
}

# Email Notification
variable "notification_email" {
  description = "Email address to send notifications to (leave empty to disable)"
  type        = string
  default     = ""
}

# AWS Batch (will be created in a future task)
variable "batch_job_queue" {
  description = "ARN of the AWS Batch job queue"
  type        = string
  default     = ""
}

variable "batch_job_definition" {
  description = "ARN of the AWS Batch job definition"
  type        = string
  default     = ""
}

# SQS Queue Names
variable "frame_extraction_queue_name" {
  description = "Name of the SQS queue for frame extraction jobs"
  type        = string
  default     = "video-super-resolution-frame-extraction-queue"
}

variable "frame_processing_queue_name" {
  description = "Name of the SQS queue for frame processing jobs"
  type        = string
  default     = "video-super-resolution-frame-processing-queue"
}

variable "video_recomposition_queue_name" {
  description = "Name of the SQS queue for video recomposition jobs"
  type        = string
  default     = "video-super-resolution-video-recomposition-queue"
}

variable "completion_notification_queue_name" {
  description = "Name of the SQS queue for completion notification jobs"
  type        = string
  default     = "video-super-resolution-completion-notification-queue"
}

# Step Functions Configuration
variable "state_machine_name" {
  description = "Name of the Step Functions state machine for video processing orchestration"
  type        = string
  default     = "video-super-resolution-workflow"
}

# SQS Queue Configuration
variable "sqs_delay_seconds" {
  description = "The time in seconds that the delivery of all messages in the queue will be delayed"
  type        = number
  default     = 0
}

variable "sqs_max_message_size" {
  description = "The limit of how many bytes a message can contain before Amazon SQS rejects it"
  type        = number
  default     = 262144  # 256 KiB
}

variable "sqs_message_retention_seconds" {
  description = "The number of seconds Amazon SQS retains a message"
  type        = number
  default     = 345600  # 4 days
}

variable "sqs_receive_wait_time_seconds" {
  description = "The time for which a ReceiveMessage call will wait for a message to arrive"
  type        = number
  default     = 20
}

variable "sqs_visibility_timeout_seconds" {
  description = "The visibility timeout for the queue"
  type        = number
  default     = 30
}

variable "sqs_max_receive_count" {
  description = "The number of times a message can be received before being sent to the dead-letter queue"
  type        = number
  default     = 5
}

variable "sqs_dlq_message_retention_seconds" {
  description = "The number of seconds Amazon SQS retains a message in the dead-letter queue"
  type        = number
  default     = 1209600  # 14 days
}

# SageMaker Configuration
variable "sagemaker_role_name" {
  description = "Name of the IAM role for SageMaker"
  type        = string
  default     = "video-super-resolution-sagemaker-role"
}

# Real-ESRGAN SageMaker Configuration
variable "realesrgan_image_uri" {
  description = "URI of the Real-ESRGAN Docker image in ECR"
  type        = string
  default     = ""  # This should be set in terraform.tfvars
}

variable "realesrgan_model_data_url" {
  description = "S3 URL to the Real-ESRGAN model data"
  type        = string
  default     = null  # If model is included in the container, this can be null
}

variable "realesrgan_instance_type" {
  description = "Instance type for Real-ESRGAN endpoint"
  type        = string
  default     = "ml.g4dn.xlarge"  # GPU instance suitable for inference
}

variable "realesrgan_instance_count" {
  description = "Initial number of instances for Real-ESRGAN endpoint"
  type        = number
  default     = 1
}

# SwinIR SageMaker Configuration
variable "swinir_image_uri" {
  description = "URI of the SwinIR Docker image in ECR"
  type        = string
  default     = ""  # This should be set in terraform.tfvars
}

variable "swinir_model_data_url" {
  description = "S3 URL to the SwinIR model data"
  type        = string
  default     = null  # If model is included in the container, this can be null
}

variable "swinir_instance_type" {
  description = "Instance type for SwinIR endpoint"
  type        = string
  default     = "ml.g4dn.xlarge"  # GPU instance suitable for inference
}

variable "swinir_instance_count" {
  description = "Initial number of instances for SwinIR endpoint"
  type        = number
  default     = 1
}

# SageMaker Auto-scaling Configuration
variable "sagemaker_min_capacity" {
  description = "Minimum capacity for SageMaker endpoint auto-scaling"
  type        = number
  default     = 1
}

variable "sagemaker_max_capacity" {
  description = "Maximum capacity for SageMaker endpoint auto-scaling"
  type        = number
  default     = 4
}

variable "sagemaker_target_cpu_utilization" {
  description = "Target CPU utilization for auto-scaling"
  type        = number
  default     = 75  # 75% CPU utilization
}

# SageMaker CloudWatch Alarm Configuration
variable "sagemaker_error_threshold" {
  description = "Threshold for SageMaker endpoint error alarms"
  type        = number
  default     = 5  # 5 errors
}
