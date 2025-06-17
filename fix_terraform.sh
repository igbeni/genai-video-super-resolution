#!/bin/bash
# Script to fix Terraform issues

set -e

echo "Fixing Terraform issues..."

# Change to the terraform directory
cd terraform

# Add the access_logs_bucket_name variable to variables.tf if it doesn't exist
if ! grep -q "access_logs_bucket_name" variables.tf; then
  echo "Adding access_logs_bucket_name variable to variables.tf..."
  cat > variables.tf.new << 'EOF'
# Root Variables for Video Super-Resolution Pipeline

variable "aws_region" {
  description = "The AWS region to deploy resources into"
  type        = string
  default     = "us-east-1"
}

variable "default_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "Video-Super-Resolution"
    Environment = "dev"
    Terraform   = "true"
  }
}

# S3 Bucket Names
variable "source_bucket_name" {
  description = "Name of the S3 bucket for source videos"
  type        = string
  default     = "video-super-resolution-source"
}

variable "processed_frames_bucket_name" {
  description = "Name of the S3 bucket for processed frames"
  type        = string
  default     = "video-super-resolution-frames"
}

variable "final_videos_bucket_name" {
  description = "Name of the S3 bucket for final videos"
  type        = string
  default     = "video-super-resolution-final"
}

variable "access_logs_bucket_name" {
  description = "Name of the S3 bucket for access logs"
  type        = string
  default     = "video-super-resolution-access-logs"
}
EOF
  # Append the rest of the original variables.tf file
  grep -A 1000 "# S3 Bucket Configuration" variables.tf >> variables.tf.new
  mv variables.tf.new variables.tf
fi

# Add the access_logs_bucket_name argument to the s3_buckets module call in main.tf
if ! grep -q "access_logs_bucket_name" main.tf; then
  echo "Adding access_logs_bucket_name argument to s3_buckets module call in main.tf..."
  cat > main.tf.new << 'EOF'
# Main Terraform Configuration for Video Super-Resolution Pipeline

# DynamoDB Table for Job Metadata
module "dynamodb" {
  source = "./modules/dynamodb"

  # Table name
  dynamodb_table_name = var.dynamodb_table_name

  # Tags
  tags = var.default_tags
}

# S3 Buckets for Video Super-Resolution Pipeline
module "s3_buckets" {
  source = "./modules/s3"

  # Bucket names
  source_bucket_name          = var.source_bucket_name
  processed_frames_bucket_name = var.processed_frames_bucket_name
  final_videos_bucket_name    = var.final_videos_bucket_name
  access_logs_bucket_name     = var.access_logs_bucket_name

  # Bucket configuration
  enable_versioning               = var.enable_versioning
  enable_lifecycle_rules          = var.enable_lifecycle_rules
  intermediate_files_expiration_days = var.intermediate_files_expiration_days

  # Tags
  tags = var.default_tags
}
EOF
  # Append the rest of the original main.tf file
  grep -A 1000 "# IAM Roles and Policies with Least Privilege" main.tf >> main.tf.new
  mv main.tf.new main.tf
fi

# Format all Terraform files
echo "Formatting Terraform files..."
terraform fmt -recursive

echo "Terraform issues fixed successfully."
