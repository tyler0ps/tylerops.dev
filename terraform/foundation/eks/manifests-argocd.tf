# ============================================================
# ARGOCD MANIFESTS
# ============================================================

resource "kubectl_manifest" "httproute_argocd" {
  yaml_body = file("${path.module}/../../../eks-bootstrap/argo/httproute.yaml")

  depends_on = [
    helm_release.argocd,
    kubectl_manifest.gateway,
    helm_release.external_dns, # ensures external-dns is running when route exists (and destroyed after route is deleted)
  ]
}
