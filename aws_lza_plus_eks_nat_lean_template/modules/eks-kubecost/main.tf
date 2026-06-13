# ============================================================================
# KUBECOST MODULE (Free Tier)
# Per-pod cost visibility with AWS pricing integration
# Free tier: 15 day metric retention, single cluster
# Includes bundled Prometheus - no separate install needed
# ============================================================================

# ─────────────────────────────────────────────────────────────────────────
# Namespace
# ─────────────────────────────────────────────────────────────────────────
resource "kubernetes_namespace" "kubecost" {
  metadata {
    name = "kubecost"
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
}

# ─────────────────────────────────────────────────────────────────────────
# IAM Role for Kubecost (IRSA)
# Needs AWS pricing + Cost Explorer read access
# ─────────────────────────────────────────────────────────────────────────
resource "aws_iam_role" "kubecost" {
  name = "${var.cluster_name}-kubecost"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.oidc_provider_url}:aud" = "sts.amazonaws.com"
          "${var.oidc_provider_url}:sub" = "system:serviceaccount:kubecost:kubecost-cost-analyzer"
        }
      }
    }]
  })

  tags = {
    Name        = "${var.cluster_name}-kubecost"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy" "kubecost" {
  name = "${var.cluster_name}-kubecost-policy"
  role = aws_iam_role.kubecost.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # AWS pricing API - accurate EC2/EKS cost data
        Effect   = "Allow"
        Action   = ["pricing:GetProducts", "pricing:DescribeServices"]
        Resource = "*"
      },
      {
        # Cost Explorer - actual AWS bill reconciliation
        Effect   = "Allow"
        Action   = ["ce:GetCostAndUsage"]
        Resource = "*"
      },
    ]
  })
}

# ─────────────────────────────────────────────────────────────────────────
# Kubecost Helm Install (Free Tier)
# Bundled Prometheus included - no separate install needed
# Grafana and alertmanager disabled to keep it lean
# ─────────────────────────────────────────────────────────────────────────
resource "helm_release" "kubecost" {
  name       = "kubecost"
  repository = "https://kubecost.github.io/cost-analyzer/"
  chart      = "cost-analyzer"
  namespace  = kubernetes_namespace.kubecost.metadata[0].name
  version    = "2.3.4"
  wait       = true
  timeout    = 300

  # Free tier - no token required
  set {
    name  = "kubecostToken"
    value = ""
  }

  # IRSA - allows Kubecost to call AWS pricing APIs
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.kubecost.arn
  }

  # AWS region for accurate pricing
  set {
    name  = "kubecostProductConfigs.region"
    value = var.aws_region
  }

  # AWS account ID for cost attribution
  set {
    name  = "cloudIntegration.awsAccountId"
    value = var.aws_account_id
  }

  # Bundled Prometheus - 8Gi storage, 15d retention (free tier max)
  set {
    name  = "prometheus.server.persistentVolume.size"
    value = "8Gi"
  }

  set {
    name  = "prometheus.server.retention"
    value = "15d"
  }

  # Disable unused components - keep it lean
  set {
    name  = "prometheus.alertmanager.enabled"
    value = "false"
  }

  set {
    name  = "prometheus.pushgateway.enabled"
    value = "false"
  }

  # Disable Grafana - Kubecost has its own UI
  set {
    name  = "grafana.enabled"
    value = "false"
  }

  depends_on = [
    kubernetes_namespace.kubecost,
    aws_iam_role_policy.kubecost,
  ]
}
