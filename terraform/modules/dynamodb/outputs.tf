# Outputs for DynamoDB Module

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table for job metadata"
  value       = aws_dynamodb_table.job_metadata.arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for job metadata"
  value       = aws_dynamodb_table.job_metadata.name
}

output "dynamodb_table_id" {
  description = "ID of the DynamoDB table for job metadata"
  value       = aws_dynamodb_table.job_metadata.id
}