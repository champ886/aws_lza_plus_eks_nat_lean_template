# -----------------------------------------------
# DEV TO SECURITY PEERING
# Kept for direct VPC-to-VPC communication
# Internet egress now handled by TGW (not peering)
# -----------------------------------------------
module "dev_to_security_peering" {
  source = "../../modules/vpc-peering"

  providers = {
    aws.requester = aws.dev_workload
    aws.accepter  = aws.security
  }

  aws_region   = var.aws_region
  environment  = "dev"
  peering_name = "dev-to-security"

  requester_vpc_id              = data.aws_vpc.dev_workload.id
  requester_vpc_cidr            = var.dev_vpc_cidr
  requester_route_table_az_a_id = data.aws_route_table.dev_workload_private_az_a.id
  requester_route_table_az_b_id = data.aws_route_table.dev_workload_private_az_b.id

  accepter_account_id            = var.security_account_id
  accepter_vpc_id                = data.aws_vpc.security.id
  accepter_vpc_cidr              = var.security_vpc_cidr
  accepter_route_table_az_a_id   = data.aws_route_table.security_private_az_a.id
  accepter_route_table_az_b_id   = data.aws_route_table.security_private_az_b.id
  accepter_public_route_table_id = data.aws_route_table.security_public.id

  # Internet egress now via TGW - NOT peering
  route_internet_via_accepter = false
}

# -----------------------------------------------
# PROD TO SECURITY PEERING
# -----------------------------------------------
module "prod_to_security_peering" {
  source = "../../modules/vpc-peering"

  providers = {
    aws.requester = aws.prod_workload
    aws.accepter  = aws.security
  }

  aws_region   = var.aws_region
  environment  = "prod"
  peering_name = "prod-to-security"

  requester_vpc_id              = data.aws_vpc.prod_workload.id
  requester_vpc_cidr            = var.prod_vpc_cidr
  requester_route_table_az_a_id = data.aws_route_table.prod_workload_private_az_a.id
  requester_route_table_az_b_id = data.aws_route_table.prod_workload_private_az_b.id

  accepter_account_id            = var.security_account_id
  accepter_vpc_id                = data.aws_vpc.security.id
  accepter_vpc_cidr              = var.security_vpc_cidr
  accepter_route_table_az_a_id   = data.aws_route_table.security_private_az_a.id
  accepter_route_table_az_b_id   = data.aws_route_table.security_private_az_b.id
  accepter_public_route_table_id = data.aws_route_table.security_public.id

  # Internet egress now via TGW - NOT peering
  route_internet_via_accepter = false
}
