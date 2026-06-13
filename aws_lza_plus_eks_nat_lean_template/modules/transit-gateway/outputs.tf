# ============================================================================
# Transit Gateway Module Outputs
# ============================================================================

output "transit_gateway_id" {
  description = "Transit Gateway ID"
  value       = aws_ec2_transit_gateway.main.id
}

output "transit_gateway_arn" {
  description = "Transit Gateway ARN"
  value       = aws_ec2_transit_gateway.main.arn
}

output "tgw_security_attachment_id" {
  description = "TGW attachment ID for Security VPC"
  value       = aws_ec2_transit_gateway_vpc_attachment.security.id
}

output "tgw_dev_attachment_id" {
  description = "TGW attachment ID for Dev VPC"
  value       = aws_ec2_transit_gateway_vpc_attachment.dev.id
}

output "tgw_prod_attachment_id" {
  description = "TGW attachment ID for Prod VPC"
  value       = aws_ec2_transit_gateway_vpc_attachment.prod.id
}
