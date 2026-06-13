# environments/transit-gateway

Transit Gateway — the **internet egress hub**. This is the only resource that allows Dev/Prod VPC traffic to reach the Security VPC's NAT Gateway, because VPC peering cannot do transitive (edge-to-edge) routing.

## Why this exists

```
❌ Dev VPC → peering → Security VPC NAT → Internet   (AWS blocks this — edge-to-edge routing)
✅ Dev VPC → TGW → Security VPC NAT → Internet        (TGW supports transitive routing)
```

Peering (see <code>environments/peering</code>) is kept for direct Dev↔Security and Prod↔Security traffic — it's free. TGW is used **only** for the <code>0.0.0.0/0</code> path.

## What it creates

<table>
<tr><th>Resource</th><th>Detail</th></tr>
<tr><td>aws_ec2_transit_gateway</td><td>Created in Security account. ASN 64512. Default route table association/propagation enabled.</td></tr>
<tr><td>RAM resource share + associations</td><td>Shares the TGW with Dev and Prod accounts so they can attach without manual acceptance. Requires <code>aws_ram_sharing_with_aws_organization</code> enabled in <code>environments/organization</code>.</td></tr>
<tr><td>TGW VPC attachments × 3</td><td>Security (private subnets), Dev (private subnets), Prod (private subnets)</td></tr>
<tr><td>TGW route table entries</td><td><code>0.0.0.0/0</code> → Security attachment; <code>10.0.0.0/16</code> → Dev attachment; <code>10.2.0.0/16</code> → Prod attachment (return paths)</td></tr>
<tr><td>Dev/Prod private route table entries</td><td><code>0.0.0.0/0</code> → TGW (replaces the old, broken peering-based default route)</td></tr>
<tr><td>Security <strong>public</strong> route table entries</td><td><code>10.0.0.0/16</code> → TGW, <code>10.2.0.0/16</code> → TGW — required so NAT return traffic can find its way back to the workload VPCs</td></tr>
</table>

## Full traffic flow

<table>
<tr><th>Route table</th><th>Destination</th><th>Target</th><th>Purpose</th></tr>
<tr><td>Dev/Prod private</td><td>0.0.0.0/0</td><td>TGW</td><td>internet egress</td></tr>
<tr><td>Dev/Prod private</td><td>10.1.0.0/16</td><td>peering</td><td>direct to Security (free)</td></tr>
<tr><td>TGW route table</td><td>0.0.0.0/0</td><td>Security attachment</td><td>all internet traffic → Security NAT</td></tr>
<tr><td>TGW route table</td><td>10.0.0.0/16 / 10.2.0.0/16</td><td>Dev / Prod attachment</td><td>NAT return traffic → originating VPC</td></tr>
<tr><td>Security private</td><td>0.0.0.0/0</td><td>NAT Gateway</td><td>egress to IGW</td></tr>
<tr><td>Security private</td><td>10.0/16, 10.2/16</td><td>peering</td><td>direct from Security (free)</td></tr>
<tr><td>Security public</td><td>10.0.0.0/16, 10.2.0.0/16</td><td>TGW</td><td>NAT return → Dev/Prod via TGW</td></tr>
<tr><td>Security public</td><td>0.0.0.0/0</td><td>IGW</td><td>internet</td></tr>
</table>

## Variables

<table>
<tr><th>Variable</th><th>Source</th></tr>
<tr><td>dev_workload_account_id</td><td>DEV_WORKLOAD_ACCOUNT_ID secret</td></tr>
<tr><td>prod_workload_account_id</td><td>PROD_WORKLOAD_ACCOUNT_ID secret</td></tr>
<tr><td>security_account_id</td><td>SECURITY_ACCOUNT_ID secret</td></tr>
<tr><td>dev_vpc_cidr, prod_vpc_cidr</td><td>defaults 10.0.0.0/16, 10.2.0.0/16</td></tr>
</table>

## Dependencies

<table>
<tr><th>Remote state</th><th>For</th></tr>
<tr><td>shared/vpc</td><td>security_vpc_id, security_private_subnet_ids, security_private_route_table_ids, security_public_route_table_id</td></tr>
<tr><td>dev/vpc</td><td>vpc_id, private_subnet_ids, private_route_table_ids</td></tr>
<tr><td>prod/vpc</td><td>vpc_id, private_subnet_ids, private_route_table_ids</td></tr>
</table>

Deployed by workflow 4️⃣b, triggered after Peering (4️⃣), triggers EKS Cluster (5️⃣a).

## Standalone run

```bash
cd environments/transit-gateway
terraform init
terraform apply \
  -var="dev_workload_account_id=<DEV_ACCOUNT_ID>" \
  -var="prod_workload_account_id=<PROD_ACCOUNT_ID>" \
  -var="security_account_id=<SECURITY_ACCOUNT_ID>"
```

## Gotchas

<table>
<tr><th>Issue</th><th>Fix</th></tr>
<tr><td>RAM sharing fails cross-account</td><td>Run <code>environments/organization</code> first — it enables <code>aws_ram_sharing_with_aws_organization</code> and adds <code>ram.amazonaws.com</code> to org service access principals</td></tr>
<tr><td><code>RouteAlreadyExists</code> on the Security public route table</td><td>These routes were likely added manually during initial NAT troubleshooting — import them: <code>terraform import 'module.transit_gateway.aws_route.security_public_to_dev' &lt;rtb-id&gt;_10.0.0.0/16</code></td></tr>
<tr><td>Shared VPC apply wants to delete TGW return routes</td><td>The <code>shared/vpc</code> module only manages the IGW route on the public route table — TGW return routes live in this state. Don't apply <code>shared/vpc</code> after this without re-running 4️⃣b immediately after.</td></tr>
</table>
