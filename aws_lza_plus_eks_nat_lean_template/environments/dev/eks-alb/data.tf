# ============================================================================
# Data Sources - Remote State
# ============================================================================

# Read VPC outputs (subnets, vpc_id)
data "terraform_remote_state" "dev_vpc" {
  backend = "s3"
  config = {
    bucket = "<YOUR_STATE_BUCKET_NAME>"
    key    = "aws-lza/dev/vpc/terraform.tfstate"
    region = "ap-southeast-2"
  }
}

# Read EKS cluster outputs (cluster_name, oidc_provider_arn, oidc_provider_url)
data "terraform_remote_state" "eks_cluster" {
  backend = "s3"
  config = {
    bucket = "<YOUR_STATE_BUCKET_NAME>"
    key    = "aws-lza/dev/eks-cluster/terraform.tfstate"
    region = "ap-southeast-2"
  }
}

# Get EKS cluster auth token for Helm provider
data "aws_eks_cluster" "main" {
  provider = aws.workload
  name     = data.terraform_remote_state.eks_cluster.outputs.cluster_name
}

data "aws_eks_cluster_auth" "main" {
  provider = aws.workload
  name     = data.terraform_remote_state.eks_cluster.outputs.cluster_name
}
