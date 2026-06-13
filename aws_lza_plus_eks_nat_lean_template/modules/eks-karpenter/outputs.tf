# ============================================================================
# Karpenter Module Outputs
# ============================================================================

output "karpenter_controller_role_arn" {
  description = "IAM role ARN for Karpenter controller"
  value       = aws_iam_role.karpenter_controller.arn
}

output "interruption_queue_url" {
  description = "SQS queue URL for spot interruption handling"
  value       = aws_sqs_queue.karpenter_interruption.url
}

output "interruption_queue_name" {
  description = "SQS queue name for spot interruption handling"
  value       = aws_sqs_queue.karpenter_interruption.name
}
