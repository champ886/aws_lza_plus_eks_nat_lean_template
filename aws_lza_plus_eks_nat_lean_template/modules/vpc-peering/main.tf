terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.requester, aws.accepter]
    }
  }
}

# Peering connection request (from workload account)
resource "aws_vpc_peering_connection" "main" {
  provider      = aws.requester
  vpc_id        = var.requester_vpc_id
  peer_vpc_id   = var.accepter_vpc_id
  peer_owner_id = var.accepter_account_id
  peer_region   = var.aws_region
  auto_accept   = false
  tags = {
    Name        = "${var.environment}-${var.peering_name}-peering"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Accept peering from security account
resource "aws_vpc_peering_connection_accepter" "main" {
  provider                  = aws.accepter
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id
  auto_accept               = true
  tags = {
    Name        = "${var.environment}-${var.peering_name}-peering"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Enable DNS resolution across peering
resource "aws_vpc_peering_connection_options" "requester" {
  provider                  = aws.requester
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.main.id
  requester {
    allow_remote_vpc_dns_resolution = true
  }
  depends_on = [aws_vpc_peering_connection_accepter.main]
}

resource "aws_vpc_peering_connection_options" "accepter" {
  provider                  = aws.accepter
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.main.id
  accepter {
    allow_remote_vpc_dns_resolution = true
  }
  depends_on = [aws_vpc_peering_connection_accepter.main]
}

# ─────────────────────────────────────────────────────────────────────────
# REQUESTER ROUTES - Dev private subnets → Security VPC
# ─────────────────────────────────────────────────────────────────────────
resource "aws_route" "requester_to_accepter_az_a" {
  provider                  = aws.requester
  route_table_id            = var.requester_route_table_az_a_id
  destination_cidr_block    = var.accepter_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id
  depends_on                = [aws_vpc_peering_connection_accepter.main]
}

resource "aws_route" "requester_to_accepter_az_b" {
  provider                  = aws.requester
  route_table_id            = var.requester_route_table_az_b_id
  destination_cidr_block    = var.accepter_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id
  depends_on                = [aws_vpc_peering_connection_accepter.main]
}

# DEFAULT ROUTE: dev internet egress via security VPC NAT GW
resource "aws_route" "requester_default_egress_az_a" {
  count                     = var.route_internet_via_accepter ? 1 : 0
  provider                  = aws.requester
  route_table_id            = var.requester_route_table_az_a_id
  destination_cidr_block    = "0.0.0.0/0"
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id
  depends_on                = [aws_vpc_peering_connection_accepter.main]
}

resource "aws_route" "requester_default_egress_az_b" {
  count                     = var.route_internet_via_accepter ? 1 : 0
  provider                  = aws.requester
  route_table_id            = var.requester_route_table_az_b_id
  destination_cidr_block    = "0.0.0.0/0"
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id
  depends_on                = [aws_vpc_peering_connection_accepter.main]
}

# ─────────────────────────────────────────────────────────────────────────
# ACCEPTER PRIVATE ROUTES - Security private subnets → Dev VPC
# ─────────────────────────────────────────────────────────────────────────
resource "aws_route" "accepter_to_requester_az_a" {
  provider                  = aws.accepter
  route_table_id            = var.accepter_route_table_az_a_id
  destination_cidr_block    = var.requester_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id
  depends_on                = [aws_vpc_peering_connection_accepter.main]
}

resource "aws_route" "accepter_to_requester_az_b" {
  provider                  = aws.accepter
  route_table_id            = var.accepter_route_table_az_b_id
  destination_cidr_block    = var.requester_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id
  depends_on                = [aws_vpc_peering_connection_accepter.main]
}

# ─────────────────────────────────────────────────────────────────────────
# ACCEPTER PUBLIC ROUTE - Security PUBLIC route table → Requester VPC
# THIS IS THE MISSING PIECE!
# NAT gateway sits in the public subnet. When internet traffic returns
# to the NAT gateway it needs to route back to the requester VPC CIDR.
# Without this route, return traffic is dropped at the public subnet.
# ─────────────────────────────────────────────────────────────────────────
resource "aws_route" "accepter_public_to_requester" {
  count                     = var.route_internet_via_accepter ? 1 : 0
  provider                  = aws.accepter
  route_table_id            = var.accepter_public_route_table_id
  destination_cidr_block    = var.requester_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id
  depends_on                = [aws_vpc_peering_connection_accepter.main]
}
