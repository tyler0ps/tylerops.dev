data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = "generic-gha-terraform-state"
    key    = "foundation/networking/terraform.tfstate"
    region = "ap-southeast-1"
  }
}

resource "aws_ec2_tag" "private_subnet_internal_elb" {
  for_each    = toset(data.terraform_remote_state.networking.outputs.private_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}

resource "aws_ec2_tag" "public_subnet_elb" {
  for_each    = toset(data.terraform_remote_state.networking.outputs.public_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

resource "aws_ec2_tag" "private_subnet_karpenter" {
  for_each    = toset(data.terraform_remote_state.networking.outputs.private_subnet_ids)
  resource_id = each.value
  key         = "karpenter.sh/discovery"
  value       = local.cluster_name
}

module "eks_cilium" {
  source = "../../modules/eks-cilium-eni"

  cluster_name       = local.cluster_name
  cluster_version    = local.cluster_version
  region             = local.region
  vpc_id             = data.terraform_remote_state.networking.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.networking.outputs.private_subnet_ids
  # pod_subnet_ids_by_az is map(string) — convert to list for Cilium ENI mode
  pod_subnet_ids    = values(data.terraform_remote_state.networking.outputs.pod_subnet_ids_by_az)
  cilium_version    = local.cilium_version
  karpenter_version = local.karpenter_version
  tags              = local.tags
}
