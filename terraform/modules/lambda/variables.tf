# Variables for Lambda Functions Module

# General Configuration
variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "video-super-resolution"
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

variable "presigned_url_generator_function_name" {
  description = "Name of the Lambda function that generates presigned S3 URLs for uploads"
  type        = string
  default     = "video-super-resolution-presigned-url-generator"
}

variable "intermediate_file_compression_function_name" {
  description = "Name of the Lambda function that compresses intermediate files"
  type        = string
  default     = "video-super-resolution-intermediate-file-compression"
}

variable "intermediate_file_cleanup_function_name" {
  description = "Name of the Lambda function that cleans up intermediate files"
  type        = string
  default     = "video-super-resolution-intermediate-file-cleanup"
}

variable "idle_instance_shutdown_function_name" {
  description = "Name of the Lambda function that shuts down idle instances"
  type        = string
  default     = "video-super-resolution-idle-instance-shutdown"
}

variable "sagemaker_endpoint_shutdown_function_name" {
  description = "Name of the Lambda function that shuts down idle SageMaker endpoints"
  type        = string
  default     = "video-super-resolution-sagemaker-endpoint-shutdown"
}

variable "resource_leak_monitor_function_name" {
  description = "Name of the Lambda function that monitors for resource leaks"
  type        = string
  default     = "video-super-resolution-resource-leak-monitor"
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

# Lambda Function Code
variable "pipeline_trigger_zip_path" {
  description = "Path to the zip file containing the pipeline trigger Lambda function code"
  type        = string
  default     = "lambda_functions/pipeline_trigger.zip"
}

variable "frame_extraction_zip_path" {
  description = "Path to the zip file containing the frame extraction Lambda function code"
  type        = string
  default     = "lambda_functions/frame_extraction.zip"
}

variable "frame_processing_zip_path" {
  description = "Path to the zip file containing the frame processing Lambda function code"
  type        = string
  default     = "lambda_functions/frame_processing.zip"
}

variable "video_recomposition_zip_path" {
  description = "Path to the zip file containing the video recomposition Lambda function code"
  type        = string
  default     = "lambda_functions/video_recomposition.zip"
}

variable "completion_notification_zip_path" {
  description = "Path to the zip file containing the completion notification Lambda function code"
  type        = string
  default     = "lambda_functions/completion_notification.zip"
}

variable "presigned_url_generator_zip_path" {
  description = "Path to the zip file containing the presigned URL generator Lambda function code"
  type        = string
  default     = "lambda_functions/presigned_url_generator.zip"
}

variable "intermediate_file_compression_zip_path" {
  description = "Path to the zip file containing the intermediate file compression Lambda function code"
  type        = string
  default     = "lambda_functions/intermediate_file_compression.zip"
}

variable "intermediate_file_cleanup_zip_path" {
  description = "Path to the zip file containing the intermediate file cleanup Lambda function code"
  type        = string
  default     = "lambda_functions/intermediate_file_cleanup.zip"
}

variable "idle_instance_shutdown_zip_path" {
  description = "Path to the zip file containing the idle instance shutdown Lambda function code"
  type        = string
  default     = "lambda_functions/idle_instance_shutdown.zip"
}

variable "sagemaker_endpoint_shutdown_zip_path" {
  description = "Path to the zip file containing the SageMaker endpoint shutdown Lambda function code"
  type        = string
  default     = "lambda_functions/sagemaker_endpoint_shutdown.zip"
}

variable "resource_leak_monitor_zip_path" {
  description = "Path to the zip file containing the resource leak monitor Lambda function code"
  type        = string
  default     = "lambda_functions/resource_leak_monitor.zip"
}

# IAM Role
variable "lambda_role_arn" {
  description = "ARN of the IAM role for Lambda functions"
  type        = string
}

# S3 Buckets
variable "source_bucket_name" {
  description = "Name of the S3 bucket for source videos"
  type        = string
}

variable "source_bucket_id" {
  description = "ID of the S3 bucket for source videos"
  type        = string
}

variable "source_bucket_arn" {
  description = "ARN of the S3 bucket for source videos"
  type        = string
}

variable "processed_frames_bucket_name" {
  description = "Name of the S3 bucket for processed frames"
  type        = string
}

variable "final_videos_bucket_name" {
  description = "Name of the S3 bucket for final videos"
  type        = string
}

# S3 Event Filter
variable "source_prefix" {
  description = "Prefix filter for S3 event notifications"
  type        = string
  default     = ""
}

variable "source_suffix" {
  description = "Suffix filter for S3 event notifications (e.g., .mp4)"
  type        = string
  default     = ".mp4"
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

# DynamoDB
variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for job metadata"
  type        = string
}

# AWS Batch
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

# Tags
variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
