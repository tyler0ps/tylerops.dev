# ============================================================
# CERT-MANAGER — Helm Release
# ============================================================

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = local.chart_versions.cert_manager
  namespace        = "cert-manager"
  create_namespace = true
  wait             = true
  wait_for_jobs    = true # waits for startupapicheck job → ensures CRDs are established

  values = [file("${path.module}/../../../eks-bootstrap/cert-manager/values.yaml")]

  depends_on = [
    module.cert_manager_pod_identity,
    helm_release.aws_lbc,
  ]
}
