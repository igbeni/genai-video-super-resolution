# Outputs for SNS Topics for Notifications Module

# Topic ARNs
output "general_notification_topic_arn" {
  description = "The ARN of the general notification SNS topic"
  value       = aws_sns_topic.general_notification.arn
}

output "pipeline_completion_topic_arn" {
  description = "The ARN of the pipeline completion SNS topic"
  value       = aws_sns_topic.pipeline_completion.arn
}

output "pipeline_failure_topic_arn" {
  description = "The ARN of the pipeline failure SNS topic"
  value       = aws_sns_topic.pipeline_failure.arn
}

output "resource_warning_topic_arn" {
  description = "The ARN of the resource warning SNS topic"
  value       = aws_sns_topic.resource_warning.arn
}

output "cost_alert_topic_arn" {
  description = "The ARN of the cost alert SNS topic"
  value       = aws_sns_topic.cost_alert.arn
}

output "ordered_notifications_topic_arn" {
  description = "The ARN of the ordered notifications FIFO SNS topic"
  value       = var.create_fifo_topic ? aws_sns_topic.ordered_notifications[0].arn : null
}

# Topic Names
output "general_notification_topic_name" {
  description = "The name of the general notification SNS topic"
  value       = aws_sns_topic.general_notification.name
}

output "pipeline_completion_topic_name" {
  description = "The name of the pipeline completion SNS topic"
  value       = aws_sns_topic.pipeline_completion.name
}

output "pipeline_failure_topic_name" {
  description = "The name of the pipeline failure SNS topic"
  value       = aws_sns_topic.pipeline_failure.name
}

output "resource_warning_topic_name" {
  description = "The name of the resource warning SNS topic"
  value       = aws_sns_topic.resource_warning.name
}

output "cost_alert_topic_name" {
  description = "The name of the cost alert SNS topic"
  value       = aws_sns_topic.cost_alert.name
}

output "ordered_notifications_topic_name" {
  description = "The name of the ordered notifications FIFO SNS topic"
  value       = var.create_fifo_topic ? aws_sns_topic.ordered_notifications[0].name : null
}

# Subscription Outputs
output "email_subscription_arns" {
  description = "The ARNs of the email subscriptions"
  value       = { for k, v in aws_sns_topic_subscription.email_subscriptions : k => v.arn }
}

output "admin_email_subscription_arns" {
  description = "The ARNs of the admin email subscriptions"
  value       = { for k, v in aws_sns_topic_subscription.admin_email_subscriptions : k => v.arn }
}

output "sms_subscription_arns" {
  description = "The ARNs of the SMS subscriptions"
  value       = { for k, v in aws_sns_topic_subscription.sms_subscriptions : k => v.arn }
}

output "lambda_subscription_arns" {
  description = "The ARNs of the Lambda subscriptions"
  value       = { for k, v in aws_sns_topic_subscription.lambda_subscriptions : k => v.arn }
}

output "sqs_subscription_arns" {
  description = "The ARNs of the SQS subscriptions"
  value       = { for k, v in aws_sns_topic_subscription.sqs_subscriptions : k => v.arn }
}

# CloudWatch Event Rule Outputs
output "pipeline_completion_rule_arn" {
  description = "The ARN of the pipeline completion CloudWatch event rule"
  value       = aws_cloudwatch_event_rule.pipeline_completion_rule.arn
}

output "pipeline_failure_rule_arn" {
  description = "The ARN of the pipeline failure CloudWatch event rule"
  value       = aws_cloudwatch_event_rule.pipeline_failure_rule.arn
}

# Dead Letter Queue Output
output "sns_dlq_arn" {
  description = "The ARN of the SNS dead letter queue"
  value       = aws_sqs_queue.sns_dlq.arn
}

output "sns_dlq_url" {
  description = "The URL of the SNS dead letter queue"
  value       = aws_sqs_queue.sns_dlq.id
}

# All Topics Map
output "all_topic_arns" {
  description = "Map of all SNS topic ARNs"
  value = {
    general_notification  = aws_sns_topic.general_notification.arn
    pipeline_completion   = aws_sns_topic.pipeline_completion.arn
    pipeline_failure      = aws_sns_topic.pipeline_failure.arn
    resource_warning      = aws_sns_topic.resource_warning.arn
    cost_alert            = aws_sns_topic.cost_alert.arn
    ordered_notifications = var.create_fifo_topic ? aws_sns_topic.ordered_notifications[0].arn : null
  }
}

# All Topics with Subscriptions
output "topics_with_subscriptions" {
  description = "Map of SNS topics with their subscriptions"
  value = {
    general_notification = {
      topic_arn = aws_sns_topic.general_notification.arn
      subscriptions = {
        email  = { for k, v in aws_sns_topic_subscription.email_subscriptions : k => v.endpoint }
        lambda = { for k, v in aws_sns_topic_subscription.lambda_subscriptions : k => v.endpoint }
        sqs    = { for k, v in aws_sns_topic_subscription.sqs_subscriptions : k => v.endpoint }
      }
    }
    pipeline_failure = {
      topic_arn = aws_sns_topic.pipeline_failure.arn
      subscriptions = {
        admin_email = { for k, v in aws_sns_topic_subscription.admin_email_subscriptions : k => v.endpoint }
        sms         = { for k, v in aws_sns_topic_subscription.sms_subscriptions : k => v.endpoint }
      }
    }
  }
}