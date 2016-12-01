# Preparations

At first look we are pretty far from an optimal setup for Kubernetes, especially the Canonical Distribution of Kubernetes. 

First of all, the machines we have run Ubuntu 14.04, and CDK is built upon systemd, hence starts on versions of Ubuntu above 15.10. It is actually developed on Ubuntu 16.04, so that is what we would need. 

The second issue we have is the number of machines. We have 3, but a proper Juju setup requires at least 4: 

* The client, which need access to the boxes and the ability to bootstrap a node
* The first Juju controller, which will manage the deployment. 
* One k8s master, which will co host etcd and the easyrsa implementation
* One worker node

Being short one node, we will have to leverage LXD, to run some things in LXC containers. 

In this context we would theoretically need to update the networking on the host, to provide a bridge, so that our containers can get IP addresses from the DHCP. Unfortunately, our nodes are in a remote location, we can't really touch them, and even less modify the network without losing access and potentially never recovering it. 

The solution we found for this was to leverage "The Fan". It is a very simple overlay network created by Canonical, which expands the number of IP addresses available on each host by a factor 256. If all our containers and machines are using "The Fan", they will think they are on the same network, and we may get somewhere interesting. 

In the end, we came up with the below ![drawing](/pics/k8sppc64-network.png)





