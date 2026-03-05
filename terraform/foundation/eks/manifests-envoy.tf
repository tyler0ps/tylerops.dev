# ============================================================
# ENVOY GATEWAY MANIFESTS
#
# DESTROY ORDER (enforced by depends_on chain, reversed by Terraform):
#   1. kubectl_manifest.gateway     → deleted first (triggers NLB deletion via AWS LBC finalizer)
#   2. kubectl_manifest.gatewayclass
#   3. kubectl_manifest.envoyproxy
#   4. helm_release.envoy_gateway   → uninstalled after NLB is gone
#   5. helm_release.aws_lbc         → uninstalled last
# ============================================================

resource "kubectl_manifest" "envoyproxy" {
  yaml_body = file("${path.module}/../../../eks-bootstrap/envoy/envoyproxy.yaml")

  depends_on = [helm_release.envoy_gateway]
}

resource "kubectl_manifest" "gatewayclass" {
  yaml_body = file("${path.module}/../../../eks-bootstrap/envoy/gatewayclass.yaml")

  depends_on = [kubectl_manifest.envoyproxy]
}

# Gateway creates the NLB via AWS LBC. It carries a finalizer — during destroy,
# Terraform waits for this resource to be fully deleted (including NLB cleanup)
# before proceeding to uninstall the helm releases.
resource "kubectl_manifest" "gateway" {
  yaml_body = file("${path.module}/../../../eks-bootstrap/envoy/gateway.yaml")

  depends_on = [
    kubectl_manifest.gatewayclass,
    kubectl_manifest.certificate_tylerops_dev, # TLS secret must exist before Gateway references it
    helm_release.aws_lbc,                      # NLB provisioner must be running
  ]
}
