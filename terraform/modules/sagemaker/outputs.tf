# Outputs for SageMaker Module

# Endpoint Names
output "realesrgan_endpoint_name" {
  description = "Name of the Real-ESRGAN SageMaker endpoint"
  value       = aws_sagemaker_endpoint.realesrgan.name
}

output "swinir_endpoint_name" {
  description = "Name of the SwinIR SageMaker endpoint"
  value       = aws_sagemaker_endpoint.swinir.name
}

# Endpoint ARNs
output "realesrgan_endpoint_arn" {
  description = "ARN of the Real-ESRGAN SageMaker endpoint"
  value       = aws_sagemaker_endpoint.realesrgan.arn
}

output "swinir_endpoint_arn" {
  description = "ARN of the SwinIR SageMaker endpoint"
  value       = aws_sagemaker_endpoint.swinir.arn
}

# Model ARNs
output "realesrgan_model_arn" {
  description = "ARN of the Real-ESRGAN SageMaker model"
  value       = aws_sagemaker_model.realesrgan.arn
}

output "swinir_model_arn" {
  description = "ARN of the SwinIR SageMaker model"
  value       = aws_sagemaker_model.swinir.arn
}

# Endpoint Configuration ARNs
output "realesrgan_endpoint_config_arn" {
  description = "ARN of the Real-ESRGAN SageMaker endpoint configuration"
  value       = aws_sagemaker_endpoint_configuration.realesrgan.arn
}

output "swinir_endpoint_config_arn" {
  description = "ARN of the SwinIR SageMaker endpoint configuration"
  value       = aws_sagemaker_endpoint_configuration.swinir.arn
}

# CloudWatch Alarm ARNs
output "sagemaker_alarm_arns" {
  description = "Map of SageMaker CloudWatch alarm ARNs"
  value       = { for k, v in aws_cloudwatch_metric_alarm.sagemaker_invocation_errors : k => v.arn }
}

# Endpoint URLs (for API access)
output "endpoint_urls" {
  description = "Map of SageMaker endpoint URLs for API access"
  value = {
    realesrgan = "https://runtime.sagemaker.${data.aws_region.current.name}.amazonaws.com/endpoints/${aws_sagemaker_endpoint.realesrgan.name}/invocations"
    swinir     = "https://runtime.sagemaker.${data.aws_region.current.name}.amazonaws.com/endpoints/${aws_sagemaker_endpoint.swinir.name}/invocations"
  }
}

# Current AWS Region
data "aws_region" "current" {}