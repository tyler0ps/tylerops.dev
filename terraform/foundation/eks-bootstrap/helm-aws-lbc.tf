# ============================================================
# AWS LOAD BALANCER CONTROLLER — Helm Release
# ============================================================

resource "helm_release" "aws_lbc" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = local.chart_versions.aws_lbc
  namespace  = "kube-system"
  wait       = true

  values = [file("${path.module}/../../../eks-bootstrap/aws-lbc/values.yaml")]

  set = [
    {
      name  = "clusterName"
      value = local.cluster_name
    },
    {
      name  = "region"
      value = var.region
    },
    {
      name  = "vpcId"
      value = local.vpc_id
    },
  ]

  depends_on = [module.aws_lbc_pod_identity]
}
