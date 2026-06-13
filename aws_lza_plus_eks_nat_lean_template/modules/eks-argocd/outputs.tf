# ============================================================================
# ArgoCD Module Outputs
# ============================================================================

output "argocd_namespace" {
  description = "Namespace where ArgoCD is installed"
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "apps_namespace" {
  description = "Namespace where apps are deployed"
  value       = kubernetes_namespace.apps.metadata[0].name
}
