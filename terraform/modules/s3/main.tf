# S3 Buckets for Video Super-Resolution Pipeline
# This module creates S3 buckets for:
# - Source videos
# - Processed frames
# - Final videos
# - Access logs

# S3 Bucket for Access Logs
resource "aws_s3_bucket" "access_logs" {
  bucket = var.access_logs_bucket_name

  tags = merge(
    var.tags,
    {
      Name        = "Access Logs Bucket"
      Description = "Stores access logs for all S3 buckets in the pipeline"
    }
  )
}

# Block public access for access logs bucket
resource "aws_s3_bucket_public_access_block" "access_logs_block_public_access" {
  bucket = aws_s3_bucket.access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enforce SSL for access logs bucket
resource "aws_s3_bucket_policy" "access_logs_ssl_policy" {
  bucket = aws_s3_bucket.access_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceSSLOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.access_logs.arn,
          "${aws_s3_bucket.access_logs.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# Server-side encryption for access logs bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs_encryption" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.use_kms ? "aws:kms" : "AES256"
      kms_master_key_id = var.use_kms ? var.kms_key_id : null
    }
    bucket_key_enabled = var.use_kms
  }
}

resource "aws_s3_bucket" "source_videos" {
  bucket = var.source_bucket_name

  tags = merge(
    var.tags,
    {
      Name        = "Source Videos Bucket"
      Description = "Stores original source videos for super-resolution processing"
    }
  )
}

resource "aws_s3_bucket" "processed_frames" {
  bucket = var.processed_frames_bucket_name

  tags = merge(
    var.tags,
    {
      Name        = "Processed Frames Bucket"
      Description = "Stores extracted and processed frames during super-resolution"
    }
  )
}

resource "aws_s3_bucket" "final_videos" {
  bucket = var.final_videos_bucket_name

  tags = merge(
    var.tags,
    {
      Name        = "Final Videos Bucket"
      Description = "Stores final super-resolution videos after processing"
    }
  )
}

# Configure bucket versioning
resource "aws_s3_bucket_versioning" "source_videos_versioning" {
  bucket = aws_s3_bucket.source_videos.id
  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_versioning" "processed_frames_versioning" {
  bucket = aws_s3_bucket.processed_frames.id
  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_versioning" "final_videos_versioning" {
  bucket = aws_s3_bucket.final_videos.id
  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# Configure server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "source_videos_encryption" {
  bucket = aws_s3_bucket.source_videos.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.use_kms ? "aws:kms" : "AES256"
      kms_master_key_id = var.use_kms ? var.kms_key_id : null
    }
    bucket_key_enabled = var.use_kms
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "processed_frames_encryption" {
  bucket = aws_s3_bucket.processed_frames.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.use_kms ? "aws:kms" : "AES256"
      kms_master_key_id = var.use_kms ? var.kms_key_id : null
    }
    bucket_key_enabled = var.use_kms
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "final_videos_encryption" {
  bucket = aws_s3_bucket.final_videos.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.use_kms ? "aws:kms" : "AES256"
      kms_master_key_id = var.use_kms ? var.kms_key_id : null
    }
    bucket_key_enabled = var.use_kms
  }
}

# Configure lifecycle rules for source videos
resource "aws_s3_bucket_lifecycle_configuration" "source_videos_lifecycle" {
  bucket = aws_s3_bucket.source_videos.id

  rule {
    id     = "optimize-source-videos"
    status = var.enable_source_lifecycle_rules ? "Enabled" : "Disabled"

    # Transition to STANDARD_IA after specified days
    transition {
      days          = var.source_standard_ia_transition_days
      storage_class = "STANDARD_IA"
    }

    # Transition to GLACIER after specified days
    transition {
      days          = var.source_glacier_transition_days
      storage_class = "GLACIER"
    }

    # Transition to DEEP_ARCHIVE after specified days
    transition {
      days          = var.source_deep_archive_transition_days
      storage_class = "DEEP_ARCHIVE"
    }

    # Apply to all objects in the bucket
    filter {
      prefix = ""
    }
  }

  # Add a separate rule for incomplete multipart uploads
  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = var.enable_source_lifecycle_rules ? "Enabled" : "Disabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

# Configure lifecycle rules for processed frames (intermediate artifacts)
resource "aws_s3_bucket_lifecycle_configuration" "processed_frames_lifecycle" {
  bucket = aws_s3_bucket.processed_frames.id

  rule {
    id     = "optimize-intermediate-frames"
    status = var.enable_lifecycle_rules ? "Enabled" : "Disabled"

    # Transition to STANDARD_IA after specified days
    dynamic "transition" {
      for_each = var.enable_standard_ia_transition ? [1] : []
      content {
        days          = var.standard_ia_transition_days
        storage_class = "STANDARD_IA"
      }
    }

    # Transition to GLACIER after specified days
    dynamic "transition" {
      for_each = var.enable_glacier_transition ? [1] : []
      content {
        days          = var.glacier_transition_days
        storage_class = "GLACIER"
      }
    }

    # Final expiration
    expiration {
      days = var.intermediate_files_expiration_days
    }

    # Apply to all objects in the bucket
    filter {
      prefix = ""
    }
  }

  # Add a rule for frames directory
  rule {
    id     = "cleanup-frames"
    status = var.enable_lifecycle_rules ? "Enabled" : "Disabled"

    # Transition to STANDARD_IA after specified days
    dynamic "transition" {
      for_each = var.enable_standard_ia_transition ? [1] : []
      content {
        days          = var.standard_ia_transition_days / 2 # Faster transition for frames
        storage_class = "STANDARD_IA"
      }
    }

    # Final expiration
    expiration {
      days = var.intermediate_files_expiration_days / 2 # Faster expiration for frames
    }

    # Apply to frames directory
    filter {
      prefix = "frames/"
    }
  }

  # Add a rule for temporary files
  rule {
    id     = "cleanup-temp-files"
    status = var.enable_lifecycle_rules ? "Enabled" : "Disabled"

    # Quick expiration for temporary files
    expiration {
      days = 1 # Delete temp files after 1 day
    }

    # Apply to temp directory
    filter {
      prefix = "temp/"
    }
  }

  # Add a separate rule for incomplete multipart uploads
  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = var.enable_lifecycle_rules ? "Enabled" : "Disabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

# Configure access logging for source videos bucket
resource "aws_s3_bucket_logging" "source_videos_logging" {
  bucket = aws_s3_bucket.source_videos.id

  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "source-videos/"
}

# Configure access logging for processed frames bucket
resource "aws_s3_bucket_logging" "processed_frames_logging" {
  bucket = aws_s3_bucket.processed_frames.id

  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "processed-frames/"
}

# Configure lifecycle rules for final videos
resource "aws_s3_bucket_lifecycle_configuration" "final_videos_lifecycle" {
  bucket = aws_s3_bucket.final_videos.id

  rule {
    id     = "optimize-final-videos"
    status = var.enable_final_lifecycle_rules ? "Enabled" : "Disabled"

    # Transition to STANDARD_IA after specified days
    transition {
      days          = var.final_standard_ia_transition_days
      storage_class = "STANDARD_IA"
    }

    # Transition to GLACIER after specified days
    transition {
      days          = var.final_glacier_transition_days
      storage_class = "GLACIER"
    }

    # Apply to all objects in the bucket
    filter {
      prefix = ""
    }
  }

  # Add a separate rule for incomplete multipart uploads
  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = var.enable_final_lifecycle_rules ? "Enabled" : "Disabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

# Configure access logging for final videos bucket
resource "aws_s3_bucket_logging" "final_videos_logging" {
  bucket = aws_s3_bucket.final_videos.id

  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "final-videos/"
}

# Block public access for all buckets
resource "aws_s3_bucket_public_access_block" "source_videos_block_public_access" {
  bucket = aws_s3_bucket.source_videos.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enforce SSL for source videos bucket
resource "aws_s3_bucket_policy" "source_videos_ssl_policy" {
  bucket = aws_s3_bucket.source_videos.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceSSLOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.source_videos.arn,
          "${aws_s3_bucket.source_videos.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_public_access_block" "processed_frames_block_public_access" {
  bucket = aws_s3_bucket.processed_frames.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enforce SSL for processed frames bucket
resource "aws_s3_bucket_policy" "processed_frames_ssl_policy" {
  bucket = aws_s3_bucket.processed_frames.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceSSLOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.processed_frames.arn,
          "${aws_s3_bucket.processed_frames.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_public_access_block" "final_videos_block_public_access" {
  bucket = aws_s3_bucket.final_videos.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enforce SSL for final videos bucket
resource "aws_s3_bucket_policy" "final_videos_ssl_policy" {
  bucket = aws_s3_bucket.final_videos.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceSSLOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.final_videos.arn,
          "${aws_s3_bucket.final_videos.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}
