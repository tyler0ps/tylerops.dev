---
title: "Container Networking Under the Hood"
description: "Demystifying container isolation by diving deep into Linux Network Namespaces, bridges, routing, and Kubernetes CNIs."
---

# Container Networking Under the Hood

Demystifying container isolation by diving deep into low-level Linux networking features, namespaces, cgroups, and then building up to understand modern Kubernetes CNIs.

## Series Outline

### [Part 1: Network Namespaces](/series/container-networking/container-networking-1)
Introduction to Linux namespaces, creating network namespaces, working with veth pairs, and isolating network traffic.

### Part 2: Linux Bridges (Coming Soon)
Solving the veth pair management nightmare by introducing Linux Bridges (`br0`), and comparing our setup with the default `docker0` bridge network.

### Part 3: IP Routing and Masquerades (Coming Soon)
Handling external traffic, outbound internet access, and IP masquerading for isolated containers.

### Part 4: Kubernetes & CNI (Coming Soon)
How Kubernetes handles pod networking, introducing the Container Network Interface (CNI), and how it maps back to our low-level Linux setup.

### Part 5: AWS VPC CNI (Coming Soon)
Deep dive into Amazon EKS's default VPC CNI plugin, secondary IPs, ENIs, and traffic routing in AWS.

### Part 6: Cilium eBPF (Coming Soon)
Bypassing iptables with eBPF. How Cilium revolutionizes container networking performance and security.

### Part 7: Performance Comparison (Coming Soon)
Comparing performance between AWS VPC CNI and Cilium eBPF on EKS with 1,000 pods.
