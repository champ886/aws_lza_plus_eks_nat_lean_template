# environments/dev/eks-alb

AWS Load Balancer Controller — turns Kubernetes <code>Ingress</code> resources into Application Load Balancers.

## What it creates

<table>
<tr><th>Resource</th><th>Detail</th></tr>
<tr><td>IAM policy</td><td><code>dev-eks-cluster-alb-controller-policy</code> — from <code>alb-controller-policy.json</code> (AWS's published policy for the controller)</td></tr>
<tr><td>IAM role (IRSA)</td><td><code>dev-eks-cluster-alb-controller-role</code>, trusts the cluster OIDC provider, scoped to <code>system:serviceaccount:kube-system:aws-load-balancer-controller</code></td></tr>
<tr><td>helm_release</td><td><code>aws-load-balancer-controller</code> chart 1.8.1, image overridden to the regional ECR mirror <code>602401143452.dkr.ecr.&lt;region&gt;.amazonaws.com/amazon/aws-load-balancer-controller</code></td></tr>
<tr><td>Subnet tags</td><td>Public subnets → <code>kubernetes.io/role/elb=1</code> + <code>kubernetes.io/cluster/&lt;name&gt;=shared</code>; private subnets → <code>kubernetes.io/role/internal-elb=1</code> — required for the controller's subnet auto-discovery</td></tr>
</table>

## Why the ECR image override

<code>public.ecr.aws</code> is reachable once TGW/NAT egress works, but the regional <code>602401143452</code> ECR mirror is faster and doesn't depend on internet egress at all — useful during initial bring-up before TGW exists.

## Variables

<table>
<tr><th>Variable</th><th>Source</th></tr>
<tr><td>workload_account_id</td><td>DEV_WORKLOAD_ACCOUNT_ID secret</td></tr>
</table>

## Dependencies

<table>
<tr><th>Remote state</th><th>For</th></tr>
<tr><td>dev/eks-cluster</td><td>cluster_name, OIDC provider, endpoint/CA/token</td></tr>
<tr><td>dev/vpc</td><td>vpc_id, public_subnet_ids, private_subnet_ids (for tagging)</td></tr>
</table>

Deployed by workflow 6️⃣, triggered after EKS Add-ons (5️⃣b). Triggers ArgoCD (7️⃣).

## Standalone run

```bash
cd environments/dev/eks-alb
terraform apply -var="workload_account_id=<DEV_ACCOUNT_ID>"
```

## Verify

```bash
kubectl get pods -n kube-system | grep load-balancer
helm list -n kube-system
```

## Gotcha — 504 from ALB despite healthy pods

The ALB controller uses <code>target-type: ip</code> — it talks **directly to pod IPs**, bypassing the node's NodePort. The node security group must allow inbound traffic from the ALB's auto-created security groups on the ingress's target port (e.g. :80):

```bash
NODE_SG=$(aws ec2 describe-security-groups --region ap-southeast-2 \
  --filters "Name=tag:Name,Values=*dev-eks-cluster-node*" \
  --query 'SecurityGroups[0].GroupId' --output text)

ALB_SGS=$(aws elbv2 describe-load-balancers --region ap-southeast-2 \
  --query 'LoadBalancers[?contains(DNSName,`k8s-apps`)].SecurityGroups' --output text)

for sg in $ALB_SGS; do
  aws ec2 authorize-security-group-ingress \
    --group-id $NODE_SG --protocol tcp --port 80 --source-group $sg \
    --region ap-southeast-2
done
```

Consider codifying this as an <code>aws_security_group_rule</code> in <code>modules/eks-cluster</code> so it survives <code>terraform apply</code> of the node SG.
