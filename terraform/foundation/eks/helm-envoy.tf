# ============================================================
# ENVOY GATEWAY — Helm Release (OCI chart)
# ============================================================

resource "helm_release" "envoy_gateway" {
  name             = "envoy-gateway"
  chart            = "oci://docker.io/envoyproxy/gateway-helm"
  version          = local.chart_versions.envoy
  namespace        = "envoy-gateway-system"
  create_namespace = true
  wait             = true

  values = [file("${path.module}/../../../eks-bootstrap/envoy/values.yaml")]

  depends_on = [
    module.eks_karpenter,
    helm_release.aws_lbc, # AWS LBC must be running before Gateway triggers NLB provisioning
  ]
}
