# Outputs for Lambda Functions Module

# Lambda Function ARNs
output "pipeline_trigger_function_arn" {
  description = "The ARN of the pipeline trigger Lambda function"
  value       = aws_lambda_function.pipeline_trigger.arn
}

output "frame_extraction_function_arn" {
  description = "The ARN of the frame extraction Lambda function"
  value       = aws_lambda_function.frame_extraction.arn
}

output "frame_processing_function_arn" {
  description = "The ARN of the frame processing Lambda function"
  value       = aws_lambda_function.frame_processing.arn
}

output "video_recomposition_function_arn" {
  description = "The ARN of the video recomposition Lambda function"
  value       = aws_lambda_function.video_recomposition.arn
}

output "completion_notification_function_arn" {
  description = "The ARN of the completion notification Lambda function"
  value       = aws_lambda_function.completion_notification.arn
}

# Lambda Function Names
output "pipeline_trigger_function_name" {
  description = "The name of the pipeline trigger Lambda function"
  value       = aws_lambda_function.pipeline_trigger.function_name
}

output "frame_extraction_function_name" {
  description = "The name of the frame extraction Lambda function"
  value       = aws_lambda_function.frame_extraction.function_name
}

output "frame_processing_function_name" {
  description = "The name of the frame processing Lambda function"
  value       = aws_lambda_function.frame_processing.function_name
}

output "video_recomposition_function_name" {
  description = "The name of the video recomposition Lambda function"
  value       = aws_lambda_function.video_recomposition.function_name
}

output "completion_notification_function_name" {
  description = "The name of the completion notification Lambda function"
  value       = aws_lambda_function.completion_notification.function_name
}

output "presigned_url_generator_function_arn" {
  description = "The ARN of the presigned URL generator Lambda function"
  value       = aws_lambda_function.presigned_url_generator.arn
}

output "presigned_url_generator_function_name" {
  description = "The name of the presigned URL generator Lambda function"
  value       = aws_lambda_function.presigned_url_generator.function_name
}

# SNS Topic ARNs
output "extract_frames_topic_arn" {
  description = "The ARN of the extract frames SNS topic"
  value       = aws_sns_topic.extract_frames_topic.arn
}

output "processing_topic_arn" {
  description = "The ARN of the processing SNS topic"
  value       = aws_sns_topic.processing_topic.arn
}

output "recomposition_topic_arn" {
  description = "The ARN of the recomposition SNS topic"
  value       = aws_sns_topic.recomposition_topic.arn
}

output "notification_topic_arn" {
  description = "The ARN of the notification SNS topic"
  value       = aws_sns_topic.notification_topic.arn
}

output "email_notification_topic_arn" {
  description = "The ARN of the email notification SNS topic"
  value       = aws_sns_topic.email_notification_topic.arn
}

# All Lambda Function ARNs Map
output "all_function_arns" {
  description = "Map of all Lambda function ARNs"
  value = {
    pipeline_trigger        = aws_lambda_function.pipeline_trigger.arn
    frame_extraction        = aws_lambda_function.frame_extraction.arn
    frame_processing        = aws_lambda_function.frame_processing.arn
    video_recomposition     = aws_lambda_function.video_recomposition.arn
    completion_notification = aws_lambda_function.completion_notification.arn
    presigned_url_generator = aws_lambda_function.presigned_url_generator.arn
  }
}

# All SNS Topic ARNs Map
output "all_topic_arns" {
  description = "Map of all SNS topic ARNs"
  value = {
    extract_frames     = aws_sns_topic.extract_frames_topic.arn
    processing         = aws_sns_topic.processing_topic.arn
    recomposition      = aws_sns_topic.recomposition_topic.arn
    notification       = aws_sns_topic.notification_topic.arn
    email_notification = aws_sns_topic.email_notification_topic.arn
  }
}
