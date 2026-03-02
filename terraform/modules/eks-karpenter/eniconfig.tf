# ============================================================
# ENIConfig - VPC CNI Custom Networking
# Maps each AZ → pod subnet (secondary CIDR 100.64.0.0/16)
# Pods get IPs from /19 subnet instead of node's /24 subnet
# ============================================================
resource "kubectl_manifest" "eniconfig" {
  for_each = var.pod_subnet_ids_by_az

  yaml_body = <<-YAML
    apiVersion: crd.k8s.amazonaws.com/v1alpha1
    kind: ENIConfig
    metadata:
      name: ${each.key}
    spec:
      subnet: ${each.value}
      securityGroups:
        - ${module.eks.node_security_group_id}
  YAML

  depends_on = [module.eks]
}
