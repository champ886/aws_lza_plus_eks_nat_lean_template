# aws_lza_plus_eks_nat_lean (template)

A complete AWS Landing Zone Accelerator plus a production-grade EKS platform, built entirely with Terraform and GitHub Actions — zero manual console steps. Covers everything from the AWS Organization down to GitOps application delivery.

**This is a template repo.** Every account ID, organization/OU ID, state bucket name, and repo reference has been replaced with a placeholder like <code>&lt;DEV_ACCOUNT_ID&gt;</code>. Start with <a href="TEMPLATE_SETUP.md">TEMPLATE_SETUP.md</a> to fill them in and bootstrap your own copy.

See <a href="RUNBOOK.md">RUNBOOK.md</a> for deployment order and gotchas once configured.

## What this repo builds

<table>
<tr><th>Layer</th><th>What</th><th>Where</th><th>How it's run</th></tr>
<tr><td>Landing Zone</td><td>AWS Organization, OUs, member accounts, SCPs, Config, logging, IAM Access Analyzer, OIDC for GitHub Actions</td><td>environments/management, environments/organization, environments/accounts, environments/scp, environments/logging, environments/iam-analyzer</td><td>Manual, one-time bootstrap (run locally from management account)</td></tr>
<tr><td>Networking</td><td>Security/Dev/Prod VPCs, VPC peering, Transit Gateway hub-and-spoke</td><td>environments/shared/vpc, environments/dev/vpc, environments/prod/vpc, environments/peering, environments/transit-gateway</td><td>GHA pipeline 1️⃣-4️⃣b</td></tr>
<tr><td>EKS Platform</td><td>EKS cluster, add-ons (EBS CSI, gp3 storage class), ALB controller</td><td>environments/dev/eks-cluster, environments/dev/eks-addons, environments/dev/eks-alb</td><td>GHA pipeline 5️⃣a-6️⃣</td></tr>
<tr><td>GitOps</td><td>ArgoCD App-of-Apps, workload apps (pgAdmin, postgres), platform apps (metrics-server)</td><td>environments/dev/eks-argocd, gitops/</td><td>GHA pipeline 7️⃣</td></tr>
<tr><td>Autoscaling</td><td>Karpenter dynamic node provisioning (spot + on-demand)</td><td>environments/dev/eks-karpenter</td><td>GHA pipeline 8️⃣</td></tr>
<tr><td>FinOps</td><td>Kubecost free tier + bundled Prometheus for per-pod cost visibility</td><td>environments/dev/eks-kubecost</td><td>GHA pipeline 9️⃣</td></tr>
</table>

## Architecture overview

### Organization structure

```
AWS Organization (<ORG_ID>) — ap-southeast-2
├── Management account (<MANAGEMENT_ACCOUNT_ID>)
│   ├── AWS Config (compliance recording)
│   ├── CloudWatch log group (/aws/management/lza-logs, 90d retention)
│   ├── S3 log archive bucket (management-lza-log-archive-<MANAGEMENT_ACCOUNT_ID>)
│   ├── IAM Access Analyzer (org-wide, free, type=ORGANIZATION)
│   ├── GitHub Actions OIDC provider + role
│   └── Terraform runs from here
│
├── Workload OU (<WORKLOAD_OU_ID>)
│   ├── Dev account (<DEV_ACCOUNT_ID>)        → Dev VPC + EKS platform
│   └── Prod account (<PROD_ACCOUNT_ID>)       → Prod VPC (networking only)
│
└── Security OU (<SECURITY_OU_ID>)
    └── Security account (<SECURITY_ACCOUNT_ID>)   → Shared VPC, NAT, TGW hub
```

### Network + EKS

```
                         ┌─────────────────────┐
                         │   Security VPC       │
                         │   10.1.0.0/16        │
                         │   NAT Gateway         │
                         │   (shared egress)     │
                         └──────────┬───────────┘
                          TGW attach │  peering (free, direct, per-AZ)
                    ┌────────────────┴────────────────┐
                    │         Transit Gateway          │
                    │   (internet egress only — hub)   │
                    └──────┬─────────────────┬─────────┘
              TGW attach    │                 │ TGW attach
        ┌───────────────────┴───┐   ┌─────────┴───────────────┐
        │   Dev VPC 10.0.0.0/16  │   │  Prod VPC 10.2.0.0/16   │
        │   EKS Cluster          │   │  (networking only)      │
        │   ├─ Karpenter         │   └──────────────────────────┘
        │   ├─ ALB Controller    │
        │   ├─ ArgoCD (App of Apps)
        │   │    ├─ pgAdmin      │
        │   │    └─ postgres     │
        │   └─ Kubecost + Prometheus
        └────────────────────────┘
```

Internet egress always flows: workload VPC → Transit Gateway → Security VPC private subnet → NAT Gateway → Internet Gateway. VPC-to-VPC traffic (Dev/Prod ↔ Security) uses free direct peering with per-AZ route tables, never the TGW. Dev and Prod have no direct peering between them.

## What is deployed and what it costs

## Data plane architecture — image pulls, security, observability

```
┌────────────────────────────┐   ┌──────────────────────────────────────┐
│  Public registries          │   │  GitHub (gitops/)                     │
│  public.ecr.aws · quay.io   │   │  ArgoCD watches for manifest changes  │
│  ghcr.io · gcr.io           │   │                                        │
└──────────────┬───────────────┘   └──────────────────┬─────────────────────┘
               │ via TGW → Security NAT                │ via TGW → Security NAT
               ▼                                        ▼
┌──────────────────────────── Dev VPC · 10.0.0.0/16 ──────────────────────────┐
│ ┌─ Public subnets ────────────────────────────────────────────────────────┐ │
│ │  Internet Gateway              ALB (pgAdmin ingress, target-type=ip)     │ │
│ └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│ ┌─ Security layer — Security Groups + NACL (no firewall appliance) ──────┐ │
│ │  Node SG:   ingress from ALB SGs → :80  ·  egress 0.0.0.0/0 → TGW       │ │
│ │  Cluster SG: nodes → :443  ·  default NACL: allow all in/out            │ │
│ └──────────────────────────────────────────────────────────────────────--┘ │
│                                                                              │
│ ┌─ Private subnets · EKS data plane ─────────────────────────────────────┐ │
│ │  Karpenter NodePool — spot + on-demand · t3/t3a medium/large            │ │
│ │  consolidateAfter: 30s · limits 16 vCPU / 32Gi                          │ │
│ │  ┌──────────────────┐ ┌──────────────────┐ ┌─────────────────────────┐│ │
│ │  │ Spot nodes        │ │ On-demand nodes  │ │ Managed node group       ││ │
│ │  │ (Karpenter)       │ │ (Karpenter)      │ │ CoreDNS·ALB ctrl·ArgoCD  ││ │
│ │  │                   │ │                  │ │ (phased out via Karpenter)││ │
│ │  └──────────────────┘ └──────────────────┘ └─────────────────────────┘│ │
│ │                                                                          │ │
│ │  In-cluster tooling                                                      │ │
│ │  ┌──────────────────┐ ┌──────────────────┐ ┌─────────────────────────┐│ │
│ │  │ ArgoCD            │ │ Karpenter ctrl   │ │ Kubecost + Prometheus   ││ │
│ │  │ App of Apps       │ │ provision/drain  │ │ per-pod cost · 15d ret. ││ │
│ │  └──────────────────┘ └──────────────────┘ └─────────────────────────┘│ │
│ │                                                                          │ │
│ │  ┌─ Public registry pull path ─────────┐ ┌─ Regional ECR pull path ───┐│ │
│ │  │ node → node SG :443                 │ │ node → ecr.api endpoint    ││ │
│ │  │  → TGW → Security NAT               │ │  → ecr.dkr endpoint        ││ │
│ │  │  → IGW → internet → registry        │ │  → S3 gateway (free)       ││ │
│ │  └──────────────────────────────────────┘ └────────────────────────--┘│ │
│ └──────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│ ┌─ VPC endpoints — ECR/S3 stay inside AWS, no NAT/TGW charge ─────────────┐ │
│ │  ecr.api + ecr.dkr (interface)  │  s3 (gateway, free)                   │ │
│ │  sts + logs + ec2 (interface)                                           │ │
│ └──────────────────────────────────────────────────────────────────────--┘ │
└──────────────────────────────────────────────────────────────────────────--┘
                          │
                          ▼
┌─ Security VPC · 10.1.0.0/16 ───────────────────────────────────────────────┐
│  NAT Gateway (shared, single AZ) — Internet Gateway — TGW attachment       │
└─────────────────────────────────────────────────────────────────────────--┘

  ── solid:  via TGW → Security NAT (public registries, general egress)
  ·····  dashed: via VPC interface/gateway endpoint (ECR, S3 — stays in AWS)
```

<table>
<tr><th>Path</th><th>Used for</th><th>Cost</th></tr>
<tr><td>Node SG → TGW → Security NAT → IGW</td><td>public.ecr.aws, quay.io, ghcr.io, gcr.io, Helm repos, ArgoCD git sync over HTTPS</td><td>NAT + TGW data processing charges</td></tr>
<tr><td>Node → ecr.api / ecr.dkr interface endpoints</td><td>Regional ECR mirror (<code>602401143452...</code>) for ALB controller, EBS CSI images</td><td>Interface endpoint hourly + data charges, no NAT/TGW</td></tr>
<tr><td>Node → S3 gateway endpoint</td><td>ECR image layer storage (backs ecr.dkr), Terraform state if run from in-VPC</td><td>Free</td></tr>
<tr><td>Node → sts / logs / ec2 interface endpoints</td><td>IRSA token exchange, CloudWatch logs, Karpenter EC2 API calls</td><td>Interface endpoint hourly + data charges, no NAT/TGW</td></tr>
</table>

Routing every AWS-API call through VPC endpoints instead of the TGW/NAT path is what keeps the lean cost model viable — Karpenter, IRSA, and ECR pulls for AWS-maintained images never touch the shared NAT.


<table>
<tr><th>Resource</th><th>Account</th><th>Cost</th></tr>
<tr><td>AWS Organizations + OUs</td><td>Management</td><td>Free</td></tr>
<tr><td>Service Control Policies (3) + attachments</td><td>All OUs</td><td>Free</td></tr>
<tr><td>AWS Config recorder + IAM role</td><td>Management</td><td>~$2-5/month</td></tr>
<tr><td>CloudWatch log group (90d retention)</td><td>Management</td><td>~$0.50-2/month</td></tr>
<tr><td>S3 log archive bucket (versioned)</td><td>Management</td><td>~$0.01/month</td></tr>
<tr><td>IAM Access Analyzer (org-wide)</td><td>Management</td><td>Free — permanent, no trial/expiry</td></tr>
<tr><td>Dev/Prod/Security VPCs + subnets + IGW</td><td>Dev, Prod, Security</td><td>Free</td></tr>
<tr><td>VPC peering (dev↔security, prod↔security)</td><td>Cross-account</td><td>Free</td></tr>
<tr><td>NAT Gateway (single, shared)</td><td>Security</td><td>~$32/month + data</td></tr>
<tr><td>Transit Gateway + 3 attachments</td><td>Security/Dev/Prod</td><td>~$36/attachment/month + data</td></tr>
<tr><td>EKS cluster + managed node group</td><td>Dev</td><td>~$73/month (control plane) + EC2</td></tr>
<tr><td>ALB (pgAdmin ingress)</td><td>Dev</td><td>~$16/month + data</td></tr>
<tr><td>EBS gp3 volumes (postgres, Prometheus)</td><td>Dev</td><td>~$0.08/GB/month</td></tr>
<tr><td>Karpenter, ArgoCD, Kubecost</td><td>Dev</td><td>Free (run on existing nodes)</td></tr>
</table>

LZA foundation alone: ~$3-8/month. Full EKS platform adds roughly ~$150-200/month depending on node sizing and Karpenter consolidation.

## Account map

<table>
<tr><th>Account</th><th>ID</th><th>OU</th><th>Purpose</th></tr>
<tr><td>Management</td><td><MANAGEMENT_ACCOUNT_ID></td><td>root</td><td>Org foundation, Config, logging, IAM Analyzer, GitHub Actions OIDC role, Terraform execution</td></tr>
<tr><td>Security</td><td><SECURITY_ACCOUNT_ID></td><td>Security (<SECURITY_OU_ID>)</td><td>Shared VPC, NAT Gateway, Transit Gateway hub</td></tr>
<tr><td>Dev</td><td><DEV_ACCOUNT_ID></td><td>Workload (<WORKLOAD_OU_ID>)</td><td>Dev VPC, EKS cluster, all workloads</td></tr>
<tr><td>Prod</td><td><PROD_ACCOUNT_ID></td><td>Workload (<WORKLOAD_OU_ID>)</td><td>Prod VPC (networking only, no workloads yet)</td></tr>
</table>

Region: <code>ap-southeast-2</code> everywhere — enforced by SCP. Terraform state: S3 bucket <code><YOUR_STATE_BUCKET_NAME></code>, DynamoDB lock table <code>tf-locks</code>.

## Service control policies

Attached to both the Workload OU and Security OU. The org-level <code>FullAWSAccess</code> policy is the baseline allow; these SCPs deny specific actions on top of it.

<table>
<tr><th>SCP</th><th>Enforces</th></tr>
<tr><td>1 — Root and org protection</td><td>Blocks the root user from any action in any account. Prevents accounts leaving the org. Prevents SCPs themselves being modified or deleted.</td></tr>
<tr><td>2 — Audit and compliance protection</td><td>Prevents CloudTrail and AWS Config from being stopped or deleted.</td></tr>
<tr><td>3 — Region and security service protection</td><td>Blocks all services outside <code>ap-southeast-2</code> (global services IAM, STS, S3, Route53, CloudFront, EC2 exempted). Prevents disabling future security services.</td></tr>
</table>

## IAM Access Analyzer

Deployed once as <code>type = ORGANIZATION</code> from the management account — covers every account in the org with a single analyzer. Continuously scans S3 buckets, IAM roles, KMS keys, Lambda functions, SQS queues, and Secrets Manager secrets for resource policies granting access outside the organization. Findings appear in AWS Console → IAM → Access Analyzer. Permanently free.

## Repository structure

```
.
├── environments/
│   ├── management/          AWS Org, OUs, accounts, SCPs, Config, logging, IAM Analyzer
│   ├── organization/         Org structure + RAM sharing enablement
│   ├── accounts/             Member account creation
│   ├── scp/                  Service control policies
│   ├── logging/              Org-wide CloudTrail / Config
│   ├── iam-analyzer/         IAM Access Analyzer (org-wide)
│   ├── shared/vpc/           Security VPC + NAT Gateway
│   ├── dev/vpc/               Dev workload VPC
│   ├── prod/vpc/              Prod workload VPC
│   ├── peering/               Dev↔Security and Prod↔Security peering (per-AZ)
│   ├── transit-gateway/        TGW hub for internet egress
│   ├── dev/eks-cluster/        EKS control plane + managed node group
│   ├── dev/eks-addons/         EBS CSI driver, gp3 StorageClass
│   ├── dev/eks-alb/            AWS Load Balancer Controller
│   ├── dev/eks-argocd/         ArgoCD + secrets + root App-of-Apps
│   ├── dev/eks-karpenter/       Karpenter controller, NodePool, EC2NodeClass
│   └── dev/eks-kubecost/        Kubecost free tier + bundled Prometheus
├── modules/                   One module per environment above, plus:
│   ├── organization/, accounts/, scp/, config/, logging/, iam-analyzer/
│   ├── vpc/                   VPC, subnets, IGW, per-AZ route tables
│   └── vpc-peering/           Peering connection, auto-accept, routes, DNS
├── gitops/                    ArgoCD-managed manifests (apps + platform)
└── .github/workflows/         11 chained GitHub Actions pipelines (component-1 .. 9)
```

Every environment folder and <code>gitops/</code> has its own <code>README.md</code> with specifics — purpose, variables, dependencies, and how to run it standalone.

## Deployment order

### Phase 1 — LZA foundation (manual, one-time, run from management account)

```bash
cd environments/management
terraform init && terraform apply -var-file="terraform.tfvars"
```

This single environment creates the org, OUs, member accounts, SCPs, Config, logging, and the org-wide IAM Access Analyzer. Everything below depends on the accounts and OIDC role this creates.

### Phase 2 — Networking + EKS platform (GitHub Actions, chained)

Eleven chained workflows (<code>component-1</code> through <code>component-9</code>, plus <code>4b</code>). Each auto-triggers the next on successful apply via <code>workflow_run</code>, with a manual approval gate before every apply. Destroy is always manual, never cascades.

```
1️⃣ Security VPC → 2️⃣ Dev VPC → 3️⃣ Prod VPC → 4️⃣ Peering → 4️⃣b Transit Gateway →
5️⃣a EKS Cluster → 5️⃣b EKS Add-ons → 6️⃣ ALB Controller → 7️⃣ ArgoCD →
8️⃣ Karpenter → 9️⃣ Kubecost
```

Full step-by-step and known gotchas: <a href="RUNBOOK.md">RUNBOOK.md</a>.

## VPC peering design

```
Dev VPC (10.0.0.0/16)  ──── peering ────► Shared security VPC (10.1.0.0/16)
Prod VPC (10.2.0.0/16) ──── peering ────► Shared security VPC (10.1.0.0/16)
Dev VPC ──────────────── no peering ──── Prod VPC
```

Per-AZ route tables keep peered traffic within the same availability zone, avoiding cross-AZ data transfer charges. DNS resolution is enabled across all peering connections. <code>auto_accept = true</code> is safe — both accounts are in the same AWS Organization.

## Terraform state backend

All state in S3 with DynamoDB locking, one isolated state file per environment — destroying one never affects another.

```
<YOUR_STATE_BUCKET_NAME>/
  aws-lza/management/terraform.tfstate          org, accounts, SCPs, Config, logging, analyzer
  aws-lza/shared/vpc/terraform.tfstate           security VPC
  aws-lza/dev/vpc/terraform.tfstate              dev workload VPC
  aws-lza/prod/vpc/terraform.tfstate             prod workload VPC
  aws-lza/peering/terraform.tfstate              VPC peering
  aws-lza/transit-gateway/terraform.tfstate      TGW
  aws-lza/dev/eks-*/terraform.tfstate            one per EKS environment
```

## Key design decisions

<table>
<tr><th>Decision</th><th>Why</th></tr>
<tr><td>SCPs at OU level, not account level</td><td>All accounts inside an OU inherit every attached SCP automatically — add an account to Workload OU and it's covered, no extra Terraform.</td></tr>
<tr><td>IAM Access Analyzer as a single org-wide analyzer</td><td>One analyzer in the management account covers every member account — no per-account deployment, and it's permanently free.</td></tr>
<tr><td>Per-AZ route tables for peering</td><td>Keeps peered traffic within the same AZ, avoiding cross-AZ data transfer charges.</td></tr>
<tr><td>Transit Gateway for internet egress only; peering for VPC↔VPC</td><td>AWS blocks edge-to-edge routing over peering (no transitive NAT). TGW costs ~$36/mo/attachment but is the only way to centralise egress through one NAT. Peering stays free for direct traffic.</td></tr>
<tr><td>Single NAT Gateway in Security VPC</td><td>Lean — one NAT shared by all workload VPCs instead of one per VPC.</td></tr>
<tr><td>No Dev↔Prod peering</td><td>No legitimate traffic path needed between environments — reduces blast radius.</td></tr>
<tr><td><code>gavinbunney/kubectl</code> provider for ArgoCD/Karpenter CRDs</td><td><code>kubernetes_manifest</code> validates CRDs at plan time, before the controller exists. <code>kubectl_manifest</code> only validates at apply time.</td></tr>
<tr><td>App of Apps GitOps pattern</td><td>Terraform creates exactly one ArgoCD <code>root</code> Application. Everything else is added via <code>gitops/apps.yaml</code> / <code>gitops/platform.yaml</code> — no Terraform changes needed for new apps.</td></tr>
<tr><td>IAM-coupled infra stays in Terraform; pure-K8s tools go to ArgoCD platform.yaml</td><td>Karpenter, Kubecost, ALB Controller, EBS CSI all need IRSA roles — coupling Helm install to IAM in Terraform avoids a chicken-and-egg dependency.</td></tr>
<tr><td>Karpenter migration is phased, never destructive</td><td>Install alongside the managed node group → taint it → verify Karpenter nodes → scale managed group to 0 → remove from Terraform.</td></tr>
<tr><td>gp3 default StorageClass</td><td>20% cheaper than gp2 with better baseline IOPS; required by Kubecost/Prometheus PVCs.</td></tr>
</table>

## Useful commands

```bash
# Check current state of all resources
terraform show

# List all resources Terraform is managing
terraform state list

# Preview changes without applying
terraform plan -var-file="terraform.tfvars"

# Format all .tf files
terraform fmt -recursive

# Destroy a specific environment only
terraform destroy -var-file="terraform.tfvars"
```

## Security notes

<table>
<tr><th>Practice</th><th>Detail</th></tr>
<tr><td><code>terraform.tfvars</code> never committed</td><td>Excluded via <code>.gitignore</code> — contains account IDs and email addresses</td></tr>
<tr><td>Cross-account access</td><td><code>OrganizationAccountAccessRole</code> in each member account lets the management account assume role in for Terraform deployments</td></tr>
<tr><td>SCP enforcement</td><td>Applied at OU level — all accounts inside inherit automatically</td></tr>
<tr><td>Baseline allow + deny overlay</td><td><code>FullAWSAccess</code> attached at OU level as baseline; SCPs deny specific actions on top</td></tr>
<tr><td>Peering auto-accept</td><td><code>auto_accept = true</code> is safe — both accounts are within the same AWS Organization</td></tr>
<tr><td>GitOps secrets</td><td>postgres/pgadmin credentials created as K8s secrets by Terraform, never stored in <code>gitops/</code></td></tr>
</table>
