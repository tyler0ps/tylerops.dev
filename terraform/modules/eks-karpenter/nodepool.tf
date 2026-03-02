# ============================================================
# KARPENTER NODE CONFIGURATION
# ============================================================

resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: default
    spec:
      amiFamily: Bottlerocket

      role: ${module.karpenter.node_iam_role_name}

      amiSelectorTerms:
        - alias: bottlerocket@latest

      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${var.cluster_name}
            kubernetes.io/role/internal-elb: "1"

      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${var.cluster_name}

      tags:
        Name: ${var.cluster_name}-karpenter-node
        ManagedBy: Karpenter
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}

resource "kubectl_manifest" "karpenter_node_pool" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: default
    spec:
      template:
        metadata:
          labels:
            workload-type: general
            node-pool: default

        spec:
          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: default

          requirements:
            - key: kubernetes.io/arch
              operator: In
              values: ["arm64"]

            - key: kubernetes.io/os
              operator: In
              values: ["linux"]

            - key: karpenter.sh/capacity-type
              operator: In
              values: ["spot"]

            - key: karpenter.k8s.aws/instance-family
              operator: In
              values: ["m6g", "c6g", "r6g", "m7g", "c7g", "r7g", "t4g"]

            - key: karpenter.k8s.aws/instance-size
              operator: In
              values: ["small", "medium", "large", "xlarge"]

      limits:
        cpu: "100"
        memory: "200Gi"

      disruption:
        consolidationPolicy: WhenEmptyOrUnderutilized
        consolidateAfter: 30s
        budgets:
          - nodes: "10%"

      weight: 10
  YAML

  depends_on = [
    kubectl_manifest.karpenter_node_class
  ]
}
