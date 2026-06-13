# environments/dev/eks-kubecost

Kubecost (free tier) with bundled Prometheus — per-pod/namespace cost visibility using real AWS pricing data.

## What it creates

<table>
<tr><th>Resource</th><th>Detail</th></tr>
<tr><td>kubernetes_namespace "kubecost"</td><td>—</td></tr>
<tr><td>IAM role (IRSA) "kubecost"</td><td>Trusts cluster OIDC provider, scoped to <code>system:serviceaccount:kubecost:kubecost-cost-analyzer</code></td></tr>
<tr><td>IAM role policy</td><td><code>pricing:GetProducts</code>, <code>pricing:DescribeServices</code>, <code>ce:GetCostAndUsage</code></td></tr>
<tr><td>helm_release "kubecost"</td><td>chart 2.3.4 from <code>https://kubecost.github.io/cost-analyzer/</code>, free tier (<code>kubecostToken=""</code>)</td></tr>
</table>

## Helm values set

<table>
<tr><th>Value</th><th>Setting</th><th>Why</th></tr>
<tr><td>serviceAccount.annotations.eks.amazonaws.com/role-arn</td><td>kubecost IAM role ARN</td><td>IRSA — lets cost-analyzer call AWS pricing/Cost Explorer APIs</td></tr>
<tr><td>kubecostProductConfigs.region</td><td>ap-southeast-2</td><td>accurate regional pricing</td></tr>
<tr><td>cloudIntegration.awsAccountId</td><td>workload account ID</td><td>cost attribution</td></tr>
<tr><td>prometheus.server.persistentVolume.size</td><td>8Gi</td><td>bundled Prometheus storage (binds to default gp3 StorageClass)</td></tr>
<tr><td>prometheus.server.retention</td><td>15d</td><td>free tier maximum</td></tr>
<tr><td>prometheus.alertmanager.enabled / pushgateway.enabled</td><td>false</td><td>not needed for cost visibility — keeps it lean</td></tr>
<tr><td>grafana.enabled</td><td>false</td><td>Kubecost has its own UI</td></tr>
</table>

## Variables

<table>
<tr><th>Variable</th><th>Source</th></tr>
<tr><td>workload_account_id</td><td>DEV_WORKLOAD_ACCOUNT_ID secret</td></tr>
</table>

## Dependencies

<table>
<tr><th>Remote state</th><th>For</th></tr>
<tr><td>dev/eks-cluster</td><td>cluster_name, OIDC provider, endpoint/CA/token</td></tr>
</table>

Hard dependency: <strong>dev/eks-addons must be applied first</strong> — the Prometheus PVC needs the default <code>gp3</code> StorageClass or it sits <code>Pending</code> forever and the Helm release times out with <code>context deadline exceeded</code>.

Deployed by workflow 9️⃣, triggered after Karpenter (8️⃣). Last in the chain.

## Standalone run

```bash
cd environments/dev/eks-kubecost
terraform init
terraform apply -var="workload_account_id=<DEV_ACCOUNT_ID>"
```

## Verify

```bash
kubectl get pods -n kubecost      # cost-analyzer, prometheus-server, forecasting, grafana(disabled) all Running
kubectl get pvc -n kubecost       # Bound, not Pending

kubectl port-forward svc/kubecost-cost-analyzer -n kubecost 9090:9090
# open http://localhost:9090
```

In the UI: <strong>Monitor → Cost Allocation</strong> for per-namespace/pod cost, <strong>Savings → Right-sizing / Cluster sizing</strong> for optimisation recommendations.

## Gotcha

If <code>kubecost-prometheus-server</code> and <code>kubecost-cost-analyzer</code> pods are stuck <code>Pending</code> with <code>unbound immediate PersistentVolumeClaims</code>:

```bash
kubectl get storageclass    # if empty/no default, apply dev/eks-addons first
```

Then:
```bash
terraform destroy -var="workload_account_id=<DEV_ACCOUNT_ID>"
terraform apply  -var="workload_account_id=<DEV_ACCOUNT_ID>"
```
so the PVCs re-request against the now-available default StorageClass.
