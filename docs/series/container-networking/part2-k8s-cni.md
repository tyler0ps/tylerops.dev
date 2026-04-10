---
title: "From Linux Namespaces to Kubernetes: Unpacking the CNI"
description: "TODO"
date: 2026-04-08
tags: [linux, networking, devops, containers]
---

# Part 2: From Linux Namespaces to Kubernetes: Unpacking the CNI

<span style="color: var(--vp-c-text-2); font-size: 0.9em;">April 08, 2026</span>

[TODO: Add description]

## Kubernetes Networking Model

To understand where CNI fits, it helps to look at the big picture. The Kubernetes Network Model is a set of principles that govern how everything in a cluster communicates. It consists of several key components:

* **Pod Networking (Where CNI lives):** The mechanism that actually wires up pods and ensures they can route traffic to one another across the cluster.
* **Service API:** The abstraction that stabilizes the chaos of ephemeral Pod IPs (handled under the hood by `kube-proxy` and `EndpointSlices`).
* **Ingress / Gateway API:** The front door that routes external client traffic into your cluster.
* **Network Policies:** The security rules that control traffic flow between pods and the outside world.

![K8s Network Model](/images/container-networking/k8s-network-model.png)

Each of these layers has a dedicated abstraction or built-in controller in Kubernetes. However, the foundational layer, **Pod Networking** is intentionally left blank.

Kubernetes simply dictates the *rules of the game* but refuses to implement the *how*. According to the official documentation, any underlying network must enforce two fundamental requirements:

* **Shared Network Namespace:** A pod has its own private network namespace, which is shared by all containers within that pod. Processes running in different containers inside the same pod can communicate with each other seamlessly over `localhost`.
* **Direct Pod-to-Pod Communication:** All pods can communicate with all other pods, whether they are on the same node or different nodes. This communication must happen directly, without the use of proxies or Network Address Translation (NAT).

As long as these conditions are met, Kubernetes does not care how the network is built. It completely "outsources" this massive responsibility to third-party plugins via the **CNI (Container Network Interface)** specification. 

![CNI Scope Highlight](/images/container-networking/cni-scope.png)
*(Caption: In this post, we are muting the noise from upper layers to focus entirely on the foundational Pod Network)*

In a nutshell: Kubernetes defines the *rules* for how pods should communicate, but the CNI is the *engine* that actually implements those rules. 

With Services, Ingress, and Policies out of the way, let's dive deep into how this CNI engine actually works under the hood.

## Can We Build Our Own CNI?
Absolutely. Getting our hands dirty and building things from scratch is exactly what we do here on the blog, right?

So, how do we solve the pod communication problem? In Part 1, we already learned how container networking is built from container-to-container, container-to-host, and out to the external world. While `Pod` is a Kubernetes-specific terminology, under the hood, it still heavily relies on the exact same containers and `Linux networking primitives`.

To fully wire up a network stack for a pod, several things need to be provisioned:
* Creating the **Network Namespace** (`netns`)
* Setting up **Network Interfaces** (like `veth` pairs)
* **IP Allocation** (IPAM)
* Configuring **Routes**
* Setting up **iptables/Netfilter rules**

Now, who does what? A common misconception is that Kubernetes does all of this. In reality, the workflow is highly decoupled. The `kubelet` doesn't even talk to the CNI directly. Instead, it delegates the job to the `Container Runtime (via CRI)`. 

Here is how the sequence actually looks under the hood:
1. **Kubelet** asks the **CRI** (e.g., containerd) to create a Pod Sandbox.
2. The **CRI** creates the Pod's Network Namespace.
3. The **CRI** reads the CNI configuration file and executes the **CNI binary**.
4. The **CNI binary** takes over to do the heavy lifting (creating veth pairs, assigning IPs, etc.) to connect the pod namespace to the host.

Visually, the architecture flows like this:
![CNI System Flow](/images/container-networking/cni-system-flow.png)

To give you a concrete mental model, here is the actual gRPC call from the Kubelet to the CRI when a pod is created:

```go
// https://github.com/kubernetes/cri-api/blob/v0.33.1/pkg/apis/runtime/v1/api.proto#L40
rpc RunPodSandbox(RunPodSandboxRequest) returns (RunPodSandboxResponse) {}
```

But since we are building a CNI, we aren't too interested in Kubelet's perspective. The real question is: **How is the CNI plugin invoked by the CRI?**

Is it a REST API? A Unix socket? gRPC? 

None of the above. A CNI plugin is not a running background service or a daemon. It is simply a "dead" executable binary sitting in `/opt/cni/bin/`. 

Here is the exact sequence of how a container runtime (like containerd or CRI-O, using the `libcni` library) executes it:
1. It looks for network configuration files in `/etc/cni/net.d/`. *(Fun fact: It picks the first file based on lexicographical/alphabetical sorting to use as the primary network, ignoring the rest)*.
2. These config files usually have a `.conflist` or `.conf` extension (do not use `.json` here, it is not the standard convention for CNI).
3. It locates the corresponding CNI binary in `/opt/cni/bin/`.
4. It executes the binary, passing context via **Environment Variables** and injecting the configuration file directly into **Standard Input (stdin)**.

Visually, the execution flow looks like this:
![CNI Plugin Execution](/images/container-networking/cni-plugin-execution.png)

If we were to translate this CRI magic into plain Bash, it would look exactly like this:

```bash
# 1. containerd explicitly sets up the environment variables...
export CNI_COMMAND=ADD
export CNI_CONTAINERID=1234abcd5678
export CNI_NETNS=/var/run/netns/testing-ns
export CNI_IFNAME=eth0
export CNI_PATH=/opt/cni/bin

# 2. ...and executes the binary while piping the config file into stdin
cat /etc/cni/net.d/10-calico.conflist | /opt/cni/bin/calico
```

Once the CNI binary finishes its job, it exits. 
* If the execution is successful, the **Exit Code is `0`**. Anything else means failure.
* The runtime expects the result to be printed to `stdout` as a JSON object, while errors are sent to `stderr`.

A successful CNI `ADD` result returned to `stdout` looks like this valid CNI v1.0.0 JSON:

```json
{
  "cniVersion": "1.0.0",
  "interfaces": [
    {
      "name": "cni0",
      "mac": "00:11:22:33:44:55"
    }
  ],
  "ips": [
    {
      "interface": 0, // Specifies the index in the interfaces array above
      "address": "10.240.0.2/24",
      "gateway": "10.240.0.1"
    }
  ]
}
```

The CRI then takes this result and moves to the next step. If you are using a chained CNI setup (like bandwidth limiting or port mapping), it passes this output to the next plugin. 

Finally, the CRI updates the Kubelet with the status of the Sandbox. If this whole CNI process fails, you will see a very familiar error in your Kubernetes cluster: `NetworkPluginNotReady`.

![CNI Plugin Execution](/images/container-networking/cni-plugin-execution-2.png)

```go
// https://github.com/kubernetes/cri-api/blob/v0.33.1/pkg/apis/runtime/v1/api.proto#L56
// PodSandboxStatus returns the status of the PodSandbox. If the PodSandbox is not
// present, returns an error.
rpc PodSandboxStatus(PodSandboxStatusRequest) returns (PodSandboxStatusResponse) {}
```

Once the execution is completely successful, the pod is fully wired up. It has its own network interfaces, an allocated IP, routing rules, and iptables configured. It is finally ready for pod-to-pod communication.

### Time to Build
Now we know exactly how the machinery works—how the CNI plugin is called, how it is configured, and the strict input/output contracts it must follow. There is no more magic left. 

It's time to build our own CNI plugin.

### To be continued...

**TODO** Spin up k8s clusters and test it

## Creating Our Own CNI Plugin

**TODO**

## A Dead Simple CNI Plugin

**TODO**

## Let's See It In Action

**TODO**

## What's Next?

**TODO**

## References

* [What Is Kubernetes Networking?](https://isovalent.com/blog/post/what-is-kubernetes-networking/)
* [Container Runtime Interface (CRI)](https://github.com/kubernetes/cri-api/tree/master)
* [Video: From CNI Zero to CNI Hero: A Kubernetes Networking Tutorial Using CNI](https://youtu.be/YumoKGhuZ2o)
* [The Kubernetes network model](https://kubernetes.io/docs/concepts/services-networking/#the-kubernetes-network-model)
* [Tigera: Kubernetes CNI Explained](https://www.tigera.io/learn/guides/kubernetes-networking/kubernetes-cni/)
* [Video: Container Networking From Scratch - Kristen Jacobs, Oracle](https://youtu.be/6v_BDHIgOY8)
