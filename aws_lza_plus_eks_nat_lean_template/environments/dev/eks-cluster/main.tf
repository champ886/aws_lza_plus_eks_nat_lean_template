# ============================================================================
# Dev Environment - EKS Cluster
# ============================================================================

module "eks_cluster" {
  source    = "../../../modules/eks-cluster"
  providers = { aws = aws.workload }

  cluster_name    = "dev-eks-cluster"
  cluster_version = "1.32"
  environment     = "dev"

  vpc_id                  = data.terraform_remote_state.dev_vpc.outputs.vpc_id
  private_subnet_ids      = data.terraform_remote_state.dev_vpc.outputs.private_subnet_ids
  public_subnet_ids       = data.terraform_remote_state.dev_vpc.outputs.public_subnet_ids
  private_route_table_ids = data.terraform_remote_state.dev_vpc.outputs.private_route_table_ids

  workload_account_id = var.workload_account_id
  cluster_admin_arns  = var.cluster_admin_arns
}
