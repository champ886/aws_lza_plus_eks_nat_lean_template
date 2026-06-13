# ============================================================================
# EKS ADD-ONS MODULE - Managed add-ons only
# ============================================================================

# ─────────────────────────────────────────────────────────────────────────
# VPC CNI Add-on
# ─────────────────────────────────────────────────────────────────────────
resource "aws_eks_addon" "vpc_cni" {
  count = var.enable_vpc_cni ? 1 : 0

  cluster_name                = var.cluster_name
  addon_name                  = "vpc-cni"
  addon_version               = var.addon_version_vpc_cni
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = {
    Name        = "${var.cluster_name}-vpc-cni"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ─────────────────────────────────────────────────────────────────────────
# CoreDNS Add-on
# ─────────────────────────────────────────────────────────────────────────
resource "aws_eks_addon" "coredns" {
  count = var.enable_coredns ? 1 : 0

  cluster_name                = var.cluster_name
  addon_name                  = "coredns"
  addon_version               = var.addon_version_coredns
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [aws_eks_addon.vpc_cni]

  tags = {
    Name        = "${var.cluster_name}-coredns"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ─────────────────────────────────────────────────────────────────────────
# kube-proxy Add-on
# ─────────────────────────────────────────────────────────────────────────
resource "aws_eks_addon" "kube_proxy" {
  count = var.enable_kube_proxy ? 1 : 0

  cluster_name                = var.cluster_name
  addon_name                  = "kube-proxy"
  addon_version               = var.addon_version_kube_proxy
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = {
    Name        = "${var.cluster_name}-kube-proxy"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ─────────────────────────────────────────────────────────────────────────
# Default StorageClass - gp3
# Required for PVCs (Kubecost, Prometheus)
# gp3 is cheaper than gp2 - 20% lower cost, better baseline performance
# ─────────────────────────────────────────────────────────────────────────
resource "kubernetes_storage_class" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"

  parameters = {
    type      = "gp3"
    encrypted = "true"
  }
}

# ─────────────────────────────────────────────────────────────────────────
# EBS CSI Driver
# ─────────────────────────────────────────────────────────────────────────

resource "aws_eks_addon" "ebs_csi" {
  cluster_name = var.cluster_name
  addon_name   = "aws-ebs-csi-driver"

  service_account_role_arn = aws_iam_role.ebs_csi.arn

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [
    aws_eks_addon.pod_identity,
    aws_eks_pod_identity_association.ebs_csi
  ]

  tags = {
    Name        = "${var.cluster_name}-ebs-csi"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}