# environments/prod/vpc

Prod workload VPC. Currently networking-only — no EKS cluster or workloads deployed here yet. Exists so peering and Transit Gateway can be built out for a future prod environment without re-architecting.

## What it creates

<table>
<tr><th>Resource</th><th>Detail</th></tr>
<tr><td>VPC</td><td><code>10.2.0.0/16</code></td></tr>
<tr><td>Public subnets</td><td>2× (one per AZ)</td></tr>
<tr><td>Private subnets</td><td>2× (one per AZ)</td></tr>
<tr><td>Private route tables</td><td>One per AZ — populated with peering/TGW routes by other environments</td></tr>
</table>

## Variables

<table>
<tr><th>Variable</th><th>Source</th></tr>
<tr><td>prod_workload_account_id</td><td><code>TF_VAR_prod_workload_account_id</code> ← <code>PROD_WORKLOAD_ACCOUNT_ID</code> secret</td></tr>
<tr><td>workload_vpc_cidr</td><td>default 10.2.0.0/16</td></tr>
</table>

## Dependencies

None directly. Deployed after Dev VPC (workflow 3️⃣, triggered by 2️⃣).

## Key outputs

<table>
<tr><th>Output</th><th>Consumed by</th></tr>
<tr><td>vpc_id, vpc_cidr</td><td>peering, transit-gateway</td></tr>
<tr><td>private_subnet_ids, private_route_table_ids</td><td>transit-gateway</td></tr>
</table>

## Standalone run

```bash
cd environments/prod/vpc
terraform init
terraform apply -var="prod_workload_account_id=<PROD_ACCOUNT_ID>"
```

## Notes

Until an EKS cluster (or any workload) is deployed in prod, this VPC has no compute — it exists purely to validate the hub-and-spoke networking pattern scales to N spokes for the same TGW/NAT cost.
