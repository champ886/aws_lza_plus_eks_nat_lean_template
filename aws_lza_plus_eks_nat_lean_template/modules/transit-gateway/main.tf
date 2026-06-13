# ============================================================================
# TRANSIT GATEWAY MODULE
# Purpose: Internet egress ONLY via Security VPC NAT Gateway
# VPC-to-VPC traffic uses peering (free, low latency)
#
# Traffic flows:
#   Dev/Prod → internet:  spoke → TGW → Security private → NAT → IGW
#   Internet → Dev/Prod:  IGW → NAT → Security public → TGW → spoke
#   Dev ↔ Security:       peering (free, not TGW)
#   Prod ↔ Security:      peering (free, not TGW)
# ============================================================================

# ─────────────────────────────────────────────────────────────────────────
# Transit Gateway - lives in Security account
# ─────────────────────────────────────────────────────────────────────────
resource "aws_ec2_transit_gateway" "main" {
  provider = aws.security

  description                     = "Shared TGW - internet egress hub for all workload VPCs"
  amazon_side_asn                 = 64512
  auto_accept_shared_attachments  = "enable"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"

  tags = {
    Name        = "${var.environment}-tgw"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ─────────────────────────────────────────────────────────────────────────
# RAM Sharing - share TGW with workload accounts
# Requires aws_ram_sharing_with_aws_organization enabled at org level
# ─────────────────────────────────────────────────────────────────────────
resource "aws_ram_resource_share" "tgw" {
  provider                  = aws.security
  name                      = "${var.environment}-tgw-share"
  allow_external_principals = false

  tags = {
    Name        = "${var.environment}-tgw-share"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_ram_resource_association" "tgw" {
  provider           = aws.security
  resource_arn       = aws_ec2_transit_gateway.main.arn
  resource_share_arn = aws_ram_resource_share.tgw.arn
}

resource "aws_ram_principal_association" "dev" {
  provider           = aws.security
  principal          = var.dev_account_id
  resource_share_arn = aws_ram_resource_share.tgw.arn
}

resource "aws_ram_principal_association" "prod" {
  provider           = aws.security
  principal          = var.prod_account_id
  resource_share_arn = aws_ram_resource_share.tgw.arn
}

# ─────────────────────────────────────────────────────────────────────────
# TGW Attachments
# ─────────────────────────────────────────────────────────────────────────
resource "aws_ec2_transit_gateway_vpc_attachment" "security" {
  provider           = aws.security
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = var.security_vpc_id
  subnet_ids         = var.security_private_subnet_ids

  dns_support                                     = "enable"
  transit_gateway_default_route_table_association = true
  transit_gateway_default_route_table_propagation = true

  tags = {
    Name        = "${var.environment}-tgw-security-attachment"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "dev" {
  provider           = aws.dev
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = var.dev_vpc_id
  subnet_ids         = var.dev_private_subnet_ids

  dns_support                                     = "enable"
  transit_gateway_default_route_table_association = true
  transit_gateway_default_route_table_propagation = true

  tags = {
    Name        = "${var.environment}-tgw-dev-attachment"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  depends_on = [
    aws_ram_principal_association.dev,
    aws_ram_resource_association.tgw,
  ]
}

resource "aws_ec2_transit_gateway_vpc_attachment" "prod" {
  provider           = aws.prod
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = var.prod_vpc_id
  subnet_ids         = var.prod_private_subnet_ids

  dns_support                                     = "enable"
  transit_gateway_default_route_table_association = true
  transit_gateway_default_route_table_propagation = true

  tags = {
    Name        = "${var.environment}-tgw-prod-attachment"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  depends_on = [
    aws_ram_principal_association.prod,
    aws_ram_resource_association.tgw,
  ]
}

# ─────────────────────────────────────────────────────────────────────────
# TGW Route Table
# Controls how TGW routes traffic between attachments
#
#   0.0.0.0/0    → Security  (all internet-bound traffic goes to Security NAT)
#   10.0.0.0/16  → Dev       (return traffic from NAT back to Dev nodes)
#   10.2.0.0/16  → Prod      (return traffic from NAT back to Prod nodes)
# ─────────────────────────────────────────────────────────────────────────

# All internet traffic from spokes → Security VPC (hits NAT)
resource "aws_ec2_transit_gateway_route" "default_to_security" {
  provider                       = aws.security
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.security.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway.main.association_default_route_table_id
}

# Return traffic from Security NAT → Dev nodes
resource "aws_ec2_transit_gateway_route" "to_dev" {
  provider                       = aws.security
  destination_cidr_block         = var.dev_vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.dev.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway.main.association_default_route_table_id
}

# Return traffic from Security NAT → Prod nodes
resource "aws_ec2_transit_gateway_route" "to_prod" {
  provider                       = aws.security
  destination_cidr_block         = var.prod_vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.prod.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway.main.association_default_route_table_id
}

# ─────────────────────────────────────────────────────────────────────────
# Dev VPC Private Route Tables
# 0.0.0.0/0 → TGW (internet only - peering handles 10.1.0.0/16)
# ─────────────────────────────────────────────────────────────────────────
resource "aws_route" "dev_internet_via_tgw_az_a" {
  provider               = aws.dev
  route_table_id         = var.dev_private_route_table_az_a_id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = aws_ec2_transit_gateway.main.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.dev]
}

resource "aws_route" "dev_internet_via_tgw_az_b" {
  provider               = aws.dev
  route_table_id         = var.dev_private_route_table_az_b_id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = aws_ec2_transit_gateway.main.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.dev]
}

# ─────────────────────────────────────────────────────────────────────────
# Prod VPC Private Route Tables
# 0.0.0.0/0 → TGW (internet only - peering handles 10.1.0.0/16)
# ─────────────────────────────────────────────────────────────────────────
resource "aws_route" "prod_internet_via_tgw_az_a" {
  provider               = aws.prod
  route_table_id         = var.prod_private_route_table_az_a_id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = aws_ec2_transit_gateway.main.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.prod]
}

resource "aws_route" "prod_internet_via_tgw_az_b" {
  provider               = aws.prod
  route_table_id         = var.prod_private_route_table_az_b_id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = aws_ec2_transit_gateway.main.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.prod]
}

# ─────────────────────────────────────────────────────────────────────────
# Security VPC PUBLIC Route Table
# NAT return traffic needs routes back to Dev/Prod via TGW
# (Public subnet cannot use peering for return - NAT sits here)
#
#   10.0.0.0/16 → TGW  (return Dev traffic after NAT)
#   10.2.0.0/16 → TGW  (return Prod traffic after NAT)
#   0.0.0.0/0   → IGW  (existing - internet access)
# ─────────────────────────────────────────────────────────────────────────
resource "aws_route" "security_public_to_dev" {
  provider               = aws.security
  route_table_id         = var.security_public_route_table_id
  destination_cidr_block = var.dev_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.main.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.security]
}

resource "aws_route" "security_public_to_prod" {
  provider               = aws.security
  route_table_id         = var.security_public_route_table_id
  destination_cidr_block = var.prod_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.main.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.security]
}
