---
title: "Container Networking Under the Hood - Part 1: Network Namespaces"
description: "Demystifying container isolation by diving deep into Linux Network Namespaces."
date: 2026-03-27
tags: [linux, networking, devops, containers]
---

# Container Networking Under the Hood - Part 1: Network Namespaces
Container platforms aren't magic, myths, or rocket science. They are engineered by people and built entirely on top of existing Linux kernel features. The kernel provides the raw capabilities; engineers simply grouped these features together to solve fundamental DevOps challenges. By effectively isolating system resources and packaging applications into a standardized unit, they created a better way to run and scale software-giving birth to what we now call a "container."

## Introduction: What are Linux Namespaces?
![Docker and Linux Namespaces](/images/container-networking/linux-namespace-intro.png)

Before diving into networking, we need to understand the absolute foundation of this isolation: **Linux Namespaces**. Namespaces are a Linux kernel feature that partitions and isolates system resources. When you run a container, you aren't spinning up a full virtual machine; you are essentially just running a standard Linux process inside a securely isolated set of namespaces.

There are 7 primary types of namespaces in Linux:
* **Mount (mnt):** Isolates filesystem mount points.
* **Process ID (pid):** Isolates the PID number space.
* **Network (net):** Isolates network interfaces, routing tables, iptables, etc.
* **Interprocess Communication (ipc):** Isolates System V IPC and POSIX message queues.
* **UNIX Timesharing System (uts):** Isolates hostname and NIS domain name.
* **User (user):** Isolates user and group IDs.
* **Control Group (cgroup):** Isolates cgroup root directories.

In this series, we will focus exclusively on the **Network Namespace**.
## The Network Namespace (`netns`)

A Network Namespace provides a brand new, completely isolated network stack for a process. We hear this definition a lot, but wait—what exactly *is* a "network stack"? 

Simply put, it is the collection of network devices (interfaces), their assigned IP addresses, routing tables, and firewall rules (iptables) that dictate how traffic flows in and out of a system. 

Think of creating a new network namespace like buying a brand-new physical router: it has no cables plugged in, no IP addresses assigned, and its routing table is completely empty. This is exactly how a container starts its life before a container runtime or a CNI plugin configures its network.

You can inspect the components of your current network stack using these standard Linux commands:

```bash
# List network devices (interfaces)
ip link

# List assigned IP addresses
ip addr

# View the routing table
ip route

# View firewall and NAT rules
sudo iptables --list-rules
```

![Linux Root Network Namespace](/images/container-networking/linux-root-netns.png)
By default, every Linux machine comes with a primary, built-in network environment known as the **root network namespace**. 

When you log into a server and run the commands we just discussed, you are viewing the network stack of this root namespace. As illustrated above, it contains your default loopback (`lo`) and primary network interfaces (like `eth0`), along with the host's main routing table and default iptables rules. 

Our goal now is to step outside this default environment and create a *new*, completely isolated network namespace from scratch.


## Building a Container Network from Scratch

Let's get our hands dirty and build what Docker or Kubernetes does under the hood.
![Linux Netowrk Namespace - ns0](/images/container-networking/ns0.png)

### 1. Create a Network Namespace (`ns0`)
First, we create our isolated environment.

```bash
# Create a new network namespace named ns0
sudo ip netns add ns0

# Verify it was created
ip netns list
```

### 2. Create a Veth Pair
To connect our host to this isolated namespace, we need a virtual cable. In Linux, this is called a Virtual Ethernet (veth) pair. A veth pair always comes in twos-what goes in one end comes out the other.

```bash
# Create a veth pair: veth0 (for the host) and ceth0 (for the namespace)
sudo ip link add veth0 type veth peer name ceth0
```
**Verify**

You should see the pair by executing:
```bash
ip link | grep -i 'veth0\|ceth0'
```
**Output**
```text
8: ceth0@veth0: <BROADCAST,MULTICAST,M-DOWN> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
9: veth0@ceth0: <BROADCAST,MULTICAST,M-DOWN> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
```
### 3. Attach the Veth Pair to the Host and ns0
By default, both ends of the veth pair are created in the host's default root network namespace. We need to move one end (ceth0) into our new namespace (ns0).

```bash
# Move ceth0 into ns0
sudo ip link set ceth0 netns ns0

# Check the host links (you will see veth0, but ceth0 is gone)
ip link list

# Result
# 9: veth0@if8: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT group default qlen 1000

# Check the ns0 links (you will see the loopback interface and ceth0)
sudo ip netns exec ns0 ip link list

# Result
# 1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000 link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
# 8: ceth0@if9: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT group default qlen 1000 link/ether c6:78:fd:d5:9b:cd brd ff:ff:ff:ff:ff:ff link-netnsid 0
```

### 4. Assign IP Addresses and Bring Interfaces UP
Note: Just plugging in a virtual cable doesn't grant network access. We need to assign IP addresses and turn the interfaces "up", just like physical hardware.

```bash
# 1. Configure the Host side
sudo ip addr add 10.0.0.1/24 dev veth0
sudo ip link set veth0 up

# 2. Configure the Namespace side
sudo ip netns exec ns0 ip addr add 10.0.0.2/24 dev ceth0
sudo ip netns exec ns0 ip link set ceth0 up

# 3. Bring up the loopback interface inside the namespace (best practice)
sudo ip netns exec ns0 ip link set lo up
```

### 5. Verify Connectivity
Let's test if the host can talk to our isolated "container" namespace, and vice versa.

```bash
# Ping from Host to ns0
ping -c 1 10.0.0.2

# Result
# PING 10.0.0.2 (10.0.0.2) 56(84) bytes of data.
# 64 bytes from 10.0.0.2: icmp_seq=1 ttl=64 time=0.296 ms

# Ping from ns0 to Host
sudo ip netns exec ns0 ping -c 1 10.0.0.1

# Result
# PING 10.0.0.1 (10.0.0.1) 56(84) bytes of data.
# 64 bytes from 10.0.0.1: icmp_seq=1 ttl=64 time=0.168 ms
```

### 6. Verify Isolation
Our namespace can talk to the host, but can it reach the outside world?

```bash
# Try to ping Google DNS from inside ns0
sudo ip netns exec ns0 ping 8.8.8.8

# Result
# ping: connect: Network is unreachable
```

It fails because `ns0` has its own isolated routing table with no default gateway or NAT rules configured to route traffic out to the physical internet. True isolation!

### 7. Scale it up: Create ns1
In reality, we will have more than one container, so let's create a second namespace, `ns1`.

```bash
# Create ns1 and its veth pair
sudo ip netns add ns1
sudo ip link add veth1 type veth peer name ceth1
sudo ip link set ceth1 netns ns1

# Configure Host side
sudo ip addr add 10.0.0.3/24 dev veth1
sudo ip link set veth1 up

# Configure ns1 side
sudo ip netns exec ns1 ip addr add 10.0.0.4/24 dev ceth1
sudo ip netns exec ns1 ip link set ceth1 up
sudo ip netns exec ns1 ip link set lo up
```

So now, we have two isolated network namespaces, `ns0` and `ns1`, and both are independently connected to the host via their own veth pairs. 
![Linux Netowrk Namespace - ns0 ns1](/images/container-networking/ns0-ns1.png)

We logically expect that `ns0` and `ns1` can both ping the host. Let's verify this assumption.

First, let's ping from `ns0`:
```bash
# Ping from ns0 to Host (10.0.0.1)
sudo ip netns exec ns0 ping -c 1 10.0.0.1
# Result: SUCCESS
```

Now, let's try pinging from `ns1` to the Host (`10.0.0.3`):
```bash
ip netns exec ns1 ping 10.0.0.3 -c 2
# PING 10.0.0.3 (10.0.0.3) 56(84) bytes of data.
# 
# --- 10.0.0.3 ping statistics ---
# 2 packets transmitted, 0 received, 100% packet loss, time 1061ms
```

Wait, why did the ping from `ns1` to the host fail with 100% packet loss? Let's run a continuous ping from `ns1` and debug the incoming traffic on the host's `veth1` interface using `tcpdump`:

```bash
root@ty-labs:~# tcpdump -i veth1

# 04:30:14.830971 IP 10.0.0.4 > ty-labs: ICMP echo request, id 5484, seq 1, length 64
# 04:30:15.892046 IP 10.0.0.4 > ty-labs: ICMP echo request, id 5484, seq 2, length 64
```

The ICMP echo requests from `ns1` (`10.0.0.4`) are successfully reaching the host on `veth1`! The problem isn't the incoming traffic; the host simply doesn't know how to send the reply back correctly. Let's look at how the host routes packets destined for `10.0.0.4`:

```bash
ip route get 10.0.0.4 
# 10.0.0.4 dev veth0 src 10.0.0.1 uid 0
```

Notice the problem? The host is trying to send the reply out through **`veth0`** instead of **`veth1`**! 

Let's view the host's full routing table to understand why this happens:

```bash
root@ty-labs:~# ip route

# 10.0.0.0/24 dev veth0 proto kernel scope link src 10.0.0.1
# 10.0.0.0/24 dev veth1 proto kernel scope link src 10.0.0.3
```

Here lies our routing conflict. Because both `veth0` and `veth1` were assigned IP addresses in the exact same `10.0.0.0/24` subnet, the Linux kernel created two overlapping routing rules. When trying to route traffic to `10.0.0.4`, the host matches the first rule it sees (`10.0.0.0/24 dev veth0`) and sends the packet down the wrong virtual cable!

### The Scaling Problem

To fix the unreachability issue, we *could* create more direct veth pairs and manually manage complex IP subnets. But imagine scaling this to 100 containers, we would need thousands of virtual cables. It becomes a completely unmanageable mess.

So, is there another way to handle this?

**Yes, the Linux Bridge.**

Instead of tangled direct connections, we simply plug every namespace into a central virtual switch. We will tear down these direct connections and bring the Linux Bridge into the picture to solve this once and for all!

## Setting Up the Linux Bridge

![Linux Network Namespace - Bridge](/images/container-networking/linux-bridge.png)

Let's tear down our old direct connections and build a proper, scalable bridged network.

### 1. Create the Virtual Bridge (`br0`)
First, we create our virtual switch. Instead of assigning IP addresses directly to individual `veth` cables on the host, we assign a single IP address directly to the bridge. This IP will act as the default gateway for all our containers.

```bash
# Create a new bridge device named br0
ip link add br0 type bridge

# Assign an IP address to the bridge and bring it UP
ip addr add dev br0 10.0.0.1/24
ip link set br0 up
```

### 2. Create Namespaces and Veth Pairs
Next, we recreate our namespaces (`ns0` and `ns1`) and their virtual cables. Notice one critical difference from our previous setup: **we no longer assign IP addresses to the host ends (`veth0` and `veth1`)**. We just bring them UP, ready to be plugged in.

```bash
# Create ns0 and its veth pair
ip netns add ns0
ip link add veth0 type veth peer name ceth0
ip link set ceth0 netns ns0
ip link set veth0 up

# Configure the namespace side (ns0)
ip netns exec ns0 ip addr add 10.0.0.2/24 dev ceth0
ip netns exec ns0 ip link set ceth0 up
ip netns exec ns0 ip link set lo up

# Create ns1 and its veth pair
ip netns add ns1
ip link add veth1 type veth peer name ceth1
ip link set ceth1 netns ns1
ip link set veth1 up

# Configure the namespace side (ns1)
ip netns exec ns1 ip addr add 10.0.0.4/24 dev ceth1
ip netns exec ns1 ip link set ceth1 up
ip netns exec ns1 ip link set lo up
```

### 3. Attach Veth Pairs to the Bridge
Right now, our virtual cables are dangling on the host side. We need to plug them into our newly created switch (`br0`). We do this by setting the bridge as the "master" of our host-side interfaces.

```bash
# "Plug" veth0 and veth1 into the br0 switch
ip link set veth0 master br0
ip link set veth1 master br0
```

### 4. Verify Connectivity
With both containers plugged into the same central switch, they should now be able to communicate perfectly on the same subnet without any routing conflicts. Let's test it:

**Ping `ns1` from `ns0`:**
```bash
ip netns exec ns0 ping 10.0.0.4 -c 1

# PING 10.0.0.4 (10.0.0.4) 56(84) bytes of data.
# 64 bytes from 10.0.0.4: icmp_seq=1 ttl=64 time=0.337 ms
# 
# --- 10.0.0.4 ping statistics ---
# 1 packets transmitted, 1 received, 0% packet loss, time 0ms
# rtt min/avg/max/mdev = 0.337/0.337/0.337/0.000 ms
```

**Ping `ns0` from `ns1`:**
```bash
ip netns exec ns1 ping 10.0.0.2 -c 1

# PING 10.0.0.2 (10.0.0.2) 56(84) bytes of data.
# 64 bytes from 10.0.0.2: icmp_seq=1 ttl=64 time=0.156 ms
# 
# --- 10.0.0.2 ping statistics ---
# 1 packets transmitted, 1 received, 0% packet loss, time 0ms
# rtt min/avg/max/mdev = 0.156/0.156/0.156/0.000 ms
```

### 5. Inspecting the Layer 2 Traffic
Because `ns0` and `ns1` are connected to the same Layer 2 bridge, they can reach each other directly using ARP (Address Resolution Protocol) without routing through the host's IP stack. We can verify this by checking their neighbor tables:

```bash
ip netns exec ns0 ip neigh
# 10.0.0.4 dev ceth0 lladdr 62:f9:58:b8:84:ca REACHABLE

ip netns exec ns1 ip neigh
# 10.0.0.2 dev ceth1 lladdr c6:78:fd:d5:9b:cd REACHABLE
```

To see this connection in action, we can monitor the traffic passing across the `br0` device itself:

```bash
tcpdump -i br0

# 06:27:36.845487 ARP, Request who-has 10.0.0.4 tell 10.0.0.2, length 28
# 06:27:36.845440 ARP, Request who-has 10.0.0.2 tell 10.0.0.4, length 28
# 06:27:36.845541 ARP, Reply 10.0.0.4 is-at 62:f9:58:b8:84:ca (oui Unknown), length 28
# 06:27:36.845558 ARP, Reply 10.0.0.2 is-at c6:78:fd:d5:9b:cd (oui Unknown), length 28
```

The bridge successfully acts as a central hub, forwarding ARP requests and ICMP traffic directly between our isolated environments-precisely how Docker allows containers to communicate on the default `docker0` bridge!

---

# To be continued

## Outbound Connectivity: Enabling Internet Access via IP Masquerading
Explain the need for Source NAT (IP Masquerading) and provide the `iptables` rule to give the container internet access.

## Ingress Traffic: Port Forwarding from Host to Container
Demonstrate using Destination NAT (DNAT) in `iptables` to expose a container's port, demystifying how `docker run -p` works under the hood.

## Connecting the Dots: The 3 Built-in Docker Networks
Briefly map the manual concepts just built to Docker's three default networking modes: `none`, `host`, and `bridge`.

## From Docker to Kubernetes: Pod Networking Basics
Briefly connect the dots by explaining that a Kubernetes Pod is simply a group of containers sharing a single network namespace and utilizing similar bridge mechanisms.

## Up Next in Part 2: Automating with Kubernetes CNI
Tease the next article by stating that Container Network Interface (CNI) plugins exist purely to automate all these manual namespace, bridge, and routing configurations across a large-scale, multi-node cluster.

## References

* [Tracing the path of network traffic in Kubernetes (LearnKube)](https://learnkube.com/kubernetes-network-packets)
* [Create Your Own Network Namespace (ITNEXT)](https://itnext.io/create-your-own-network-namespace-90aaebc745d)
* [How Container Networking Works: Building a Bridge Network From Scratch (iximiuz Labs)](https://labs.iximiuz.com/tutorials/container-networking-from-scratch)
* [YouTube Video Reference](https://www.youtube.com/watch?v=6v_BDHIgOY8)
* [Building containers by hand using namespaces: The net namespace (Red Hat)](https://www.redhat.com/en/blog/net-namespaces)