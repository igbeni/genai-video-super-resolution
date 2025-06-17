# Outputs for IAM Roles and Policies Module

# Lambda Role Outputs
output "lambda_role_name" {
  description = "The name of the Lambda execution role"
  value       = aws_iam_role.lambda_execution_role.name
}

output "lambda_role_arn" {
  description = "The ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution_role.arn
}

# EC2 Role Outputs
output "ec2_role_name" {
  description = "The name of the EC2 processing role"
  value       = aws_iam_role.ec2_processing_role.name
}

output "ec2_role_arn" {
  description = "The ARN of the EC2 processing role"
  value       = aws_iam_role.ec2_processing_role.arn
}

output "ec2_instance_profile_name" {
  description = "The name of the EC2 instance profile"
  value       = aws_iam_instance_profile.ec2_processing_profile.name
}

output "ec2_instance_profile_arn" {
  description = "The ARN of the EC2 instance profile"
  value       = aws_iam_instance_profile.ec2_processing_profile.arn
}

# AWS Batch Service Role Outputs
output "batch_service_role_name" {
  description = "The name of the AWS Batch service role"
  value       = aws_iam_role.batch_service_role.name
}

output "batch_service_role_arn" {
  description = "The ARN of the AWS Batch service role"
  value       = aws_iam_role.batch_service_role.arn
}

# AWS Batch Job Role Outputs
output "batch_job_role_name" {
  description = "The name of the AWS Batch job role"
  value       = aws_iam_role.batch_job_role.name
}

output "batch_job_role_arn" {
  description = "The ARN of the AWS Batch job role"
  value       = aws_iam_role.batch_job_role.arn
}

# SageMaker Role Outputs
output "sagemaker_role_name" {
  description = "The name of the SageMaker role"
  value       = aws_iam_role.sagemaker_role.name
}

output "sagemaker_role_arn" {
  description = "The ARN of the SageMaker role"
  value       = aws_iam_role.sagemaker_role.arn
}

# All Role ARNs Map
output "all_role_arns" {
  description = "Map of all IAM role ARNs"
  value = {
    lambda_execution = aws_iam_role.lambda_execution_role.arn
    ec2_processing   = aws_iam_role.ec2_processing_role.arn
    batch_service    = aws_iam_role.batch_service_role.arn
    batch_job        = aws_iam_role.batch_job_role.arn
    sagemaker        = aws_iam_role.sagemaker_role.arn
  }
}

# All Role Names Map
output "all_role_names" {
  description = "Map of all IAM role names"
  value = {
    lambda_execution = aws_iam_role.lambda_execution_role.name
    ec2_processing   = aws_iam_role.ec2_processing_role.name
    batch_service    = aws_iam_role.batch_service_role.name
    batch_job        = aws_iam_role.batch_job_role.name
    sagemaker        = aws_iam_role.sagemaker_role.name
  }
}
