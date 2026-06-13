# ============================================================================
# Outputs
# ============================================================================

output "argocd_namespace" {
  value = module.eks_argocd.argocd_namespace
}

output "apps_namespace" {
  value = module.eks_argocd.apps_namespace
}

output "argocd_access" {
  description = "How to access ArgoCD UI"
  value       = "kubectl port-forward svc/argocd-server -n argocd 8080:80"
}
