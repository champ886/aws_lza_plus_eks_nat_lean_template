# ============================================================================
# PROD VPC STACK OUTPUTS
# ============================================================================
# Outputs consumed by:
#   - environments/peering (VPC ID, route table IDs)
#   - environments/prod/eks (subnet IDs, VPC ID)
# ============================================================================

output "vpc_id" {
  description = "Prod workload VPC ID"
  value       = module.vpc_workload.vpc_id
}

output "vpc_cidr" {
  description = "Prod workload VPC CIDR block"
  value       = module.vpc_workload.vpc_cidr
}

output "public_subnet_ids" {
  description = "Prod workload public subnet IDs"
  value       = module.vpc_workload.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Prod workload private subnet IDs"
  value       = module.vpc_workload.private_subnet_ids
}

output "private_route_table_ids" {
  description = "Prod workload private route table IDs (per AZ)"
  value       = module.vpc_workload.private_route_table_ids
}

output "public_route_table_id" {
  description = "Prod workload public route table ID"
  value       = module.vpc_workload.public_route_table_id
}

output "internet_gateway_id" {
  description = "Prod workload Internet Gateway ID"
  value       = module.vpc_workload.internet_gateway_id
}