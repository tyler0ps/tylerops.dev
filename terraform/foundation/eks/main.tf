# Lấy VPC và subnet IDs từ networking state
data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = "generic-gha-terraform-state"
    key    = "foundation/networking/terraform.tfstate"
    region = "ap-southeast-1"
  }
}

# Gắn EKS/Karpenter discovery tags vào private subnets
resource "aws_ec2_tag" "private_subnet_karpenter" {
  for_each    = toset(data.terraform_remote_state.networking.outputs.private_subnet_ids)
  resource_id = each.value
  key         = "karpenter.sh/discovery"
  value       = local.cluster_name
}

resource "aws_ec2_tag" "private_subnet_internal_elb" {
  for_each    = toset(data.terraform_remote_state.networking.outputs.private_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}

module "eks_karpenter" {
  source = "../../modules/eks-karpenter"

  cluster_name       = local.cluster_name
  cluster_version    = local.cluster_version
  region             = local.region
  vpc_id             = data.terraform_remote_state.networking.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.networking.outputs.private_subnet_ids
  karpenter_version  = local.karpenter_version
  tags               = local.tags

  depends_on = [
    aws_ec2_tag.private_subnet_karpenter,
    aws_ec2_tag.private_subnet_internal_elb,
  ]
}
