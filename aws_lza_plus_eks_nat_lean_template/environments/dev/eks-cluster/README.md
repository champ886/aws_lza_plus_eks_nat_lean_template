# EKS Cluster Module

Creates an AWS EKS cluster with managed node groups, OIDC provider for IRSA, and necessary security groups.

## Features

- **EKS Control Plane**: Fully managed Kubernetes control plane
- **Managed Node Groups**: Auto-scaling worker nodes
- **OIDC Provider**: For IAM Roles for Service Accounts (IRSA)
- **Security Groups**: Cluster and node security groups with best practices
- **CloudWatch Logging**: Control plane logs enabled

## Usage

```hcl
module "eks_cluster" {
  source = "../../../modules/eks-cluster"

  cluster_name    = "dev-eks-cluster"
  cluster_version = "1.32"
  environment     = "dev"

  vpc_id             = "vpc-xxxxx"
  private_subnet_ids = ["subnet-aaa", "subnet-bbb"]
  public_subnet_ids  = ["subnet-ccc", "subnet-ddd"]

  workload_account_id = "123456789012"
  cluster_admin_arns  = ["arn:aws:iam::123456789012:user/admin"]
}
```

## Inputs

<table>
  <thead>
    <tr>
      <th>Name</th>
      <th>Description</th>
      <th>Type</th>
      <th>Default</th>
      <th align="center">Required</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>cluster_name</code></td>
      <td>Name of the EKS cluster</td>
      <td><code>string</code></td>
      <td>n/a</td>
      <td align="center">yes</td>
    </tr>
    <tr>
      <td><code>cluster_version</code></td>
      <td>Kubernetes version for the cluster</td>
      <td><code>string</code></td>
      <td><code>"1.32"</code></td>
      <td align="center">no</td>
    </tr>
    <tr>
      <td><code>environment</code></td>
      <td>Environment name (dev, staging, prod)</td>
      <td><code>string</code></td>
      <td>n/a</td>
      <td align="center">yes</td>
    </tr>
    <tr>
      <td><code>vpc_id</code></td>
      <td>VPC ID where EKS will be deployed</td>
      <td><code>string</code></td>
      <td>n/a</td>
      <td align="center">yes</td>
    </tr>
    <tr>
      <td><code>private_subnet_ids</code></td>
      <td>List of private subnet IDs for nodes</td>
      <td><code>list(string)</code></td>
      <td>n/a</td>
      <td align="center">yes</td>
    </tr>
    <tr>
      <td><code>public_subnet_ids</code></td>
      <td>List of public subnet IDs for control plane</td>
      <td><code>list(string)</code></td>
      <td>n/a</td>
      <td align="center">yes</td>
    </tr>
    <tr>
      <td><code>workload_account_id</code></td>
      <td>AWS account ID where cluster is deployed</td>
      <td><code>string</code></td>
      <td>n/a</td>
      <td align="center">yes</td>
    </tr>
    <tr>
      <td><code>cluster_admin_arns</code></td>
      <td>IAM ARNs for cluster admin access</td>
      <td><code>list(string)</code></td>
      <td><code>[]</code></td>
      <td align="center">no</td>
    </tr>
  </tbody>
</table>

## Outputs

<table>
  <thead>
    <tr>
      <th>Name</th>
      <th>Description</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>cluster_id</code></td>
      <td>EKS cluster ID</td>
    </tr>
    <tr>
      <td><code>cluster_name</code></td>
      <td>EKS cluster name</td>
    </tr>
    <tr>
      <td><code>cluster_endpoint</code></td>
      <td>EKS cluster API endpoint</td>
    </tr>
    <tr>
      <td><code>cluster_version</code></td>
      <td>Kubernetes version running on the cluster</td>
    </tr>
    <tr>
      <td><code>cluster_security_group_id</code></td>
      <td>Security group ID for the cluster control plane</td>
    </tr>
    <tr>
      <td><code>node_security_group_id</code></td>
      <td>Security group ID for worker nodes</td>
    </tr>
    <tr>
      <td><code>cluster_certificate_authority_data</code></td>
      <td>Base64 encoded certificate for cluster auth (sensitive)</td>
    </tr>
    <tr>
      <td><code>oidc_provider_arn</code></td>
      <td>ARN of the OIDC provider for IRSA</td>
    </tr>
    <tr>
      <td><code>oidc_provider_url</code></td>
      <td>URL of the OIDC provider (without https://)</td>
    </tr>
    <tr>
      <td><code>node_role_arn</code></td>
      <td>ARN of the IAM role for EKS nodes</td>
    </tr>
  </tbody>
</table>

## Resources Created

<table>
  <thead>
    <tr>
      <th>Resource</th>
      <th>Description</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><code>aws_eks_cluster</code></td>
      <td>EKS control plane</td>
    </tr>
    <tr>
      <td><code>aws_eks_node_group</code></td>
      <td>Managed worker node group</td>
    </tr>
    <tr>
      <td><code>aws_iam_openid_connect_provider</code></td>
      <td>OIDC provider for IRSA</td>
    </tr>
    <tr>
      <td><code>aws_iam_role</code> (cluster)</td>
      <td>IAM role for EKS control plane</td>
    </tr>
    <tr>
      <td><code>aws_iam_role</code> (nodes)</td>
      <td>IAM role for worker nodes</td>
    </tr>
    <tr>
      <td><code>aws_security_group</code> (cluster)</td>
      <td>Security group for control plane</td>
    </tr>
    <tr>
      <td><code>aws_security_group</code> (nodes)</td>
      <td>Security group for worker nodes</td>
    </tr>
  </tbody>
</table>

## Node Group Configuration

Default node group settings:
- **Instance Type**: t3.medium
- **Capacity Type**: ON_DEMAND
- **Disk Size**: 20 GB
- **Scaling**: Min 1, Desired 2, Max 5
- **Update Strategy**: Max unavailable 1

## Notes

- Cluster is deployed in private subnets for security
- Control plane endpoint is accessible from public internet (can be restricted via security groups)
- CloudWatch logging is enabled for all log types
- OIDC provider is automatically created for IRSA support

## Post-Deployment

After cluster creation:

```bash
# Configure kubectl
aws eks update-kubeconfig --name dev-eks-cluster --region ap-southeast-2

# Verify nodes
kubectl get nodes

# Check system pods
kubectl get pods -n kube-system
```

## References

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/latest/userguide/)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [IRSA Documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)



# environments/dev/eks-cluster

The EKS control plane and its initial managed node group, deployed into the Dev VPC's private subnets.

## What it creates

<table>
<tr><th>Resource</th><th>Detail</th></tr>
<tr><td>EKS cluster</td><td><code>dev-eks-cluster</code>, Kubernetes 1.32, private+public API endpoint</td></tr>
<tr><td>OIDC provider</td><td>Required for IRSA — every other module (ALB, ArgoCD, Karpenter, Kubecost) creates IAM roles trusting this provider</td></tr>
<tr><td>Managed node group</td><td><code>dev-eks-cluster-system-nodes</code> — runs cluster-critical pods (CoreDNS, ALB controller, ArgoCD, Karpenter controller itself) until Karpenter takes over workload scaling</td></tr>
<tr><td>Launch template</td><td>Custom launch template attaching nodes to <strong>both</strong> the custom node security group <em>and</em> the EKS-auto-created cluster security group — without both, nodes fail to join</td></tr>
<tr><td>Node IAM role</td><td><code>dev-eks-cluster-node-role</code> with <code>AmazonEKS_CNI_Policy</code>, <code>AmazonEC2ContainerRegistryReadOnly</code>, <code>AmazonEKSWorkerNodePolicy</code></td></tr>
</table>

## Variables

<table>
<tr><th>Variable</th><th>Source</th></tr>
<tr><td>workload_account_id</td><td>DEV_WORKLOAD_ACCOUNT_ID secret</td></tr>
</table>

## Dependencies

<table>
<tr><th>Remote state</th><th>For</th></tr>
<tr><td>dev/vpc</td><td>vpc_id, private_subnet_ids, public_subnet_ids</td></tr>
</table>

Deployed by workflow 5️⃣a, triggered after Transit Gateway (4️⃣b). Triggers EKS Add-ons (5️⃣b). Timeout 60 min — cluster creation alone takes ~10-15 min.

## Key outputs

<table>
<tr><th>Output</th><th>Consumed by</th></tr>
<tr><td>cluster_name, cluster_endpoint, cluster_ca</td><td>every downstream eks-* environment</td></tr>
<tr><td>oidc_provider_arn, oidc_provider_url</td><td>eks-alb, eks-argocd, eks-karpenter, eks-kubecost (IRSA trust policies)</td></tr>
<tr><td>node_role_arn</td><td>eks-karpenter (Karpenter-launched nodes reuse this role via instance profile)</td></tr>
<tr><td>node_security_group_id</td><td>eks-alb (ALB→node SG rule), eks-karpenter (discovery tag)</td></tr>
</table>

## Standalone run

```bash
cd environments/dev/eks-cluster
terraform init
terraform apply -var="workload_account_id=<DEV_ACCOUNT_ID>"

aws eks update-kubeconfig --name dev-eks-cluster --region ap-southeast-2 \
  --role-arn arn:aws:iam::<DEV_ACCOUNT_ID>:role/OrganizationAccountAccessRole
```

## Gotcha

EKS auto-creates a cluster security group (<code>eks-cluster-sg-*</code>) separate from the custom node SG defined here. Nodes must be members of **both** — handled via the launch template's <code>vpc_security_group_ids</code>. If nodes show <code>NotReady</code> and never join, check this first.
