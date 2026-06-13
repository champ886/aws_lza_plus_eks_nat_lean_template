# environments/dev/eks-argocd

Installs ArgoCD and bootstraps the **App of Apps** GitOps pattern. After this, all application deployment/changes happen via git pushes to <code>gitops/</code> — see <a href="../../../gitops/README.md">gitops/README.md</a>.

## What it creates

<table>
<tr><th>Resource</th><th>Detail</th></tr>
<tr><td>Namespaces</td><td><code>argocd</code>, <code>apps</code></td></tr>
<tr><td>helm_release "argocd"</td><td>chart 7.4.1, <code>dex.enabled=false</code>, <code>server.insecure=true</code>, <code>server.service.type=ClusterIP</code>, <code>wait=true timeout=600</code></td></tr>
<tr><td>time_sleep "wait_for_argocd_crds"</td><td>30s pause after Helm reports ready — CRDs need a moment to become queryable</td></tr>
<tr><td>kubernetes_secret "postgres"</td><td><code>postgres-secret</code> in <code>apps</code> — DB name/user/password from Terraform vars, never in git</td></tr>
<tr><td>kubernetes_secret "pgadmin"</td><td><code>pgadmin-secret</code> in <code>apps</code> — admin email/password</td></tr>
<tr><td>kubectl_manifest "root_app"</td><td>The <strong>only</strong> ArgoCD Application Terraform creates — points at <code>gitops/</code> directory, <code>directory.recurse: false</code>, auto-sync + self-heal + prune</td></tr>
</table>

## Why <code>kubectl_manifest</code>, not <code>kubernetes_manifest</code>

<code>kubernetes_manifest</code> validates the <code>Application</code> CRD **at plan time** — but ArgoCD (and its CRDs) don't exist until apply. <code>gavinbunney/kubectl</code>'s <code>kubectl_manifest</code> only validates at apply time, by which point the Helm release + <code>time_sleep</code> have completed.

## What this does NOT create (anymore)

Individual <code>postgres_app</code> / <code>pgadmin_app</code> Application resources were removed. They're now defined in <code>gitops/apps.yaml</code> and deployed by the <code>root</code> app automatically. **Adding a new workload app never requires a Terraform change** — edit <code>gitops/apps.yaml</code>, push to main.

## Variables

<table>
<tr><th>Variable</th><th>Source</th></tr>
<tr><td>workload_account_id</td><td>DEV_WORKLOAD_ACCOUNT_ID secret</td></tr>
<tr><td>git_repo_url</td><td>GIT_REPO_URL secret — must match the repo containing <code>gitops/</code></td></tr>
<tr><td>postgres_db / postgres_user / postgres_password</td><td>POSTGRES_DB / POSTGRES_USER / POSTGRES_PASSWORD secrets</td></tr>
<tr><td>pgadmin_email / pgadmin_password</td><td>PGADMIN_EMAIL / PGADMIN_PASSWORD secrets</td></tr>
</table>

## Dependencies

<table>
<tr><th>Remote state</th><th>For</th></tr>
<tr><td>dev/eks-cluster</td><td>endpoint, CA, token (providers)</td></tr>
</table>

Deployed by workflow 7️⃣ in **two stages** (see workflow for exact <code>-target</code> list): Stage 1 installs ArgoCD + namespaces + secrets; a 60s wait for CRDs; Stage 2 creates the root app. Triggered after ALB Controller (6️⃣). Triggers Karpenter (8️⃣).

## Standalone run

```bash
cd environments/dev/eks-argocd
terraform init

# Stage 1
terraform apply -auto-approve \
  -target=module.eks_argocd.kubernetes_namespace.argocd \
  -target=module.eks_argocd.kubernetes_namespace.apps \
  -target=module.eks_argocd.helm_release.argocd \
  -target=module.eks_argocd.kubernetes_secret.postgres \
  -target=module.eks_argocd.kubernetes_secret.pgadmin \
  -var="workload_account_id=<DEV_ACCOUNT_ID>" \
  -var="git_repo_url=https://github.com/<YOUR_GITHUB_ORG>/<YOUR_REPO_NAME>.git" \
  -var="postgres_db=..." -var="postgres_user=..." -var="postgres_password=..." \
  -var="pgadmin_email=..." -var="pgadmin_password=..."

sleep 60

# Stage 2 — same vars, no -target
terraform apply -auto-approve -var="workload_account_id=<DEV_ACCOUNT_ID>" ...
```

## Verify

```bash
kubectl get applications -n argocd
# root, pgadmin, postgres — all Synced/Healthy

kubectl get ingress -n apps
kubectl get pods -n apps
```

Access pgAdmin at the ALB hostname from <code>kubectl get ingress -n apps</code>. Connect to postgres inside pgAdmin using host <code>postgres</code> (K8s service DNS), port 5432, and the values from <code>postgres-secret</code>.

## Gotchas

<table>
<tr><th>Symptom</th><th>Fix</th></tr>
<tr><td><code>argocd-redis-secret-init</code> stuck ImagePullBackOff, Helm release fails pre-install timeout</td><td>NAT/TGW egress not working — ArgoCD pulls from <code>quay.io</code>. Fix TGW first, then <code>terraform destroy</code> + re-apply this environment</td></tr>
<tr><td>root app Synced/Healthy but pgadmin/postgres apps never appear</td><td><code>gitops/apps.yaml</code> and <code>gitops/platform.yaml</code> must live at the top level of <code>gitops/</code>, not inside <code>gitops/apps/</code> — root app's <code>directory.recurse: false</code> only scans the top level</td></tr>
<tr><td><code>update-kubeconfig</code> in GHA can't find <code>dev-eks-cluster</code></td><td>Explicitly <code>aws sts assume-role</code> into the workload account and export the returned credentials before calling <code>update-kubeconfig</code> — passing <code>--role-arn</code> alone isn't sufficient from the management-account GHA role</td></tr>
</table>
