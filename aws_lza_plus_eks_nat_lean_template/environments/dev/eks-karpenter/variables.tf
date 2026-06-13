# ============================================================================
# Variables
# ============================================================================

variable "aws_region" {
  type    = string
  default = "ap-southeast-2"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "workload_account_id" {
  type = string
}
