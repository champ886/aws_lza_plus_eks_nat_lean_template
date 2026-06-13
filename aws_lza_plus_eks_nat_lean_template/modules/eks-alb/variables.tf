# ============================================================================
# EKS ALB Controller Module Variables
# ============================================================================

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-2"
}

variable "vpc_id" {
  description = "VPC ID where the cluster lives"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for internet-facing ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for internal ALB"
  type        = list(string)
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider (for IRSA)"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the EKS OIDC provider (for IRSA)"
  type        = string
}
