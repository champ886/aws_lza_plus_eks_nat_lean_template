# ============================================================================
# Dev Environment - EKS ALB Controller
# ============================================================================

module "eks_alb" {
  source    = "../../../modules/eks-alb"
  providers = { aws = aws.workload }

  cluster_name       = data.terraform_remote_state.eks_cluster.outputs.cluster_name
  environment        = var.environment
  aws_region         = var.aws_region
  vpc_id             = data.terraform_remote_state.dev_vpc.outputs.vpc_id
  public_subnet_ids  = data.terraform_remote_state.dev_vpc.outputs.public_subnet_ids
  private_subnet_ids = data.terraform_remote_state.dev_vpc.outputs.private_subnet_ids
  oidc_provider_arn  = data.terraform_remote_state.eks_cluster.outputs.oidc_provider_arn
  oidc_provider_url  = data.terraform_remote_state.eks_cluster.outputs.oidc_provider_url
}
