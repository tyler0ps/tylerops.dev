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

  # Override hardcoded values with dynamic terraform outputs
  set = [
    {
      name  = "clusterName"
      value = local.cluster_name
    },
    {
      name  = "region"
      value = local.region
    },
    {
      name  = "vpcId"
      value = data.terraform_remote_state.networking.outputs.vpc_id
    },
  ]

  depends_on = [
    module.eks_karpenter,
    module.aws_lbc_pod_identity,
  ]
}
