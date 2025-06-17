# Variables for AWS Step Functions Module

variable "state_machine_name" {
  description = "Name of the Step Functions state machine"
  type        = string
  default     = "video-super-resolution-workflow"
}

variable "step_functions_role_name" {
  description = "Name of the IAM role for Step Functions"
  type        = string
  default     = "video-super-resolution-step-functions-role"
}

variable "step_functions_role_arn" {
  description = "ARN of the IAM role for Step Functions"
  type        = string
  default     = null
}

variable "frame_extraction_function_arn" {
  description = "ARN of the Lambda function for frame extraction"
  type        = string
}

variable "frame_processing_function_arn" {
  description = "ARN of the Lambda function for frame processing"
  type        = string
}

variable "video_recomposition_function_arn" {
  description = "ARN of the Lambda function for video recomposition"
  type        = string
}

variable "completion_notification_function_arn" {
  description = "ARN of the Lambda function for completion notification"
  type        = string
}

variable "check_status_function_arn" {
  description = "ARN of the Lambda function for checking job status (defaults to frame_extraction_function_arn if not provided)"
  type        = string
  default     = null
}

variable "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch Log Group for Step Functions"
  type        = string
  default     = null
}

variable "log_retention_days" {
  description = "Number of days to retain logs in CloudWatch"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
