# ============================================================================
# EKS Add-ons Module Outputs
# ============================================================================

output "vpc_cni_version" {
  description = "Deployed VPC CNI add-on version"
  value       = var.enable_vpc_cni ? aws_eks_addon.vpc_cni[0].addon_version : null
}

output "vpc_cni_arn" {
  description = "ARN of the VPC CNI add-on"
  value       = var.enable_vpc_cni ? aws_eks_addon.vpc_cni[0].arn : null
}

output "coredns_version" {
  description = "Deployed CoreDNS add-on version"
  value       = var.enable_coredns ? aws_eks_addon.coredns[0].addon_version : null
}

output "coredns_arn" {
  description = "ARN of the CoreDNS add-on"
  value       = var.enable_coredns ? aws_eks_addon.coredns[0].arn : null
}

output "kube_proxy_version" {
  description = "Deployed kube-proxy add-on version"
  value       = var.enable_kube_proxy ? aws_eks_addon.kube_proxy[0].addon_version : null
}

output "kube_proxy_arn" {
  description = "ARN of the kube-proxy add-on"
  value       = var.enable_kube_proxy ? aws_eks_addon.kube_proxy[0].arn : null
}

output "pod_identity_arn" {
  description = "ARN of the Pod Identity Agent add-on"
  value       = var.enable_pod_identity ? aws_eks_addon.pod_identity[0].arn : null
}

output "all_addon_versions" {
  description = "Map of all deployed add-on versions"
  value = {
    vpc_cni      = var.enable_vpc_cni ? aws_eks_addon.vpc_cni[0].addon_version : "disabled"
    coredns      = var.enable_coredns ? aws_eks_addon.coredns[0].addon_version : "disabled"
    kube_proxy   = var.enable_kube_proxy ? aws_eks_addon.kube_proxy[0].addon_version : "disabled"
    pod_identity = var.enable_pod_identity ? aws_eks_addon.pod_identity[0].arn : "disabled"
  }
}