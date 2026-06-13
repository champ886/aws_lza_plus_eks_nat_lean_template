# ============================================================================
# Backend Configuration - with state locking
# ============================================================================

terraform {
  backend "s3" {
    bucket       = "<YOUR_STATE_BUCKET_NAME>"
    key          = "aws-lza/dev/eks-alb/terraform.tfstate"
    region       = "ap-southeast-2"
    dynamodb_table = "tf-locks"
    encrypt        = true
  }
}
