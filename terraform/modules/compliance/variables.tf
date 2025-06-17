# Variables for Compliance Module

variable "name_prefix" {
  description = "Prefix to use for resource names"
  type        = string
  default     = "video-super-resolution"
}

variable "config_bucket_name" {
  description = "Name of the S3 bucket where AWS Config snapshots will be stored"
  type        = string
}

variable "report_bucket_name" {
  description = "Name of the S3 bucket where compliance reports will be stored"
  type        = string
}

variable "config_delivery_frequency" {
  description = "Frequency with which AWS Config delivers configuration snapshots"
  type        = string
  default     = "One_Hour"
  validation {
    condition     = contains(["One_Hour", "Three_Hours", "Six_Hours", "Twelve_Hours", "TwentyFour_Hours"], var.config_delivery_frequency)
    error_message = "Valid values for config_delivery_frequency are One_Hour, Three_Hours, Six_Hours, Twelve_Hours, TwentyFour_Hours."
  }
}

variable "report_schedule" {
  description = "Schedule expression for when to generate compliance reports"
  type        = string
  default     = "cron(0 0 * * ? *)" # Daily at midnight UTC
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic to notify when compliance reports are generated"
  type        = string
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}