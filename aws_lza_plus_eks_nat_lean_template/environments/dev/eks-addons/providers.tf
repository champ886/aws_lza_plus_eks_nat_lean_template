# ============================================================================
# Provider Configuration
# ============================================================================

provider "aws" {
  alias  = "workload"
  region = var.aws_region

  # Assumes the OrganizationAccountAccessRole in the dev workload account
  # This is how Terraform authenticates into account <DEV_ACCOUNT_ID>
  # Without this, Terraform uses your default credentials (management account)
  # and can't find the EKS cluster which lives in the workload account
  assume_role {
    role_arn = "arn:aws:iam::${var.workload_account_id}:role/OrganizationAccountAccessRole"
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.main.token
}