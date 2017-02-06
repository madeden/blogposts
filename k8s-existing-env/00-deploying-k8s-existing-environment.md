# Deploying Kubernetes in AWS

When I talk about [Ubuntu](https://www.ubuntu.com/) and [Kubernetes](https://www.ubuntu.com/cloud/kubernetes), and how we deploy the later at [Canonical](https://www.canonical.com/), the main question I get is: Can you deploy in an existing infrastructure? 

Often, "existing infrastructure" means **the VPC and/or subnets that I have been allocated to do my work on AWS**. What is better than a little hands on to explain how Juju can interact with your infrastructure, and leverage a predefined network environment? 

The rest of this post assumes that 

* You have access to an AWS account that can provision VMs and create network infrastructure
* You are familiar with Kubernetes in general
* You are familiar with AWS infrastructure 
* You have notions of CloudFormation 
* You understand [Juju](https://jujucharms.com) concepts, and have the client installed on your work machine

About this last point, as a reminder, if you have not yet installed Juju, do it by entering the following commands on an Ubuntu 16.04 machine or VM

```
sudo apt-add-repository ppa:juju/stable
sudo apt-add-repository ppa:conjure-up/next
sudo apt update && apt upgrade -yqq
sudo apt install -yqq juju conjure-up
```

for other OSes, lookup the [official docs](https://jujucharms.com/docs/2.0/getting-started-general)

Then to connect to the AWS cloud with your credentials, read [this page](https://jujucharms.com/docs/2.0/help-aws)

Now that you are ready, this is what we are going to do: 

1. Deploy a network environment made of a VPC, public subnets and private subnet via CloudFormation. This will be our "existing infrastructure"
2. Bootstrap a Juju Controller in that VPC
3. Setup Juju to understand the network layout we have
4. Deploy Kubernetes in that environment
   4.1. PKI node and etcd nodes will be in the private subnets
   4.2. Master and Worker nodes will be in the public subnets
5. We'll open a few ports for our worker nodes, deploy a sample application and expose it via an ingress in k8s. 


