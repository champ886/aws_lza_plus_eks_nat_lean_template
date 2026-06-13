# -----------------------------------------------
# REMOTE STATE BACKEND
# Peering state isolated from all other states
# Destroying peering never affects VPCs
# -----------------------------------------------
terraform {
  backend "s3" {
    bucket         = "<YOUR_STATE_BUCKET_NAME>"
    key            = "aws-lza/peering/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "tf-locks"
    encrypt        = true
  }
}