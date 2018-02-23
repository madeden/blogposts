# Deploying the cluster
## Boostrap

As usual start with the bootstrap sequence. Just be careful that p2 instances are only available in us-west-2, us-east-1 and eu-west-2 as well as the us-gov regions. I have experience issues running p2 instances on the EU side hence I recommend using a US region. 

```
juju bootstrap aws/us-east-1 --credential canonical --constraints "cores=4 mem=16G root-disk=64G" 
# Creating Juju controller "aws-us-east-1" on aws/us-east-1
# Looking for packaged Juju agent version 2.1-rc1 for amd64
# Launching controller instance(s) on aws/us-east-1...
#  - i-0d48b2c872d579818 (arch=amd64 mem=16G cores=4)
# Fetching Juju GUI 2.3.0
# Waiting for address
# Attempting to connect to 54.174.129.155:22
# Attempting to connect to 172.31.15.3:22
# Logging to /var/log/cloud-init-output.log on the bootstrap machine
# Running apt-get update
# Running apt-get upgrade
# Installing curl, cpu-checker, bridge-utils, cloud-utils, tmux
# Fetching Juju agent version 2.1-rc1 for amd64
# Installing Juju machine agent
# Starting Juju machine agent (service jujud-machine-0)
# Bootstrap agent now started
# Contacting Juju controller at 172.31.15.3 to verify accessibility...
# Bootstrap complete, "aws-us-east-1" controller now available.
# Controller machines are in the "controller" model.
# Initial model "default" added.

```

## Deploying instances

Once the controller is ready we can start deploying services. In my previous posts, I used "bundles" which are shortcuts to deploy complex apps. You can find some bundles in the repo you copied (named k8s-aws.yaml or equivalent) but this time we will deploy manually, to go through the mechanics of Juju when deploying applications. 

Kubernetes is made of 5 individual applications: Master, Worker, Flannel (network), etcd (cluster state storage DB) and easyRSA (PKI to encrypt communication and provide x509 certs). In the juju vocabulary, each app is modeled by a charm, which is a recipe of how to deploy an app. 

At deployment time, you can give constraints to Juju, either very specific (instance type) or laxist (# of cores). With the later, Juju will elect the cheapest instance matching your constraints on the target cloud. 

First thing is to deploy the applications: 

```
juju deploy cs:~containers/kubernetes-master-47 --constraints "cores=4 mem=8G root-disk=32G"
# Located charm "cs:~containers/kubernetes-master-47".
# Deploying charm "cs:~containers/kubernetes-master-47".
juju deploy cs:~containers/etcd-48 --to 0
# Located charm "cs:~containers/etcd-48".
# Deploying charm "cs:~containers/etcd-48".
juju deploy cs:~containers/easyrsa-15 --to lxd:0
# Located charm "cs:~containers/easyrsa-15".
# Deploying charm "cs:~containers/easyrsa-15".
juju deploy cs:~containers/flannel-26
# Located charm "cs:~containers/flannel-26".
# Deploying charm "cs:~containers/flannel-26".
juju deploy cs:~containers/kubernetes-worker-52 --constraints "instance-type=p2.xlarge" kubernetes-worker-gpu
# Located charm "cs:~containers/kubernetes-worker-52".
# Deploying charm "cs:~containers/kubernetes-worker-52".
juju deploy cs:~containers/kubernetes-worker-52 --constraints "instance-type=p2.8xlarge" kubernetes-worker-gpu8
# Located charm "cs:~containers/kubernetes-worker-52".
# Deploying charm "cs:~containers/kubernetes-worker-52".
juju deploy cs:~containers/kubernetes-worker-52 --constraints "instance-type=m4.2xlarge" -n3 kubernetes-worker-cpu
# Located charm "cs:~containers/kubernetes-worker-52".
# Deploying charm "cs:~containers/kubernetes-worker-52".
```

Here you can see an interesting property in Juju that we never approached before: naming the services you deploy. We deployed the same kubernetes-worker charm twice, but twice with GPUs and the other without. This gives us a way to group instances of a certain type, at the cost of duplicating some commands. 


## Adding the relations & Exposing software

Now that the applications are deployed, we need to tell Juju how they are related together. For example, the Kubernetes master needs certificates to secure its API. Therefore, there is a relation between the kubernetes-master:certificates and easyrsa:client. 

This relation means that once the 2 applications will be connected, some scripts will run to query the EasyRSA API to create the required certificates, then copy them in the right location on the k8s master. 

These relations then create statuses in the cluster, to which charms can react. 

Essentially, very high level, think Juju's objective as a pub-sub implementation of application deployment. Every action inside or outside of the cluster posts a message to a common bus, and charms can react to these and perform additional actions. 

Let's add the relations: 

```
juju add-relation kubernetes-master:certificates easyrsa:client
juju add-relation etcd:certificates easyrsa:client
juju add-relation kubernetes-master:etcd etcd:db
juju add-relation flannel:etcd etcd:db
juju add-relation flannel:cni kubernetes-master:cni

for TYPE in cpu gpu gpu8
do 
  juju add-relation kubernetes-worker-${TYPE}:kube-api-endpoint kubernetes-master:kube-api-endpoint
  juju add-relation kubernetes-master:kube-control kubernetes-worker-${TYPE}:kube-control
  juju add-relation kubernetes-worker-${TYPE}:certificates easyrsa:client
  juju add-relation flannel:cni kubernetes-worker-${TYPE}:cni
  juju expose kubernetes-worker-${TYPE}
done 

juju expose kubernetes-master
```

Note at the end the "expose" commands. These are instructions for Juju to open up firewall in the cloud for specific ports of the instances. Some are predefined (Kubernetes Master API is 6443, Workers open up 80 and 443 for ingresses) but you can also force them if you need (for example, when you manually add stuff in the instances post deployment)

## Adding CUDA

Discovery and installation of CUDA is now a fully automated process. Every 5 minutes, the charms will check if nVidia GPUs are present and if so, install drivers and CUDA. 

2 options help controlling the behavior in the worker charm : 

<pre><code>
  "cuda-version":
    "type": "string"
    "default": "8.0.61-1"
    "description": |
      The cuda-repo package version to install.
  "install-cuda":
    "type": "boolean"
    "default": !!bool "true"
    "description": |
      Install the CUDA binaries if capable hardware is present.
</code></pre>

El despliegue y configuración de CUDA aparecen en el estatus de Juju y los logs. 

```
juju status
Model    Controller     Cloud/Region   Version
default  aws-us-east-1  aws/us-east-1  2.2.4

App                     Version  Status       Scale  Charm              Store       Rev  OS      Notes
easyrsa                 3.0.1    active           1  easyrsa            jujucharms   15  ubuntu  
etcd                    2.3.8    active           1  etcd               jujucharms   48  ubuntu  
flannel                 0.7.0    active           6  flannel            jujucharms   26  ubuntu  
kubernetes-master       1.7.4    active           1  kubernetes-master  jujucharms   47  ubuntu  exposed
kubernetes-worker-cpu   1.7.4    active           3  kubernetes-worker  jujucharms   52  ubuntu  exposed
kubernetes-worker-gpu   1.7.4    active           1  kubernetes-worker  jujucharms   52  ubuntu  exposed
kubernetes-worker-gpu8  1.7.4    active           1  kubernetes-worker  jujucharms   52  ubuntu  exposed

Unit                       Workload     Agent      Machine  Public address  Ports           Message
easyrsa/0*                 active       idle       0/lxd/0  10.0.0.122                      Certificate Authority connected.
etcd/0*                    active       idle       0        54.242.44.224   2379/tcp        Healthy with 1 known peers.
kubernetes-master/0*       active       idle       0        54.242.44.224   6443/tcp        Kubernetes master running.
  flannel/0*               active       idle                54.242.44.224                   Flannel subnet 10.1.76.1/24
kubernetes-worker-cpu/0    active       idle       4        52.86.161.22    80/tcp,443/tcp  Kubernetes worker running.
  flannel/4                active       idle                52.86.161.22                    Flannel subnet 10.1.79.1/24
kubernetes-worker-cpu/1*   active       idle       5        52.70.5.49      80/tcp,443/tcp  Kubernetes worker running.
  flannel/2                active       idle                52.70.5.49                      Flannel subnet 10.1.63.1/24
kubernetes-worker-cpu/2    active       idle       6        174.129.164.95  80/tcp,443/tcp  Kubernetes worker running.
  flannel/3                active       idle                174.129.164.95                  Flannel subnet 10.1.22.1/24
kubernetes-worker-gpu8/0*  active       idle       3        52.90.163.167   80/tcp,443/tcp  Kubernetes worker running.
  flannel/5                active       idle                52.90.163.167                   Flannel subnet 10.1.35.1/24
kubernetes-worker-gpu/0*   active       idle       1        52.90.29.98     80/tcp,443/tcp  Kubernetes worker running.
  flannel/1                active       idle                52.90.29.98                     Flannel subnet 10.1.58.1/24

Machine  State    DNS             Inst id              Series  AZ
0        started  54.242.44.224   i-09ea4f951f651687f  xenial  us-east-1a
0/lxd/0  started  10.0.0.122      juju-65a910-0-lxd-0  xenial  
1        started  52.90.29.98     i-03c3e35c2e8595491  xenial  us-east-1c
3        started  52.90.163.167   i-0ca0716985645d3f2  xenial  us-east-1d
4        started  52.86.161.22    i-02de3aa8efcd52366  xenial  us-east-1e
5        started  52.70.5.49      i-092ac5367e31188bb  xenial  us-east-1a
6        started  174.129.164.95  i-0a0718343068a5c94  xenial  us-east-1c

Relation      Provides                Consumes                Type
certificates  easyrsa                 etcd                    regular
certificates  easyrsa                 kubernetes-master       regular
certificates  easyrsa                 kubernetes-worker-cpu   regular
certificates  easyrsa                 kubernetes-worker-gpu   regular
certificates  easyrsa                 kubernetes-worker-gpu8  regular
cluster       etcd                    etcd                    peer
etcd          etcd                    flannel                 regular
etcd          etcd                    kubernetes-master       regular
cni           flannel                 kubernetes-master       regular
cni           flannel                 kubernetes-worker-cpu   regular
cni           flannel                 kubernetes-worker-gpu   regular
cni           flannel                 kubernetes-worker-gpu8  regular
cni           kubernetes-master       flannel                 subordinate
kube-dns      kubernetes-master       kubernetes-worker-cpu   regular
kube-dns      kubernetes-master       kubernetes-worker-gpu   regular
kube-dns      kubernetes-master       kubernetes-worker-gpu8  regular
cni           kubernetes-worker-cpu   flannel                 subordinate
juju-info     kubernetes-worker-gpu   cuda                    subordinate
cni           kubernetes-worker-gpu   flannel                 subordinate
juju-info     kubernetes-worker-gpu8  cuda                    subordinate
cni           kubernetes-worker-gpu8  flannel                 subordinate
```

Let us see what nvidia-smi gives us: 

```
juju ssh kubernetes-worker-gpu/0 sudo nvidia-smi
Tue Feb 14 13:28:42 2017       
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 375.26                 Driver Version: 375.26                    |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|===============================+======================+======================|
|   0  Tesla K80           On   | 0000:00:1E.0     Off |                    0 |
| N/A   33C    P0    81W / 149W |      0MiB / 11439MiB |     95%      Default |
+-------------------------------+----------------------+----------------------+
                                                                               
+-----------------------------------------------------------------------------+
| Processes:                                                       GPU Memory |
|  GPU       PID  Type  Process name                               Usage      |
|=============================================================================|
|  No running processes found                                                 |
+-----------------------------------------------------------------------------+
```

On the more powerful 8xlarge, 

```
juju ssh kubernetes-worker-gpu8/0 sudo nvidia-smi
Tue Feb 14 13:59:24 2017       
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 375.26                 Driver Version: 375.26                    |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|===============================+======================+======================|
|   0  Tesla K80           On   | 0000:00:17.0     Off |                    0 |
| N/A   41C    P8    31W / 149W |      0MiB / 11439MiB |      0%      Default |
+-------------------------------+----------------------+----------------------+
|   1  Tesla K80           On   | 0000:00:18.0     Off |                    0 |
| N/A   36C    P0    70W / 149W |      0MiB / 11439MiB |      0%      Default |
+-------------------------------+----------------------+----------------------+
|   2  Tesla K80           On   | 0000:00:19.0     Off |                    0 |
| N/A   44C    P0    57W / 149W |      0MiB / 11439MiB |      0%      Default |
+-------------------------------+----------------------+----------------------+
|   3  Tesla K80           On   | 0000:00:1A.0     Off |                    0 |
| N/A   38C    P0    70W / 149W |      0MiB / 11439MiB |      0%      Default |
+-------------------------------+----------------------+----------------------+
|   4  Tesla K80           On   | 0000:00:1B.0     Off |                    0 |
| N/A   43C    P0    57W / 149W |      0MiB / 11439MiB |      0%      Default |
+-------------------------------+----------------------+----------------------+
|   5  Tesla K80           On   | 0000:00:1C.0     Off |                    0 |
| N/A   38C    P0    69W / 149W |      0MiB / 11439MiB |      0%      Default |
+-------------------------------+----------------------+----------------------+
|   6  Tesla K80           On   | 0000:00:1D.0     Off |                    0 |
| N/A   44C    P0    58W / 149W |      0MiB / 11439MiB |      0%      Default |
+-------------------------------+----------------------+----------------------+
|   7  Tesla K80           On   | 0000:00:1E.0     Off |                    0 |
| N/A   38C    P0    71W / 149W |      0MiB / 11439MiB |     39%      Default |
+-------------------------------+----------------------+----------------------+
                                                                               
+-----------------------------------------------------------------------------+
| Processes:                                                       GPU Memory |
|  GPU       PID  Type  Process name                               Usage      |
|=============================================================================|
|  No running processes found                                                 |
+-----------------------------------------------------------------------------+
```

So yes!! We have our 8 local GPUs as expected!! 



