# GitOps Platform on Amazon EKS

On-demand EKS cluster (Terraform + GitHub Actions) running my portfolio app the GitOps way with ArgoCD,
fed by my DevSecOps Jenkins pipeline (Project 1), with monitoring, policy enforcement and a chaos test.

## Flow
git push (portfolio) -> Jenkins: Gitleaks, OWASP, SonarQube, Trivy -> ECR `portfolio:<build>`
-> Jenkins commits the tag to `gitops-manifests/envs/dev` -> ArgoCD syncs dev -> ALB serves it.
Prod = manual sync of `envs/prod`. Rollback = `git revert`.

## Repos
| Repo | Holds |
|---|---|
| `eks-gitops-platform` (this) | Terraform (state bucket, OIDC role, VPC, EKS Auto Mode, ArgoCD bootstrap), GitHub Actions |
| `gitops-manifests` | Helm chart, env values, ArgoCD apps (app-of-apps), monitoring, Kyverno |
| `portfolio` | App code + Jenkinsfile (Project 1) |

## Highlights
- **Terraform:** S3 remote state with native locking, VPC (private nodes, single NAT), EKS Auto Mode, access entries.
- **GitHub Actions + OIDC:** no AWS keys in GitHub; manual apply/destroy; plan + Infracost cost diff on every PR.
- **ArgoCD app-of-apps:** dev auto-sync + self-heal, prod manual sync, rollback by `git revert`.
- **Observability:** kube-prometheus-stack, Loki + Alloy, custom alert to Slack.
- **Kyverno (CEL ValidatingPolicy):** ECR-only images, no `:latest`, resource limits required.
- **Chaos test:** node kill caused a 7 min outage, then fixed to **0/179 failed requests**. See `docs/postmortem-chaos-test.md`.

## Layout
bootstrap/   state bucket + GitHub OIDC role (local state, survives destroy)
infra/       VPC, EKS, ArgoCD + root app (S3 state)
.github/workflows/  terraform-plan.yml, infracost.yml, cluster.yml (apply/destroy)
docs/        postmortem, probe logs, screenshots/
