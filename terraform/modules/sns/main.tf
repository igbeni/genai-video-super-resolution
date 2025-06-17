# SNS Topics for Notifications in Video Super-Resolution Pipeline
# This module creates SNS topics and subscriptions for various notification purposes

# General Notification Topic
resource "aws_sns_topic" "general_notification" {
  name = "${var.name_prefix}-general-notification"
  
  tags = var.tags
}

# Pipeline Completion Topic
resource "aws_sns_topic" "pipeline_completion" {
  name = "${var.name_prefix}-pipeline-completion"
  
  tags = var.tags
}

# Pipeline Failure Topic
resource "aws_sns_topic" "pipeline_failure" {
  name = "${var.name_prefix}-pipeline-failure"
  
  tags = var.tags
}

# Resource Warning Topic
resource "aws_sns_topic" "resource_warning" {
  name = "${var.name_prefix}-resource-warning"
  
  tags = var.tags
}

# Cost Alert Topic
resource "aws_sns_topic" "cost_alert" {
  name = "${var.name_prefix}-cost-alert"
  
  tags = var.tags
}

# Email Subscriptions
resource "aws_sns_topic_subscription" "email_subscriptions" {
  for_each  = { for idx, email in var.email_subscribers : idx => email }
  
  topic_arn = aws_sns_topic.general_notification.arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_sns_topic_subscription" "admin_email_subscriptions" {
  for_each  = { for idx, email in var.admin_email_subscribers : idx => email }
  
  topic_arn = aws_sns_topic.pipeline_failure.arn
  protocol  = "email"
  endpoint  = each.value
}

# SMS Subscriptions
resource "aws_sns_topic_subscription" "sms_subscriptions" {
  for_each  = { for idx, phone in var.sms_subscribers : idx => phone }
  
  topic_arn = aws_sns_topic.pipeline_failure.arn
  protocol  = "sms"
  endpoint  = each.value
}

# Lambda Subscriptions
resource "aws_sns_topic_subscription" "lambda_subscriptions" {
  for_each  = var.lambda_function_arns
  
  topic_arn = aws_sns_topic.general_notification.arn
  protocol  = "lambda"
  endpoint  = each.value
}

# SQS Subscriptions
resource "aws_sns_topic_subscription" "sqs_subscriptions" {
  for_each  = var.sqs_queue_arns
  
  topic_arn = aws_sns_topic.general_notification.arn
  protocol  = "sqs"
  endpoint  = each.value
}

# Lambda Permissions for SNS
resource "aws_lambda_permission" "allow_sns_invocation" {
  for_each      = var.lambda_function_arns
  
  statement_id  = "AllowExecutionFromSNS-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = each.value
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.general_notification.arn
}

# Topic Policies
resource "aws_sns_topic_policy" "general_notification_policy" {
  arn    = aws_sns_topic.general_notification.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    actions = [
      "SNS:Subscribe",
      "SNS:SetTopicAttributes",
      "SNS:RemovePermission",
      "SNS:Receive",
      "SNS:Publish",
      "SNS:ListSubscriptionsByTopic",
      "SNS:GetTopicAttributes",
      "SNS:DeleteTopic",
      "SNS:AddPermission",
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceOwner"
      values   = [var.account_id]
    }

    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      aws_sns_topic.general_notification.arn,
      aws_sns_topic.pipeline_completion.arn,
      aws_sns_topic.pipeline_failure.arn,
      aws_sns_topic.resource_warning.arn,
      aws_sns_topic.cost_alert.arn,
    ]
  }
}

# CloudWatch Event Rules for SNS
resource "aws_cloudwatch_event_rule" "pipeline_completion_rule" {
  name        = "${var.name_prefix}-pipeline-completion-rule"
  description = "Rule to capture pipeline completion events"
  
  event_pattern = jsonencode({
    source      = ["aws.lambda"],
    detail-type = ["Lambda Function Invocation Result - Success"],
    detail = {
      requestContext = {
        functionName = [var.completion_lambda_name]
      }
    }
  })
  
  tags = var.tags
}

resource "aws_cloudwatch_event_target" "pipeline_completion_target" {
  rule      = aws_cloudwatch_event_rule.pipeline_completion_rule.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.pipeline_completion.arn
}

resource "aws_cloudwatch_event_rule" "pipeline_failure_rule" {
  name        = "${var.name_prefix}-pipeline-failure-rule"
  description = "Rule to capture pipeline failure events"
  
  event_pattern = jsonencode({
    source      = ["aws.lambda"],
    detail-type = ["Lambda Function Invocation Result - Failure"],
    detail = {
      requestContext = {
        functionName = var.pipeline_lambda_names
      }
    }
  })
  
  tags = var.tags
}

resource "aws_cloudwatch_event_target" "pipeline_failure_target" {
  rule      = aws_cloudwatch_event_rule.pipeline_failure_rule.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.pipeline_failure.arn
}

# Dead Letter Queue for Failed Message Delivery
resource "aws_sqs_queue" "sns_dlq" {
  name = "${var.name_prefix}-sns-dlq"
  
  tags = var.tags
}

# Configure DLQ for SNS Topics
resource "aws_sns_topic_subscription" "dlq_subscription" {
  topic_arn            = aws_sns_topic.general_notification.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.sns_dlq.arn
  raw_message_delivery = true
  redrive_policy       = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.sns_dlq.arn
  })
}

# FIFO Topic for Ordered Notifications (if needed)
resource "aws_sns_topic" "ordered_notifications" {
  count = var.create_fifo_topic ? 1 : 0
  
  name       = "${var.name_prefix}-ordered-notifications.fifo"
  fifo_topic = true
  
  tags = var.tags
}