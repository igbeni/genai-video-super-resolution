# IAM Roles and Policies for Video Super-Resolution Pipeline
# This module creates IAM roles and policies with least privilege for:
# - Lambda functions for pipeline orchestration
# - EC2 instances for processing nodes
# - AWS Batch jobs
# - CloudWatch logging

# Lambda Execution Role
resource "aws_iam_role" "lambda_execution_role" {
  name = var.lambda_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Lambda Basic Execution Policy
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda S3 Access Policy
resource "aws_iam_policy" "lambda_s3_access" {
  name        = "${var.lambda_role_name}-s3-access"
  description = "Policy for Lambda to access S3 buckets for video processing"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          var.source_bucket_arn,
          "${var.source_bucket_arn}/*",
          var.processed_frames_bucket_arn,
          "${var.processed_frames_bucket_arn}/*",
          var.final_videos_bucket_arn,
          "${var.final_videos_bucket_arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_s3_access_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_s3_access.arn
}

# Lambda DynamoDB Access Policy (for job metadata)
resource "aws_iam_policy" "lambda_dynamodb_access" {
  name        = "${var.lambda_role_name}-dynamodb-access"
  description = "Policy for Lambda to access DynamoDB for job metadata"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Effect = "Allow"
        Resource = [
          var.dynamodb_table_arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_access_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_access.arn
}

# EC2 Instance Role for Processing Nodes
resource "aws_iam_role" "ec2_processing_role" {
  name = var.ec2_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# EC2 Instance Profile
resource "aws_iam_instance_profile" "ec2_processing_profile" {
  name = "${var.ec2_role_name}-profile"
  role = aws_iam_role.ec2_processing_role.name
}

# EC2 S3 Access Policy
resource "aws_iam_policy" "ec2_s3_access" {
  name        = "${var.ec2_role_name}-s3-access"
  description = "Policy for EC2 instances to access S3 buckets for video processing"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          var.source_bucket_arn,
          "${var.source_bucket_arn}/*",
          var.processed_frames_bucket_arn,
          "${var.processed_frames_bucket_arn}/*",
          var.final_videos_bucket_arn,
          "${var.final_videos_bucket_arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_s3_access_attachment" {
  role       = aws_iam_role.ec2_processing_role.name
  policy_arn = aws_iam_policy.ec2_s3_access.arn
}

# EC2 CloudWatch Logs Access Policy
resource "aws_iam_policy" "ec2_cloudwatch_access" {
  name        = "${var.ec2_role_name}-cloudwatch-access"
  description = "Policy for EC2 instances to write to CloudWatch Logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Effect = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_cloudwatch_access_attachment" {
  role       = aws_iam_role.ec2_processing_role.name
  policy_arn = aws_iam_policy.ec2_cloudwatch_access.arn
}

# AWS Batch Service Role
resource "aws_iam_role" "batch_service_role" {
  name = var.batch_service_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "batch.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# AWS Batch Service Role Policy
resource "aws_iam_role_policy_attachment" "batch_service_role_attachment" {
  role       = aws_iam_role.batch_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
}

# AWS Batch Job Role
resource "aws_iam_role" "batch_job_role" {
  name = var.batch_job_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# AWS Batch Job S3 Access Policy
resource "aws_iam_policy" "batch_job_s3_access" {
  name        = "${var.batch_job_role_name}-s3-access"
  description = "Policy for Batch jobs to access S3 buckets for video processing"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          var.source_bucket_arn,
          "${var.source_bucket_arn}/*",
          var.processed_frames_bucket_arn,
          "${var.processed_frames_bucket_arn}/*",
          var.final_videos_bucket_arn,
          "${var.final_videos_bucket_arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "batch_job_s3_access_attachment" {
  role       = aws_iam_role.batch_job_role.name
  policy_arn = aws_iam_policy.batch_job_s3_access.arn
}

# AWS Batch Job CloudWatch Logs Access Policy
resource "aws_iam_policy" "batch_job_cloudwatch_access" {
  name        = "${var.batch_job_role_name}-cloudwatch-access"
  description = "Policy for Batch jobs to write to CloudWatch Logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Effect = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "batch_job_cloudwatch_access_attachment" {
  role       = aws_iam_role.batch_job_role.name
  policy_arn = aws_iam_policy.batch_job_cloudwatch_access.arn
}

# SageMaker Role for Model Deployment
resource "aws_iam_role" "sagemaker_role" {
  name = var.sagemaker_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "sagemaker.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# SageMaker Execution Policy
resource "aws_iam_role_policy_attachment" "sagemaker_full_access" {
  role       = aws_iam_role.sagemaker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

# SageMaker S3 Access Policy
resource "aws_iam_policy" "sagemaker_s3_access" {
  name        = "${var.sagemaker_role_name}-s3-access"
  description = "Policy for SageMaker to access S3 buckets for model artifacts and data"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          var.source_bucket_arn,
          "${var.source_bucket_arn}/*",
          var.processed_frames_bucket_arn,
          "${var.processed_frames_bucket_arn}/*",
          var.final_videos_bucket_arn,
          "${var.final_videos_bucket_arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sagemaker_s3_access_attachment" {
  role       = aws_iam_role.sagemaker_role.name
  policy_arn = aws_iam_policy.sagemaker_s3_access.arn
}

# SageMaker CloudWatch Logs Access Policy
resource "aws_iam_policy" "sagemaker_cloudwatch_access" {
  name        = "${var.sagemaker_role_name}-cloudwatch-access"
  description = "Policy for SageMaker to write to CloudWatch Logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Effect = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sagemaker_cloudwatch_access_attachment" {
  role       = aws_iam_role.sagemaker_role.name
  policy_arn = aws_iam_policy.sagemaker_cloudwatch_access.arn
}

# SageMaker ECR Access Policy
resource "aws_iam_policy" "sagemaker_ecr_access" {
  name        = "${var.sagemaker_role_name}-ecr-access"
  description = "Policy for SageMaker to access ECR repositories"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
        Effect = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sagemaker_ecr_access_attachment" {
  role       = aws_iam_role.sagemaker_role.name
  policy_arn = aws_iam_policy.sagemaker_ecr_access.arn
}
