# SQS Queues for Video Super-Resolution Pipeline Job Coordination
# This module creates SQS queues for:
# - Frame extraction jobs
# - Frame processing jobs
# - Video recomposition jobs
# - Completion notification jobs

# SQS Queue for Frame Extraction Jobs
resource "aws_sqs_queue" "frame_extraction_queue" {
  name                      = var.frame_extraction_queue_name
  delay_seconds             = var.delay_seconds
  max_message_size          = var.max_message_size
  message_retention_seconds = var.message_retention_seconds
  receive_wait_time_seconds = var.receive_wait_time_seconds
  visibility_timeout_seconds = var.visibility_timeout_seconds
  
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.frame_extraction_dlq.arn
    maxReceiveCount     = var.max_receive_count
  })
  
  tags = merge(
    var.tags,
    {
      Name = "Frame Extraction Queue"
      Description = "Queue for frame extraction jobs"
    }
  )
}

# Dead Letter Queue for Frame Extraction Jobs
resource "aws_sqs_queue" "frame_extraction_dlq" {
  name                      = "${var.frame_extraction_queue_name}-dlq"
  message_retention_seconds = var.dlq_message_retention_seconds
  
  tags = merge(
    var.tags,
    {
      Name = "Frame Extraction DLQ"
      Description = "Dead letter queue for frame extraction jobs"
    }
  )
}

# SQS Queue for Frame Processing Jobs
resource "aws_sqs_queue" "frame_processing_queue" {
  name                      = var.frame_processing_queue_name
  delay_seconds             = var.delay_seconds
  max_message_size          = var.max_message_size
  message_retention_seconds = var.message_retention_seconds
  receive_wait_time_seconds = var.receive_wait_time_seconds
  visibility_timeout_seconds = var.visibility_timeout_seconds
  
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.frame_processing_dlq.arn
    maxReceiveCount     = var.max_receive_count
  })
  
  tags = merge(
    var.tags,
    {
      Name = "Frame Processing Queue"
      Description = "Queue for frame processing jobs"
    }
  )
}

# Dead Letter Queue for Frame Processing Jobs
resource "aws_sqs_queue" "frame_processing_dlq" {
  name                      = "${var.frame_processing_queue_name}-dlq"
  message_retention_seconds = var.dlq_message_retention_seconds
  
  tags = merge(
    var.tags,
    {
      Name = "Frame Processing DLQ"
      Description = "Dead letter queue for frame processing jobs"
    }
  )
}

# SQS Queue for Video Recomposition Jobs
resource "aws_sqs_queue" "video_recomposition_queue" {
  name                      = var.video_recomposition_queue_name
  delay_seconds             = var.delay_seconds
  max_message_size          = var.max_message_size
  message_retention_seconds = var.message_retention_seconds
  receive_wait_time_seconds = var.receive_wait_time_seconds
  visibility_timeout_seconds = var.visibility_timeout_seconds
  
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.video_recomposition_dlq.arn
    maxReceiveCount     = var.max_receive_count
  })
  
  tags = merge(
    var.tags,
    {
      Name = "Video Recomposition Queue"
      Description = "Queue for video recomposition jobs"
    }
  )
}

# Dead Letter Queue for Video Recomposition Jobs
resource "aws_sqs_queue" "video_recomposition_dlq" {
  name                      = "${var.video_recomposition_queue_name}-dlq"
  message_retention_seconds = var.dlq_message_retention_seconds
  
  tags = merge(
    var.tags,
    {
      Name = "Video Recomposition DLQ"
      Description = "Dead letter queue for video recomposition jobs"
    }
  )
}

# SQS Queue for Completion Notification Jobs
resource "aws_sqs_queue" "completion_notification_queue" {
  name                      = var.completion_notification_queue_name
  delay_seconds             = var.delay_seconds
  max_message_size          = var.max_message_size
  message_retention_seconds = var.message_retention_seconds
  receive_wait_time_seconds = var.receive_wait_time_seconds
  visibility_timeout_seconds = var.visibility_timeout_seconds
  
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.completion_notification_dlq.arn
    maxReceiveCount     = var.max_receive_count
  })
  
  tags = merge(
    var.tags,
    {
      Name = "Completion Notification Queue"
      Description = "Queue for completion notification jobs"
    }
  )
}

# Dead Letter Queue for Completion Notification Jobs
resource "aws_sqs_queue" "completion_notification_dlq" {
  name                      = "${var.completion_notification_queue_name}-dlq"
  message_retention_seconds = var.dlq_message_retention_seconds
  
  tags = merge(
    var.tags,
    {
      Name = "Completion Notification DLQ"
      Description = "Dead letter queue for completion notification jobs"
    }
  )
}

# Subscribe SQS queues to SNS topics
resource "aws_sns_topic_subscription" "frame_extraction_subscription" {
  topic_arn = var.extract_frames_topic_arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.frame_extraction_queue.arn
}

resource "aws_sns_topic_subscription" "frame_processing_subscription" {
  topic_arn = var.processing_topic_arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.frame_processing_queue.arn
}

resource "aws_sns_topic_subscription" "video_recomposition_subscription" {
  topic_arn = var.recomposition_topic_arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.video_recomposition_queue.arn
}

resource "aws_sns_topic_subscription" "completion_notification_subscription" {
  topic_arn = var.notification_topic_arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.completion_notification_queue.arn
}

# SQS Queue Policy to allow SNS to send messages
resource "aws_sqs_queue_policy" "frame_extraction_queue_policy" {
  queue_url = aws_sqs_queue.frame_extraction_queue.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action = "sqs:SendMessage"
        Resource = aws_sqs_queue.frame_extraction_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = var.extract_frames_topic_arn
          }
        }
      }
    ]
  })
}

resource "aws_sqs_queue_policy" "frame_processing_queue_policy" {
  queue_url = aws_sqs_queue.frame_processing_queue.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action = "sqs:SendMessage"
        Resource = aws_sqs_queue.frame_processing_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = var.processing_topic_arn
          }
        }
      }
    ]
  })
}

resource "aws_sqs_queue_policy" "video_recomposition_queue_policy" {
  queue_url = aws_sqs_queue.video_recomposition_queue.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action = "sqs:SendMessage"
        Resource = aws_sqs_queue.video_recomposition_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = var.recomposition_topic_arn
          }
        }
      }
    ]
  })
}

resource "aws_sqs_queue_policy" "completion_notification_queue_policy" {
  queue_url = aws_sqs_queue.completion_notification_queue.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action = "sqs:SendMessage"
        Resource = aws_sqs_queue.completion_notification_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = var.notification_topic_arn
          }
        }
      }
    ]
  })
}