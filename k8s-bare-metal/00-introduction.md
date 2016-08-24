# Bare Metal Kubernetes

Kubernetes was born in the cloud, primarily designed to sheperd cattle. Even the local deployment kube-up script deploys in Vagrant, using the same VMs you would find on the like of GCE, AWS or Azure. 

While this makes perfect sense, there is a class of use cases that must not be forgotten: bare metal deployment. Bare metal is useful in a number of cases: 

* If you operate your own datacenter and operate solely your own containerized apps;
* In environments where network access is a challenge;
* If you need to extract a lot of performance, in scenarii such as HPC;
* In most cases where you need access to PCI devices such as a GPU, and the cloud does not provide the GPU you need;
* In small teams to benefit from a local dev cluster, where you can run a small PaaS independently from network access;

Working on bare metal require to focus on at least 2 more aspects of the deployment: 

* **Storage**: public clouds have a notion of block storage (like EBS), which gets attached to machines. If the machine dies, the disk remains and can be allocated to another instance. Your database is safe, we can keep the data away from the compute and it will survive even dramatic events. In the world of k8s, containers live and die regardless of the underlying hardware. They can be scheduled on any instance that is part of the cluster, making the construct of instance-attached storage somewhat irrelevant. Kubernetes provides ways to abstract storage via PetSets, but there is still a need for a back end storage layer. On bare metal, this construct can be challenging, as using the host storage will not scale very much. 
* **Networking**: Once a service is created in k8s as a load balancer, its sole purpose is to be consumed from the outside world. Which means opening an external Load Balancer, and mapping it to the instances and ports that are allocated to its pods. 

How can I have resilient storage in an easy way for my stateful containers? How can I easily expose functionality to the outside world on a bare metal cluster? Ultimately, can I build a mini PaaS on metal, or should I stick to the cloud? 

Interestingly enough, there is little information about building k8s on metal. Hence the only way to find out is DIY! 

Here start our journey to install k8s on bare metal. In this blog, we will use the toolbox created by CoreOS to install a small bare metal Kubernetes cluster. This will take 2 main phases:

1. Understanding the requirements at the network level to automate the deployment
2. Understanding the security requirements to run k8s with TLS enabled
3. Deploying our system 

In a next part, we will study the installation of a resilient storage cluster to make sure we manage can stateful containers, and create a proxy / LB for services. 

# Requirements

For this setup, we will need: 

* a **home router** that can offer some advanced configuration. I use a [Ubiquity EdgeRouter](https://www.ubnt.com/edgemax/edgerouter/). Any OpenWRT system should work (and feel free to propose configs for this). If you do not have such machine, then you can emulate what is needed, but you will have to disable DHCP on your network while you do the setup, or do it on a separate VLAN/network. You will need at least 4 available ethernet ports. 
* **3 Intel NUCs**: we will want one master and 2 workers for a basic setup. k8s is not very power hungry so you should be ok with 4 to 8GB RAM and core i5 systems. For my setup, I re used a former  Gen5 5i7RYH (core i7, 16GB RAM, 256GB SSD + 250GB M.2 SSD), and I added 2 Gen6 6i5SYH (core i5 6400, 32GB RAM, 480GB SSD + 250GB M.2 SSD)
* A **laptop** connected to the same network with a cable (no wireless) and with the below capabilities:
  * Running docker containers 
  * Go 1.5+ installed and GOPATH configured, Go binaries folder added to PATH
  * Ports 80/tcp and 69/udp available
  * This repository cloned locally: ```cd ~ && git clone https://github.com/madeden/blogposts && ln -sf ~/blogposts/k8s-bare-metal ./k8s-bare-metal```

For the rest of this document, we assume these requirements are met, and that the NUCs are connected to the network, powered off and ready to start. 

# Conventions

For the sake of simplicity we will adopt the following conventions: 

## Network

We assume a classic Home Network, configured with a 192.168.1.0/24 subnet. Our router is 192.168.1.1 and acts as gateway, DHCP and DNS. 

## Servers

* Our laptop is node00, its MAC address is 00:00:00:00:00:00, IP address 192.168.1.250
* Our Master Node will be kube-master, and its MAC address is 00:00:00:00:00:01, IP address 192.168.1.201
* Our Worker nodes are
  * kube-worker-1, MAC address 00:00:00:00:00:11, IP address 192.168.1.211
  * kube-worker-2, with MAC address 00:00:00:00:00:12, IP address 192.168.1.212


