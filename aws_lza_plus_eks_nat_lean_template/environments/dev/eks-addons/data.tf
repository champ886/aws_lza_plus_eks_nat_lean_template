# ============================================================================
# EKS Add-Ons Data Sources
# ============================================================================

data "terraform_remote_state" "eks_cluster" {
  backend = "s3"
  config = {
    bucket = "<YOUR_STATE_BUCKET_NAME>"
    key    = "aws-lza/dev/eks-cluster/terraform.tfstate"
    region = "ap-southeast-2"
  }
}

data "aws_eks_cluster" "main" {
  provider = aws.workload
  name     = data.terraform_remote_state.eks_cluster.outputs.cluster_name
}

data "aws_eks_cluster_auth" "main" {
  provider = aws.workload
  name     = data.terraform_remote_state.eks_cluster.outputs.cluster_name
}