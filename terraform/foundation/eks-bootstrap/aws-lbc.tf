# ============================================================
# AWS LOAD BALANCER CONTROLLER — Pod Identity
# ============================================================

module "aws_lbc_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 1.6"

  name                            = "${local.cluster_name}-aws-lbc"
  attach_aws_lb_controller_policy = true

  associations = {
    aws-lbc = {
      cluster_name    = local.cluster_name
      namespace       = "kube-system"
      service_account = "aws-load-balancer-controller"
    }
  }

  tags = local.tags
}
