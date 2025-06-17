# Outputs for SQS Queues Module

# Frame Extraction Queue
output "frame_extraction_queue_arn" {
  description = "ARN of the frame extraction queue"
  value       = aws_sqs_queue.frame_extraction_queue.arn
}

output "frame_extraction_queue_url" {
  description = "URL of the frame extraction queue"
  value       = aws_sqs_queue.frame_extraction_queue.id
}

output "frame_extraction_dlq_arn" {
  description = "ARN of the frame extraction dead-letter queue"
  value       = aws_sqs_queue.frame_extraction_dlq.arn
}

output "frame_extraction_dlq_url" {
  description = "URL of the frame extraction dead-letter queue"
  value       = aws_sqs_queue.frame_extraction_dlq.id
}

# Frame Processing Queue
output "frame_processing_queue_arn" {
  description = "ARN of the frame processing queue"
  value       = aws_sqs_queue.frame_processing_queue.arn
}

output "frame_processing_queue_url" {
  description = "URL of the frame processing queue"
  value       = aws_sqs_queue.frame_processing_queue.id
}

output "frame_processing_dlq_arn" {
  description = "ARN of the frame processing dead-letter queue"
  value       = aws_sqs_queue.frame_processing_dlq.arn
}

output "frame_processing_dlq_url" {
  description = "URL of the frame processing dead-letter queue"
  value       = aws_sqs_queue.frame_processing_dlq.id
}

# Video Recomposition Queue
output "video_recomposition_queue_arn" {
  description = "ARN of the video recomposition queue"
  value       = aws_sqs_queue.video_recomposition_queue.arn
}

output "video_recomposition_queue_url" {
  description = "URL of the video recomposition queue"
  value       = aws_sqs_queue.video_recomposition_queue.id
}

output "video_recomposition_dlq_arn" {
  description = "ARN of the video recomposition dead-letter queue"
  value       = aws_sqs_queue.video_recomposition_dlq.arn
}

output "video_recomposition_dlq_url" {
  description = "URL of the video recomposition dead-letter queue"
  value       = aws_sqs_queue.video_recomposition_dlq.id
}

# Completion Notification Queue
output "completion_notification_queue_arn" {
  description = "ARN of the completion notification queue"
  value       = aws_sqs_queue.completion_notification_queue.arn
}

output "completion_notification_queue_url" {
  description = "URL of the completion notification queue"
  value       = aws_sqs_queue.completion_notification_queue.id
}

output "completion_notification_dlq_arn" {
  description = "ARN of the completion notification dead-letter queue"
  value       = aws_sqs_queue.completion_notification_dlq.arn
}

output "completion_notification_dlq_url" {
  description = "URL of the completion notification dead-letter queue"
  value       = aws_sqs_queue.completion_notification_dlq.id
}

# All Queue ARNs and URLs
output "queue_arns" {
  description = "Map of all queue ARNs"
  value = {
    frame_extraction       = aws_sqs_queue.frame_extraction_queue.arn
    frame_extraction_dlq   = aws_sqs_queue.frame_extraction_dlq.arn
    frame_processing       = aws_sqs_queue.frame_processing_queue.arn
    frame_processing_dlq   = aws_sqs_queue.frame_processing_dlq.arn
    video_recomposition    = aws_sqs_queue.video_recomposition_queue.arn
    video_recomposition_dlq = aws_sqs_queue.video_recomposition_dlq.arn
    completion_notification = aws_sqs_queue.completion_notification_queue.arn
    completion_notification_dlq = aws_sqs_queue.completion_notification_dlq.arn
  }
}

output "queue_urls" {
  description = "Map of all queue URLs"
  value = {
    frame_extraction       = aws_sqs_queue.frame_extraction_queue.id
    frame_extraction_dlq   = aws_sqs_queue.frame_extraction_dlq.id
    frame_processing       = aws_sqs_queue.frame_processing_queue.id
    frame_processing_dlq   = aws_sqs_queue.frame_processing_dlq.id
    video_recomposition    = aws_sqs_queue.video_recomposition_queue.id
    video_recomposition_dlq = aws_sqs_queue.video_recomposition_dlq.id
    completion_notification = aws_sqs_queue.completion_notification_queue.id
    completion_notification_dlq = aws_sqs_queue.completion_notification_dlq.id
  }
}

# SNS Topic Subscription ARNs
output "sns_subscription_arns" {
  description = "Map of SNS topic subscription ARNs"
  value = {
    frame_extraction       = aws_sns_topic_subscription.frame_extraction_subscription.arn
    frame_processing       = aws_sns_topic_subscription.frame_processing_subscription.arn
    video_recomposition    = aws_sns_topic_subscription.video_recomposition_subscription.arn
    completion_notification = aws_sns_topic_subscription.completion_notification_subscription.arn
  }
}