# ============================================================
# ARGOCD — Helm Release
# ============================================================

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = local.chart_versions.argocd
  namespace        = "argocd"
  create_namespace = true
  wait             = true

  values = [file("${path.module}/../../../eks-bootstrap/argo/values.yaml")]

  # Dex Authentik client secret — passed securely, not in values.yaml
  set_sensitive = [{
    name  = "configs.secret.extra.dex\\.authentik\\.clientSecret"
    value = var.argocd_dex_client_secret
  }]

  depends_on = [
    module.eks_karpenter,
    helm_release.cert_manager,
  ]
}

# Dex server init container races with argocd-secret population on first install.
# If init container runs before the secret key is available, it generates an empty
# dex config (issuer = ""). A rollout restart after Helm reports ready fixes this.
resource "null_resource" "argocd_dex_restart" {
  triggers = {
    release_id = helm_release.argocd.id
  }

  provisioner "local-exec" {
    command = "kubectl rollout restart deployment/argocd-dex-server -n argocd"
  }

  depends_on = [helm_release.argocd]
}
