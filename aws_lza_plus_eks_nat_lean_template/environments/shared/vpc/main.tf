# -----------------------------------------------
# SHARED SECURITY VPC
# Deployed once and shared by dev and prod
# Both environments assume role into this account
# for security monitoring and tooling
# -----------------------------------------------
# ── Security VPC — single NAT GW in AZ-a, shared egress for all envs ──────
module "vpc_security" {
  source    = "../../../modules/vpc"
  providers = { aws = aws.security }

  environment          = var.environment
  account_name         = "security"
  vpc_cidr             = var.security_vpc_cidr
  public_subnet_cidrs  = var.security_public_subnet_cidrs
  private_subnet_cidrs = var.security_private_subnet_cidrs
  availability_zones   = var.availability_zones
  enable_nat_gateway   = true
}

# NOTE: Public route table return routes (10.0.0.0/16, 10.2.0.0/16)
# are managed by the Transit Gateway module, not here.
# TGW handles all internet egress return routing via TGW attachments.
