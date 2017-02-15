# GPU Cluster in the cloud

A few weeks ago I shared a side project about building a [DIY GPU Cluster]([Building a DYI GPU cluster for k8s](https://hackernoon.com/installing-a-diy-bare-metal-gpu-cluster-for-kubernetes-364200254187) to play with Kubernetes with a proper ROI vs. AWS. 

This was spectacularly interesting when AWS was lagging behind with old nVidia K20s cards. But with the addition of the [P series](https://aws.amazon.com/ec2/instance-types/#p2) (p2.xlarge, 8xlarge and 16xlarge) it can also sometimes be more interesting to run workloads in the cloud just long enough to train a model. 

Baidu just released the PaddlePaddle setup, so I thought it would be interesting looking at a setup of Kubernetes on AWS using some GPU nodes and some CPU only nodes, then exercise this Deep Learning framework on it. 

This post will be part of a sequence of 3: Setup the GPU cluster, Adding Storage to a Kubernetes Cluster, and finally run a Deep Learning training on the cluster.

# The Plan

In this blog, we will: 

1. Deploy k8s on AWS in a development mode (no HA, colocating etcd, the control plane and PKI)
2. Deploy 2x nodes with GPUs (p2.xlarge and p2.8xlarge instances)
3. Deploy 3x nodes with CPU only (m4.xlarge)
4. Validate GPU availability

## Requirements

For what follows, it is important that: 

* You understand Kubernetes 101
* You have admin credentials for AWS
* If you followed the other posts, you know we'll be using the [Canonical Distribution of Kubernetes](https://www.ubuntu.com/cloud/kubernetes), hence some knowledge about Ubuntu, Juju and the rest of Canonical's ecosystem will help. 

# Foreplay

* Make sure you have Juju installed. 

On Ubuntu, 

```
sudo apt-add-repository ppa:juju/stable
sudo apt update
sudo apt install -yqq juju 
```

for other OSes, lookup the [official docs](https://jujucharms.com/docs/2.0/getting-started-general)

Then to connect to the AWS cloud with your credentials, read [this page](https://jujucharms.com/docs/2.0/help-aws)

* Finally copy this repo to have access to all the sources

```
git clone https://github.com/madeden/blogposts ./
cd blogposts/k8s-gpu-cloud
```

OK! Let's start GPU-izing the world! 


