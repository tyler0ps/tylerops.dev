---
title: "Container Networking Under the Hood"
description: "A deep dive into Linux networking primitives, Kubernetes CNI, the Service Layer, and Network Policy, from raw namespaces to production-grade security."
---

# Container Networking Under the Hood

A deep dive into Linux networking primitives, Kubernetes CNI, the Service Layer, and Network Policy, from raw namespaces to production-grade security.

## [Part 1: Building Container Networks from Scratch](/series/container-networking/container-networking-1)
Building a container network from scratch using Linux Network Namespaces, veth pairs, Linux Bridges, and iptables (Masquerading & Port Forwarding).

## [Part 2: From Linux Namespaces to Kubernetes: Unpacking the CNI](/series/container-networking/part2-k8s-cni)
In this part, we will walk through the Kubernetes networking model, dive deep into the CNI, and actually build our own CNI plugin to see how it works under the hood.

## Part 3: The Service Layer - kube-proxy & CoreDNS (Coming Soon)
How Kubernetes gives ephemeral pods a stable IP and DNS name, tracing DNAT rules through kube-proxy and DNS queries through CoreDNS.

## Part 4: The Security Layer - Network Policy with Calico (Coming Soon)
How Calico enforces NetworkPolicy under the hood, reading the actual iptables chains a production CNI generates, rule by rule.
