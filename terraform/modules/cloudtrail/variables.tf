# Variables for CloudTrail Module

variable "trail_name" {
  description = "Name of the CloudTrail trail"
  type        = string
  default     = "video-super-resolution-api-activity"
}

variable "cloudtrail_bucket_name" {
  description = "Name of the S3 bucket where CloudTrail logs will be stored"
  type        = string
}

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

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 90
}

variable "kms_key_id" {
  description = "KMS key ID for encrypting CloudTrail logs"
  type        = string
  default     = null
}

variable "alarm_actions" {
  description = "List of ARNs to notify when alarm transitions to ALARM state"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}