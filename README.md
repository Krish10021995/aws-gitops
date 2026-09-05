# aws-gitops

Infrastructure as Code for a GitOps Kubernetes platform: **Terraform + Amazon EKS + Argo CD + GitHub Actions + Prometheus/Grafana**.

This repo is a self-contained demonstration of a modern cloud-native application pipeline:

- **Infrastructure** — Terraform modules for VPC, EKS (managed node groups, IRSA, OIDC), ECR, RDS/Postgres, and addons (Argo CD, external-secrets, kube-prometheus-stack, AWS Load Balancer Controller).
- **Applications** — three small demo services (`api`, `worker`, `web`) with Dockerfiles, health checks, probes, autoscaling and ingress.
- **GitOps** — Argo CD `Application`s that declare the desired state in git; the cluster constantly converges toward `main`.
- **CI/CD** — one GitHub Actions workflow per concern: CI (terraform validate, kustomize + kubeconform, pytest, Docker build + container smoke tests), CD for apps (build → push to GHCR → commit tag bump → Argo CD deploys), CD for infra (terraform plan/apply via OIDC — enabled when AWS secrets exist).

```
                    ┌──────────────────────────────────────────────────────┐
                    │                     GitHub Actions                    │
                    │  CI: tf validate · kubeconform · pytest · docker     │
                    │  CD apps : build → GHCR → commit image tag !         │
                    └───────────────┬──────────────┬───────────────────────┘
                                    │ git push     │ poll: repo == cluster
                                    ▼              ▼
                      ┌───────────────────────────────┐
                      │          Argo CD              │
                      │  App of Apps → projects +    │
                      │  Applications per service    │
                      └──────────────┬───────────────┘
                                     ▼ sync
                      ┌───────────────────────────────┐
                      │             EKS              │
                      │  api ──┐                     │
                      │  worker┤──> RDS Postgres     │
                      │  web ──┤   (external-secrets)│
                      │  HPA · ALB Ingress · Nginx   │
                      └───────────────────────────────┘
```

## Repo layout

```
.
├── apps/
│   ├── api/                 FastAPI + PostgreSQL (CRUD demo API)
│   ├── worker/              Python worker draining "pending" rows
│   └── web/                 nginx: static UI + reverse proxy to api
├── gitops/
│   ├── argocd/              AppProject, App-of-Apps, per-service Applications
│   └── apps/                kustomize overlays for api / worker / web
│   └── app-infra/           SecretStore + ExternalSecret (AWS Secrets Manager)
├── terraform/
│   ├── modules/
│   │   ├── vpc/             VPC, public/private subnets, NAT, routing
│   │   ├── eks/             EKS cluster, node groups, OIDC, IRSA roles, Secret
│   │   ├── ecr/             ECR repositories + lifecycle policy
│   │   ├── rds/             Postgres 15, private subnets, from-app SG rule
│   │   └── eks-addons/      Helm releases: ArgoCD, external-secrets, etc.
│   └── envs/dev/            environment wiring (local state by default)
├── .github/workflows/
│   ├── ci.yml               PR + main: everything above, zero credentials
│   ├── cd-app.yml           merge → build/push → bump tags → ArgoCD deploys
│   └── cd-infra.yml         merge → terraform plan/apply (needs AWS secrets)
└── docs/
    └── terraform-state.md   how to switch from local to S3 state
```

## What runs without any cloud account

Everything except an actual `terraform apply` / cluster provisioning:

```bash
make tf-fmt          # terraform fmt -recursive -check
make tf-validate     # terraform init -backend=false && terraform validate
make gitops-check    # kustomize build every overlay
make apps-lint       # ruff across api + worker
make apps-test       # pytest across api + worker
make ci              # all of the above
```

This is exactly what `ci.yml` checks on every pull request.

## Deploying the apps (fastest demo — nothing to install locally)

The CD pipeline already runs on `main` and needs no AWS at all:

1. Push any change under `apps/` or `gitops/`.
2. `cd-app.yml` builds the three Docker images and pushes them to **GHCR** (`ghcr.io/krish10021995/aws-gitops-<svc>`), then commits the new image tags back to `gitops/`.
3. Argo CD (once connected to a cluster) sees the git diff and rolls the apps out.

The manifests are day-1 deployable: probes match the container health endpoints, HPAs scale on CPU, the web Ingress uses the AWS ALB controller.

## Provisioning the AWS platform

### Prerequisites

- AWS CLI + credentials (or a GitHub OIDC role), Terraform `>= 1.5`.
- `TF_VAR_db_password` (never put the DB password in a file).

### 1. Choose state backend

Keep **local** state for a sandbox, or follow `docs/terraform-state.md` to switch to an S3-backed state + DynamoDB lock (recommended before running infra CD).

### 2. Init + plan

```bash
cd terraform/envs/dev
terraform init                          # local backend by default
$env:TF_VAR_db_password = "<your-pass>" # PowerShell / or use shell env
terraform plan -out=tfplan
```

### 3. Apply

```bash
terraform apply tfplan
```

This provisions (region: `eu-west-1` by default, override in `terraform.tfvars`):

| Component            | Detail                                              |
| -------------------- | --------------------------------------------------- |
| VPC                  | 2 public + 2 private subnets, NAT, route tables     |
| EKS                  | cluster `gitops-demo` v1.31, t3.medium nodes ×1–3   |
| OIDC + IRSA          | roles for ArgoCD, ALB controller, external-secrets  |
| ECR                  | `api-dev`, `worker-dev`, `web-dev` + lifecycle rule |
| RDS Postgres 15      | `db.t4g.micro`, encrypted, private subnets          |
| Secrets Manager      | `demoapp/db` with placeholders to update            |
| Helm installs        | ArgoCD, external-secrets, kube-prometheus-stack     |

> `demoapp/db` in Secrets Manager is seeded with placeholder values. Point it at the real RDS endpoint (`outputs`) before the apps are expected to store data:
> ```bash
> aws secretsmanager put-secret-value --secret-id demoapp/db \
>   --secret-string '{"db_host":"<rds-endpoint>","db_name":"demoapp","db_username":"demoapp","db_password":"<pass>"}'
> ```

### 4. Connect Argo CD and bootstrap

```bash
kubectl apply -k gitops/apps            # namespace + demo apps (fallback, not ArgoCD)
kubectl apply -f gitops/argocd/app-of-apps.yaml   # App of Apps bootstrap
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

Open http://localhost:8080 (admin / the password above), and you'll see `app-infra`, `api`, `worker`, `web` all **Synced/Healthy**, managed purely from git.

App URLs (once the ALB is up):

```bash
kubectl -n demo get ingress web -o jsonpath="{.status.loadBalancer.ingress[0].hostname}"
```

### 5. Enable infra CD (optional, when AWS secrets exist)

Add repo secrets:

| Secret                | Value                          |
| --------------------- | ------------------------------ |
| `AWS_ROLE_TO_ASSUME`  | OIDC deploy role ARN           |
| `AWS_REGION`          | `eu-west-1`                    |

From then on, terraform changes merged to `main` run `plan` (and `apply` on the merge commit) with the corresponding GitHub OIDC role.

## Daily workflow demo (what a reviewer can watch)

1. Edit an app, open a PR → CI: `terraform fmt/validate`, `kustomize build` + `kubeconform`, `pytest`, Docker build + live container smoke tests.
2. Merge → `cd-app.yml` builds images, pushes to GHCR, bumps the kustomize tag in git.
3. Argo CD observes the commit and rolls the new image into EKS (nice animation on the UI from the current commit SHA).

## Cost notes (dev sandbox)

Rough, `eu-west-1`, ~24/7: NAT gateway ~$32/mo, EKS control plane ~$73/mo, (1 × t3.medium) ~$29/mo, RDS `db.t4g.micro` ~$13/mo, plus a few cents for ECR/Secrets. Total ≈ **$150/mo**. Destroy when done:

```bash
terraform destroy
```

## Switching the registry to ECR (optional)

1. Set `aws-actions/configure-aws-credentials` + `aws ecr get-login-password` in `cd-app.yml`.
2. Change `IMG_BASE` to `${{ secrets.AWS_REGION }}-...dkr.ecr.../aws-gitops`.
3. The same `kustomize edit set image` mechanism applies — Argo CD behaves identically.

---

Built by [Krishnendu Pramanik](https://github.com/krish10021995). Part of a 7-repo portfolio covering MLOps + DevOps: `mlops-pipeline`, `aws-gitops`, `docqa-rag`, `codechat-rag`, `multisource-agent`, `llm-finetune`.