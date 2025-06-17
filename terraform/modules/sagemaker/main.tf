# SageMaker Module for Video Super-Resolution Pipeline
# This module creates SageMaker resources for model deployment

# SageMaker Model for Real-ESRGAN
resource "aws_sagemaker_model" "realesrgan" {
  name               = "${var.name_prefix}-realesrgan"
  execution_role_arn = var.sagemaker_role_arn

  primary_container {
    image          = var.realesrgan_image_uri
    model_data_url = var.realesrgan_model_data_url
  }

  tags = var.tags
}

# SageMaker Model for SwinIR
resource "aws_sagemaker_model" "swinir" {
  name               = "${var.name_prefix}-swinir"
  execution_role_arn = var.sagemaker_role_arn

  primary_container {
    image          = var.swinir_image_uri
    model_data_url = var.swinir_model_data_url
  }

  tags = var.tags
}

# SageMaker Endpoint Configuration for Real-ESRGAN
resource "aws_sagemaker_endpoint_configuration" "realesrgan" {
  name = "${var.name_prefix}-realesrgan-config"

  production_variants {
    variant_name           = "default"
    model_name             = aws_sagemaker_model.realesrgan.name
    instance_type          = var.realesrgan_instance_type
    initial_instance_count = var.realesrgan_instance_count
  }

  tags = var.tags
}

# SageMaker Endpoint Configuration for SwinIR
resource "aws_sagemaker_endpoint_configuration" "swinir" {
  name = "${var.name_prefix}-swinir-config"

  production_variants {
    variant_name           = "default"
    model_name             = aws_sagemaker_model.swinir.name
    instance_type          = var.swinir_instance_type
    initial_instance_count = var.swinir_instance_count
  }

  tags = var.tags
}

# SageMaker Endpoint for Real-ESRGAN
resource "aws_sagemaker_endpoint" "realesrgan" {
  name                 = "${var.name_prefix}-realesrgan"
  endpoint_config_name = aws_sagemaker_endpoint_configuration.realesrgan.name

  tags = var.tags
}

# SageMaker Endpoint for SwinIR
resource "aws_sagemaker_endpoint" "swinir" {
  name                 = "${var.name_prefix}-swinir"
  endpoint_config_name = aws_sagemaker_endpoint_configuration.swinir.name

  tags = var.tags
}

# CloudWatch Alarms for SageMaker Endpoints
resource "aws_cloudwatch_metric_alarm" "sagemaker_invocation_errors" {
  for_each = {
    realesrgan = aws_sagemaker_endpoint.realesrgan.name
    swinir     = aws_sagemaker_endpoint.swinir.name
  }

  alarm_name          = "${each.value}-invocation-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Invocation4XXErrors"
  namespace           = "AWS/SageMaker"
  period              = 300
  statistic           = "Sum"
  threshold           = var.error_threshold
  alarm_description   = "This alarm monitors SageMaker endpoint invocation errors"
  
  dimensions = {
    EndpointName = each.value
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions
  
  tags = var.tags
}

# Auto-scaling configuration for SageMaker endpoints
resource "aws_appautoscaling_target" "sagemaker_endpoints" {
  for_each = {
    realesrgan = aws_sagemaker_endpoint.realesrgan.name
    swinir     = aws_sagemaker_endpoint.swinir.name
  }

  max_capacity       = var.max_endpoint_capacity
  min_capacity       = var.min_endpoint_capacity
  resource_id        = "endpoint/${each.value}/variant/default"
  scalable_dimension = "sagemaker:variant:DesiredInstanceCount"
  service_namespace  = "sagemaker"
}

resource "aws_appautoscaling_policy" "sagemaker_endpoints_cpu" {
  for_each = aws_appautoscaling_target.sagemaker_endpoints

  name               = "${each.value.resource_id}-cpu-utilization"
  policy_type        = "TargetTrackingScaling"
  resource_id        = each.value.resource_id
  scalable_dimension = each.value.scalable_dimension
  service_namespace  = each.value.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "SageMakerVariantCPUUtilization"
    }
    target_value = var.target_cpu_utilization
  }
}