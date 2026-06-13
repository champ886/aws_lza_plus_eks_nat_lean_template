# ============================================================================
# EKS Add-ons Module Variables
# ============================================================================

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# ─────────────────────────────────────────────────────────────────────────
# Add-on Versions - defaults compatible with Kubernetes 1.32
# ─────────────────────────────────────────────────────────────────────────

variable "addon_version_vpc_cni" {
  description = "Version of the VPC CNI add-on"
  type        = string
  default     = "v1.19.0-eksbuild.1"
}

variable "addon_version_coredns" {
  description = "Version of the CoreDNS add-on"
  type        = string
  default     = "v1.11.3-eksbuild.1"
}

variable "addon_version_kube_proxy" {
  description = "Version of the kube-proxy add-on"
  type        = string
  default     = "v1.32.0-eksbuild.2"
}

# ─────────────────────────────────────────────────────────────────────────
# Feature Flags
# ─────────────────────────────────────────────────────────────────────────

variable "enable_vpc_cni" {
  description = "Enable VPC CNI add-on"
  type        = bool
  default     = true
}

variable "enable_coredns" {
  description = "Enable CoreDNS add-on"
  type        = bool
  default     = true
}

variable "enable_kube_proxy" {
  description = "Enable kube-proxy add-on"
  type        = bool
  default     = true
}

variable "enable_pod_identity" {
  description = "Enable Pod Identity Agent add-on"
  type        = bool
  default     = true
}
