# Variables for CloudWatch Dashboards, Alarms, and Log Groups Module

# General Configuration
variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "video-super-resolution"
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

# S3 Buckets
variable "source_bucket_name" {
  description = "Name of the S3 bucket for source videos"
  type        = string
}

variable "processed_frames_bucket_name" {
  description = "Name of the S3 bucket for processed frames"
  type        = string
}

variable "final_videos_bucket_name" {
  description = "Name of the S3 bucket for final videos"
  type        = string
}

# Lambda Functions
variable "lambda_function_names" {
  description = "Map of Lambda function names by role"
  type        = map(string)
  default = {
    pipeline_trigger        = "video-super-resolution-pipeline-trigger"
    frame_extraction        = "video-super-resolution-frame-extraction"
    frame_processing        = "video-super-resolution-frame-processing"
    video_recomposition     = "video-super-resolution-video-recomposition"
    completion_notification = "video-super-resolution-completion-notification"
  }
}

# AWS Batch
variable "batch_job_queue_names" {
  description = "Map of AWS Batch job queue names by type"
  type        = map(string)
  default = {
    spot     = "video-super-resolution-spot-job-queue"
    ondemand = "video-super-resolution-ondemand-job-queue"
    hybrid   = "video-super-resolution-hybrid-job-queue"
  }
}

# EC2 Auto Scaling Groups
variable "ec2_asg_names" {
  description = "Map of EC2 Auto Scaling Group names by type"
  type        = map(string)
  default = {
    spot     = "video-super-resolution-spot-fleet"
    ondemand = "video-super-resolution-ondemand-fleet"
  }
}

# SNS Topics
variable "sns_topic_arns" {
  description = "Map of SNS topic ARNs by purpose"
  type        = map(string)
  default     = {}
}

# CloudWatch Log Groups
variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30
}

# Alarm Thresholds
variable "lambda_error_threshold" {
  description = "Threshold for Lambda function errors alarm"
  type        = number
  default     = 1
}

variable "s3_storage_threshold" {
  description = "Threshold for S3 bucket storage size alarm (in bytes)"
  type        = number
  default     = 5368709120 # 5 GB
}

variable "ec2_cpu_threshold" {
  description = "Threshold for EC2 CPU utilization alarm (percentage)"
  type        = number
  default     = 80
}

variable "ec2_idle_threshold" {
  description = "Threshold for EC2 idle CPU utilization alarm (percentage)"
  type        = number
  default     = 10
}

variable "idle_evaluation_periods" {
  description = "Number of periods to evaluate for idle instances before triggering alarm"
  type        = number
  default     = 6 # 30 minutes (6 periods of 5 minutes each)
}

# Alarm Actions
variable "alarm_actions" {
  description = "List of ARNs of actions to execute when the alarm transitions to ALARM state"
  type        = list(string)
  default     = []
}

variable "ok_actions" {
  description = "List of ARNs of actions to execute when the alarm transitions to OK state"
  type        = list(string)
  default     = []
}

# Dashboard Configuration
variable "dashboard_refresh_interval" {
  description = "Refresh interval for CloudWatch dashboards in seconds"
  type        = number
  default     = 300
}

# Cost Tracking and Budgeting
variable "environment" {
  description = "Environment name for cost tracking (e.g., dev, test, prod)"
  type        = string
  default     = "prod"
}

variable "project_name" {
  description = "Project name for cost tracking"
  type        = string
  default     = "video-super-resolution"
}

variable "cost_center" {
  description = "Cost center identifier for cost tracking"
  type        = string
  default     = "media-processing"
}

variable "monthly_budget" {
  description = "Monthly budget amount in USD for cost tracking and alerts"
  type        = number
  default     = 1000
}

variable "budget_notification_emails" {
  description = "List of email addresses to notify when budget thresholds are exceeded"
  type        = list(string)
  default     = ["admin@example.com"]
}

# Event Rules Configuration
variable "event_rule_enabled" {
  description = "Whether to enable CloudWatch Event Rules"
  type        = bool
  default     = true
}

# Lambda Configuration for Auto Scaling
variable "lambda_role_arn" {
  description = "ARN of the IAM role for Lambda functions"
  type        = string
  default     = ""
}

variable "auto_scale_down_zip_path" {
  description = "Path to the zip file containing the auto scale down Lambda function code"
  type        = string
  default     = "lambda_functions/dist/auto_scale_down.zip"
}
