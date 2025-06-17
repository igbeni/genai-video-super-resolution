# Variables for SageMaker Module

variable "name_prefix" {
  description = "Prefix to be used for resource names"
  type        = string
  default     = "video-super-resolution"
}

variable "sagemaker_role_arn" {
  description = "ARN of the IAM role for SageMaker"
  type        = string
}

# Real-ESRGAN variables
variable "realesrgan_image_uri" {
  description = "URI of the Real-ESRGAN Docker image in ECR"
  type        = string
}

variable "realesrgan_model_data_url" {
  description = "S3 URL to the Real-ESRGAN model data"
  type        = string
  default     = null # If model is included in the container, this can be null
}

variable "realesrgan_instance_type" {
  description = "Instance type for Real-ESRGAN endpoint"
  type        = string
  default     = "ml.g4dn.xlarge" # GPU instance suitable for inference
}

variable "realesrgan_instance_count" {
  description = "Initial number of instances for Real-ESRGAN endpoint"
  type        = number
  default     = 1
}

# SwinIR variables
variable "swinir_image_uri" {
  description = "URI of the SwinIR Docker image in ECR"
  type        = string
}

variable "swinir_model_data_url" {
  description = "S3 URL to the SwinIR model data"
  type        = string
  default     = null # If model is included in the container, this can be null
}

variable "swinir_instance_type" {
  description = "Instance type for SwinIR endpoint"
  type        = string
  default     = "ml.g4dn.xlarge" # GPU instance suitable for inference
}

variable "swinir_instance_count" {
  description = "Initial number of instances for SwinIR endpoint"
  type        = number
  default     = 1
}

# Auto-scaling variables
variable "min_endpoint_capacity" {
  description = "Minimum capacity for SageMaker endpoint auto-scaling"
  type        = number
  default     = 1
}

variable "max_endpoint_capacity" {
  description = "Maximum capacity for SageMaker endpoint auto-scaling"
  type        = number
  default     = 4
}

variable "target_cpu_utilization" {
  description = "Target CPU utilization for auto-scaling"
  type        = number
  default     = 75 # 75% CPU utilization
}

# CloudWatch alarm variables
variable "error_threshold" {
  description = "Threshold for SageMaker endpoint error alarms"
  type        = number
  default     = 5 # 5 errors
}

variable "alarm_actions" {
  description = "List of ARNs to notify when alarm transitions to ALARM state"
  type        = list(string)
  default     = []
}

variable "ok_actions" {
  description = "List of ARNs to notify when alarm transitions to OK state"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}