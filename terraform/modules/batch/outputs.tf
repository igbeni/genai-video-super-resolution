# Outputs for AWS Batch Compute Environments and Job Queues Module

# Compute Environment Outputs
output "spot_compute_environment_arn" {
  description = "The ARN of the Spot compute environment"
  value       = aws_batch_compute_environment.spot.arn
}

output "spot_compute_environment_name" {
  description = "The name of the Spot compute environment"
  value       = aws_batch_compute_environment.spot.compute_environment_name
}

output "ondemand_compute_environment_arn" {
  description = "The ARN of the On-Demand compute environment"
  value       = aws_batch_compute_environment.ondemand.arn
}

output "ondemand_compute_environment_name" {
  description = "The name of the On-Demand compute environment"
  value       = aws_batch_compute_environment.ondemand.compute_environment_name
}

# Job Queue Outputs
output "spot_job_queue_arn" {
  description = "The ARN of the Spot job queue"
  value       = aws_batch_job_queue.spot.arn
}

output "spot_job_queue_name" {
  description = "The name of the Spot job queue"
  value       = aws_batch_job_queue.spot.name
}

output "ondemand_job_queue_arn" {
  description = "The ARN of the On-Demand job queue"
  value       = aws_batch_job_queue.ondemand.arn
}

output "ondemand_job_queue_name" {
  description = "The name of the On-Demand job queue"
  value       = aws_batch_job_queue.ondemand.name
}

output "hybrid_job_queue_arn" {
  description = "The ARN of the hybrid job queue"
  value       = aws_batch_job_queue.hybrid.arn
}

output "hybrid_job_queue_name" {
  description = "The name of the hybrid job queue"
  value       = aws_batch_job_queue.hybrid.name
}

# Job Definition Outputs
output "frame_extraction_job_definition_arn" {
  description = "The ARN of the frame extraction job definition"
  value       = aws_batch_job_definition.frame_extraction.arn
}

output "frame_extraction_job_definition_name" {
  description = "The name of the frame extraction job definition"
  value       = aws_batch_job_definition.frame_extraction.name
}

output "frame_processing_job_definition_arn" {
  description = "The ARN of the frame processing job definition"
  value       = aws_batch_job_definition.frame_processing.arn
}

output "frame_processing_job_definition_name" {
  description = "The name of the frame processing job definition"
  value       = aws_batch_job_definition.frame_processing.name
}

output "video_recomposition_job_definition_arn" {
  description = "The ARN of the video recomposition job definition"
  value       = aws_batch_job_definition.video_recomposition.arn
}

output "video_recomposition_job_definition_name" {
  description = "The name of the video recomposition job definition"
  value       = aws_batch_job_definition.video_recomposition.name
}

# CloudWatch Outputs
output "cloudwatch_log_group_arn" {
  description = "The ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.batch_logs.arn
}

output "cloudwatch_log_group_name" {
  description = "The name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.batch_logs.name
}

output "cloudwatch_dashboard_name" {
  description = "The name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.batch_dashboard.dashboard_name
}

output "job_failures_alarm_arn" {
  description = "The ARN of the CloudWatch alarm for job failures"
  value       = aws_cloudwatch_metric_alarm.job_failures.arn
}

# All Resources Map
output "all_resources" {
  description = "Map of all resources created by this module"
  value = {
    spot_compute_environment_arn      = aws_batch_compute_environment.spot.arn
    ondemand_compute_environment_arn  = aws_batch_compute_environment.ondemand.arn
    spot_job_queue_arn                = aws_batch_job_queue.spot.arn
    ondemand_job_queue_arn            = aws_batch_job_queue.ondemand.arn
    hybrid_job_queue_arn              = aws_batch_job_queue.hybrid.arn
    frame_extraction_job_definition_arn = aws_batch_job_definition.frame_extraction.arn
    frame_processing_job_definition_arn = aws_batch_job_definition.frame_processing.arn
    video_recomposition_job_definition_arn = aws_batch_job_definition.video_recomposition.arn
    cloudwatch_log_group_arn          = aws_cloudwatch_log_group.batch_logs.arn
    cloudwatch_dashboard_name         = aws_cloudwatch_dashboard.batch_dashboard.dashboard_name
    job_failures_alarm_arn            = aws_cloudwatch_metric_alarm.job_failures.arn
  }
}