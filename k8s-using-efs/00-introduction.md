# Using EFS for storage in Kubernetes

Over the last few weeks we have seen various methods of building Kubernetes clusters on different clouds such as AWS or Azure, integrate with existing infrastructure and eventually add GPUs. 

One thing that Kubernetse is used for in particular is Machine Learning and Deep Learning. Both these require access to large amount of data. Most of the tutorials for Tensorflow or the recent PaddlePaddle blog posts start with running a Kubernetes job to download and prepare a dataset. 

There are many ways of providing a storage layer for Kubernetes

* On Premises options: 
  * Ceph
  * GlusterFS 
  * or simply NFS
* In the cloud
  * Any of the block primitives of the clouds (EBS, Google Cloud Volumes, Azure Block Storage)
  * NFS or GlusterFS

AWS recently released EFS, a NFS-compliant storage layer, which can extremely easily be leveraged to provide a multiReadWrite PVs to Kubernetes pods. 

Let us see how. 

# The Plan

In this blog, you will: 

1. Deploy k8s on AWS in a development mode (no HA, colocating etcd, the control plane and PKI)
2. Deploy 2x worker nodes 
3. Programmatically add an EFS File System and Mount Points into your nodes

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
sudo apt update && apt upgrade -yqq
sudo apt install -yqq juju 
```

for other OSes, lookup the [official docs](https://jujucharms.com/docs/2.0/getting-started-general)

Then to connect to the AWS cloud with your credentials, read [this page](https://jujucharms.com/docs/2.0/help-aws)

* Finally copy this repo to have access to all the sources

```
git clone https://github.com/madeden/blogposts ./
cd blogposts/k8s-using-efs
```

Ready? Let's Kubernetes! 


