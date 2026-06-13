# ============================================================================
# Outputs
# ============================================================================

output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks_cluster.cluster_id
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks_cluster.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks_cluster.cluster_endpoint
}

output "cluster_version" {
  description = "EKS cluster Kubernetes version"
  value       = module.eks_cluster.cluster_version
}

output "cluster_security_group_id" {
  description = "Cluster security group ID"
  value       = module.eks_cluster.cluster_security_group_id
}

output "node_security_group_id" {
  description = "Node security group ID"
  value       = module.eks_cluster.node_security_group_id
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN"
  value       = module.eks_cluster.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "OIDC provider URL"
  value       = module.eks_cluster.oidc_provider_url
}

output "node_role_arn" {
  description = "Node IAM role ARN"
  value       = module.eks_cluster.node_role_arn
}
