# -----------------------------------------------
# DATA SOURCES - REMOTE STATE
# -----------------------------------------------

# Shared Security VPC state
data "terraform_remote_state" "shared_vpc" {
  backend = "s3"
  config = {
    bucket = "<YOUR_STATE_BUCKET_NAME>"
    key    = "aws-lza/shared/vpc/terraform.tfstate"
    region = "ap-southeast-2"
  }
}

# Dev VPC state
data "terraform_remote_state" "dev_vpc" {
  backend = "s3"
  config = {
    bucket = "<YOUR_STATE_BUCKET_NAME>"
    key    = "aws-lza/dev/vpc/terraform.tfstate"
    region = "ap-southeast-2"
  }
}

# Prod VPC state
data "terraform_remote_state" "prod_vpc" {
  backend = "s3"
  config = {
    bucket = "<YOUR_STATE_BUCKET_NAME>"
    key    = "aws-lza/prod/vpc/terraform.tfstate"
    region = "ap-southeast-2"
  }
}

# -----------------------------------------------
# DATA SOURCES - DEV WORKLOAD VPC & ROUTE TABLES
# -----------------------------------------------
data "aws_vpc" "dev_workload" {
  provider   = aws.dev_workload
  cidr_block = var.dev_vpc_cidr
}

data "aws_route_table" "dev_workload_private_az_a" {
  provider = aws.dev_workload
  filter {
    name   = "tag:Name"
    values = ["dev-workload-private-rt-1"]  # ← FIXED
  }
}

data "aws_route_table" "dev_workload_private_az_b" {
  provider = aws.dev_workload
  filter {
    name   = "tag:Name"
    values = ["dev-workload-private-rt-2"]  # ← FIXED
  }
}

# -----------------------------------------------
# DATA SOURCES - PROD WORKLOAD VPC & ROUTE TABLES
# -----------------------------------------------
data "aws_vpc" "prod_workload" {
  provider   = aws.prod_workload
  cidr_block = var.prod_vpc_cidr
}

data "aws_route_table" "prod_workload_private_az_a" {
  provider = aws.prod_workload
  filter {
    name   = "tag:Name"
    values = ["prod-workload-private-rt-1"]  # ← FIXED
  }
}

data "aws_route_table" "prod_workload_private_az_b" {
  provider = aws.prod_workload
  filter {
    name   = "tag:Name"
    values = ["prod-workload-private-rt-2"]  # ← FIXED
  }
}

# -----------------------------------------------
# DATA SOURCES - SECURITY VPC & ROUTE TABLES
# -----------------------------------------------
data "aws_vpc" "security" {
  provider   = aws.security
  cidr_block = var.security_vpc_cidr
}

data "aws_route_table" "security_private_az_a" {
  provider = aws.security
  filter {
    name   = "tag:Name"
    values = ["shared-security-private-rt-1"]
  }
}

data "aws_route_table" "security_private_az_b" {
  provider = aws.security
  filter {
    name   = "tag:Name"
    values = ["shared-security-private-rt-2"]
  }
}

# Security VPC public route table
# Needed for NAT gateway return routes to workload VPCs
data "aws_route_table" "security_public" {
  provider = aws.security

  filter {
    name   = "tag:Name"
    values = ["shared-security-public-rt"]
  }
}