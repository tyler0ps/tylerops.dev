---
title: "EKS + Karpenter: Kubernetes Autoscaling Done Right"
date: 2025-01-29
description: Learn how to set up Amazon EKS with Karpenter for efficient, cost-optimized Kubernetes autoscaling using Terraform.
---

# EKS + Karpenter: Kubernetes Autoscaling Done Right

If you've ever been frustrated waiting for the Kubernetes Cluster Autoscaler to spin up nodes, or seen your cloud bill spike due to overprovisioned instances, Karpenter might be exactly what you need.

In this guide, I'll walk you through setting up Amazon EKS with Karpenter using Terraform - a setup I use for cost-optimized, fast autoscaling.

## What is Karpenter?

[Karpenter](https://karpenter.sh/) is an open-source Kubernetes cluster autoscaler built by AWS. Unlike the traditional Cluster Autoscaler that works with predefined node groups, Karpenter:

- **Provisions nodes in seconds**, not minutes
- **Selects optimal instance types** based on pod requirements
- **Consolidates underutilized nodes** automatically
- **Handles Spot interruptions** gracefully

### Karpenter vs Cluster Autoscaler

| Feature | Cluster Autoscaler | Karpenter |
|---------|-------------------|-----------|
| Provisioning speed | 3-5 minutes | 30-60 seconds |
| Instance selection | Fixed node groups | Dynamic, per-pod |
| Consolidation | Manual/limited | Automatic |
| Spot handling | Basic | Native SQS integration |
| Configuration | Node group focused | Pod-centric |

## Architecture Overview

Here's what we're building:

```
┌─────────────────────────────────────────────────────────────┐
│                     VPC (10.2.0.0/16)                       │
│  ┌─────────────────────┐    ┌─────────────────────┐        │
│  │   Public Subnets    │    │   Private Subnets   │        │
│  │  10.2.101.0/24 (a)  │    │  10.2.1.0/24 (a)    │        │
│  │  10.2.102.0/24 (b)  │    │  10.2.2.0/24 (b)    │        │
│  └─────────────────────┘    └─────────────────────┘        │
│           │                          │                      │
│      NAT Gateway              EKS Cluster (1.34)           │
│                                      │                      │
│                    ┌─────────────────┴──────────────────┐  │
│                    │                                     │  │
│          ┌─────────┴─────────┐    ┌─────────────────┐   │  │
│          │  Managed Nodes    │    │ Karpenter Nodes │   │  │
│          │  (Controller)     │    │  (Workloads)    │   │  │
│          │  m5.large Spot    │    │  Dynamic Spot   │   │  │
│          └───────────────────┘    └─────────────────┘   │  │
│                                                          │  │
└─────────────────────────────────────────────────────────────┘
```

**Key components:**
- **VPC** with public/private subnets across 2 AZs
- **EKS Cluster** (Kubernetes 1.34) with IRSA enabled
- **Managed Node Group** for Karpenter controller (1-3 Spot instances)
- **Karpenter** (v1.8.5) managing workload nodes dynamically

## Prerequisites

Before you begin, ensure you have:

```bash
# AWS CLI configured
aws sts get-caller-identity

# Terraform >= 1.0
terraform version

# kubectl
kubectl version --client
```

You'll also need AWS permissions to create VPC, EKS, IAM, EC2, and SQS resources.

## Infrastructure Setup

### Project Structure

```
karpenter-experiment/
├── backend.tf        # S3 state configuration
├── providers.tf      # AWS, Kubernetes, Helm providers
├── locals.tf         # Variables (cluster name, region, CIDRs)
├── main.tf           # VPC and EKS cluster
├── karpenter.tf      # Karpenter IAM and Helm installation
├── nodepool.tf       # NodePool and EC2NodeClass
├── test-deployment.tf # Test workload
└── outputs.tf        # Useful commands
```

### Core Configuration

The setup uses Terraform AWS modules for VPC and EKS:

```hcl
# locals.tf
locals {
  cluster_name    = "karpenter-experiment"
  cluster_version = "1.34"
  region          = "ap-southeast-1"

  vpc_cidr             = "10.2.0.0/16"
  private_subnet_cidrs = ["10.2.1.0/24", "10.2.2.0/24"]
  public_subnet_cidrs  = ["10.2.101.0/24", "10.2.102.0/24"]

  karpenter_version = "1.8.5"
}
```

### VPC with Karpenter Discovery Tags

Karpenter discovers subnets and security groups using tags. This is crucial:

```hcl
# Subnet tags for Karpenter discovery
private_subnet_tags = {
  "kubernetes.io/role/internal-elb"             = 1
  "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  "karpenter.sh/discovery"                      = local.cluster_name
}
```

### EKS Cluster with Minimal Node Group

We use a small managed node group just for the Karpenter controller:

```hcl
eks_managed_node_groups = {
  karpenter = {
    instance_types = ["m5.large"]
    capacity_type  = "SPOT"  # Cost savings

    min_size     = 1
    max_size     = 3
    desired_size = 1

    labels = {
      role                      = "karpenter-controller"
      "karpenter.sh/controller" = "true"
    }
  }
}
```

## Karpenter Configuration

### EC2NodeClass - AWS-specific Settings

The EC2NodeClass defines how Karpenter provisions EC2 instances:

```yaml
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  # Amazon Linux 2023 - latest EKS-optimized AMI
  amiFamily: AL2023
  amiSelectorTerms:
    - alias: al2023@latest

  # IAM role for nodes
  role: karpenter-node-role

  # Discover subnets by tags (private only)
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: karpenter-experiment
        kubernetes.io/role/internal-elb: "1"

  # Discover security groups by tags
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: karpenter-experiment
```

### NodePool - Provisioning Rules

The NodePool defines what types of nodes Karpenter can provision:

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    spec:
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default

      requirements:
        # Architecture
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]

        # Prefer Spot, fallback to on-demand
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]

        # Instance families: Compute, Memory, General
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["c", "m", "r"]

        # Newer generations only (5+)
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["4"]

        # Size range
        - key: karpenter.k8s.aws/instance-size
          operator: In
          values: ["medium", "large", "xlarge"]

  # Prevent unlimited scaling
  limits:
    cpu: "100"
    memory: "200Gi"

  # Auto-consolidation settings
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 30s
    budgets:
      - nodes: "10%"  # Max 10% disruption at once
```

## Deployment

```bash
# Initialize and deploy
terraform init
terraform apply

# Configure kubectl
aws eks update-kubeconfig --name karpenter-experiment --region ap-southeast-1

# Verify Karpenter is running
kubectl get pods -n kube-system -l app.kubernetes.io/name=karpenter
```

## Testing Autoscaling

### Scale Up

Watch Karpenter provision new nodes:

```bash
# Terminal 1: Watch Karpenter logs
kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter -f

# Terminal 2: Scale up the test deployment
kubectl scale deployment nginx-test -n test --replicas=5

# Terminal 3: Watch new nodes appear
kubectl get nodes --watch
```

You should see Karpenter:
1. Detect pending pods
2. Calculate optimal instance type
3. Launch EC2 instance (within 30-60 seconds)
4. Node joins cluster
5. Pods get scheduled

### Consolidation

Watch Karpenter remove underutilized nodes:

```bash
# Scale down
kubectl scale deployment nginx-test -n test --replicas=1

# Watch consolidation (after 30s)
kubectl get nodes --watch
```

## Cost Optimization Tips

### 1. Use Spot Instances (50-70% savings)

Already configured in our NodePool with `capacity-type: ["spot", "on-demand"]`. Karpenter prefers Spot and falls back to on-demand.

### 2. Enable Consolidation

```yaml
disruption:
  consolidationPolicy: WhenEmptyOrUnderutilized
  consolidateAfter: 30s
```

This removes nodes that are empty or have pods that can fit elsewhere.

### 3. Set Resource Limits

```yaml
limits:
  cpu: "100"
  memory: "200Gi"
```

Prevents runaway scaling and surprise bills.

### 4. Single NAT Gateway

For non-production, use one NAT Gateway instead of per-AZ (~$32/month savings per gateway).

### Estimated Monthly Costs

| Resource | Cost |
|----------|------|
| EKS Control Plane | $73 |
| Initial Nodes (2x m5.large Spot) | ~$20-25 |
| NAT Gateway | ~$32 |
| **Baseline Total** | **~$125-130** |

## Cleanup

```bash
# Destroy all resources
terraform destroy
```

## Source Code

The complete Terraform code will be available on GitHub soon.

*TBD*

---

Have questions or feedback? Reach out on [GitHub](https://github.com/tyler0ps) or [LinkedIn](https://linkedin.com/in/tylerops).
