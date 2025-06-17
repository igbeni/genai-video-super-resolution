# Outputs for VPC Endpoints Module

output "s3_vpc_endpoint_id" {
  description = "ID of the S3 VPC endpoint"
  value       = aws_vpc_endpoint.s3.id
}

output "s3_vpc_endpoint_prefix_list_id" {
  description = "Prefix list ID of the S3 VPC endpoint"
  value       = aws_vpc_endpoint.s3.prefix_list_id
}

output "dynamodb_vpc_endpoint_id" {
  description = "ID of the DynamoDB VPC endpoint"
  value       = aws_vpc_endpoint.dynamodb.id
}

output "dynamodb_vpc_endpoint_prefix_list_id" {
  description = "Prefix list ID of the DynamoDB VPC endpoint"
  value       = aws_vpc_endpoint.dynamodb.prefix_list_id
}

output "logs_vpc_endpoint_id" {
  description = "ID of the CloudWatch Logs VPC endpoint"
  value       = aws_vpc_endpoint.logs.id
}

output "logs_vpc_endpoint_dns_entries" {
  description = "DNS entries for the CloudWatch Logs VPC endpoint"
  value       = aws_vpc_endpoint.logs.dns_entry
}

output "monitoring_vpc_endpoint_id" {
  description = "ID of the CloudWatch Monitoring VPC endpoint"
  value       = aws_vpc_endpoint.monitoring.id
}

output "monitoring_vpc_endpoint_dns_entries" {
  description = "DNS entries for the CloudWatch Monitoring VPC endpoint"
  value       = aws_vpc_endpoint.monitoring.dns_entry
}

output "sns_vpc_endpoint_id" {
  description = "ID of the SNS VPC endpoint"
  value       = aws_vpc_endpoint.sns.id
}

output "sns_vpc_endpoint_dns_entries" {
  description = "DNS entries for the SNS VPC endpoint"
  value       = aws_vpc_endpoint.sns.dns_entry
}

output "sqs_vpc_endpoint_id" {
  description = "ID of the SQS VPC endpoint"
  value       = aws_vpc_endpoint.sqs.id
}

output "sqs_vpc_endpoint_dns_entries" {
  description = "DNS entries for the SQS VPC endpoint"
  value       = aws_vpc_endpoint.sqs.dns_entry
}

output "vpc_endpoints_security_group_id" {
  description = "ID of the security group for VPC endpoints"
  value       = aws_security_group.vpc_endpoints.id
}