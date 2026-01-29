# ============================================================
# KARPENTER NODE CONFIGURATION
# ============================================================
# Defines HOW and WHEN Karpenter provisions nodes
#
# EC2NodeClass: Defines AWS-specific node configuration (AMI, subnets, SGs)
# NodePool: Defines node requirements, limits, and provisioning behavior

# ============================================================
# EC2 NODE CLASS
# ============================================================
# Specifies AWS EC2 configuration for Karpenter-managed nodes
resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: default
    spec:
      # AMI family - Amazon Linux 2023
      amiFamily: AL2023

      # IAM role for nodes (created by Karpenter module)
      # Extract role name from ARN (last part after /)
      role: ${module.karpenter.node_iam_role_name}

      # AMI selector - use latest EKS-optimized AMI for AL2023
      amiSelectorTerms:
        - alias: al2023@latest

      # Subnet discovery using tags
      # Karpenter will launch nodes in PRIVATE subnets only
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${local.cluster_name}
            kubernetes.io/role/internal-elb: "1"

      # Security group discovery using tags
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${local.cluster_name}

      # Additional tags for EC2 instances
      tags:
        Name: ${local.cluster_name}-karpenter-node
        Project: karpenter-experiment
        Environment: experiment
        ManagedBy: Karpenter
        CreatedBy: Karpenter
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}

# ============================================================
# NODE POOL
# ============================================================
# Defines node provisioning behavior, requirements, and limits
resource "kubectl_manifest" "karpenter_node_pool" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: default
    spec:
      # Template for nodes that Karpenter will create
      template:
        metadata:
          # Labels applied to all nodes in this pool
          labels:
            workload-type: general
            node-pool: default

        spec:
          # Reference to EC2NodeClass
          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: default

          # Node requirements and constraints
          requirements:
            # Architecture - amd64 for broad compatibility
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64"]

            # Operating system
            - key: kubernetes.io/os
              operator: In
              values: ["linux"]

            # Capacity type - prioritize Spot for cost savings
            - key: karpenter.sh/capacity-type
              operator: In
              values: ["spot", "on-demand"]

            # Instance categories - cost-optimized types
            - key: karpenter.k8s.aws/instance-category
              operator: In
              values: ["c", "m", "r"]

            # Instance generations - use newer for better performance
            - key: karpenter.k8s.aws/instance-generation
              operator: Gt
              values: ["4"]

            # Instance sizes - medium to xlarge for flexibility
            - key: karpenter.k8s.aws/instance-size
              operator: In
              values: ["medium", "large", "xlarge"]

      # Resource limits - prevents unlimited scaling
      limits:
        # Maximum total CPU across all nodes in this pool
        cpu: "100"
        # Maximum total memory across all nodes in this pool
        memory: "200Gi"

      # Disruption settings - how Karpenter consolidates nodes
      disruption:
        # Consolidation policy - remove underutilized nodes
        consolidationPolicy: WhenEmptyOrUnderutilized

        # How long to wait before consolidating (required field)
        # For experiments, 30s is good to see quick results
        consolidateAfter: 30s

        # Consolidation budget - limits disruption rate
        budgets:
          - nodes: "10%"  # Max 10% of nodes can be disrupted at once

      # Weight - priority when multiple NodePools exist
      # Higher weight = higher priority
      weight: 10
  YAML

  depends_on = [
    kubectl_manifest.karpenter_node_class
  ]
}
