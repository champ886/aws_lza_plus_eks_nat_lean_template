output "transit_gateway_id" {
  description = "Transit Gateway ID"
  value       = module.transit_gateway.transit_gateway_id
}

output "tgw_dev_attachment_id" {
  description = "Dev VPC TGW attachment ID"
  value       = module.transit_gateway.tgw_dev_attachment_id
}

output "tgw_prod_attachment_id" {
  description = "Prod VPC TGW attachment ID"
  value       = module.transit_gateway.tgw_prod_attachment_id
}

