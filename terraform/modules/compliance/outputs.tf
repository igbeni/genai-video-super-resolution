# Outputs for Compliance Module

output "config_recorder_id" {
  description = "ID of the AWS Config configuration recorder"
  value       = aws_config_configuration_recorder.recorder.id
}

output "config_delivery_channel_id" {
  description = "ID of the AWS Config delivery channel"
  value       = aws_config_delivery_channel.delivery_channel.id
}

output "config_role_arn" {
  description = "ARN of the IAM role for AWS Config"
  value       = aws_iam_role.config_role.arn
}

output "config_rules" {
  description = "List of AWS Config rule names"
  value = [
    aws_config_config_rule.s3_bucket_public_read_prohibited.id,
    aws_config_config_rule.s3_bucket_public_write_prohibited.id,
    aws_config_config_rule.s3_bucket_ssl_requests_only.id,
    aws_config_config_rule.s3_bucket_server_side_encryption_enabled.id,
    aws_config_config_rule.cloudtrail_enabled.id,
    aws_config_config_rule.cloudwatch_log_group_encrypted.id
  ]
}

output "compliance_report_lambda_arn" {
  description = "ARN of the Lambda function for generating compliance reports"
  value       = aws_lambda_function.compliance_report_generator.arn
}

output "compliance_report_lambda_name" {
  description = "Name of the Lambda function for generating compliance reports"
  value       = aws_lambda_function.compliance_report_generator.function_name
}

output "compliance_report_schedule_arn" {
  description = "ARN of the CloudWatch event rule for scheduled report generation"
  value       = aws_cloudwatch_event_rule.compliance_report_schedule.arn
}

output "lambda_role_arn" {
  description = "ARN of the IAM role for the compliance report Lambda function"
  value       = aws_iam_role.lambda_role.arn
}