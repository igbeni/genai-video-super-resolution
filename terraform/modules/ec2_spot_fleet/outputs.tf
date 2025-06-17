# Outputs for EC2 Spot Fleet Configurations Module

# Spot Fleet Request
output "spot_fleet_request_id" {
  description = "The ID of the Spot Fleet request"
  value       = aws_spot_fleet_request.processing_fleet.id
}

output "spot_fleet_request_state" {
  description = "The state of the Spot Fleet request"
  value       = aws_spot_fleet_request.processing_fleet.spot_request_state
}

output "spot_fleet_target_capacity" {
  description = "The target capacity of the Spot Fleet request"
  value       = aws_spot_fleet_request.processing_fleet.target_capacity
}

# Note: Fulfilled capacity is not directly available as an output
# It can be monitored through CloudWatch metrics

# CloudWatch Resources
output "spot_capacity_alarm_arn" {
  description = "The ARN of the CloudWatch alarm for Spot Fleet capacity"
  value       = aws_cloudwatch_metric_alarm.spot_capacity_alarm.arn
}

output "spot_fleet_dashboard_name" {
  description = "The name of the CloudWatch dashboard for Spot Fleet monitoring"
  value       = aws_cloudwatch_dashboard.spot_fleet_dashboard.dashboard_name
}

# SNS Topics
output "spot_interruption_topic_arn" {
  description = "The ARN of the SNS topic for Spot instance interruption notifications"
  value       = aws_sns_topic.spot_interruption_topic.arn
}

output "spot_interruption_topic_name" {
  description = "The name of the SNS topic for Spot instance interruption notifications"
  value       = aws_sns_topic.spot_interruption_topic.name
}

# Lambda Function
output "spot_interruption_handler_arn" {
  description = "The ARN of the Lambda function for handling Spot instance interruptions"
  value       = var.create_interruption_handler ? aws_lambda_function.spot_interruption_handler[0].arn : null
}

output "spot_interruption_handler_name" {
  description = "The name of the Lambda function for handling Spot instance interruptions"
  value       = var.create_interruption_handler ? aws_lambda_function.spot_interruption_handler[0].function_name : null
}

# CloudWatch Event Rule
output "spot_interruption_warning_rule_arn" {
  description = "The ARN of the CloudWatch event rule for Spot instance interruption warnings"
  value       = aws_cloudwatch_event_rule.spot_interruption_warning.arn
}

output "spot_interruption_warning_rule_name" {
  description = "The name of the CloudWatch event rule for Spot instance interruption warnings"
  value       = aws_cloudwatch_event_rule.spot_interruption_warning.name
}

# All Resources Map
output "all_resources" {
  description = "Map of all resources created by this module"
  value = {
    spot_fleet_request_id         = aws_spot_fleet_request.processing_fleet.id
    spot_capacity_alarm_arn       = aws_cloudwatch_metric_alarm.spot_capacity_alarm.arn
    spot_fleet_dashboard_name     = aws_cloudwatch_dashboard.spot_fleet_dashboard.dashboard_name
    spot_interruption_topic_arn   = aws_sns_topic.spot_interruption_topic.arn
    spot_interruption_warning_arn = aws_cloudwatch_event_rule.spot_interruption_warning.arn
    spot_interruption_handler_arn = var.create_interruption_handler ? aws_lambda_function.spot_interruption_handler[0].arn : null
  }
}
