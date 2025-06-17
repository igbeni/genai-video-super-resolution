# Test Environment Terraform Variables for Video Super-Resolution Pipeline

# AWS Configuration
aws_region = "us-east-1"

# Default Tags
default_tags = {
  Project     = "Video-Super-Resolution"
  Environment = "test"
  Terraform   = "true"
  Owner       = "TestTeam"
}

# S3 Bucket Names
# Note: S3 bucket names must be globally unique
source_bucket_name          = "test-video-super-resolution-source"
processed_frames_bucket_name = "test-video-super-resolution-frames"
final_videos_bucket_name    = "test-video-super-resolution-final"

# S3 Bucket Configuration
enable_versioning               = true  # Enable versioning for test to track changes
enable_lifecycle_rules          = true
intermediate_files_expiration_days = 5  # Medium retention for test environment

# Lambda Function Configuration
lambda_runtime    = "python3.9"
lambda_timeout    = 300
lambda_memory_size = 512  # More memory for test environment to handle larger test cases

# Email Notification (optional - leave empty to disable)
notification_email = "test-team@example.com"

# SageMaker Configuration
realesrgan_instance_type = "ml.g4dn.xlarge"
realesrgan_instance_count = 1
swinir_instance_type = "ml.g4dn.xlarge"
swinir_instance_count = 1

# SageMaker Auto-scaling Configuration
sagemaker_min_capacity = 1
sagemaker_max_capacity = 3  # Medium max capacity for test environment
sagemaker_target_cpu_utilization = 75