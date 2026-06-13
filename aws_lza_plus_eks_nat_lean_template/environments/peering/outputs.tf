output "dev_peering_connection_id" {
  description = "Dev to Security peering connection ID"
  value       = module.dev_to_security_peering.peering_connection_id
}

output "prod_peering_connection_id" {
  description = "Prod to Security peering connection ID"
  value       = module.prod_to_security_peering.peering_connection_id
}