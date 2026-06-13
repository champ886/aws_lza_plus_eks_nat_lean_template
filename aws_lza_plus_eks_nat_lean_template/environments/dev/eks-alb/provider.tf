# ============================================================================
# Provider Configuration
# ============================================================================

provider "aws" {
  alias  = "workload"
  region = var.aws_region

  # Assumes role into the dev workload account (same as eks-cluster + eks-addons)
  assume_role {
    role_arn = "arn:aws:iam::${var.workload_account_id}:role/OrganizationAccountAccessRole"
  }
}

# Helm provider uses the EKS cluster credentials to install the controller
provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.main.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.main.token
  }
}
