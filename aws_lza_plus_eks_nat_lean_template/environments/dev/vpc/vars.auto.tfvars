# ============================================================================
# DEV VPC AUTO-LOADED VARIABLES
# ============================================================================
# Safe to commit - contains no secrets
# Values automatically loaded by Terraform (*.auto.tfvars pattern)
# ============================================================================

aws_region                   = "ap-southeast-2"
environment                  = "dev"
workload_vpc_cidr            = "10.0.0.0/16"
workload_public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
workload_private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
availability_zones           = ["ap-southeast-2a", "ap-southeast-2b"]