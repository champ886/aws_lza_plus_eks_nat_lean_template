# ============================================================================
# Variables
# ============================================================================

variable "aws_region" {
  type    = string
  default = "ap-southeast-2"
}

variable "environment" {
  type    = string
  default = "shared"
}

variable "dev_workload_account_id" {
  type = string
}

variable "prod_workload_account_id" {
  type = string
}

variable "security_account_id" {
  type = string
}

variable "dev_vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "prod_vpc_cidr" {
  type    = string
  default = "10.2.0.0/16"
}
