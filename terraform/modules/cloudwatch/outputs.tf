# Outputs for CloudWatch Dashboards, Alarms, and Log Groups Module

# Dashboard Outputs
output "main_dashboard_name" {
  description = "The name of the main CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.main_dashboard.dashboard_name
}

output "performance_dashboard_name" {
  description = "The name of the performance CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.performance_dashboard.dashboard_name
}

output "cost_dashboard_name" {
  description = "The name of the cost CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.cost_dashboard.dashboard_name
}

# Log Group Outputs
output "lambda_log_group_arns" {
  description = "Map of Lambda function log group ARNs"
  value       = { for k, v in aws_cloudwatch_log_group.lambda_logs : k => v.arn }
}

output "ec2_log_group_arn" {
  description = "The ARN of the EC2 log group"
  value       = aws_cloudwatch_log_group.ec2_logs.arn
}

# Alarm Outputs
output "lambda_error_alarm_arns" {
  description = "Map of Lambda function error alarm ARNs"
  value       = { for k, v in aws_cloudwatch_metric_alarm.lambda_errors : k => v.arn }
}

output "s3_storage_alarm_arns" {
  description = "Map of S3 bucket storage alarm ARNs"
  value       = { for k, v in aws_cloudwatch_metric_alarm.s3_storage_alarm : k => v.arn }
}

output "ec2_cpu_alarm_arns" {
  description = "Map of EC2 CPU alarm ARNs"
  value       = { for k, v in aws_cloudwatch_metric_alarm.ec2_cpu_alarm : k => v.arn }
}

output "pipeline_health_alarm_arn" {
  description = "The ARN of the pipeline health composite alarm"
  value       = aws_cloudwatch_composite_alarm.pipeline_health.arn
}

# Event Rule Outputs
output "pipeline_completion_rule_arn" {
  description = "The ARN of the pipeline completion event rule"
  value       = aws_cloudwatch_event_rule.pipeline_completion.arn
}

output "pipeline_failure_rule_arn" {
  description = "The ARN of the pipeline failure event rule"
  value       = aws_cloudwatch_event_rule.pipeline_failure.arn
}

# All Resources Map
output "all_resources" {
  description = "Map of all resources created by this module"
  value = {
    dashboards = {
      main        = aws_cloudwatch_dashboard.main_dashboard.dashboard_name
      performance = aws_cloudwatch_dashboard.performance_dashboard.dashboard_name
      cost        = aws_cloudwatch_dashboard.cost_dashboard.dashboard_name
    }
    log_groups = {
      lambda = { for k, v in aws_cloudwatch_log_group.lambda_logs : k => v.name }
      ec2    = aws_cloudwatch_log_group.ec2_logs.name
    }
    alarms = {
      lambda_errors   = { for k, v in aws_cloudwatch_metric_alarm.lambda_errors : k => v.alarm_name }
      s3_storage      = { for k, v in aws_cloudwatch_metric_alarm.s3_storage_alarm : k => v.alarm_name }
      ec2_cpu         = { for k, v in aws_cloudwatch_metric_alarm.ec2_cpu_alarm : k => v.alarm_name }
      pipeline_health = aws_cloudwatch_composite_alarm.pipeline_health.alarm_name
    }
    event_rules = {
      pipeline_completion = aws_cloudwatch_event_rule.pipeline_completion.name
      pipeline_failure    = aws_cloudwatch_event_rule.pipeline_failure.name
    }
  }
}