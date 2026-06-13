# ============================================================================
# DEV VPC STACK PROVIDERS
# ============================================================================
# Assumes OrganizationAccountAccessRole in dev workload account
# ============================================================================

provider "aws" {
  alias  = "dev_workload"
  region = var.aws_region
  
  assume_role {
    role_arn = "arn:aws:iam::${var.dev_workload_account_id}:role/OrganizationAccountAccessRole"
  }

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Stack       = "dev-vpc"
    }
  }
}