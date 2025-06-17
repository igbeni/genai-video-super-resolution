# AWS Step Functions for Video Super-Resolution Pipeline Orchestration

# Step Functions State Machine
resource "aws_sfn_state_machine" "video_processing_workflow" {
  name     = var.state_machine_name
  role_arn = var.step_functions_role_arn

  definition = jsonencode({
    Comment = "Video Super-Resolution Processing Workflow",
    StartAt = "TriggerFrameExtraction",
    States = {
      "TriggerFrameExtraction" = {
        Type     = "Task",
        Resource = var.frame_extraction_function_arn,
        Next     = "WaitForFrameExtraction"
      },
      "WaitForFrameExtraction" = {
        Type     = "Wait",
        Seconds  = 10,
        Next     = "CheckFrameExtractionStatus"
      },
      "CheckFrameExtractionStatus" = {
        Type     = "Task",
        Resource = var.check_status_function_arn != null ? var.check_status_function_arn : var.frame_extraction_function_arn,
        Parameters = {
          "stage.$" = "$.stage",
          "taskId.$" = "$.taskId"
        },
        ResultPath = "$.extractionResult",
        Next       = "IsFrameExtractionComplete"
      },
      "IsFrameExtractionComplete" = {
        Type        = "Choice",
        Choices     = [
          {
            Variable    = "$.extractionResult.status",
            StringEquals = "COMPLETED",
            Next        = "TriggerFrameProcessing"
          },
          {
            Variable    = "$.extractionResult.status",
            StringEquals = "FAILED",
            Next        = "FrameExtractionFailed"
          }
        ],
        Default     = "WaitForFrameExtraction"
      },
      "FrameExtractionFailed" = {
        Type     = "Fail",
        Error    = "FrameExtractionFailed",
        Cause    = "Frame extraction process failed"
      },
      "TriggerFrameProcessing" = {
        Type     = "Task",
        Resource = var.frame_processing_function_arn,
        Next     = "WaitForFrameProcessing"
      },
      "WaitForFrameProcessing" = {
        Type     = "Wait",
        Seconds  = 30,
        Next     = "CheckFrameProcessingStatus"
      },
      "CheckFrameProcessingStatus" = {
        Type     = "Task",
        Resource = var.check_status_function_arn != null ? var.check_status_function_arn : var.frame_extraction_function_arn,
        Parameters = {
          "stage.$" = "$.stage",
          "taskId.$" = "$.taskId"
        },
        ResultPath = "$.processingResult",
        Next       = "IsFrameProcessingComplete"
      },
      "IsFrameProcessingComplete" = {
        Type        = "Choice",
        Choices     = [
          {
            Variable    = "$.processingResult.status",
            StringEquals = "COMPLETED",
            Next        = "TriggerVideoRecomposition"
          },
          {
            Variable    = "$.processingResult.status",
            StringEquals = "FAILED",
            Next        = "FrameProcessingFailed"
          }
        ],
        Default     = "WaitForFrameProcessing"
      },
      "FrameProcessingFailed" = {
        Type     = "Fail",
        Error    = "FrameProcessingFailed",
        Cause    = "Frame processing failed"
      },
      "TriggerVideoRecomposition" = {
        Type     = "Task",
        Resource = var.video_recomposition_function_arn,
        Next     = "WaitForVideoRecomposition"
      },
      "WaitForVideoRecomposition" = {
        Type     = "Wait",
        Seconds  = 20,
        Next     = "CheckVideoRecompositionStatus"
      },
      "CheckVideoRecompositionStatus" = {
        Type     = "Task",
        Resource = var.check_status_function_arn != null ? var.check_status_function_arn : var.frame_extraction_function_arn,
        Parameters = {
          "stage.$" = "$.stage",
          "taskId.$" = "$.taskId"
        },
        ResultPath = "$.recompositionResult",
        Next       = "IsVideoRecompositionComplete"
      },
      "IsVideoRecompositionComplete" = {
        Type        = "Choice",
        Choices     = [
          {
            Variable    = "$.recompositionResult.status",
            StringEquals = "COMPLETED",
            Next        = "SendCompletionNotification"
          },
          {
            Variable    = "$.recompositionResult.status",
            StringEquals = "FAILED",
            Next        = "VideoRecompositionFailed"
          }
        ],
        Default     = "WaitForVideoRecomposition"
      },
      "VideoRecompositionFailed" = {
        Type     = "Fail",
        Error    = "VideoRecompositionFailed",
        Cause    = "Video recomposition failed"
      },
      "SendCompletionNotification" = {
        Type     = "Task",
        Resource = var.completion_notification_function_arn,
        End      = true
      }
    }
  })

  logging_configuration {
    log_destination        = "${var.cloudwatch_log_group_arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  tags = var.tags
}

# CloudWatch Log Group for Step Functions
resource "aws_cloudwatch_log_group" "step_functions_log_group" {
  name              = "/aws/states/${var.state_machine_name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# IAM Role for Step Functions
resource "aws_iam_role" "step_functions_role" {
  name = var.step_functions_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Policy for Step Functions
resource "aws_iam_policy" "step_functions_policy" {
  name        = "${var.step_functions_role_name}-policy"
  description = "Policy for Step Functions to invoke Lambda functions and access CloudWatch Logs"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "lambda:InvokeFunction"
        ],
        Effect = "Allow",
        Resource = concat([
          var.frame_extraction_function_arn,
          var.frame_processing_function_arn,
          var.video_recomposition_function_arn,
          var.completion_notification_function_arn
        ], var.check_status_function_arn != null ? [var.check_status_function_arn] : [])
      },
      {
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutLogEvents",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ],
        Effect = "Allow",
        Resource = "*"
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "step_functions_policy_attachment" {
  role       = aws_iam_role.step_functions_role.name
  policy_arn = aws_iam_policy.step_functions_policy.arn
}
