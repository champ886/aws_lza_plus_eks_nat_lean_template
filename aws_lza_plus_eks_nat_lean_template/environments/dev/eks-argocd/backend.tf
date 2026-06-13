# ============================================================================
# Backend Configuration
# ============================================================================

terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }

  backend "s3" {
    bucket         = "<YOUR_STATE_BUCKET_NAME>"
    key            = "aws-lza/dev/eks-argocd/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "tf-locks"
    encrypt        = true
  }
}