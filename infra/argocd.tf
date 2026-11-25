# ---------- Helm provider talks to the EKS cluster ----------
provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.region]
    }
  }
}

# ---------- ArgoCD itself ----------
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "10.20.0"
  namespace        = "argocd"
  create_namespace = true
  wait             = true
  timeout          = 900

  values = [yamlencode({
    configs = { params = { "server.insecure" = true } } # TLS not needed behind port-forward
    dex     = { enabled = false }                       # no SSO in this lab
  })]
}

# ---------- Root app (app-of-apps): watches apps/ in the GitOps repo ----------
resource "helm_release" "argocd_root" {
  name       = "argocd-root"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = "2.0.10"
  namespace  = "argocd"

  values = [yamlencode({
    applications = {
      root = {
        namespace = "argocd"
        project   = "default"
        source = {
          repoURL        = "https://github.com/NamanChaturvedii/gitops-manifests.git"
          targetRevision = "main"
          path           = "apps"
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = "argocd"
        }
        syncPolicy = { automated = { prune = true, selfHeal = true } }
      }
    }
  })]

  depends_on = [helm_release.argocd]
}
