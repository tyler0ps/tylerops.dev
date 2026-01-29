# ============================================================
# OUTPUTS - Cluster Information and Verification Commands
# ============================================================

# ============================================================
# CLUSTER INFORMATION
# ============================================================
output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "Kubernetes version"
  value       = module.eks.cluster_version
}

output "region" {
  description = "AWS region"
  value       = local.region
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data for cluster authentication"
  value       = module.eks.cluster_certificate_authority_data
}

# ============================================================
# KARPENTER INFORMATION
# ============================================================
output "karpenter_irsa_arn" {
  description = "ARN of IAM role for Karpenter controller"
  value       = module.karpenter.iam_role_arn
}

output "karpenter_node_iam_role_name" {
  description = "Name of IAM role for Karpenter-managed nodes"
  value       = module.karpenter.node_iam_role_name
}

output "karpenter_queue_name" {
  description = "Name of SQS queue for Karpenter spot termination handling"
  value       = module.karpenter.queue_name
}

# ============================================================
# KUBECONFIG COMMAND
# ============================================================
output "configure_kubectl" {
  description = "Command to configure kubectl for this cluster"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${local.region}"
}

# ============================================================
# VERIFICATION COMMANDS
# ============================================================
output "verification_commands" {
  description = "Commands to verify the Karpenter installation"
  value       = <<-EOT

    ============================================================
    KARPENTER EXPERIMENT - CLUSTER READY
    ============================================================

    Cluster: ${module.eks.cluster_name}
    Region: ${local.region}
    Version: ${local.cluster_version}

    ============================================================
    STEP 1: Configure kubectl
    ============================================================
    aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${local.region}

    ============================================================
    STEP 2: Verify cluster access
    ============================================================
    kubectl cluster-info
    kubectl get nodes

    ============================================================
    STEP 3: Check Karpenter installation
    ============================================================
    # Check Karpenter pods
    kubectl get pods -n kube-system -l app.kubernetes.io/name=karpenter

    # View Karpenter logs
    kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter --tail=50

    # Check Karpenter CRDs
    kubectl get crd | grep karpenter

    ============================================================
    STEP 4: Verify Karpenter resources
    ============================================================
    # Check NodePools
    kubectl get nodepools

    # Check EC2NodeClasses
    kubectl get ec2nodeclasses

    # Describe the default NodePool
    kubectl describe nodepool default

    ============================================================
    STEP 5: Test autoscaling
    ============================================================
    # Check the test deployment
    kubectl get deployment -n test nginx-test
    kubectl get pods -n test -o wide

    # Scale up to trigger Karpenter
    kubectl scale deployment nginx-test -n test --replicas=5

    # Watch Karpenter provision nodes (in a separate terminal)
    kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter -f

    # Watch nodes being created
    kubectl get nodes --watch

    # Scale down to trigger consolidation
    kubectl scale deployment nginx-test -n test --replicas=1

    ============================================================
    STEP 6: Experiment with Karpenter
    ============================================================
    # View Karpenter events
    kubectl get events -n kube-system --field-selector source=karpenter

    # Check node labels (Karpenter adds labels to provisioned nodes)
    kubectl get nodes --show-labels

    # View node capacity and allocatable resources
    kubectl describe nodes

    ============================================================
    COST ESTIMATE
    ============================================================
    - EKS Control Plane: $73/month
    - Initial nodes (2x m5.large spot): ~$20-25/month
    - Karpenter-managed nodes: Variable (based on workload)
    - NAT Gateway: ~$32/month
    - Total baseline: ~$125-130/month

    ============================================================
    CLEANUP
    ============================================================
    # When done experimenting, destroy all resources:
    cd terraform/karpenter-experiment
    terraform destroy

  EOT
}

# ============================================================
# QUICK ACCESS OUTPUTS
# ============================================================
output "quick_start" {
  description = "Quick commands to get started"
  value       = <<-EOT
    # Configure kubectl
    ${module.eks.cluster_name != "" ? "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${local.region}" : ""}

    # View Karpenter logs
    kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter -f

    # Check nodes
    kubectl get nodes -L karpenter.sh/nodepool,node.kubernetes.io/instance-type,karpenter.sh/capacity-type
  EOT
}
