terraform {
  backend "s3" {
    bucket         = "<YOUR_STATE_BUCKET_NAME>"
    key            = "aws-lza/transit-gateway/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "tf-locks"
    encrypt        = true
  }
}
