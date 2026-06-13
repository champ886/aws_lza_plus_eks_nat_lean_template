output "karpenter_controller_role_arn" {
  description = "Karpenter controller IAM role ARN"
  value       = module.eks_karpenter.karpenter_controller_role_arn
}

output "interruption_queue_url" {
  description = "SQS queue for spot interruption handling"
  value       = module.eks_karpenter.interruption_queue_url
}
