# Compliance Reports for Video Super-Resolution Pipeline
# This module creates resources for generating regular compliance reports

# AWS Config Configuration Recorder
resource "aws_config_configuration_recorder" "recorder" {
  name     = "${var.name_prefix}-config-recorder"
  role_arn = aws_iam_role.config_role.arn
  
  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

# AWS Config Delivery Channel
resource "aws_config_delivery_channel" "delivery_channel" {
  name           = "${var.name_prefix}-config-delivery-channel"
  s3_bucket_name = var.config_bucket_name
  s3_key_prefix  = "config"
  
  snapshot_delivery_properties {
    delivery_frequency = var.config_delivery_frequency
  }
  
  depends_on = [aws_config_configuration_recorder.recorder]
}

# Enable AWS Config Recording
resource "aws_config_configuration_recorder_status" "recorder_status" {
  name       = aws_config_configuration_recorder.recorder.name
  is_enabled = true
  
  depends_on = [aws_config_delivery_channel.delivery_channel]
}

# IAM Role for AWS Config
resource "aws_iam_role" "config_role" {
  name = "${var.name_prefix}-config-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })
  
  tags = var.tags
}

# IAM Policy for AWS Config
resource "aws_iam_policy" "config_policy" {
  name        = "${var.name_prefix}-config-policy"
  description = "Policy for AWS Config to access resources and deliver to S3"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:s3:::${var.config_bucket_name}/config/*"
        Condition = {
          StringLike = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Action = [
          "s3:GetBucketAcl"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:s3:::${var.config_bucket_name}"
      },
      {
        Action = [
          "config:Put*",
          "config:Get*",
          "config:List*",
          "config:Describe*"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Attach IAM Policy to Role
resource "aws_iam_role_policy_attachment" "config_policy_attachment" {
  role       = aws_iam_role.config_role.name
  policy_arn = aws_iam_policy.config_policy.arn
}

# Attach AWS Managed Config Policy
resource "aws_iam_role_policy_attachment" "config_managed_policy" {
  role       = aws_iam_role.config_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRole"
}

# AWS Config Rules
resource "aws_config_config_rule" "s3_bucket_public_read_prohibited" {
  name        = "s3-bucket-public-read-prohibited"
  description = "Checks that your S3 buckets do not allow public read access"
  
  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }
  
  depends_on = [aws_config_configuration_recorder.recorder]
}

resource "aws_config_config_rule" "s3_bucket_public_write_prohibited" {
  name        = "s3-bucket-public-write-prohibited"
  description = "Checks that your S3 buckets do not allow public write access"
  
  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_WRITE_PROHIBITED"
  }
  
  depends_on = [aws_config_configuration_recorder.recorder]
}

resource "aws_config_config_rule" "s3_bucket_ssl_requests_only" {
  name        = "s3-bucket-ssl-requests-only"
  description = "Checks whether S3 buckets have policies that require requests to use SSL"
  
  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SSL_REQUESTS_ONLY"
  }
  
  depends_on = [aws_config_configuration_recorder.recorder]
}

resource "aws_config_config_rule" "s3_bucket_server_side_encryption_enabled" {
  name        = "s3-bucket-server-side-encryption-enabled"
  description = "Checks whether S3 bucket have encryption enabled"
  
  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
  }
  
  depends_on = [aws_config_configuration_recorder.recorder]
}

resource "aws_config_config_rule" "cloudtrail_enabled" {
  name        = "cloudtrail-enabled"
  description = "Checks whether AWS CloudTrail is enabled in your AWS account"
  
  source {
    owner             = "AWS"
    source_identifier = "CLOUD_TRAIL_ENABLED"
  }
  
  depends_on = [aws_config_configuration_recorder.recorder]
}

resource "aws_config_config_rule" "cloudwatch_log_group_encrypted" {
  name        = "cloudwatch-log-group-encrypted"
  description = "Checks whether CloudWatch Log Groups are encrypted"
  
  source {
    owner             = "AWS"
    source_identifier = "CLOUDWATCH_LOG_GROUP_ENCRYPTED"
  }
  
  depends_on = [aws_config_configuration_recorder.recorder]
}

# Lambda Function for Generating Compliance Reports
resource "aws_lambda_function" "compliance_report_generator" {
  function_name    = "${var.name_prefix}-compliance-report-generator"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "python3.9"
  timeout          = 300
  memory_size      = 256
  
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  
  environment {
    variables = {
      CONFIG_BUCKET_NAME = var.config_bucket_name
      REPORT_BUCKET_NAME = var.report_bucket_name
      SNS_TOPIC_ARN      = var.sns_topic_arn
    }
  }
  
  tags = var.tags
}

# Lambda IAM Role
resource "aws_iam_role" "lambda_role" {
  name = "${var.name_prefix}-compliance-report-lambda-role"
  
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

# Lambda IAM Policy
resource "aws_iam_policy" "lambda_policy" {
  name        = "${var.name_prefix}-compliance-report-lambda-policy"
  description = "Policy for Lambda to generate compliance reports"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:s3:::${var.config_bucket_name}",
          "arn:aws:s3:::${var.config_bucket_name}/*"
        ]
      },
      {
        Action = [
          "s3:PutObject"
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:s3:::${var.report_bucket_name}",
          "arn:aws:s3:::${var.report_bucket_name}/*"
        ]
      },
      {
        Action = [
          "config:DescribeConfigRules",
          "config:DescribeConfigRuleEvaluationStatus",
          "config:GetComplianceDetailsByConfigRule"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "sns:Publish"
        ]
        Effect   = "Allow"
        Resource = var.sns_topic_arn
      }
    ]
  })
}

# Attach Lambda Policy to Role
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# Lambda Function Code
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"
  
  source {
    content  = <<EOF
import boto3
import json
import os
import datetime

def handler(event, context):
    # Get environment variables
    config_bucket = os.environ['CONFIG_BUCKET_NAME']
    report_bucket = os.environ['REPORT_BUCKET_NAME']
    sns_topic_arn = os.environ['SNS_TOPIC_ARN']
    
    # Initialize AWS clients
    config_client = boto3.client('config')
    s3_client = boto3.client('s3')
    sns_client = boto3.client('sns')
    
    # Get list of Config Rules
    rules_response = config_client.describe_config_rules()
    
    # Generate report
    report = {
        'report_date': datetime.datetime.now().isoformat(),
        'rules_compliance': []
    }
    
    for rule in rules_response['ConfigRules']:
        rule_name = rule['ConfigRuleName']
        
        # Get compliance details for the rule
        compliance = config_client.get_compliance_details_by_config_rule(
            ConfigRuleName=rule_name,
            ComplianceTypes=['COMPLIANT', 'NON_COMPLIANT']
        )
        
        # Count compliant and non-compliant resources
        compliant_count = 0
        non_compliant_count = 0
        non_compliant_resources = []
        
        for eval_result in compliance.get('EvaluationResults', []):
            if eval_result['ComplianceType'] == 'COMPLIANT':
                compliant_count += 1
            else:
                non_compliant_count += 1
                non_compliant_resources.append({
                    'resource_id': eval_result['EvaluationResultIdentifier']['EvaluationResultQualifier']['ResourceId'],
                    'resource_type': eval_result['EvaluationResultIdentifier']['EvaluationResultQualifier']['ResourceType']
                })
        
        # Add rule compliance to report
        report['rules_compliance'].append({
            'rule_name': rule_name,
            'compliant_resources': compliant_count,
            'non_compliant_resources': non_compliant_count,
            'non_compliant_details': non_compliant_resources
        })
    
    # Calculate overall compliance percentage
    total_resources = 0
    total_compliant = 0
    
    for rule_compliance in report['rules_compliance']:
        rule_total = rule_compliance['compliant_resources'] + rule_compliance['non_compliant_resources']
        total_resources += rule_total
        total_compliant += rule_compliance['compliant_resources']
    
    if total_resources > 0:
        report['overall_compliance_percentage'] = (total_compliant / total_resources) * 100
    else:
        report['overall_compliance_percentage'] = 100  # No resources to evaluate
    
    # Generate report filename with timestamp
    timestamp = datetime.datetime.now().strftime('%Y-%m-%d-%H-%M-%S')
    report_filename = f'compliance-report-{timestamp}.json'
    
    # Upload report to S3
    s3_client.put_object(
        Bucket=report_bucket,
        Key=f'compliance-reports/{report_filename}',
        Body=json.dumps(report, indent=2),
        ContentType='application/json'
    )
    
    # Send SNS notification
    sns_client.publish(
        TopicArn=sns_topic_arn,
        Subject='Compliance Report Generated',
        Message=f'A new compliance report has been generated and is available at s3://{report_bucket}/compliance-reports/{report_filename}.\n\nOverall compliance: {report["overall_compliance_percentage"]:.2f}%'
    )
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Compliance report generated successfully',
            'report_location': f's3://{report_bucket}/compliance-reports/{report_filename}'
        })
    }
EOF
    filename = "index.py"
  }
}

# CloudWatch Event Rule for Scheduled Report Generation
resource "aws_cloudwatch_event_rule" "compliance_report_schedule" {
  name                = "${var.name_prefix}-compliance-report-schedule"
  description         = "Trigger compliance report generation on schedule"
  schedule_expression = var.report_schedule
  
  tags = var.tags
}

# CloudWatch Event Target
resource "aws_cloudwatch_event_target" "compliance_report_target" {
  rule      = aws_cloudwatch_event_rule.compliance_report_schedule.name
  target_id = "TriggerComplianceReportLambda"
  arn       = aws_lambda_function.compliance_report_generator.arn
}

# Lambda Permission for CloudWatch Events
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.compliance_report_generator.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.compliance_report_schedule.arn
}