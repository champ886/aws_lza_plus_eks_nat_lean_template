# ============================================================================
# Dev EKS Add-ons Outputs
# ============================================================================

output "addon_versions" {
  description = "Map of all deployed add-on versions"
  value       = module.eks_addons.all_addon_versions
}

output "vpc_cni_version" {
  description = "Deployed VPC CNI version"
  value       = module.eks_addons.vpc_cni_version
}

output "coredns_version" {
  description = "Deployed CoreDNS version"
  value       = module.eks_addons.coredns_version
}

output "kube_proxy_version" {
  description = "Deployed kube-proxy version"
  value       = module.eks_addons.kube_proxy_version
}