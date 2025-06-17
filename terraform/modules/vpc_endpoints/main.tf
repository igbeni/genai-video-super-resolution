# VPC Endpoints for Video Super-Resolution Pipeline
# This module creates VPC endpoints for secure access to AWS services without traversing the public internet

# VPC Endpoint for S3
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.route_table_ids

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
          "arn:aws:s3:::${var.source_bucket_name}",
          "arn:aws:s3:::${var.source_bucket_name}/*",
          "arn:aws:s3:::${var.processed_frames_bucket_name}",
          "arn:aws:s3:::${var.processed_frames_bucket_name}/*",
          "arn:aws:s3:::${var.final_videos_bucket_name}",
          "arn:aws:s3:::${var.final_videos_bucket_name}/*",
          "arn:aws:s3:::${var.access_logs_bucket_name}",
          "arn:aws:s3:::${var.access_logs_bucket_name}/*"
        ]
        Principal = "*"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-s3-endpoint"
    }
  )
}

# VPC Endpoint for DynamoDB
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.route_table_ids

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
        Principal = "*"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-dynamodb-endpoint"
    }
  )
}

# VPC Endpoint for CloudWatch Logs
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-logs-endpoint"
    }
  )
}

# VPC Endpoint for CloudWatch
resource "aws_vpc_endpoint" "monitoring" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.monitoring"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-monitoring-endpoint"
    }
  )
}

# VPC Endpoint for SNS
resource "aws_vpc_endpoint" "sns" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.sns"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-sns-endpoint"
    }
  )
}

# VPC Endpoint for SQS
resource "aws_vpc_endpoint" "sqs" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.sqs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-sqs-endpoint"
    }
  )
}

# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.name_prefix}-vpc-endpoints-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
    description = "HTTPS from VPC"
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
    description = "Allow HTTPS outbound traffic within VPC"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-vpc-endpoints-sg"
    }
  )
}
