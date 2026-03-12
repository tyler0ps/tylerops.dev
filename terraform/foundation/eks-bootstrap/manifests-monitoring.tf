# ============================================================
# MONITORING MANIFESTS
# Bootstraps the App-of-Apps root Application.
# ArgoCD then discovers and manages all child apps from:
#   eks-bootstrap/monitoring/apps/ (in git)
# ============================================================

resource "kubectl_manifest" "argocd_app_monitoring_root" {
  yaml_body = file("${path.module}/../../../eks-bootstrap/monitoring/root-app.yaml")

  depends_on = [
    helm_release.argocd,
    kubernetes_namespace_v1.monitoring,
    kubernetes_secret_v1.grafana_oauth,
    aws_iam_role_policy_attachment.loki_s3,
    aws_s3_bucket.loki,
  ]
}

resource "kubectl_manifest" "httproute_grafana" {
  yaml_body = file("${path.module}/../../../eks-bootstrap/monitoring/httproute-grafana.yaml")

  depends_on = [
    kubectl_manifest.argocd_app_monitoring_root,
    kubectl_manifest.gateway,
    helm_release.external_dns,
  ]
}
