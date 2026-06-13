# ============================================================================
# PROD VPC STACK PROVIDERS
# ============================================================================
# Assumes OrganizationAccountAccessRole in prod workload account
# ============================================================================

provider "aws" {
  alias  = "workload"
  region = var.aws_region
  
  assume_role {
    role_arn = "arn:aws:iam::${var.workload_account_id}:role/OrganizationAccountAccessRole"
  }

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Stack       = "prod-vpc"
    }
  }
}