# Variables for IAM Roles and Policies Module

# Role Names
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

variable "sagemaker_role_name" {
  description = "Name of the IAM role for SageMaker"
  type        = string
  default     = "video-super-resolution-sagemaker-role"
}

# S3 Bucket ARNs
variable "source_bucket_arn" {
  description = "ARN of the S3 bucket for source videos"
  type        = string
}

variable "processed_frames_bucket_arn" {
  description = "ARN of the S3 bucket for processed frames"
  type        = string
}

variable "final_videos_bucket_arn" {
  description = "ARN of the S3 bucket for final videos"
  type        = string
}

# DynamoDB Table ARN
variable "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table for job metadata"
  type        = string
  default     = "" # Will be created in a future task
}

# Tags
variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

# Optional: Role Path
variable "role_path" {
  description = "Path for all IAM roles"
  type        = string
  default     = "/"
}

# Optional: Custom Policy Names
variable "custom_policy_name_prefix" {
  description = "Prefix for custom policy names"
  type        = string
  default     = "video-super-resolution-"
}
