# -----------------------------------------------
# REMOTE STATE BACKEND
# Dev VPC state stored separately from management
# Destroying dev VPC never affects management
# -----------------------------------------------
terraform {
  backend "s3" {
    bucket         = "<YOUR_STATE_BUCKET_NAME>"
    key            = "aws-lza/dev/vpc/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "tf-locks"
    encrypt        = true
  }
}