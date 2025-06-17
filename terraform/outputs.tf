# Root Outputs for Video Super-Resolution Pipeline

# S3 Bucket Outputs
output "source_bucket_id" {
  description = "The ID of the source videos bucket"
  value       = module.s3_buckets.source_bucket_id
}

output "source_bucket_arn" {
  description = "The ARN of the source videos bucket"
  value       = module.s3_buckets.source_bucket_arn
}

output "processed_frames_bucket_id" {
  description = "The ID of the processed frames bucket"
  value       = module.s3_buckets.processed_frames_bucket_id
}

output "processed_frames_bucket_arn" {
  description = "The ARN of the processed frames bucket"
  value       = module.s3_buckets.processed_frames_bucket_arn
}

output "final_videos_bucket_id" {
  description = "The ID of the final videos bucket"
  value       = module.s3_buckets.final_videos_bucket_id
}

output "final_videos_bucket_arn" {
  description = "The ARN of the final videos bucket"
  value       = module.s3_buckets.final_videos_bucket_arn
}

# Map of all bucket IDs and ARNs
output "all_bucket_ids" {
  description = "Map of all bucket IDs"
  value       = module.s3_buckets.all_bucket_ids
}

output "all_bucket_arns" {
  description = "Map of all bucket ARNs"
  value       = module.s3_buckets.all_bucket_arns
}

# IAM Role Outputs
output "lambda_role_arn" {
  description = "The ARN of the Lambda execution role"
  value       = module.iam_roles.lambda_role_arn
}

output "ec2_role_arn" {
  description = "The ARN of the EC2 processing role"
  value       = module.iam_roles.ec2_role_arn
}

output "ec2_instance_profile_name" {
  description = "The name of the EC2 instance profile"
  value       = module.iam_roles.ec2_instance_profile_name
}

output "batch_service_role_arn" {
  description = "The ARN of the AWS Batch service role"
  value       = module.iam_roles.batch_service_role_arn
}

output "batch_job_role_arn" {
  description = "The ARN of the AWS Batch job role"
  value       = module.iam_roles.batch_job_role_arn
}

# Map of all IAM role ARNs
output "all_role_arns" {
  description = "Map of all IAM role ARNs"
  value       = module.iam_roles.all_role_arns
}

# Lambda Function ARNs
output "pipeline_trigger_function_arn" {
  description = "The ARN of the pipeline trigger Lambda function"
  value       = module.lambda_functions.pipeline_trigger_function_arn
}

output "frame_extraction_function_arn" {
  description = "The ARN of the frame extraction Lambda function"
  value       = module.lambda_functions.frame_extraction_function_arn
}

output "frame_processing_function_arn" {
  description = "The ARN of the frame processing Lambda function"
  value       = module.lambda_functions.frame_processing_function_arn
}

output "video_recomposition_function_arn" {
  description = "The ARN of the video recomposition Lambda function"
  value       = module.lambda_functions.video_recomposition_function_arn
}

output "completion_notification_function_arn" {
  description = "The ARN of the completion notification Lambda function"
  value       = module.lambda_functions.completion_notification_function_arn
}

# SNS Topic ARNs
output "extract_frames_topic_arn" {
  description = "The ARN of the extract frames SNS topic"
  value       = module.lambda_functions.extract_frames_topic_arn
}

output "processing_topic_arn" {
  description = "The ARN of the processing SNS topic"
  value       = module.lambda_functions.processing_topic_arn
}

output "recomposition_topic_arn" {
  description = "The ARN of the recomposition SNS topic"
  value       = module.lambda_functions.recomposition_topic_arn
}

output "notification_topic_arn" {
  description = "The ARN of the notification SNS topic"
  value       = module.lambda_functions.notification_topic_arn
}

output "email_notification_topic_arn" {
  description = "The ARN of the email notification SNS topic"
  value       = module.lambda_functions.email_notification_topic_arn
}

# Maps of all Lambda Function and SNS Topic ARNs
output "all_function_arns" {
  description = "Map of all Lambda function ARNs"
  value       = module.lambda_functions.all_function_arns
}

output "all_topic_arns" {
  description = "Map of all SNS topic ARNs"
  value       = module.lambda_functions.all_topic_arns
}

# Additional outputs will be added as more resources are created
