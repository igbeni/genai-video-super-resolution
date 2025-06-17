# Outputs for CloudTrail Module

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail trail"
  value       = aws_cloudtrail.api_activity_trail.arn
}

output "cloudtrail_id" {
  description = "ID of the CloudTrail trail"
  value       = aws_cloudtrail.api_activity_trail.id
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group for CloudTrail"
  value       = aws_cloudwatch_log_group.cloudtrail_logs.arn
}

output "cloudtrail_cloudwatch_role_arn" {
  description = "ARN of the IAM role for CloudTrail to CloudWatch Logs"
  value       = aws_iam_role.cloudtrail_cloudwatch_role.arn
}

output "unauthorized_api_calls_alarm_arn" {
  description = "ARN of the CloudWatch alarm for unauthorized API calls"
  value       = aws_cloudwatch_metric_alarm.unauthorized_api_calls.arn
}

output "root_account_usage_alarm_arn" {
  description = "ARN of the CloudWatch alarm for root account usage"
  value       = aws_cloudwatch_metric_alarm.root_account_usage.arn
}

output "iam_policy_changes_alarm_arn" {
  description = "ARN of the CloudWatch alarm for IAM policy changes"
  value       = aws_cloudwatch_metric_alarm.iam_policy_changes.arn
}