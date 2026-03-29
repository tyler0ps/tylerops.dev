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


## In Action: Building a Container Network from Scratch

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
To demonstrate the next problem, let's quickly create a second namespace, `ns1`.

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

Right now, `ns0` can talk to the Host, and `ns1` can talk to the Host. But can they talk to each other? Let's test it:

```bash
# Try to ping ns1 (10.0.0.4) from ns0
sudo ip netns exec ns0 ping -c 1 10.0.0.4

# Result
# ping: connect: Network is unreachable
```

### 8. The Scaling Problem: Managing Veth Pairs
So far, we have successfully created isolated network namespaces (`ns0, ns1`) and connected them to the host using individual `veth` pairs.

To fix the unreachability issue above, we could create a new, dedicated `veth` pair directly connecting `ns0` to `ns1`. However, imagine scaling this up to just 10 microservices. If every container needs a direct virtual cable to every other container, we would need to manage **45 separate veth pairs** *(using the N(N-1)/2 formula)*. If you run 100 containers, that jumps to **4,950 pairs**! This approach quickly becomes a tangled, unmanageable mess of virtual cables and complex routing rules.

## The Solution: The Linux Bridge
In the physical networking world, when we have dozens of computers in a room that need to communicate, we don't connect them all directly to each other with crossover cables. We plug them all into a central Network Switch.

In the Linux networking world, the virtual equivalent for this exact problem is the Linux Bridge. Instead of direct container-to-container connections, we simply plug each namespace into a single, central bridge device. 

**In Part 2**, we will tear down our direct connections, set up a Linux Bridge (`br0`), and see how it elegantly solves container communication-giving us the foundation for the famous `docker0` bridge!