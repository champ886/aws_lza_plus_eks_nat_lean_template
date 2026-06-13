# environments/dev/eks-addons

Foundational cluster add-ons that other workloads depend on — primarily storage.

## What it creates

<table>
<tr><th>Resource</th><th>Detail</th></tr>
<tr><td>EKS addon: aws-ebs-csi-driver</td><td><code>resolve_conflicts_on_create = OVERWRITE</code>, <code>resolve_conflicts_on_update = PRESERVE</code></td></tr>
<tr><td>kubernetes_storage_class "gp3"</td><td>Marked default via <code>storageclass.kubernetes.io/is-default-class: "true"</code>. <code>ebs.csi.aws.com</code> provisioner, <code>WaitForFirstConsumer</code> binding, <code>allow_volume_expansion = true</code>, encrypted</td></tr>
</table>

Also includes (pre-existing): <code>iam.tf</code>, <code>podidentity.tf</code> for vpc-cni / coredns / kube-proxy / pod-identity addons set up during initial cluster bring-up.

## Why gp3, not gp2

20% cheaper than gp2 with better baseline IOPS (3000 vs 100) and throughput (125MB/s vs disk-size-dependent) at the same price point. Every PVC created without an explicit <code>storageClassName</code> binds to this.

## Variables

<table>
<tr><th>Variable</th><th>Source</th></tr>
<tr><td>workload_account_id</td><td>DEV_WORKLOAD_ACCOUNT_ID secret</td></tr>
</table>

## Provider requirements

This environment's <code>providers.tf</code> must include a <code>kubernetes</code> provider block pointing at the cluster — without it, <code>kubernetes_storage_class</code> fails with <code>dial tcp 127.0.0.1:80: connect: connection refused</code> (provider defaults to localhost).

```hcl
provider "kubernetes" {
  host                   = data.aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.main.token
}
```

And <code>data.tf</code> must declare <code>aws_eks_cluster</code> + <code>aws_eks_cluster_auth</code> data sources (in addition to the <code>terraform_remote_state.eks_cluster</code> lookup).

## Dependencies

<table>
<tr><th>Remote state</th><th>For</th></tr>
<tr><td>dev/eks-cluster</td><td>cluster_name, endpoint, CA, OIDC details</td></tr>
</table>

Deployed by workflow 5️⃣b, triggered after EKS Cluster (5️⃣a). Triggers ALB Controller (6️⃣).

## Standalone run

```bash
cd environments/dev/eks-addons
rm -f .terraform.lock.hcl
terraform init
terraform apply -var="workload_account_id=<DEV_ACCOUNT_ID>"
```

## Verify

```bash
kubectl get storageclass
# NAME            PROVISIONER       ...
# gp3 (default)   ebs.csi.aws.com

aws eks list-addons --cluster-name dev-eks-cluster --region ap-southeast-2
```

## Gotcha

If Kubecost/Prometheus PVCs are stuck <code>Pending</code> with <code>unbound immediate PersistentVolumeClaims</code>, this environment hasn't been applied (or was applied before the EBS CSI driver/storage class additions). Re-apply this, then destroy + re-apply the dependent environment so its PVCs re-request against the now-available default class.
