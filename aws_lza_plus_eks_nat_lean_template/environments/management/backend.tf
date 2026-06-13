# -----------------------------------------------
# REMOTE STATE BACKEND
# State stored separately from dev and prod
# DynamoDB prevents concurrent state modifications
# -----------------------------------------------
terraform {
  backend "s3" {
    bucket         = "<YOUR_STATE_BUCKET_NAME>"
    key            = "aws-lza/management/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "tf-locks"
    encrypt        = true
  }
}