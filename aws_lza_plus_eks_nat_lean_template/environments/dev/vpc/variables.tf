# ============================================================================
# DEV VPC STACK VARIABLES
# ============================================================================
# Variables for the dev workload VPC configuration
# Non-secret values stored in vars.auto.tfvars (safe to commit)
# Secret values injected via GitHub Actions as TF_VAR_ environment variables
# ============================================================================

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "ap-southeast-2"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# ──────────────────────────────────────────────────────────────────────────
# AWS ACCOUNT ID (Injected as Secret from GitHub Actions)
# ──────────────────────────────────────────────────────────────────────────
variable "dev_workload_account_id" {
  description = "AWS account ID for dev workload account"
  type        = string
  sensitive   = true
}

# ──────────────────────────────────────────────────────────────────────────
# VPC CIDR BLOCKS
# ──────────────────────────────────────────────────────────────────────────
variable "workload_vpc_cidr" {
  description = "CIDR block for dev workload VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# ──────────────────────────────────────────────────────────────────────────
# SUBNET CIDR BLOCKS
# ──────────────────────────────────────────────────────────────────────────
variable "workload_public_subnet_cidrs" {
  description = "CIDR blocks for public subnets in dev VPC"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "workload_private_subnet_cidrs" {
  description = "CIDR blocks for private subnets in dev VPC"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

# ──────────────────────────────────────────────────────────────────────────
# AVAILABILITY ZONES
# ──────────────────────────────────────────────────────────────────────────
variable "availability_zones" {
  description = "List of availability zones for subnet placement"
  type        = list(string)
  default     = ["ap-southeast-2a", "ap-southeast-2b"]
}

