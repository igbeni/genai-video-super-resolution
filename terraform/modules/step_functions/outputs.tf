# Outputs for AWS Step Functions Module

output "state_machine_id" {
  description = "The ID of the Step Functions state machine"
  value       = aws_sfn_state_machine.video_processing_workflow.id
}

output "state_machine_arn" {
  description = "The ARN of the Step Functions state machine"
  value       = aws_sfn_state_machine.video_processing_workflow.arn
}

output "state_machine_name" {
  description = "The name of the Step Functions state machine"
  value       = aws_sfn_state_machine.video_processing_workflow.name
}

output "step_functions_role_id" {
  description = "The ID of the IAM role for Step Functions"
  value       = aws_iam_role.step_functions_role.id
}

output "step_functions_role_arn" {
  description = "The ARN of the IAM role for Step Functions"
  value       = aws_iam_role.step_functions_role.arn
}

output "step_functions_role_name" {
  description = "The name of the IAM role for Step Functions"
  value       = aws_iam_role.step_functions_role.name
}

output "cloudwatch_log_group_arn" {
  description = "The ARN of the CloudWatch Log Group for Step Functions"
  value       = aws_cloudwatch_log_group.step_functions_log_group.arn
}

output "cloudwatch_log_group_name" {
  description = "The name of the CloudWatch Log Group for Step Functions"
  value       = aws_cloudwatch_log_group.step_functions_log_group.name
}