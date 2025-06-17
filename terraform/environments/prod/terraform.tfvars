# Production Environment Terraform Variables for Video Super-Resolution Pipeline

# AWS Configuration
aws_region = "us-east-1"

# Default Tags
default_tags = {
  Project     = "Video-Super-Resolution"
  Environment = "prod"
  Terraform   = "true"
  Owner       = "ProdTeam"
}

# S3 Bucket Names
# Note: S3 bucket names must be globally unique
source_bucket_name          = "prod-video-super-resolution-source"
processed_frames_bucket_name = "prod-video-super-resolution-frames"
final_videos_bucket_name    = "prod-video-super-resolution-final"

# S3 Bucket Configuration
enable_versioning               = true  # Enable versioning for production to ensure data integrity
enable_lifecycle_rules          = true
intermediate_files_expiration_days = 7  # Standard retention for production environment

# Lambda Function Configuration
lambda_runtime    = "python3.9"
lambda_timeout    = 600  # Longer timeout for production to handle larger workloads
lambda_memory_size = 1024  # More memory for production to handle larger workloads

# Email Notification (optional - leave empty to disable)
notification_email = "prod-team@example.com"

# SageMaker Configuration
realesrgan_instance_type = "ml.g4dn.2xlarge"  # Larger instance for production
realesrgan_instance_count = 2  # Multiple instances for production
swinir_instance_type = "ml.g4dn.2xlarge"  # Larger instance for production
swinir_instance_count = 2  # Multiple instances for production

# SageMaker Auto-scaling Configuration
sagemaker_min_capacity = 2  # Higher min capacity for production
sagemaker_max_capacity = 4  # Full max capacity for production environment
sagemaker_target_cpu_utilization = 70  # Lower target utilization for better responsiveness