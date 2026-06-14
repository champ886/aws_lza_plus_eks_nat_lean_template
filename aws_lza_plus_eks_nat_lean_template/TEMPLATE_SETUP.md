# Template setup guide

This repo is a templated copy of a working AWS Landing Zone + EKS platform. All account IDs, organization/OU IDs, state bucket names, and repo references have been replaced with placeholders. Follow this guide top-to-bottom to make it yours.

## 1. Fork / clone this repo

```bash
git clone https://github.com/<YOUR_GITHUB_ORG>/<YOUR_REPO_NAME>.git
cd <YOUR_REPO_NAME>
```

## 2. Create your Terraform state backend

Create an S3 bucket and DynamoDB table in your management account before running anything:

```bash
aws s3api create-bucket \
  --bucket <YOUR_STATE_BUCKET_NAME> \
  --region ap-southeast-2 \
  --create-bucket-configuration LocationConstraint=ap-southeast-2

aws s3api put-bucket-versioning \
  --bucket <YOUR_STATE_BUCKET_NAME> \
  --versioning-configuration Status=Enabled

aws dynamodb create-table \
  --table-name tf-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-southeast-2
```

## 3. Replace all placeholders

<table>
<tr><th>Placeholder</th><th>What it is</th><th>How to get it</th></tr>
<tr><td><code>&lt;YOUR_STATE_BUCKET_NAME&gt;</code></td><td>S3 bucket from step 2</td><td>Bucket name you chose — must be globally unique</td></tr>
<tr><td><code>&lt;YOUR_GITHUB_ORG&gt;</code></td><td>Your GitHub username or org</td><td>github.com/&lt;this&gt;</td></tr>
<tr><td><code>&lt;YOUR_REPO_NAME&gt;</code></td><td>This repo's name after you fork/rename it</td><td>github.com/.../&lt;this&gt;</td></tr>
<tr><td><code>&lt;ORG_ID&gt;</code></td><td>AWS Organization ID</td><td><code>aws organizations describe-organization --query Organization.Id</code> (after step 4)</td></tr>
<tr><td><code>&lt;WORKLOAD_OU_ID&gt;</code></td><td>Workload OU ID (Dev + Prod accounts)</td><td>Output of <code>module.organization</code> after first apply, or <code>aws organizations list-organizational-units-for-parent</code></td></tr>
<tr><td><code>&lt;SECURITY_OU_ID&gt;</code></td><td>Security OU ID</td><td>Same as above</td></tr>
<tr><td><code>&lt;MANAGEMENT_ACCOUNT_ID&gt;</code></td><td>Your AWS Organization's management account ID</td><td><code>aws sts get-caller-identity</code> run from management account</td></tr>
<tr><td><code>&lt;DEV_ACCOUNT_ID&gt;</code></td><td>Dev workload account ID</td><td>Created by <code>environments/management</code> in step 4, or <code>aws organizations list-accounts</code></td></tr>
<tr><td><code>&lt;PROD_ACCOUNT_ID&gt;</code></td><td>Prod workload account ID</td><td>Same as above</td></tr>
<tr><td><code>&lt;SECURITY_ACCOUNT_ID&gt;</code></td><td>Security account ID</td><td>Same as above</td></tr>
</table>

Find every occurrence:

```bash
grep -rn "<YOUR_STATE_BUCKET_NAME>\|<YOUR_GITHUB_ORG>\|<YOUR_REPO_NAME>\|<ORG_ID>\|<WORKLOAD_OU_ID>\|<SECURITY_OU_ID>\|<MANAGEMENT_ACCOUNT_ID>\|<DEV_ACCOUNT_ID>\|<PROD_ACCOUNT_ID>\|<SECURITY_ACCOUNT_ID>" \
  --include="*.tf" --include="*.tfvars" --include="*.yml" --include="*.yaml" --include="*.md" --include="*.sh" -r .
```

Some placeholders (account IDs, org/OU IDs) can only be filled in **after** step 4 creates those accounts — do the bucket name, GitHub org/repo, and state bucket placeholders first, run step 4, then come back and fill in the rest.

> Note: <code>602401143452</code> appearing in <code>modules/eks-alb</code> and a few READMEs is **AWS's own** regional ECR account for EKS add-on images — not yours, leave it as-is.

## 4. Bootstrap the AWS Organization (one-time, manual)

```bash
cd environments/management
cp terraform.tfvars.example terraform.tfvars   # create this — see below
```

`terraform.tfvars` (gitignored, never commit):

```hcl
org_id                      = "<your-org-id-if-org-already-exists>"
workload_dev_account_name   = "dev"
workload_dev_account_email  = "aws-dev@yourdomain.com"     # must be globally unique
workload_prod_account_name  = "prod"
workload_prod_account_email = "aws-prod@yourdomain.com"    # must be globally unique
security_account_name       = "security"
security_account_email      = "aws-security@yourdomain.com" # must be globally unique
log_retention_days          = 90
approved_regions            = ["ap-southeast-2"]
```

```bash
terraform init
terraform apply
```

This creates the AWS Organization (or uses an existing one if <code>org_id</code> is set), OUs, the three member accounts, SCPs, Config, logging, and the org-wide IAM Access Analyzer.

```bash
# Now retrieve the IDs you need for step 3
aws organizations describe-organization --query 'Organization.{Id:Id,Master:MasterAccountId}'
aws organizations list-accounts --query 'Accounts[].{Name:Name,Id:Id,Email:Email}'
aws organizations list-organizational-units-for-parent --parent-id <ORG_ROOT_ID>
```

Go back to step 3 and fill in <code>&lt;MANAGEMENT_ACCOUNT_ID&gt;</code>, <code>&lt;DEV_ACCOUNT_ID&gt;</code>, <code>&lt;PROD_ACCOUNT_ID&gt;</code>, <code>&lt;SECURITY_ACCOUNT_ID&gt;</code>, <code>&lt;ORG_ID&gt;</code>, <code>&lt;WORKLOAD_OU_ID&gt;</code>, <code>&lt;SECURITY_OU_ID&gt;</code>.

## 5. Deploy GitHub Actions OIDC role

```bash
cd environments/management/github-oidc
terraform init
terraform apply
```

Outputs the role ARN — add it as the <code>AWS_ROLE_ARN</code> GitHub secret.

## 6. Configure GitHub repo

<table>
<tr><th>Setting</th><th>Value</th></tr>
<tr><td>Secrets (Settings → Secrets → Actions)</td><td>AWS_ROLE_ARN, SECURITY_ACCOUNT_ID, DEV_WORKLOAD_ACCOUNT_ID, PROD_WORKLOAD_ACCOUNT_ID, GIT_REPO_URL, POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD, PGADMIN_EMAIL, PGADMIN_PASSWORD — see RUNBOOK.md</td></tr>
<tr><td>Environments (Settings → Environments)</td><td>Create <code>shared</code>, <code>dev</code>, <code>prod</code> — add required reviewers for the approval gate</td></tr>
<tr><td>Self-hosted runner (Settings → Actions → Runners)</td><td>Register a runner with <code>aws-cli</code>, <code>kubectl</code>, <code>terraform 1.5.0</code> installed</td></tr>
</table>

## 7. Run the pipeline

Trigger workflow <strong>🚀 Pipeline (apply)</strong> with <code>action: apply</code>. All 9 components run as a single job graph, in order — approve each <code>environment</code> gate as it appears. Full details in <a href="RUNBOOK.md">RUNBOOK.md</a>.

## What you're getting

<table>
<tr><th>Component</th><th>Detail</th></tr>
<tr><td>AWS Organization</td><td>3 accounts (dev/prod/security), 2 OUs, 3 SCPs, org-wide IAM Access Analyzer, Config + CloudWatch logging</td></tr>
<tr><td>Networking</td><td>3 VPCs, cross-account peering, Transit Gateway hub-and-spoke, single shared NAT Gateway</td></tr>
<tr><td>EKS</td><td>Cluster + managed node group, EBS CSI + gp3 default storage class, AWS Load Balancer Controller</td></tr>
<tr><td>GitOps</td><td>ArgoCD App-of-Apps, example pgAdmin + postgres workload apps, metrics-server platform app</td></tr>
<tr><td>Autoscaling</td><td>Karpenter (spot + on-demand) running alongside the managed node group</td></tr>
<tr><td>FinOps</td><td>Kubecost free tier + bundled Prometheus for per-pod cost visibility</td></tr>
</table>

Estimated cost once fully deployed: roughly $150-200/month (region ap-southeast-2), dominated by the EKS control plane (~$73), Transit Gateway attachments (~$36 each), NAT Gateway (~$32), and ALB (~$16). See the cost table in <a href="README.md">README.md</a>.
