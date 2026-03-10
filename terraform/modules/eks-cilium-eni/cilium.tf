# ============================================================
# CILIUM - eBPF Networking (replaces kube-proxy + vpc-cni)
# IPAM mode: ENI — Cilium manages ENIs directly via AWS API
# ============================================================

# ============================================================
# CILIUM HELM INSTALLATION
# Nodes join cluster tainted with node.cilium.io/agent-not-ready:NoExecute.
# Cilium DaemonSet tolerates this taint, schedules on nodes, sets up
# ENI networking, then removes the taint so other pods can schedule.
#
# nodeinit.enabled: true deploys a DaemonSet that removes aws-node
# and kube-proxy configuration from each node before Cilium starts,
# giving Cilium exclusive control of networking.
# ============================================================
resource "helm_release" "cilium" {
  name          = "cilium"
  repository    = "oci://quay.io/cilium/charts"
  chart         = "cilium"
  version       = var.cilium_version
  namespace     = "kube-system"
  wait          = false
  wait_for_jobs = false

  values = [
    <<-EOT
    cluster:
      name: ${var.cluster_name}
    ipam:
      mode: eni
    eni:
      enabled: true
      awsEnablePrefixDelegation: true
      subnetIDs: ${jsonencode(var.pod_subnet_ids)}
      securityGroups:
        - ${module.eks.node_security_group_id}
    kubeProxyReplacement: true
    k8sServiceHost: ${trimprefix(module.eks.cluster_endpoint, "https://")}
    k8sServicePort: 443
    routingMode: native
    # bpf:
    #   masquerade: true
    hubble:
      enabled: false
      relay:
        enabled: false
    # nodeinit removes aws-node and kube-proxy from each node before
    # Cilium agent starts. Required when those DaemonSets are already
    # running on nodes (EKS deploys them by default).
    nodeinit:
      enabled: false
    operator:
      replicas: 1
      tolerations:
        - key: "CriticalAddonsOnly"
          operator: "Exists"
          effect: "NoSchedule"
    EOT
  ]

  depends_on = [module.eks]
}
