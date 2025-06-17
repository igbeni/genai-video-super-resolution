# Variables for EC2 Spot Fleet Configurations Module

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

# Spot Fleet Configuration
variable "fleet_role_arn" {
  description = "ARN of the IAM role for Spot Fleet"
  type        = string
}

variable "target_capacity" {
  description = "Number of instances to launch in the Spot Fleet"
  type        = number
  default     = 2
}

variable "on_demand_backup_count" {
  description = "Number of on-demand instances to use as fallback when spot instances are not available"
  type        = number
  default     = 2
}

variable "allocation_strategy" {
  description = "Strategy for allocating Spot instances (lowestPrice, diversified, capacityOptimized, capacityOptimizedPrioritized)"
  type        = string
  default     = "capacityOptimizedPrioritized"
  # capacityOptimizedPrioritized is the best strategy for minimizing interruptions
  # while still allowing for instance type prioritization based on the order in instance_types
}

variable "instance_interruption_behavior" {
  description = "Behavior when a Spot instance is interrupted (terminate, stop, hibernate)"
  type        = string
  default     = "stop"
}

variable "wait_for_fulfillment" {
  description = "Whether to wait for the Spot Fleet request to be fulfilled"
  type        = bool
  default     = true
}

variable "valid_until" {
  description = "Duration from now for the Spot Fleet request to remain valid (e.g., '24h')"
  type        = string
  default     = "168h" # 7 days
}

# Instance Configuration
variable "instance_types" {
  description = "List of EC2 instance types to launch in the Spot Fleet"
  type        = list(string)
  default     = [
    # NVIDIA GPU instances - G4dn family
    "g4dn.xlarge", "g4dn.2xlarge", "g4dn.4xlarge", "g4dn.8xlarge",
    # NVIDIA GPU instances - G5 family
    "g5.xlarge", "g5.2xlarge", "g5.4xlarge", "g5.8xlarge",
    # NVIDIA GPU instances - P3 family
    "p3.2xlarge", "p3.8xlarge",
    # NVIDIA GPU instances - P4d family
    "p4d.24xlarge",
    # AMD GPU instances - G4ad family
    "g4ad.xlarge", "g4ad.2xlarge", "g4ad.4xlarge",
    # Fallback to CPU instances for less demanding tasks
    "c5.9xlarge", "c5.12xlarge", "c5a.8xlarge", "c5a.12xlarge"
  ]
}

variable "instance_weights" {
  description = "Map of instance types to their weights (capacity units)"
  type        = map(number)
  default     = {
    # NVIDIA GPU instances - G4dn family
    "g4dn.xlarge"  = 1
    "g4dn.2xlarge" = 2
    "g4dn.4xlarge" = 4
    "g4dn.8xlarge" = 8
    # NVIDIA GPU instances - G5 family
    "g5.xlarge"    = 1
    "g5.2xlarge"   = 2
    "g5.4xlarge"   = 4
    "g5.8xlarge"   = 8
    # NVIDIA GPU instances - P3 family
    "p3.2xlarge"   = 4
    "p3.8xlarge"   = 16
    # NVIDIA GPU instances - P4d family
    "p4d.24xlarge" = 24
    # AMD GPU instances - G4ad family
    "g4ad.xlarge"  = 1
    "g4ad.2xlarge" = 2
    "g4ad.4xlarge" = 4
    # CPU instances for less demanding tasks
    "c5.9xlarge"   = 3
    "c5.12xlarge"  = 4
    "c5a.8xlarge"  = 3
    "c5a.12xlarge" = 4
  }
}

variable "ami_id" {
  description = "ID of the AMI to use for the instances"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs to launch instances in"
  type        = list(string)
}

variable "availability_zones" {
  description = "List of availability zones to launch instances in for better diversification"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs to associate with the instances"
  type        = list(string)
}

variable "instance_profile_name" {
  description = "Name of the IAM instance profile to associate with the instances"
  type        = string
}

variable "key_name" {
  description = "Name of the key pair to use for SSH access"
  type        = string
  default     = ""
}

# Storage Configuration
variable "root_volume_size" {
  description = "Size of the root volume in GB"
  type        = number
  default     = 100
}

variable "root_volume_type" {
  description = "Type of the root volume (gp2, gp3, io1, etc.)"
  type        = string
  default     = "gp3"
}

variable "encrypt_volumes" {
  description = "Whether to encrypt the EBS volumes"
  type        = bool
  default     = true
}

variable "ebs_block_devices" {
  description = "List of additional EBS block devices to attach to the instances"
  type        = list(object({
    device_name = string
    volume_size = number
    volume_type = string
  }))
  default     = []
}

# User Data Configuration
variable "user_data_template" {
  description = "Path to the user data template file"
  type        = string
  default     = "templates/user_data.tpl"
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for storing data"
  type        = string
}

variable "jobs_table_name" {
  description = "Name of the DynamoDB table for storing job information"
  type        = string
  default     = "video-super-resolution-jobs"
}

# Monitoring and Alarms
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

# Interruption Handling
variable "create_interruption_handler" {
  description = "Whether to create a Lambda function to handle Spot instance interruptions"
  type        = bool
  default     = true
}

variable "lambda_role_arn" {
  description = "ARN of the IAM role for the Lambda function"
  type        = string
  default     = ""
}

variable "interruption_handler_zip_path" {
  description = "Path to the zip file containing the interruption handler Lambda function code"
  type        = string
  default     = "lambda_functions/dist/spot_interruption_handler.zip"
}
