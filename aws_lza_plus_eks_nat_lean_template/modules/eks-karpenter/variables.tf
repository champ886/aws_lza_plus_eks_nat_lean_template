# ============================================================================
# Karpenter Module Variables
# ============================================================================

variable "cluster_name" {
  description = "EKS cluster name"
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

variable "private_subnet_ids" {
  description = "Private subnet IDs for Karpenter node discovery"
  type        = list(string)
}

variable "node_security_group_id" {
  description = "Node security group ID for Karpenter discovery"
  type        = string
}

variable "node_role_arn" {
  description = "IAM role ARN for nodes launched by Karpenter"
  type        = string
}

variable "oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  type        = string
}

variable "oidc_provider_url" {
  description = "OIDC provider URL for IRSA"
  type        = string
}
