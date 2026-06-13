# RUNBOOK

Operational guide for deploying, verifying, and troubleshooting this stack. Read <a href="README.md">README.md</a> first for architecture context.

## Prerequisites (one-time)

<table>
<tr><th>Item</th><th>Detail</th></tr>
<tr><td>S3 state bucket</td><td><code><YOUR_STATE_BUCKET_NAME></code> in <code>ap-southeast-2</code></td></tr>
<tr><td>DynamoDB lock table</td><td><code>tf-locks</code></td></tr>
<tr><td>GitHub OIDC role</td><td><code>AWS_ROLE_ARN</code> secret — management account role GitHub Actions assumes</td></tr>
<tr><td>Self-hosted runner</td><td>Registered in repo settings; needs <code>aws-cli</code>, <code>kubectl</code>, <code>terraform 1.5.0</code></td></tr>
<tr><td>GitHub Environments</td><td><code>shared</code>, <code>dev</code>, <code>prod</code> — each with required reviewers for the approval gate</td></tr>
<tr><td>RAM sharing enabled org-wide</td><td><code>aws_ram_sharing_with_aws_organization</code> in environments/organization — required before Transit Gateway can be shared cross-account</td></tr>
</table>

### GitHub Secrets required

<table>
<tr><th>Secret</th><th>Used by</th></tr>
<tr><td>AWS_ROLE_ARN</td><td>All workflows — OIDC assume-role into management account</td></tr>
<tr><td>SECURITY_ACCOUNT_ID</td><td>1, 4, 4b</td></tr>
<tr><td>DEV_WORKLOAD_ACCOUNT_ID</td><td>2, 4, 4b, 5a, 5b, 6, 7, 8, 9</td></tr>
<tr><td>PROD_WORKLOAD_ACCOUNT_ID</td><td>3, 4, 4b</td></tr>
<tr><td>GIT_REPO_URL</td><td>7 — ArgoCD root app source</td></tr>
<tr><td>POSTGRES_DB / POSTGRES_USER / POSTGRES_PASSWORD</td><td>7</td></tr>
<tr><td>PGADMIN_EMAIL / PGADMIN_PASSWORD</td><td>7</td></tr>
</table>

## Deployment order

Run workflow 1 manually with <code>action: apply</code>. Approve each subsequent apply as it arrives — the rest of the chain triggers automatically via <code>workflow_run</code>.

<table>
<tr><th>#</th><th>Workflow</th><th>Approval env</th><th>What it creates</th><th>Typical time</th></tr>
<tr><td>1️⃣</td><td>Security VPC</td><td>shared</td><td>Security VPC, public/private subnets, single NAT Gateway</td><td>~3 min</td></tr>
<tr><td>2️⃣</td><td>Dev VPC</td><td>dev</td><td>Dev workload VPC, public/private subnets, S3 gateway endpoint</td><td>~2 min</td></tr>
<tr><td>3️⃣</td><td>Prod VPC</td><td>prod</td><td>Prod workload VPC (networking only)</td><td>~2 min</td></tr>
<tr><td>4️⃣</td><td>VPC Peering</td><td>shared</td><td>Dev↔Security and Prod↔Security peering, private + public route table entries</td><td>~2 min</td></tr>
<tr><td>4️⃣b</td><td>Transit Gateway</td><td>shared</td><td>TGW, RAM share to Dev/Prod, attachments, 0.0.0.0/0 routes</td><td>~5 min</td></tr>
<tr><td>5️⃣a</td><td>Dev EKS Cluster</td><td>dev</td><td>EKS control plane, managed node group, OIDC provider</td><td>~15 min</td></tr>
<tr><td>5️⃣b</td><td>Dev EKS Add-ons</td><td>dev</td><td>EBS CSI driver addon, gp3 default StorageClass</td><td>~2 min</td></tr>
<tr><td>6️⃣</td><td>Dev EKS ALB Controller</td><td>dev</td><td>AWS Load Balancer Controller, IRSA role, subnet tags</td><td>~3 min</td></tr>
<tr><td>7️⃣</td><td>Dev EKS ArgoCD</td><td>dev</td><td>ArgoCD, app secrets, root App-of-Apps → pgAdmin + postgres</td><td>~5 min</td></tr>
<tr><td>8️⃣</td><td>Dev EKS Karpenter</td><td>dev</td><td>Karpenter controller, SQS interruption queue, NodePool, EC2NodeClass</td><td>~3 min</td></tr>
<tr><td>9️⃣</td><td>Dev EKS Kubecost</td><td>dev</td><td>Kubecost free tier + bundled Prometheus, IRSA role</td><td>~5 min</td></tr>
</table>

Total: roughly 45 minutes including approval pauses.

## Post-deploy verification

```bash
# Auth into dev account
assume-dev
aws eks update-kubeconfig --name dev-eks-cluster --region ap-southeast-2

# Everything should be Running
kubectl get pods -A

# Internet egress works
kubectl run nettest --image=busybox --restart=Never --rm -it \
  -- wget -O- --timeout=10 https://google.com

# ALB created for pgAdmin
kubectl get ingress -n apps

# ArgoCD apps all Synced/Healthy
kubectl get applications -n argocd

# Karpenter ready
kubectl get nodepool
kubectl get ec2nodeclass

# Kubecost UI
kubectl port-forward svc/kubecost-cost-analyzer -n kubecost 9090:9090
# open http://localhost:9090

# Storage class present (gp3, default)
kubectl get storageclass
```

## Known gotchas

<table>
<tr><th>Symptom</th><th>Root cause</th><th>Fix</th></tr>
<tr><td><code>provider registry.terraform.io/hashicorp/kubectl does not have...</code></td><td>ArgoCD/Karpenter modules use <code>gavinbunney/kubectl</code>, not <code>hashicorp/kubectl</code></td><td>Add <code>required_providers</code> block for <code>gavinbunney/kubectl ~> 1.14</code> to <strong>both</strong> the module's <code>versions.tf</code> and the environment's <code>providers.tf</code>/<code>backend.tf</code>, then <code>rm .terraform.lock.hcl && terraform init</code></td></tr>
<tr><td><code>ImagePullBackOff</code> on ArgoCD/ALB/Karpenter pods</td><td>Nodes can't reach the image registry — usually a broken NAT/TGW egress path</td><td>Run the nettest pod above. If it fails, check Security VPC public route table has TGW return routes for Dev/Prod CIDRs (see Transit Gateway section)</td></tr>
<tr><td>Karpenter <code>403 Forbidden</code> pulling <code>602401143452.dkr.ecr.../karpenter/controller</code></td><td>That registry account doesn't host Karpenter images — only AWS-maintained add-ons</td><td>Remove the <code>controller.image.repository</code> override in the Helm release; let it default to <code>public.ecr.aws/karpenter</code> (reachable once NAT/TGW works)</td></tr>
<tr><td>504 Gateway Timeout from ALB</td><td>Node security group doesn't allow inbound :80 from the ALB's security groups (ALB uses <code>target-type: ip</code>, talks directly to pod IPs)</td><td>Add ingress rule on node SG: source = ALB SGs, port 80</td></tr>
<tr><td>PVCs stuck <code>Pending</code> (Kubecost/Prometheus)</td><td>No default StorageClass</td><td>Apply the <code>gp3</code> StorageClass in <code>modules/eks-addons</code> (requires EBS CSI driver addon + <code>kubernetes</code> provider configured in that environment's <code>providers.tf</code>)</td></tr>
<tr><td>Terraform prompts for a var that "isn't used"</td><td>Variable declared in <code>variables.tf</code> but no longer referenced, or workflow env var name doesn't match the Terraform variable name</td><td>Either remove the unused variable, or fix the <code>TF_VAR_&lt;name&gt;</code> in the workflow to exactly match <code>variable "&lt;name&gt;"</code></td></tr>
<tr><td><code>RouteAlreadyExists</code> when applying peering/TGW routes</td><td>Route was created manually during troubleshooting before Terraform owned it</td><td><code>terraform import 'module.x.aws_route.y[0]' &lt;route-table-id&gt;_&lt;cidr&gt;</code></td></tr>
<tr><td><code>aws eks update-kubeconfig --role-arn ...</code> still resolves as management account in GHA</td><td>The GitHub Actions OIDC role can't internally assume the workload account role for kubeconfig generation</td><td>Explicitly <code>aws sts assume-role</code>, export the returned <code>AWS_ACCESS_KEY_ID</code>/<code>AWS_SECRET_ACCESS_KEY</code>/<code>AWS_SESSION_TOKEN</code>, <em>then</em> call <code>update-kubeconfig</code> without <code>--role-arn</code></td></tr>
<tr><td>Account ID shows as <code>***</code> in GHA logs</td><td>GitHub masks any string matching a secret value, even in plain ARNs</td><td>Harmless — the value is still correct at runtime. Hardcode non-sensitive account IDs directly in workflow steps if it gets confusing</td></tr>
<tr><td>Helm release <code>context deadline exceeded</code></td><td>Underlying pod(s) never reached Ready (often the PVC issue above)</td><td>Fix the PVC/StorageClass issue first, then re-run <code>terraform apply</code> — Helm release will pick up the existing failed release</td></tr>
<tr><td>Disk full: <code>no space left on device</code> during <code>terraform init</code></td><td>Stale <code>.terraform</code> provider caches accumulate across many environments</td><td><code>find . -name ".terraform" -type d -exec rm -rf {} +</code> then re-init</td></tr>
<tr><td>ArgoCD child apps (pgadmin/postgres) never appear under <code>root</code></td><td><code>gitops/apps.yaml</code> / <code>platform.yaml</code> placed inside <code>gitops/apps/</code> instead of <code>gitops/</code> — root app uses <code>directory.recurse: false</code> on path <code>gitops</code></td><td>Move both files to the top level of <code>gitops/</code></td></tr>
<tr><td>ArgoCD shows <code>argocd-redis-secret-init</code> stuck <code>ImagePullBackOff</code></td><td>Same NAT/TGW egress issue — ArgoCD pulls from <code>quay.io</code></td><td>Fix internet egress (TGW) first; destroy and re-apply <code>eks-argocd</code></td></tr>
</table>

## Destroy order

Destroy is manual-only per workflow and never cascades automatically. To fully tear down, run <code>action: destroy</code> on each workflow in **reverse order**:

```
9️⃣ Kubecost → 8️⃣ Karpenter → 7️⃣ ArgoCD → 6️⃣ ALB Controller →
5️⃣b EKS Add-ons → 5️⃣a EKS Cluster → 4️⃣b Transit Gateway →
4️⃣ Peering → 3️⃣ Prod VPC → 2️⃣ Dev VPC → 1️⃣ Security VPC
```

## Karpenter migration checklist

Karpenter runs alongside the existing managed node group until verified stable.

```bash
# 1. Confirm Karpenter pods running and NodePool ready
kubectl get pods -n karpenter
kubectl get nodepool

# 2. Taint the managed node group (stops new pods scheduling there)
aws eks update-nodegroup-config \
  --cluster-name dev-eks-cluster \
  --nodegroup-name dev-eks-cluster-system-nodes \
  --taints 'addOrUpdateTaints=[{key=dedicated,value=managed,effect=NO_SCHEDULE}]' \
  --region ap-southeast-2

# 3. Watch for Karpenter-provisioned nodes (24-48hr soak)
kubectl get nodes -L karpenter.sh/capacity-type -w

# 4. Once stable, scale managed node group to zero
aws eks update-nodegroup-config \
  --cluster-name dev-eks-cluster \
  --nodegroup-name dev-eks-cluster-system-nodes \
  --scaling-config minSize=0,maxSize=0,desiredSize=0 \
  --region ap-southeast-2

# 5. Remove the managed node group resource from eks-cluster Terraform
```
