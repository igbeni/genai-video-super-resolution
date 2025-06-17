# Variables for AWS Batch Compute Environments and Job Queues Module

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

# IAM Roles
variable "batch_service_role_arn" {
  description = "ARN of the IAM role for AWS Batch service"
  type        = string
}

variable "batch_instance_profile_arn" {
  description = "ARN of the IAM instance profile for AWS Batch compute resources"
  type        = string
}

variable "batch_job_role_arn" {
  description = "ARN of the IAM role for AWS Batch jobs"
  type        = string
}

variable "spot_fleet_role_arn" {
  description = "ARN of the IAM role for Spot Fleet"
  type        = string
}

# Network Configuration
variable "subnet_ids" {
  description = "List of subnet IDs for AWS Batch compute environments"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs for AWS Batch compute environments"
  type        = list(string)
}

# Spot Compute Environment Configuration
variable "spot_allocation_strategy" {
  description = "Allocation strategy for Spot instances (BEST_FIT, BEST_FIT_PROGRESSIVE, SPOT_CAPACITY_OPTIMIZED)"
  type        = string
  default     = "SPOT_CAPACITY_OPTIMIZED"
}

variable "spot_bid_percentage" {
  description = "Percentage of On-Demand price for Spot instances (0-100)"
  type        = number
  default     = 100
}

variable "spot_max_vcpus" {
  description = "Maximum number of vCPUs for Spot compute environment"
  type        = number
  default     = 256
}

variable "spot_min_vcpus" {
  description = "Minimum number of vCPUs for Spot compute environment"
  type        = number
  default     = 0
}

variable "spot_desired_vcpus" {
  description = "Desired number of vCPUs for Spot compute environment"
  type        = number
  default     = 0
}

variable "spot_instance_types" {
  description = "List of instance types for Spot compute environment"
  type        = list(string)
  default     = ["g4dn.xlarge", "g4dn.2xlarge", "g5.xlarge", "g5.2xlarge"]
}

# On-Demand Compute Environment Configuration
variable "ondemand_allocation_strategy" {
  description = "Allocation strategy for On-Demand instances (BEST_FIT, BEST_FIT_PROGRESSIVE)"
  type        = string
  default     = "BEST_FIT_PROGRESSIVE"
}

variable "ondemand_max_vcpus" {
  description = "Maximum number of vCPUs for On-Demand compute environment"
  type        = number
  default     = 256
}

variable "ondemand_min_vcpus" {
  description = "Minimum number of vCPUs for On-Demand compute environment"
  type        = number
  default     = 0
}

variable "ondemand_desired_vcpus" {
  description = "Desired number of vCPUs for On-Demand compute environment"
  type        = number
  default     = 0
}

variable "ondemand_instance_types" {
  description = "List of instance types for On-Demand compute environment"
  type        = list(string)
  default     = ["g4dn.xlarge", "g4dn.2xlarge", "g5.xlarge", "g5.2xlarge"]
}

# Job Configuration
variable "job_retry_attempts" {
  description = "Number of retry attempts for failed jobs"
  type        = number
  default     = 3
}

# Frame Extraction Job Configuration
variable "frame_extraction_image" {
  description = "Docker image for frame extraction job"
  type        = string
}

variable "frame_extraction_vcpus" {
  description = "Number of vCPUs for frame extraction job"
  type        = number
  default     = 2
}

variable "frame_extraction_memory" {
  description = "Memory (in MiB) for frame extraction job"
  type        = number
  default     = 4096
}

variable "frame_extraction_command" {
  description = "Command for frame extraction job"
  type        = list(string)
  default     = ["/bin/bash", "-c", "extract_frames.sh"]
}

variable "frame_extraction_volumes" {
  description = "List of volumes for frame extraction job"
  type        = list(any)
  default     = []
}

variable "frame_extraction_mount_points" {
  description = "List of mount points for frame extraction job"
  type        = list(any)
  default     = []
}

variable "frame_extraction_environment" {
  description = "Environment variables for frame extraction job"
  type        = list(map(string))
  default     = []
}

variable "frame_extraction_resource_requirements" {
  description = "Resource requirements for frame extraction job"
  type        = list(any)
  default     = []
}

variable "frame_extraction_linux_parameters" {
  description = "Linux parameters for frame extraction job"
  type        = any
  default     = null
}

variable "frame_extraction_timeout" {
  description = "Timeout (in seconds) for frame extraction job"
  type        = number
  default     = 3600
}

# Frame Processing Job Configuration
variable "frame_processing_image" {
  description = "Docker image for frame processing job"
  type        = string
}

variable "frame_processing_vcpus" {
  description = "Number of vCPUs for frame processing job"
  type        = number
  default     = 4
}

variable "frame_processing_memory" {
  description = "Memory (in MiB) for frame processing job"
  type        = number
  default     = 16384
}

variable "frame_processing_command" {
  description = "Command for frame processing job"
  type        = list(string)
  default     = ["/bin/bash", "-c", "process_frames.sh"]
}

variable "frame_processing_volumes" {
  description = "List of volumes for frame processing job"
  type        = list(any)
  default     = []
}

variable "frame_processing_mount_points" {
  description = "List of mount points for frame processing job"
  type        = list(any)
  default     = []
}

variable "frame_processing_environment" {
  description = "Environment variables for frame processing job"
  type        = list(map(string))
  default     = []
}

variable "frame_processing_resource_requirements" {
  description = "Resource requirements for frame processing job"
  type        = list(any)
  default     = []
}

variable "frame_processing_linux_parameters" {
  description = "Linux parameters for frame processing job"
  type        = any
  default     = null
}

variable "frame_processing_timeout" {
  description = "Timeout (in seconds) for frame processing job"
  type        = number
  default     = 7200
}

# Video Recomposition Job Configuration
variable "video_recomposition_image" {
  description = "Docker image for video recomposition job"
  type        = string
}

variable "video_recomposition_vcpus" {
  description = "Number of vCPUs for video recomposition job"
  type        = number
  default     = 4
}

variable "video_recomposition_memory" {
  description = "Memory (in MiB) for video recomposition job"
  type        = number
  default     = 8192
}

variable "video_recomposition_command" {
  description = "Command for video recomposition job"
  type        = list(string)
  default     = ["/bin/bash", "-c", "recompose_video.sh"]
}

variable "video_recomposition_volumes" {
  description = "List of volumes for video recomposition job"
  type        = list(any)
  default     = []
}

variable "video_recomposition_mount_points" {
  description = "List of mount points for video recomposition job"
  type        = list(any)
  default     = []
}

variable "video_recomposition_environment" {
  description = "Environment variables for video recomposition job"
  type        = list(map(string))
  default     = []
}

variable "video_recomposition_resource_requirements" {
  description = "Resource requirements for video recomposition job"
  type        = list(any)
  default     = []
}

variable "video_recomposition_linux_parameters" {
  description = "Linux parameters for video recomposition job"
  type        = any
  default     = null
}

variable "video_recomposition_timeout" {
  description = "Timeout (in seconds) for video recomposition job"
  type        = number
  default     = 3600
}

# CloudWatch Configuration
variable "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for AWS Batch jobs"
  type        = string
  default     = "/aws/batch/video-super-resolution"
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30
}

variable "failure_alarm_threshold" {
  description = "Threshold for job failures alarm"
  type        = number
  default     = 3
}

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
