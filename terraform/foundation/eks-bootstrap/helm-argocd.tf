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
    value = data.aws_ssm_parameter.argocd_dex_client_secret.value
  }]
}
