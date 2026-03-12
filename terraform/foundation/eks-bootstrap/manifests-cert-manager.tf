# ============================================================
# CERT-MANAGER MANIFESTS
# ClusterIssuer and Certificate are CRD-backed — use kubectl provider.
# wait_for_jobs=true on helm_release ensures CRDs are established
# before these resources are created.
# ============================================================

resource "kubectl_manifest" "clusterissuer_letsencrypt_prod" {
  yaml_body = file("${path.module}/../../../eks-bootstrap/cert-manager/clusterissuer.yaml")

  depends_on = [helm_release.cert_manager]
}

# Certificate lives in envoy-gateway-system namespace — depends on that
# namespace being created by the Envoy Gateway helm release.
resource "kubectl_manifest" "certificate_tylerops_dev" {
  yaml_body = file("${path.module}/../../../eks-bootstrap/cert-manager/certificate.yaml")

  depends_on = [
    kubectl_manifest.clusterissuer_letsencrypt_prod,
    helm_release.envoy_gateway, # ensures envoy-gateway-system namespace exists
  ]
}
