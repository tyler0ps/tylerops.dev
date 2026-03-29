---
title: AWS Baseline
description: A full cloud stack built on AWS best practices — multi-account structure, centralized SSO, Kubernetes, Observability, and self-hosted tooling.
---

# AWS Baseline

A production-grade personal cloud infrastructure built on AWS best practices. Covers multi-account governance, centralized identity, container orchestration, observability, and self-hosted internal tooling — all managed with Terraform and deployed as code.

## Stack Overview

| Component | Status |
|---|---|
| Static Website Hosting | ✅ Done |
| AWS Organization & Account Structure | 📝 Write-up coming |
| Passwordless SSO (IAM Identity Center) | 📝 Write-up coming |
| Kubernetes on AWS (EKS + Karpenter) | ✅ Done |
| Observability Stack (LGTM) | 📝 Write-up coming |
| Self-hosted Internal Stack | 📝 Write-up coming |

---

## ✅ Static Website Hosting

S3 + CloudFront + Route53 with GitHub Actions CI/CD. No servers, sub-50ms latency from edge, costs cents per month. OIDC-based auth for zero long-lived AWS credentials in CI.

[Read the blog post →](/projects/aws-baseline/static-website-hosting)

---

## 📝 AWS Organization & Account Structure

Multi-account structure following AWS best practices — separate accounts for workloads, logging, and security. Service Control Policies (SCPs) for guardrails, consolidated billing, and centralized CloudTrail.

*Write-up coming soon.*

---

## 📝 Passwordless SSO (IAM Identity Center)

Centralized identity with AWS IAM Identity Center. Single sign-on across AWS accounts, GitHub, and self-hosted tools — no IAM users, no long-lived credentials.

*Write-up coming soon.*

---

## ✅ Kubernetes on AWS (EKS + Karpenter)

EKS cluster with Karpenter for node autoscaling. Cost-optimized with Spot instances, right-sized automatically. Full Terraform setup with sensible defaults.

[Read the blog post →](/projects/aws-baseline/eks-karpenter-setup) | [Source code](https://github.com/tyler0ps/tylerops.dev/tree/main/source/eks-karpenter)

---

## 📝 Observability Stack (LGTM)

Centralized logging, metrics, and tracing across the baseline. Built on Loki, Grafana, Tempo, and Mimir — deployed on EKS with Terraform.

*Write-up coming soon.*

---

## 📝 Self-hosted Internal Stack

Self-hosted project management and documentation using Plane, backed by the same SSO. Fully deployed on AWS with Terraform — no SaaS dependency for internal tooling.

*Write-up coming soon.*

---

## Additional Reference Implementations

Standalone setups that complement the baseline.

### EKS + ArgoCD

GitOps workflow for Kubernetes. Deploy and manage applications on EKS using ArgoCD for declarative, version-controlled deployments.

::: info Coming Soon
Blog post and source code in progress.
:::

### Private AWS Resources with VPN

Secure access to private AWS resources. Set up a VPN solution to safely connect to resources in private subnets without exposing them to the public internet.

::: info Coming Soon
Blog post and source code in progress.
:::

### GitHub Actions for Microservices Monorepo

Complete CI/CD pipeline for microservices. Test, build, push, and release workflows using release-please for multiple environments in a monorepo setup.

::: info Coming Soon
Blog post and source code in progress.
:::
