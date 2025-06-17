# Variables for SNS Topics for Notifications Module

# General Configuration
variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "video-super-resolution"
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
}

# Subscription Configuration
variable "email_subscribers" {
  description = "List of email addresses to subscribe to the general notification topic"
  type        = list(string)
  default     = []
}

variable "admin_email_subscribers" {
  description = "List of admin email addresses to subscribe to the pipeline failure topic"
  type        = list(string)
  default     = []
}

variable "sms_subscribers" {
  description = "List of phone numbers to subscribe to the pipeline failure topic"
  type        = list(string)
  default     = []
}

variable "lambda_function_arns" {
  description = "Map of Lambda function ARNs to subscribe to the general notification topic"
  type        = map(string)
  default     = {}
}

variable "sqs_queue_arns" {
  description = "Map of SQS queue ARNs to subscribe to the general notification topic"
  type        = map(string)
  default     = {}
}

# Lambda Function Names for CloudWatch Event Rules
variable "completion_lambda_name" {
  description = "Name of the Lambda function that handles pipeline completion"
  type        = string
  default     = "video-super-resolution-completion-notification"
}

variable "pipeline_lambda_names" {
  description = "List of Lambda function names that are part of the pipeline"
  type        = list(string)
  default     = [
    "video-super-resolution-pipeline-trigger",
    "video-super-resolution-frame-extraction",
    "video-super-resolution-frame-processing",
    "video-super-resolution-video-recomposition",
    "video-super-resolution-completion-notification"
  ]
}

# FIFO Topic Configuration
variable "create_fifo_topic" {
  description = "Whether to create a FIFO topic for ordered notifications"
  type        = bool
  default     = false
}

# Topic Configuration
variable "topic_delivery_policy" {
  description = "JSON string of the delivery policy for SNS topics"
  type        = string
  default     = <<EOF
{
  "http": {
    "defaultHealthyRetryPolicy": {
      "minDelayTarget": 20,
      "maxDelayTarget": 20,
      "numRetries": 3,
      "numMaxDelayRetries": 0,
      "numNoDelayRetries": 0,
      "numMinDelayRetries": 0,
      "backoffFunction": "linear"
    },
    "disableSubscriptionOverrides": false,
    "defaultRequestPolicy": {
      "headerContentType": "text/plain; charset=UTF-8"
    }
  }
}
EOF
}

# Cross-Account Access
variable "cross_account_access_role_arns" {
  description = "List of IAM role ARNs from other accounts that need access to the SNS topics"
  type        = list(string)
  default     = []
}

# Encryption
variable "enable_encryption" {
  description = "Whether to enable encryption for SNS topics"
  type        = bool
  default     = true
}

variable "kms_master_key_id" {
  description = "The ID of an AWS-managed customer master key (CMK) for Amazon SNS or a custom CMK"
  type        = string
  default     = "alias/aws/sns"
}