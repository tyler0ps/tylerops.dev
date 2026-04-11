---
title: "Container Networking Under the Hood"
description: "Demystifying container isolation by diving deep into Linux Network Namespaces, bridges, routing, and Kubernetes CNIs."
---

# Container Networking Under the Hood

Demystifying container isolation by diving deep into low-level Linux networking features, namespaces, and then building up to understand modern Kubernetes CNIs.

## Series Outline

### [Part 1: Building Container Networks from Scratch](/series/container-networking/container-networking-1)
Building a container network from scratch using Linux Network Namespaces, veth pairs, Linux Bridges, and iptables (Masquerading & Port Forwarding).

### [Part 2: From Linux Namespaces to Kubernetes: Unpacking the CNI](/series/container-networking/part2-k8s-cni)
In this part, we will walk through the Kubernetes networking model, dive deep into the CNI, and actually build our own CNI plugin to see how it works under the hood.

### Part 3: AWS VPC CNI (Coming Soon)
Deep dive into Amazon EKS's default VPC CNI plugin, exploring secondary IPs, ENIs, and traffic routing in AWS.

### Part 4: Cilium eBPF (Coming Soon)
Bypassing iptables with eBPF. How Cilium revolutionizes container networking performance, observability, and security.

### Part 5: Performance Comparison (Coming Soon)
Benchmarking AWS VPC CNI against Cilium eBPF on an EKS environment with 1,000 pods.