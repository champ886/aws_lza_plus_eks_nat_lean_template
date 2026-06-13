# ============================================================================
# DEV VPC STACK OUTPUTS
# ============================================================================
# Outputs consumed by:
#   - environments/peering (VPC ID, route table IDs)
#   - environments/dev/eks (subnet IDs, VPC ID)
# ============================================================================

output "vpc_id" {
  description = "Dev workload VPC ID"
  value       = module.vpc_workload.vpc_id  # ← Changed from vpc_dev to vpc_workload
}

output "vpc_cidr" {
  description = "Dev workload VPC CIDR block"
  value       = module.vpc_workload.vpc_cidr
}

output "public_subnet_ids" {
  description = "Dev workload public subnet IDs"
  value       = module.vpc_workload.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Dev workload private subnet IDs"
  value       = module.vpc_workload.private_subnet_ids
}

output "private_route_table_ids" {
  description = "Dev workload private route table IDs (per AZ)"
  value       = module.vpc_workload.private_route_table_ids
}

output "public_route_table_id" {
  description = "Dev workload public route table ID"
  value       = module.vpc_workload.public_route_table_id
}

output "internet_gateway_id" {
  description = "Dev workload Internet Gateway ID"
  value       = module.vpc_workload.internet_gateway_id
}