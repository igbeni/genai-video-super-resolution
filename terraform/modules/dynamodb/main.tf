# DynamoDB Table for Video Super-Resolution Pipeline
# This module creates a DynamoDB table for storing job metadata

resource "aws_dynamodb_table" "job_metadata" {
  name           = var.dynamodb_table_name
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "JobId"
  
  attribute {
    name = "JobId"
    type = "S"
  }
  
  attribute {
    name = "VideoName"
    type = "S"
  }
  
  attribute {
    name = "Status"
    type = "S"
  }
  
  global_secondary_index {
    name               = "VideoNameIndex"
    hash_key           = "VideoName"
    projection_type    = "ALL"
  }
  
  global_secondary_index {
    name               = "StatusIndex"
    hash_key           = "Status"
    projection_type    = "ALL"
  }
  
  point_in_time_recovery {
    enabled = true
  }
  
  tags = merge(
    var.tags,
    {
      Name = "Video Super-Resolution Job Metadata"
      Description = "Stores metadata for video super-resolution jobs"
    }
  )
}