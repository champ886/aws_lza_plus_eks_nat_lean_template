# ============================================================================
# Kubecost Module Outputs
# ============================================================================

output "kubecost_role_arn" {
  description = "IAM role ARN for Kubecost"
  value       = aws_iam_role.kubecost.arn
}

output "kubecost_ui" {
  description = "How to access Kubecost UI"
  value       = "kubectl port-forward svc/kubecost-cost-analyzer -n kubecost 9090:9090 then open http://localhost:9090"
}
