# ============================================================================
# VPC MODULE OUTPUTS
# ============================================================================
# These outputs are used by:
#   - Peering module (needs VPC IDs, route table IDs)
#   - EKS module (needs subnet IDs, VPC ID)
#   - Other environment stacks (for cross-stack references)
# ============================================================================

# ──────────────────────────────────────────────────────────────────────────
# VPC CORE OUTPUTS
# ──────────────────────────────────────────────────────────────────────────
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "vpc_arn" {
  description = "The ARN of the VPC"
  value       = aws_vpc.main.arn
}

# ──────────────────────────────────────────────────────────────────────────
# SUBNET OUTPUTS
# ──────────────────────────────────────────────────────────────────────────
output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks"
  value       = aws_subnet.public[*].cidr_block
}

output "private_subnet_cidrs" {
  description = "List of private subnet CIDR blocks"
  value       = aws_subnet.private[*].cidr_block
}

# ──────────────────────────────────────────────────────────────────────────
# ROUTE TABLE OUTPUTS
# ──────────────────────────────────────────────────────────────────────────
output "public_route_table_id" {
  description = "Public route table ID"
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "Per-AZ private route table IDs (ordered by AZ)"
  value       = aws_route_table.private[*].id
}

# ──────────────────────────────────────────────────────────────────────────
# GATEWAY OUTPUTS
# ──────────────────────────────────────────────────────────────────────────
output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_id" {
  description = "NAT Gateway ID (null if not enabled)"
  value       = length(aws_nat_gateway.main) > 0 ? aws_nat_gateway.main[0].id : null
}

output "nat_gateway_public_ip" {
  description = "NAT Gateway public IP (null if not enabled)"
  value       = length(aws_eip.nat) > 0 ? aws_eip.nat[0].public_ip : null
}

# ──────────────────────────────────────────────────────────────────────────
# AVAILABILITY ZONE OUTPUTS
# ──────────────────────────────────────────────────────────────────────────
output "availability_zones" {
  description = "List of availability zones used"
  value       = var.availability_zones
}

output "azs_count" {
  description = "Number of availability zones"
  value       = length(var.availability_zones)
}


