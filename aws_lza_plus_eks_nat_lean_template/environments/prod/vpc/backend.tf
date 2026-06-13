# -----------------------------------------------
# REMOTE STATE BACKEND
# Prod VPC state completely isolated from
# dev and management state files
# -----------------------------------------------
terraform {
  backend "s3" {
    bucket         = "<YOUR_STATE_BUCKET_NAME>"
    key            = "aws-lza/prod/vpc/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "tf-locks"
    encrypt        = true
  }
}

