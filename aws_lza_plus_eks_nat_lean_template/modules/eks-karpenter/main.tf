# ============================================================================
# KARPENTER MODULE
# Dynamic node provisioning - replaces managed node group
# Spot + On-demand mixed for cost efficiency
# Migration strategy: runs alongside managed node group initially
# ============================================================================

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# ─────────────────────────────────────────────────────────────────────────
# IAM Role for Karpenter Controller (IRSA)
# Allows Karpenter pod to launch/terminate EC2 instances
# ─────────────────────────────────────────────────────────────────────────
resource "aws_iam_role" "karpenter_controller" {
  name = "${var.cluster_name}-karpenter-controller"

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
          "${var.oidc_provider_url}:sub" = "system:serviceaccount:karpenter:karpenter"
        }
      }
    }]
  })

  tags = {
    Name        = "${var.cluster_name}-karpenter-controller"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy" "karpenter_controller" {
  name = "${var.cluster_name}-karpenter-controller-policy"
  role = aws_iam_role.karpenter_controller.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateLaunchTemplate",
          "ec2:CreateFleet",
          "ec2:RunInstances",
          "ec2:CreateTags",
          "ec2:TerminateInstances",
          "ec2:DeleteLaunchTemplate",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeSpotPriceHistory",
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = var.node_role_arn
      },
      {
        Effect   = "Allow"
        Action   = "eks:DescribeCluster"
        Resource = "arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}"
      },
      {
        Effect   = "Allow"
        Action   = "pricing:GetProducts"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:DeleteMessage",
          "sqs:GetQueueUrl",
          "sqs:GetQueueAttributes",
          "sqs:ReceiveMessage",
        ]
        Resource = aws_sqs_queue.karpenter_interruption.arn
      },
    ]
  })
}

# ─────────────────────────────────────────────────────────────────────────
# SQS Queue for Spot Interruption Handling
# AWS sends 2-minute warning before reclaiming spot instance
# Karpenter listens here and gracefully drains the node
# ─────────────────────────────────────────────────────────────────────────
resource "aws_sqs_queue" "karpenter_interruption" {
  name                      = "${var.cluster_name}-karpenter-interruption"
  message_retention_seconds = 300

  tags = {
    Name        = "${var.cluster_name}-karpenter-interruption"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_sqs_queue_policy" "karpenter_interruption" {
  queue_url = aws_sqs_queue.karpenter_interruption.url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.karpenter_interruption.arn
    }]
  })
}

# EventBridge rules → SQS for spot interruption events
resource "aws_cloudwatch_event_rule" "spot_interruption" {
  name        = "${var.cluster_name}-spot-interruption"
  description = "Spot interruption warnings for Karpenter"
  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })
}

resource "aws_cloudwatch_event_rule" "instance_rebalance" {
  name        = "${var.cluster_name}-instance-rebalance"
  description = "Instance rebalance recommendations for Karpenter"
  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance Rebalance Recommendation"]
  })
}

resource "aws_cloudwatch_event_rule" "instance_state_change" {
  name        = "${var.cluster_name}-instance-state-change"
  description = "Instance state changes for Karpenter"
  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
  })
}

resource "aws_cloudwatch_event_target" "spot_interruption" {
  rule = aws_cloudwatch_event_rule.spot_interruption.name
  arn  = aws_sqs_queue.karpenter_interruption.arn
}

resource "aws_cloudwatch_event_target" "instance_rebalance" {
  rule = aws_cloudwatch_event_rule.instance_rebalance.name
  arn  = aws_sqs_queue.karpenter_interruption.arn
}

resource "aws_cloudwatch_event_target" "instance_state_change" {
  rule = aws_cloudwatch_event_rule.instance_state_change.name
  arn  = aws_sqs_queue.karpenter_interruption.arn
}

# ─────────────────────────────────────────────────────────────────────────
# Tag subnets and security group for Karpenter discovery
# ─────────────────────────────────────────────────────────────────────────
resource "aws_ec2_tag" "karpenter_subnet" {
  for_each    = toset(var.private_subnet_ids)
  resource_id = each.value
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}

resource "aws_ec2_tag" "karpenter_sg" {
  resource_id = var.node_security_group_id
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}

# ─────────────────────────────────────────────────────────────────────────
# Karpenter Namespace
# ─────────────────────────────────────────────────────────────────────────
resource "kubernetes_namespace" "karpenter" {
  metadata {
    name = "karpenter"
  }
}

# ─────────────────────────────────────────────────────────────────────────
# Karpenter Helm Install
# Uses regional ECR mirror - same pattern as ALB controller
# ─────────────────────────────────────────────────────────────────────────
resource "helm_release" "karpenter" {
  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  namespace  = kubernetes_namespace.karpenter.metadata[0].name
  version    = "1.0.6"
  wait       = true
  timeout    = 300

  set {
    name  = "settings.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "settings.interruptionQueue"
    value = aws_sqs_queue.karpenter_interruption.name
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.karpenter_controller.arn
  }

  depends_on = [
    kubernetes_namespace.karpenter,
    aws_iam_role_policy.karpenter_controller,
  ]
}

# ─────────────────────────────────────────────────────────────────────────
# EC2NodeClass - defines WHAT nodes Karpenter can launch
# ─────────────────────────────────────────────────────────────────────────
resource "kubectl_manifest" "node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: default
    spec:
      amiSelectorTerms:
        - alias: al2@latest
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${var.cluster_name}
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${var.cluster_name}
      instanceProfile: ${var.cluster_name}-node-role
      blockDeviceMappings:
        - deviceName: /dev/xvda
          ebs:
            volumeSize: 20Gi
            volumeType: gp3
            deleteOnTermination: true
  YAML

  depends_on = [helm_release.karpenter]
}

# ─────────────────────────────────────────────────────────────────────────
# NodePool - defines HOW Karpenter scales
# Spot first, on-demand fallback, consolidate after 30s
# ─────────────────────────────────────────────────────────────────────────
resource "kubectl_manifest" "node_pool" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: default
    spec:
      template:
        spec:
          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: default
          requirements:
            - key: karpenter.sh/capacity-type
              operator: In
              values: ["spot", "on-demand"]
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64"]
            - key: node.kubernetes.io/instance-type
              operator: In
              values: ["t3.medium", "t3.large", "t3a.medium", "t3a.large"]
      disruption:
        consolidationPolicy: WhenEmptyOrUnderutilized
        consolidateAfter: 30s
      limits:
        cpu: "16"
        memory: 32Gi
  YAML

  depends_on = [kubectl_manifest.node_class]
}
