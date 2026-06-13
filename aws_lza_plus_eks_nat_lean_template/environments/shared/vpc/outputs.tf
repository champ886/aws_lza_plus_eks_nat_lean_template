# ============================================================================
# SHARED/SECURITY VPC STACK OUTPUTS
# ============================================================================
# These outputs are consumed by:
#   - environments/peering (for peering connections)
#   - environments/dev/eks (for security group rules)
# ============================================================================

output "security_vpc_id" {
  description = "Security VPC ID"
  value       = module.vpc_security.vpc_id
}

output "security_vpc_cidr" {
  description = "Security VPC CIDR block"
  value       = module.vpc_security.vpc_cidr
}

output "security_public_subnet_ids" {
  description = "Security VPC public subnet IDs"
  value       = module.vpc_security.public_subnet_ids
}

output "security_private_subnet_ids" {
  description = "Security VPC private subnet IDs"
  value       = module.vpc_security.private_subnet_ids
}

output "security_private_route_table_ids" {
  description = "Security VPC private route table IDs (per AZ)"
  value       = module.vpc_security.private_route_table_ids
}

output "security_nat_gateway_id" {
  description = "Security VPC NAT Gateway ID"
  value       = module.vpc_security.nat_gateway_id
}

output "security_nat_gateway_public_ip" {
  description = "Security VPC NAT Gateway public IP"
  value       = module.vpc_security.nat_gateway_public_ip
}

output "security_public_route_table_id" {
  description = "Security VPC public route table ID"
  value       = module.vpc_security.public_route_table_id
}