# Variables for SQS Queues Module

variable "frame_extraction_queue_name" {
  description = "Name of the SQS queue for frame extraction jobs"
  type        = string
  default     = "frame-extraction-queue"
}

variable "frame_processing_queue_name" {
  description = "Name of the SQS queue for frame processing jobs"
  type        = string
  default     = "frame-processing-queue"
}

variable "video_recomposition_queue_name" {
  description = "Name of the SQS queue for video recomposition jobs"
  type        = string
  default     = "video-recomposition-queue"
}

variable "completion_notification_queue_name" {
  description = "Name of the SQS queue for completion notification jobs"
  type        = string
  default     = "completion-notification-queue"
}

variable "delay_seconds" {
  description = "The time in seconds that the delivery of all messages in the queue will be delayed"
  type        = number
  default     = 0
}

variable "max_message_size" {
  description = "The limit of how many bytes a message can contain before Amazon SQS rejects it"
  type        = number
  default     = 262144 # 256 KiB
}

variable "message_retention_seconds" {
  description = "The number of seconds Amazon SQS retains a message"
  type        = number
  default     = 345600 # 4 days
}

variable "receive_wait_time_seconds" {
  description = "The time for which a ReceiveMessage call will wait for a message to arrive"
  type        = number
  default     = 20
}

variable "visibility_timeout_seconds" {
  description = "The visibility timeout for the queue"
  type        = number
  default     = 30
}

variable "max_receive_count" {
  description = "The number of times a message can be received before being sent to the dead-letter queue"
  type        = number
  default     = 5
}

variable "dlq_message_retention_seconds" {
  description = "The number of seconds Amazon SQS retains a message in the dead-letter queue"
  type        = number
  default     = 1209600 # 14 days
}

variable "extract_frames_topic_arn" {
  description = "ARN of the SNS topic for frame extraction"
  type        = string
}

variable "processing_topic_arn" {
  description = "ARN of the SNS topic for frame processing"
  type        = string
}

variable "recomposition_topic_arn" {
  description = "ARN of the SNS topic for video recomposition"
  type        = string
}

variable "notification_topic_arn" {
  description = "ARN of the SNS topic for completion notification"
  type        = string
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}