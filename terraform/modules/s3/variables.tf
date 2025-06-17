# Variables for S3 Buckets Module

variable "source_bucket_name" {
  description = "Name of the S3 bucket for source videos"
  type        = string
}

variable "access_logs_bucket_name" {
  description = "Name of the S3 bucket for access logs"
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

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "enable_versioning" {
  description = "Enable versioning for S3 buckets"
  type        = bool
  default     = false
}

variable "enable_lifecycle_rules" {
  description = "Enable lifecycle rules for intermediate artifacts"
  type        = bool
  default     = true
}

variable "intermediate_files_expiration_days" {
  description = "Number of days after which intermediate files will be deleted"
  type        = number
  default     = 30
}

variable "enable_standard_ia_transition" {
  description = "Enable transition to STANDARD_IA storage class for intermediate artifacts"
  type        = bool
  default     = true
}

variable "standard_ia_transition_days" {
  description = "Number of days after which objects transition to STANDARD_IA storage class"
  type        = number
  default     = 7
}

variable "enable_glacier_transition" {
  description = "Enable transition to Glacier storage class for intermediate artifacts"
  type        = bool
  default     = true
}

variable "glacier_transition_days" {
  description = "Number of days after which objects transition to Glacier storage class"
  type        = number
  default     = 14
}

variable "use_kms" {
  description = "Whether to use KMS encryption for S3 buckets"
  type        = bool
  default     = false
}

variable "kms_key_id" {
  description = "KMS key ID for encrypting S3 bucket contents"
  type        = string
  default     = null
}

# Source videos lifecycle configuration
variable "enable_source_lifecycle_rules" {
  description = "Enable lifecycle rules for source videos"
  type        = bool
  default     = true
}

variable "source_standard_ia_transition_days" {
  description = "Number of days after which source videos transition to STANDARD_IA storage class"
  type        = number
  default     = 30
}

variable "source_glacier_transition_days" {
  description = "Number of days after which source videos transition to Glacier storage class"
  type        = number
  default     = 90
}

variable "source_deep_archive_transition_days" {
  description = "Number of days after which source videos transition to Glacier Deep Archive storage class"
  type        = number
  default     = 180
}

# Final videos lifecycle configuration
variable "enable_final_lifecycle_rules" {
  description = "Enable lifecycle rules for final videos"
  type        = bool
  default     = true
}

variable "final_standard_ia_transition_days" {
  description = "Number of days after which final videos transition to STANDARD_IA storage class"
  type        = number
  default     = 30
}

variable "final_glacier_transition_days" {
  description = "Number of days after which final videos transition to Glacier storage class"
  type        = number
  default     = 90
}

# Compression configuration
variable "enable_compression" {
  description = "Enable compression for intermediate files"
  type        = bool
  default     = true
}
