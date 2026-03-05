# ============================================================
# CERT-MANAGER — Helm Release
# ============================================================

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = local.chart_versions.cert_manager
  namespace        = local.cert_manager_namespace
  create_namespace = true
  wait             = true
  wait_for_jobs    = true # waits for startupapicheck job → ensures CRDs are established

  values = [file("${path.module}/../../../eks-bootstrap/cert-manager/values.yaml")]

  # Override hardcoded ARN in values.yaml with dynamic terraform value
  set = [{
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.cert_manager.arn
  }]

  depends_on = [
    module.eks_karpenter,
    helm_release.aws_lbc, # AWS LBC webhook (mservice.elbv2.k8s.aws) must be ready before cert-manager installs
  ]
}
