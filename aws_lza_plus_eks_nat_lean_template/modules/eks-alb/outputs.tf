# ============================================================================
# EKS ALB Controller Module Outputs
# ============================================================================

output "alb_controller_role_arn" {
  description = "IAM role ARN for the ALB controller"
  value       = aws_iam_role.alb_controller.arn
}

output "alb_controller_policy_arn" {
  description = "IAM policy ARN for the ALB controller"
  value       = aws_iam_policy.alb_controller.arn
}
