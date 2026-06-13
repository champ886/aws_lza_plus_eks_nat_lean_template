# ============================================================================
# Transit Gateway Module Variables
# ============================================================================

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-2"
}

# ─────────────────────────────────────────────────────────────────────────
# Account IDs
# ─────────────────────────────────────────────────────────────────────────
variable "dev_account_id" {
  description = "Dev workload account ID"
  type        = string
}

variable "prod_account_id" {
  description = "Prod workload account ID"
  type        = string
}

# ─────────────────────────────────────────────────────────────────────────
# Security VPC (Hub)
# ─────────────────────────────────────────────────────────────────────────
variable "security_vpc_id" {
  description = "Security VPC ID"
  type        = string
}

variable "security_private_subnet_ids" {
  description = "Security VPC private subnet IDs for TGW attachment"
  type        = list(string)
}

variable "security_private_route_table_az_a_id" {
  description = "Security VPC private route table AZ-a ID"
  type        = string
}

variable "security_private_route_table_az_b_id" {
  description = "Security VPC private route table AZ-b ID"
  type        = string
}

variable "security_public_route_table_id" {
  description = "Security VPC public route table ID"
  type        = string
}

# ─────────────────────────────────────────────────────────────────────────
# Dev VPC (Spoke)
# ─────────────────────────────────────────────────────────────────────────
variable "dev_vpc_id" {
  description = "Dev VPC ID"
  type        = string
}

variable "dev_vpc_cidr" {
  description = "Dev VPC CIDR"
  type        = string
}

variable "dev_private_subnet_ids" {
  description = "Dev VPC private subnet IDs for TGW attachment"
  type        = list(string)
}

variable "dev_private_route_table_az_a_id" {
  description = "Dev VPC private route table AZ-a ID"
  type        = string
}

variable "dev_private_route_table_az_b_id" {
  description = "Dev VPC private route table AZ-b ID"
  type        = string
}

# ─────────────────────────────────────────────────────────────────────────
# Prod VPC (Spoke)
# ─────────────────────────────────────────────────────────────────────────
variable "prod_vpc_id" {
  description = "Prod VPC ID"
  type        = string
}

variable "prod_vpc_cidr" {
  description = "Prod VPC CIDR"
  type        = string
}

variable "prod_private_subnet_ids" {
  description = "Prod VPC private subnet IDs for TGW attachment"
  type        = list(string)
}

variable "prod_private_route_table_az_a_id" {
  description = "Prod VPC private route table AZ-a ID"
  type        = string
}

variable "prod_private_route_table_az_b_id" {
  description = "Prod VPC private route table AZ-b ID"
  type        = string
}
