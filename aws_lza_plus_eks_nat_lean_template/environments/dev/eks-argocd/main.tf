module "eks_argocd" {
  source    = "../../../modules/eks-argocd"
  providers = { aws = aws.workload }

  cluster_name      = data.terraform_remote_state.eks_cluster.outputs.cluster_name
  environment       = var.environment
  aws_region        = var.aws_region
  git_repo_url      = var.git_repo_url

  # ALL secrets passed through - none hardcoded
  postgres_db       = var.postgres_db
  postgres_user     = var.postgres_user
  postgres_password = var.postgres_password
  pgadmin_email     = var.pgadmin_email
  pgadmin_password  = var.pgadmin_password
}