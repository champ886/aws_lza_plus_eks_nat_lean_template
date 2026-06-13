# ============================================================================
# Outputs
# ============================================================================

output "alb_controller_role_arn" {
  description = "IAM role ARN used by the ALB controller"
  value       = module.eks_alb.alb_controller_role_arn
}
