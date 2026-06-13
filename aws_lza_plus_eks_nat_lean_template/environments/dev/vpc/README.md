# environments/dev/vpc

Dev workload VPC. Hosts the EKS cluster and all dev workloads.

## What it creates

<table>
<tr><th>Resource</th><th>Detail</th></tr>
<tr><td>VPC</td><td><code>10.0.0.0/16</code></td></tr>
<tr><td>Public subnets</td><td>2× (one per AZ) — used for ALB only</td></tr>
<tr><td>Private subnets</td><td>2× (one per AZ) — EKS nodes live here</td></tr>
<tr><td>S3 gateway VPC endpoint</td><td>Free, avoids NAT charges for S3 traffic (ECR layer caching etc.)</td></tr>
<tr><td>Private route tables</td><td>One per AZ — populated with peering/TGW routes by other environments</td></tr>
</table>

## Variables

<table>
<tr><th>Variable</th><th>Source</th></tr>
<tr><td>dev_workload_account_id</td><td><code>TF_VAR_dev_workload_account_id</code> ← <code>DEV_WORKLOAD_ACCOUNT_ID</code> secret</td></tr>
<tr><td>workload_vpc_cidr</td><td>default 10.0.0.0/16</td></tr>
<tr><td>workload_public_subnet_cidrs / workload_private_subnet_cidrs</td><td>defaults</td></tr>
<tr><td>availability_zones</td><td>default ["ap-southeast-2a","ap-southeast-2b"]</td></tr>
</table>

## Dependencies

None directly, but deployed after Security VPC (workflow 2️⃣, triggered by 1️⃣).

## Key outputs

<table>
<tr><th>Output</th><th>Consumed by</th></tr>
<tr><td>vpc_id, vpc_cidr</td><td>peering, transit-gateway, eks-cluster</td></tr>
<tr><td>private_subnet_ids</td><td>eks-cluster, eks-karpenter</td></tr>
<tr><td>public_subnet_ids</td><td>eks-alb (subnet tagging)</td></tr>
<tr><td>private_route_table_ids</td><td>peering, transit-gateway</td></tr>
</table>

## Routing summary (final state, after peering + TGW applied)

<table>
<tr><th>Destination</th><th>Target</th><th>Purpose</th></tr>
<tr><td>10.0.0.0/16</td><td>local</td><td>intra-VPC</td></tr>
<tr><td>10.1.0.0/16</td><td>VPC peering to Security</td><td>direct, free, low-latency</td></tr>
<tr><td>0.0.0.0/0</td><td>Transit Gateway</td><td>internet egress via Security NAT</td></tr>
<tr><td>S3 prefix list</td><td>S3 gateway endpoint</td><td>free ECR/S3 traffic</td></tr>
</table>

## Standalone run

```bash
cd environments/dev/vpc
terraform init
terraform apply -var="dev_workload_account_id=<DEV_ACCOUNT_ID>"
```
