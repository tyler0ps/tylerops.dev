# ============================================================
# EXTERNAL-DNS — Helm Release
# ============================================================

resource "helm_release" "external_dns" {
  name             = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns"
  chart            = "external-dns"
  version          = local.chart_versions.external_dns
  namespace        = local.external_dns_namespace
  create_namespace = true
  wait             = true

  values = [file("${path.module}/../../../eks-bootstrap/external-dns/values.yaml")]

  set = [{
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.external_dns.arn
  }]
}
