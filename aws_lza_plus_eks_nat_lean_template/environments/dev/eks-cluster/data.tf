# ============================================================================
# Data Sources - Remote State + Route Tables
# ============================================================================

data "terraform_remote_state" "dev_vpc" {
  backend = "s3"
  config = {
    bucket = "<YOUR_STATE_BUCKET_NAME>"
    key    = "aws-lza/dev/vpc/terraform.tfstate"
    region = "ap-southeast-2"
  }
}

# Query route tables directly
data "aws_route_tables" "private" {
  vpc_id = data.terraform_remote_state.dev_vpc.outputs.vpc_id

  filter {
    name   = "tag:Name"
    values = ["dev-workload-private-rt-*"]
  }
}