# ============================================================================
# Dev Environment - EKS Add-ons
# ============================================================================

module "eks_addons" {
  source    = "../../../modules/eks-addons"
  providers = { aws = aws.workload }

  cluster_name = data.terraform_remote_state.eks_cluster.outputs.cluster_name
  environment  = var.environment

  # Versions pinned to Kubernetes 1.32 compatible releases
  addon_version_vpc_cni    = "v1.19.0-eksbuild.1"
  addon_version_coredns    = "v1.11.3-eksbuild.1"
  addon_version_kube_proxy = "v1.32.0-eksbuild.2"
}
