# ============================================================================
# Dev Environment - Kubecost (Free Tier)
# ============================================================================

module "eks_kubecost" {
  source    = "../../../modules/eks-kubecost"
  providers = { aws = aws.workload }

  cluster_name      = data.terraform_remote_state.eks_cluster.outputs.cluster_name
  environment       = var.environment
  aws_region        = var.aws_region
  aws_account_id    = var.workload_account_id
  oidc_provider_arn = data.terraform_remote_state.eks_cluster.outputs.oidc_provider_arn
  oidc_provider_url = data.terraform_remote_state.eks_cluster.outputs.oidc_provider_url
}
