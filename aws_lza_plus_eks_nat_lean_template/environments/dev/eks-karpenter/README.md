# environments/dev/eks-karpenter

Karpenter — dynamic, just-in-time node provisioning. Runs **alongside** the existing managed node group during migration (see <a href="../../../RUNBOOK.md">RUNBOOK.md</a> for the phased cutover).

## What it creates

<table>
<tr><th>Resource</th><th>Detail</th></tr>
<tr><td>IAM role (IRSA) "karpenter_controller"</td><td>Trusts cluster OIDC provider, scoped to <code>system:serviceaccount:karpenter:karpenter</code></td></tr>
<tr><td>IAM role policy</td><td>EC2 launch/terminate/describe, <code>iam:PassRole</code> on the node role, <code>eks:DescribeCluster</code>, <code>pricing:GetProducts</code>, SQS consume on the interruption queue</td></tr>
<tr><td>SQS queue "karpenter_interruption"</td><td>5-min retention. Receives spot interruption / rebalance / instance-state-change events so Karpenter can drain nodes gracefully before AWS reclaims them</td></tr>
<tr><td>EventBridge rules × 3</td><td>Spot interruption warning, instance rebalance recommendation, instance state-change → all targeted at the SQS queue</td></tr>
<tr><td>EC2 tags</td><td><code>karpenter.sh/discovery=&lt;cluster_name&gt;</code> on private subnets and the node security group — Karpenter's <code>EC2NodeClass</code> uses this to find where to launch</td></tr>
<tr><td>kubernetes_namespace "karpenter"</td><td>—</td></tr>
<tr><td>helm_release "karpenter"</td><td>chart 1.0.6 from <code>oci://public.ecr.aws/karpenter</code>. <strong>No image override</strong> — uses default <code>public.ecr.aws/karpenter/controller</code> image (the regional <code>602401143452</code> ECR mirror does NOT host Karpenter)</td></tr>
<tr><td>kubectl_manifest "node_class"</td><td><code>EC2NodeClass/default</code> — AL2 latest AMI, discovers subnets/SG via the tags above, uses <code>&lt;cluster_name&gt;-node-role</code> instance profile, 20Gi gp3 root volume</td></tr>
<tr><td>kubectl_manifest "node_pool"</td><td><code>NodePool/default</code> — spot+on-demand, amd64, t3/t3a medium/large, consolidate when empty/underutilized after 30s, limits 16 vCPU / 32Gi</td></tr>
</table>

## Variables

<table>
<tr><th>Variable</th><th>Source</th></tr>
<tr><td>workload_account_id</td><td>DEV_WORKLOAD_ACCOUNT_ID secret</td></tr>
</table>

## Dependencies

<table>
<tr><th>Remote state</th><th>For</th></tr>
<tr><td>dev/vpc</td><td>private_subnet_ids</td></tr>
<tr><td>dev/eks-cluster</td><td>cluster_name, node_security_group_id, node_role_arn, OIDC provider, endpoint/CA/token</td></tr>
</table>

Deployed by workflow 8️⃣, triggered after ArgoCD (7️⃣). Triggers Kubecost (9️⃣).

## Provider requirements

Needs <code>gavinbunney/kubectl ~> 1.14</code> declared in both <code>modules/eks-karpenter/versions.tf</code> **and** this environment's <code>providers.tf</code> (or <code>backend.tf</code>) <code>required_providers</code> block — same pattern as eks-argocd.

## Standalone run

```bash
cd environments/dev/eks-karpenter
rm -f .terraform.lock.hcl
terraform init
terraform apply -var="workload_account_id=<DEV_ACCOUNT_ID>"
```

## Verify

```bash
kubectl get pods -n karpenter          # 2 controller pods Running
kubectl get nodepool                   # default
kubectl get ec2nodeclass               # default
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=20

# Force a scale-out to confirm a node is launched
kubectl create deployment karpenter-test --image=busybox --replicas=10 -- sleep 3600
kubectl get nodes -w
kubectl delete deployment karpenter-test
```

New nodes appear in the AWS console tagged <code>karpenter.sh/nodepool=default</code>.

## Gotcha

<code>ImagePullBackOff</code> with <code>403 Forbidden</code> on <code>602401143452.dkr.ecr.../eks/karpenter/controller</code> means an image override is still present pointing at the regional ECR mirror — that account doesn't host Karpenter images. Remove the override entirely; the default <code>public.ecr.aws/karpenter</code> image is reachable once TGW/NAT egress is working.
