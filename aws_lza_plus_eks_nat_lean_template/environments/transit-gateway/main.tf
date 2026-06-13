# ============================================================================
# Transit Gateway Environment
# Hub-and-spoke: Security VPC is the hub, Dev/Prod are spokes
# ============================================================================

module "transit_gateway" {
  source = "../../modules/transit-gateway"

  providers = {
    aws.security = aws.security
    aws.dev      = aws.dev
    aws.prod     = aws.prod
  }

  environment     = var.environment
  aws_region      = var.aws_region
  dev_account_id  = var.dev_workload_account_id
  prod_account_id = var.prod_workload_account_id

  # Security VPC (hub) - matched to actual shared VPC output names
  security_vpc_id                      = data.terraform_remote_state.shared_vpc.outputs.security_vpc_id
  security_private_subnet_ids          = data.terraform_remote_state.shared_vpc.outputs.security_private_subnet_ids
  security_private_route_table_az_a_id = data.terraform_remote_state.shared_vpc.outputs.security_private_route_table_ids[0]
  security_private_route_table_az_b_id = data.terraform_remote_state.shared_vpc.outputs.security_private_route_table_ids[1]
  security_public_route_table_id       = data.terraform_remote_state.shared_vpc.outputs.security_public_route_table_id

  # Dev VPC (spoke) - from dev VPC remote state
  dev_vpc_id                      = data.terraform_remote_state.dev_vpc.outputs.vpc_id
  dev_vpc_cidr                    = var.dev_vpc_cidr
  dev_private_subnet_ids          = data.terraform_remote_state.dev_vpc.outputs.private_subnet_ids
  dev_private_route_table_az_a_id = data.terraform_remote_state.dev_vpc.outputs.private_route_table_ids[0]
  dev_private_route_table_az_b_id = data.terraform_remote_state.dev_vpc.outputs.private_route_table_ids[1]

  # Prod VPC (spoke) - from prod VPC remote state
  prod_vpc_id                      = data.terraform_remote_state.prod_vpc.outputs.vpc_id
  prod_vpc_cidr                    = var.prod_vpc_cidr
  prod_private_subnet_ids          = data.terraform_remote_state.prod_vpc.outputs.private_subnet_ids
  prod_private_route_table_az_a_id = data.terraform_remote_state.prod_vpc.outputs.private_route_table_ids[0]
  prod_private_route_table_az_b_id = data.terraform_remote_state.prod_vpc.outputs.private_route_table_ids[1]
}
