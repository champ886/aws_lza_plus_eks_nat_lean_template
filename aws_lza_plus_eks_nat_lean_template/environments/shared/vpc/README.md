# environments/shared/vpc

Security VPC — the network hub. Hosts the single shared NAT Gateway used for all internet egress, and the private subnets where the Transit Gateway attaches.

## What it creates

<table>
<tr><th>Resource</th><th>Detail</th></tr>
<tr><td>VPC</td><td><code>10.1.0.0/16</code></td></tr>
<tr><td>Public subnets</td><td><code>10.1.1.0/24</code> (AZ-a), <code>10.1.2.0/24</code> (AZ-b)</td></tr>
<tr><td>Private subnets</td><td><code>10.1.3.0/24</code> (AZ-a), <code>10.1.4.0/24</code> (AZ-b)</td></tr>
<tr><td>NAT Gateway</td><td>Single NAT in AZ-a public subnet — shared egress for Dev and Prod</td></tr>
<tr><td>Internet Gateway</td><td>Attached to public route table</td></tr>
<tr><td>Route tables</td><td>Public (IGW + dynamic TGW return routes), two private (NAT + dynamic peering routes)</td></tr>
</table>

## What it does NOT create

Peering routes and Transit Gateway routes are intentionally **not** here — they're owned by <code>environments/peering</code> and <code>environments/transit-gateway</code> respectively, to avoid two Terraform states fighting over the same route table.

## Variables

<table>
<tr><th>Variable</th><th>Source</th><th>Default</th></tr>
<tr><td>security_account_id</td><td><code>TF_VAR_security_account_id</code> ← <code>SECURITY_ACCOUNT_ID</code> secret</td><td>—</td></tr>
<tr><td>security_vpc_cidr</td><td>—</td><td>10.1.0.0/16</td></tr>
<tr><td>security_public_subnet_cidrs</td><td>—</td><td>["10.1.1.0/24","10.1.2.0/24"]</td></tr>
<tr><td>security_private_subnet_cidrs</td><td>—</td><td>["10.1.3.0/24","10.1.4.0/24"]</td></tr>
<tr><td>availability_zones</td><td>—</td><td>["ap-southeast-2a","ap-southeast-2b"]</td></tr>
</table>

## Dependencies

None — this is the first thing deployed (workflow 1️⃣).

## Key outputs

<table>
<tr><th>Output</th><th>Consumed by</th></tr>
<tr><td>security_vpc_id, security_vpc_cidr</td><td>peering, transit-gateway</td></tr>
<tr><td>security_public_subnet_ids, security_private_subnet_ids</td><td>transit-gateway</td></tr>
<tr><td>security_private_route_table_ids</td><td>peering, transit-gateway</td></tr>
<tr><td>security_public_route_table_id</td><td>peering, transit-gateway (NAT return routes)</td></tr>
<tr><td>security_nat_gateway_id, security_nat_gateway_public_ip</td><td>diagnostics</td></tr>
</table>

## Standalone run

```bash
cd environments/shared/vpc
terraform init
terraform apply -var="security_account_id=<SECURITY_ACCOUNT_ID>"
```

## Gotcha

Applying this environment after peering/TGW have added routes to the public route table will show a diff trying to **remove** those routes (this module's <code>main.tf</code> only knows about the IGW route). Do not apply unless you've checked the plan — if peering/TGW routes are about to be deleted, re-run workflow 4️⃣ and 4️⃣b immediately after.
