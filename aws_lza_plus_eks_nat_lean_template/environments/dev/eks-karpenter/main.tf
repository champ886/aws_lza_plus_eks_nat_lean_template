# ============================================================================
# Dev Environment - Karpenter
# Reads state from aws_lza_plus_eks_nat_lean repo
# ============================================================================

module "eks_karpenter" {
  source    = "../../../modules/eks-karpenter"
  providers = { aws = aws.workload }

  cluster_name           = data.terraform_remote_state.eks_cluster.outputs.cluster_name
  environment            = var.environment
  aws_region             = var.aws_region
  private_subnet_ids     = data.terraform_remote_state.dev_vpc.outputs.private_subnet_ids
  node_security_group_id = data.terraform_remote_state.eks_cluster.outputs.node_security_group_id
  node_role_arn          = data.terraform_remote_state.eks_cluster.outputs.node_role_arn
  oidc_provider_arn      = data.terraform_remote_state.eks_cluster.outputs.oidc_provider_arn
  oidc_provider_url      = data.terraform_remote_state.eks_cluster.outputs.oidc_provider_url
}
