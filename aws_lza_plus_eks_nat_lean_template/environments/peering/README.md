# environments/peering

Direct VPC peering between each workload VPC and the Security VPC. Used for free, low-latency Dev↔Security and Prod↔Security traffic. **Not** used for internet egress — see <code>transit-gateway</code> for that.

## What it creates

<table>
<tr><th>Resource</th><th>Detail</th></tr>
<tr><td>aws_vpc_peering_connection × 2</td><td>dev-to-security, prod-to-security</td></tr>
<tr><td>aws_vpc_peering_connection_accepter × 2</td><td>auto-accept on the Security side</td></tr>
<tr><td>DNS resolution options</td><td>enabled both directions on both connections</td></tr>
<tr><td>Routes — requester private route tables (AZ-a, AZ-b)</td><td><code>&lt;security_vpc_cidr&gt;</code> → peering connection</td></tr>
<tr><td>Routes — accepter (Security) private route tables (AZ-a, AZ-b)</td><td><code>&lt;requester_vpc_cidr&gt;</code> → peering connection</td></tr>
<tr><td>Routes — accepter (Security) <strong>public</strong> route table</td><td><code>&lt;requester_vpc_cidr&gt;</code> → peering connection (only if <code>route_internet_via_accepter = true</code> — currently <code>false</code>)</td></tr>
</table>

## Module: <code>modules/vpc-peering</code>

Generic two-sided module. Each call passes a <code>requester</code> (Dev or Prod) and <code>accepter</code> (Security) provider alias plus their route table IDs.

<table>
<tr><th>Key variable</th><th>Meaning</th></tr>
<tr><td>route_internet_via_accepter</td><td><strong>false</strong>. Historically this added <code>0.0.0.0/0</code> routes via peering — removed because AWS does not support edge-to-edge (transitive) routing over peering. Internet egress is handled entirely by Transit Gateway now.</td></tr>
<tr><td>accepter_public_route_table_id</td><td>Retained for completeness but unused while <code>route_internet_via_accepter = false</code>.</td></tr>
</table>

## Variables

<table>
<tr><th>Variable</th><th>Source</th></tr>
<tr><td>dev_workload_account_id</td><td>DEV_WORKLOAD_ACCOUNT_ID secret</td></tr>
<tr><td>prod_workload_account_id</td><td>PROD_WORKLOAD_ACCOUNT_ID secret</td></tr>
<tr><td>security_account_id</td><td>SECURITY_ACCOUNT_ID secret</td></tr>
<tr><td>security_vpc_cidr, dev_vpc_cidr, prod_vpc_cidr</td><td>defaults (10.1/10.0/10.2 .0.0/16)</td></tr>
</table>

## Dependencies

<table>
<tr><th>Remote state</th><th>For</th></tr>
<tr><td>shared/vpc</td><td>Security VPC ID, CIDR, private + public route table IDs</td></tr>
<tr><td>dev/vpc, prod/vpc</td><td>VPC IDs, CIDRs, private route table IDs (via data sources, looked up by tag name)</td></tr>
</table>

Deployed by workflow 4️⃣, triggered after Prod VPC (3️⃣), triggers Transit Gateway (4️⃣b).

## Standalone run

```bash
cd environments/peering
terraform init
terraform apply \
  -var="dev_workload_account_id=<DEV_ACCOUNT_ID>" \
  -var="prod_workload_account_id=<PROD_ACCOUNT_ID>" \
  -var="security_account_id=<SECURITY_ACCOUNT_ID>"
```

## Gotcha

If routes were added manually during troubleshooting before this state existed, <code>terraform apply</code> will fail with <code>RouteAlreadyExists</code>. Import them first:

```bash
terraform import 'module.dev_to_security_peering.aws_route.accepter_to_requester_az_a' <route-table-id>_<cidr>
```
