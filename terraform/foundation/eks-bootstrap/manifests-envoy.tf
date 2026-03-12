# ============================================================
# ENVOY GATEWAY MANIFESTS
#
# EnvoyProxy: ClusterIP service (NLB managed by Terraform, not AWS LBC)
# Gateway: HTTP only (TLS terminates at NLB/ACM)
# TargetGroupBinding: registers Envoy Gateway pods into NLB target group
#
# DESTROY ORDER (reversed by Terraform):
#   1. kubectl_manifest.target_group_binding  → deregisters targets
#   2. kubectl_manifest.gateway
#   3. kubectl_manifest.gatewayclass
#   4. kubectl_manifest.envoyproxy
#   5. helm_release.envoy_gateway
#   6. helm_release.aws_lbc
# ============================================================

resource "kubectl_manifest" "envoyproxy" {
  yaml_body = file("${path.module}/../../../eks-bootstrap/envoy/envoyproxy.yaml")

  depends_on = [helm_release.envoy_gateway]
}

resource "kubectl_manifest" "gatewayclass" {
  yaml_body = file("${path.module}/../../../eks-bootstrap/envoy/gatewayclass.yaml")

  depends_on = [kubectl_manifest.envoyproxy]
}

resource "kubectl_manifest" "gateway" {
  yaml_body = file("${path.module}/../../../eks-bootstrap/envoy/gateway.yaml")

  depends_on = [
    kubectl_manifest.gatewayclass,
    helm_release.aws_lbc,
  ]
}

# TargetGroupBinding: registers Envoy Gateway pods as NLB targets.
# Service name follows Envoy Gateway's auto-generated pattern:
#   envoy-<namespace>-<gatewayname>
# Verify with: kubectl get svc -n envoy-gateway-system after first deploy.

# resource "kubectl_manifest" "target_group_binding" {
#   yaml_body = <<-YAML
#     apiVersion: elbv2.k8s.aws/v1beta1
#     kind: TargetGroupBinding
#     metadata:
#       name: envoy-gateway
#       namespace: envoy-gateway-system
#     spec:
#       serviceRef:
#         name: envoy-envoy-gateway-system-main-b3b376e9
#         port: 80
#       targetGroupARN: ${aws_lb_target_group.envoy.arn}
#   YAML

#   depends_on = [
#     kubectl_manifest.gateway,
#   ]
# }
