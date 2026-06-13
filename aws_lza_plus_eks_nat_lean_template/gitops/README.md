# gitops/

ArgoCD-managed manifests, following the **App of Apps** pattern. Terraform (<code>environments/dev/eks-argocd</code>) creates exactly one ArgoCD <code>Application</code> — <code>root</code> — pointed at this directory. Everything below is deployed and kept in sync by ArgoCD itself, not Terraform.

## How it works

```
root app (created by Terraform)
  source.path: gitops
  source.directory.recurse: false   ← scans top-level .yaml files only
        │
        ├── apps.yaml       → creates child Applications: pgadmin, postgres
        └── platform.yaml   → creates child Application: metrics-server
                │
                each child Application points at its own
                gitops/apps/<name>/ subfolder for the actual manifests
```

## Structure

```
gitops/
├── apps.yaml        Workload app definitions (pgadmin, postgres)
├── platform.yaml    Platform tool definitions (metrics-server)
├── root-app.yaml    Reference copy of the root Application spec
│                    (the live one is created by Terraform, kept here for docs)
└── apps/
    ├── pgadmin/
    │   ├── deployment.yaml
    │   ├── service.yaml
    │   ├── ingress.yaml          ← creates the ALB
    │   └── pgadmin-servers.yaml  ← pre-registers the postgres connection
    └── postgres/
        ├── deployment.yaml
        ├── service.yaml
        └── pvc.yaml               ← no storageClassName, binds to default gp3
```

## Adding a new workload app

1. Create <code>gitops/apps/&lt;name&gt;/</code> with your manifests.
2. Append an <code>Application</code> block to <code>apps.yaml</code>:

```yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: <name>
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/<YOUR_GITHUB_ORG>/<YOUR_REPO_NAME>.git
    targetRevision: main
    path: gitops/apps/<name>
  destination:
    server: https://kubernetes.default.svc
    namespace: apps
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

3. <code>git push</code> to <code>main</code>. ArgoCD polls every ~3 minutes (or force with <code>kubectl patch application root -n argocd --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'</code>).

**No Terraform change required.**

## Adding a new platform tool

Same as above but append to <code>platform.yaml</code> instead, and typically target <code>kube-system</code> or a dedicated namespace rather than <code>apps</code>. Use this for pure-Kubernetes tools with **no AWS IAM dependency** — cert-manager, external-secrets, ingress configs, network policies, HPAs.

<table>
<tr><th>Belongs in platform.yaml</th><th>Belongs in Terraform instead</th></tr>
<tr><td>cert-manager, external-secrets, metrics-server, network policies, HPA configs</td><td>Karpenter, Kubecost, ALB Controller, EBS CSI — anything needing an IRSA role</td></tr>
</table>

## Secrets

<code>postgres-secret</code> and <code>pgadmin-secret</code> are created by Terraform (<code>environments/dev/eks-argocd</code>), **not** stored in this directory. The <code>postgres</code> and <code>pgadmin</code> deployments reference them via <code>envFrom.secretRef</code> — never commit credentials here.

## Verify

```bash
kubectl get applications -n argocd
# root, pgadmin, postgres, metrics-server — all Synced/Healthy

kubectl get ingress -n apps
kubectl get pvc -n apps
```

## Gotcha

<code>apps.yaml</code> and <code>platform.yaml</code> **must** live at the top level of <code>gitops/</code>, not inside <code>gitops/apps/</code>. The root app's <code>directory.recurse: false</code> only scans the path it's given (<code>gitops</code>) — files one level deeper are invisible to it.
