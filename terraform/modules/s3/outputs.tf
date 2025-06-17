# Outputs for S3 Buckets Module

# Source Videos Bucket Outputs
output "source_bucket_id" {
  description = "The ID of the source videos bucket"
  value       = aws_s3_bucket.source_videos.id
}

output "source_bucket_arn" {
  description = "The ARN of the source videos bucket"
  value       = aws_s3_bucket.source_videos.arn
}

output "source_bucket_domain_name" {
  description = "The domain name of the source videos bucket"
  value       = aws_s3_bucket.source_videos.bucket_domain_name
}

# Processed Frames Bucket Outputs
output "processed_frames_bucket_id" {
  description = "The ID of the processed frames bucket"
  value       = aws_s3_bucket.processed_frames.id
}

output "processed_frames_bucket_arn" {
  description = "The ARN of the processed frames bucket"
  value       = aws_s3_bucket.processed_frames.arn
}

output "processed_frames_bucket_domain_name" {
  description = "The domain name of the processed frames bucket"
  value       = aws_s3_bucket.processed_frames.bucket_domain_name
}

# Final Videos Bucket Outputs
output "final_videos_bucket_id" {
  description = "The ID of the final videos bucket"
  value       = aws_s3_bucket.final_videos.id
}

output "final_videos_bucket_arn" {
  description = "The ARN of the final videos bucket"
  value       = aws_s3_bucket.final_videos.arn
}

output "final_videos_bucket_domain_name" {
  description = "The domain name of the final videos bucket"
  value       = aws_s3_bucket.final_videos.bucket_domain_name
}

# All Buckets Output
output "all_bucket_ids" {
  description = "Map of all bucket IDs"
  value = {
    source_videos    = aws_s3_bucket.source_videos.id
    processed_frames = aws_s3_bucket.processed_frames.id
    final_videos     = aws_s3_bucket.final_videos.id
  }
}

output "all_bucket_arns" {
  description = "Map of all bucket ARNs"
  value = {
    source_videos    = aws_s3_bucket.source_videos.arn
    processed_frames = aws_s3_bucket.processed_frames.arn
    final_videos     = aws_s3_bucket.final_videos.arn
  }
}