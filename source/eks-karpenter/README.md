# EKS + Karpenter

Terraform code for setting up Amazon EKS with Karpenter for efficient, cost-optimized Kubernetes node provisioning.

## Overview

- EKS cluster with Karpenter installed via Helm
- NodePool and EC2NodeClass configurations
- Spot instances with automatic consolidation
- Test deployment for autoscaling validation

## Usage

```bash
terraform init
terraform apply
```

## Full Guide

For detailed walkthrough, architecture diagrams, and step-by-step instructions, see the blog post:

**[EKS + Karpenter Setup](https://tylerops.dev/blog/posts/eks-karpenter-setup)**
