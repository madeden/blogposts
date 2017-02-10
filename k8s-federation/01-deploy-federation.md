# Deploying 

In this section we will

* Deploy k8s on Azure, AWS and GKE
* Install tools for the federation
* Deploy the Federation

## Microsoft Azure

Let's spawn a k8s cluster in Azure first: 

```
# Bootstrap the Juju Controller
juju bootstrap azure/westeurope azure \
  --bootstrap-constraints "root-disk=64G mem=8G" \
  --bootstrap-series xenial
# Deploy Canonical Distribution of Kubernetes
juju deploy src/bundle/k8s-azure.yaml
```
Azure is relatively slow to spin up the whole thing, so you can let it go and we'll come back to it later. 

## Amazon AWS

juju bootstrap aws/us-west-2 k8s-us-west-2 --to "subnet=subnet-bb1ab2dc" --config vpc-id=vpc-fa6dfa9d --config vpc-id-force=true --bootstrap-constraints "root-disk=128G mem=8G" --credential canonical --bootstrap-series xenial

```
# Bootstrap the Juju Controller
juju bootstrap aws/us-west-2 aws \
  --bootstrap-constraints "root-disk=64G mem=8G" \
  --bootstrap-series xenial
# Deploy Canonical Distribution of Kubernetes
juju deploy src/bundle/k8s-aws.yaml
```

This takes about 10min, so let's let it run and we'll come back to it again later

## GKE

```
# Spin up the DNS Zone
gcloud dns managed-zones create federation \
  --description "Kubernetes federation testing" \
  --dns-name demo.madeden.com
# Spin up a GKE cluster
gcloud container clusters create gke \
  --zone=us-east1-b \
  --scopes "cloud-platform,storage-ro,service-control,service-management,https://www.googleapis.com/auth/ndev.clouddns.readwrite" \
  --num-nodes=2
```

You will need a globally available DNS, that you can programmatically drive, which is why we use this Google Cloud DNS. I had to configure it to delegate the sub domain from Gandi, which is reasonably easy as Google gives you all the instructions you need on their [help page](https://cloud.google.com/dns/zones/). 

# Federation 
## installing kubefed

Since 1.5 Kubernetes comes with a tool called [KubeFed](https://kubernetes.io/docs/admin/federation/kubefed/) which manages the lifecycle of federations. 

Install it with: 

```
curl -O https://storage.googleapis.com/kubernetes-release/release/v1.5.2/kubernetes-client-linux-amd64.tar.gz
tar -xzvf kubernetes-client-linux-amd64.tar.gz
sudo cp kubernetes/client/bin/kubefed /usr/local/bin
sudo chmod +x /usr/local/bin/kubefed
sudo cp kubernetes/client/bin/kubectl /usr/local/bin
sudo chmod +x /usr/local/bin/kubectl
mkdir -p ~/.kube
```

## Configuring kubectl

On Azure, check that your cluster is now up & running: 

```
# Switch Juju to the Azure cluster
juju switch azure
# Get status
juju status
# Which gets you (if finished)
Model    Controller        Cloud/Region      Version
default  azure             azure/westeurope  2.1-beta5

App                Version  Status  Scale  Charm              Store       Rev  OS      Notes
easyrsa            3.0.1    active      1  easyrsa            jujucharms    6  ubuntu  
etcd               2.2.5    active      3  etcd               jujucharms   23  ubuntu  
flannel            0.7.0    active      4  flannel            jujucharms   10  ubuntu  
kubernetes-master  1.5.2    active      1  kubernetes-master  jujucharms   11  ubuntu  exposed
kubernetes-worker  1.5.2    active      3  kubernetes-worker  jujucharms   13  ubuntu  exposed

Unit                  Workload  Agent  Machine  Public address  Ports           Message
easyrsa/0*            active    idle   0        40.114.244.142                  Certificate Authority connected.
etcd/0                active    idle   1        40.114.247.142  2379/tcp        Healthy with 3 known peers.
etcd/1*               active    idle   2        104.47.167.187  2379/tcp        Healthy with 3 known peers.
etcd/2                active    idle   3        104.47.163.137  2379/tcp        Healthy with 3 known peers.
kubernetes-master/0*  active    idle   4        40.114.243.251  6443/tcp        Kubernetes master running.
  flannel/2           active    idle            40.114.243.251                  Flannel subnet 10.1.96.1/24
kubernetes-worker/0   active    idle   5        104.47.162.134  80/tcp,443/tcp  Kubernetes worker running.
  flannel/1           active    idle            104.47.162.134                  Flannel subnet 10.1.94.1/24
kubernetes-worker/1*  active    idle   6        104.47.162.82   80/tcp,443/tcp  Kubernetes worker running.
  flannel/0*          active    idle            104.47.162.82                   Flannel subnet 10.1.58.1/24
kubernetes-worker/2   active    idle   7        104.47.160.138  80/tcp,443/tcp  Kubernetes worker running.
  flannel/3           active    idle            104.47.160.138                  Flannel subnet 10.1.43.1/24

Machine  State    DNS             Inst id    Series  AZ
0        started  40.114.244.142  machine-0  xenial  
1        started  40.114.247.142  machine-1  xenial  
2        started  104.47.167.187  machine-2  xenial  
3        started  104.47.163.137  machine-3  xenial  
4        started  40.114.243.251  machine-4  xenial  
5        started  104.47.162.134  machine-5  xenial  
6        started  104.47.162.82   machine-6  xenial  
7        started  104.47.160.138  machine-7  xenial  

Relation      Provides           Consumes           Type
certificates  easyrsa            etcd               regular
certificates  easyrsa            kubernetes-master  regular
certificates  easyrsa            kubernetes-worker  regular
cluster       etcd               etcd               peer
etcd          etcd               flannel            regular
etcd          etcd               kubernetes-master  regular
cni           flannel            kubernetes-master  regular
cni           flannel            kubernetes-worker  regular
cni           kubernetes-master  flannel            subordinate
kube-dns      kubernetes-master  kubernetes-worker  regular
cni           kubernetes-worker  flannel            subordinate
```

Now download the config file 

```
juju scp kubernetes-master/0:/home/ubuntu/config ./config-azure
```

Repeat the operation on AWS 

```
juju switch aws
Model    Controller     Cloud/Region   Version
default  aws            aws/us-west-2  2.1-beta5

App                Version  Status  Scale  Charm              Store       Rev  OS      Notes
easyrsa            3.0.1    active      1  easyrsa            jujucharms    6  ubuntu  
etcd               2.2.5    active      3  etcd               jujucharms   23  ubuntu  
flannel            0.7.0    active      4  flannel            jujucharms   10  ubuntu  
kubernetes-master  1.5.2    active      1  kubernetes-master  jujucharms   11  ubuntu  exposed
kubernetes-worker  1.5.2    active      3  kubernetes-worker  jujucharms   13  ubuntu  exposed

Unit                  Workload  Agent  Machine  Public address  Ports           Message
easyrsa/0*            active    idle   2        10.0.251.198                    Certificate Authority connected.
etcd/0*               active    idle   1        10.0.252.237    2379/tcp        Healthy with 3 known peers.
etcd/1                active    idle   6        10.0.251.143    2379/tcp        Healthy with 3 known peers.
etcd/2                active    idle   7        10.0.251.31     2379/tcp        Healthy with 3 known peers.
kubernetes-master/0*  active    idle   0        35.164.145.16   6443/tcp        Kubernetes master running.
  flannel/0*          active    idle            35.164.145.16                   Flannel subnet 10.1.37.1/24
kubernetes-worker/0*  active    idle   3        52.27.16.150    80/tcp,443/tcp  Kubernetes worker running.
  flannel/3           active    idle            52.27.16.150                    Flannel subnet 10.1.11.1/24
kubernetes-worker/1   active    idle   4        52.10.62.234    80/tcp,443/tcp  Kubernetes worker running.
  flannel/1           active    idle            52.10.62.234                    Flannel subnet 10.1.43.1/24
kubernetes-worker/2   active    idle   5        52.27.1.171     80/tcp,443/tcp  Kubernetes worker running.
  flannel/2           active    idle            52.27.1.171                     Flannel subnet 10.1.68.1/24

Machine  State    DNS            Inst id              Series  AZ
0        started  35.164.145.16  i-0a3fdb3ce9590cb7e  xenial  us-west-2a
1        started  10.0.252.237   i-0dcbd977bee04563b  xenial  us-west-2b
2        started  10.0.251.198   i-04cedb17e22064212  xenial  us-west-2a
3        started  52.27.16.150   i-0f44e7e27f776aebf  xenial  us-west-2b
4        started  52.10.62.234   i-02ff8041a61550802  xenial  us-west-2a
5        started  52.27.1.171    i-0a4505185421bbdaf  xenial  us-west-2a
6        started  10.0.251.143   i-05a855d5c0c6f847d  xenial  us-west-2a
7        started  10.0.251.31    i-03f1aafe15d163a34  xenial  us-west-2a

Relation      Provides           Consumes           Type
certificates  easyrsa            etcd               regular
certificates  easyrsa            kubernetes-master  regular
certificates  easyrsa            kubernetes-worker  regular
cluster       etcd               etcd               peer
etcd          etcd               flannel            regular
etcd          etcd               kubernetes-master  regular
cni           flannel            kubernetes-master  regular
cni           flannel            kubernetes-worker  regular
cni           kubernetes-master  flannel            subordinate
kube-dns      kubernetes-master  kubernetes-worker  regular
cni           kubernetes-worker  flannel            subordinate
```

```
juju scp kubernetes-master/0:/home/ubuntu/config ./config-aws
```

Now for GKE

```
gcloud container clusters get-credentials gce --zone=us-east1-b
```

This last operation will actually create or modify your **~/.kube/config** file for GKE, so you can query the context directly from kubectl. GKE has this tendency of creating veryyyyyy looooong naaaaaames, and we just want a short one right now to ease our command lines foo. 

```
# Identify the cluster name
LONG_NAME=$(kubectl config view -o jsonpath='{.contexts[*].name}')
# Replace it in kubeconfig
sed -i "s/$LONG_NAME/gke/g" ~/.kube/config
```

Now modify the files that Juju downloaded to integrate them into this config file. 

A few clever people built a tool to merge kubeconfig files together: [load-kubeconfig](https://github.com/Collaborne/load-kubeconfig)

```
# Install tool 
sudo npm install -g load-kubeconfig
# Replace the username and context name with our cloud names in both files and combine
for cloud in aws azure
do
  sed -i -e "s/juju-cluster/${cloud}/g" \
    -e "s/juju-context/${cloud}/g" \
    -e "s/ubuntu/${cloud}/g" \
    ./config-${cloud}
  load-kubeconfig ./config-${cloud}
done
```

Excellent, you can now very easily switch between the 3 cluster by using **--context={gke | aws | azure }**. 

## Labelling Nodes 

One of the goals of deploying Kubernetes federations is to ensure multi-region HA for the applications. Within regions, you would want also to have HA between AZs. As a result, you should consider deploying one cluster per AZ.

To a federation, nothing looks more like a k8s cluster than another k8s. You can't expect it to be region-aware without giving it a few hints. That is what we will be doing here. 

By default, Juju will give you the following labels:

```
# AWS
kubectl --context=aws get nodes --show-labels
NAME           STATUS    AGE       LABELS
ip-10-0-1-54   Ready     1d        beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/hostname=ip-10-0-1-54
ip-10-0-1-95   Ready     1d        beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/hostname=ip-10-0-1-95
ip-10-0-2-43   Ready     1d        beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/hostname=ip-10-0-2-43
# Azure
kubectl --context=azure get nodes --show-labels
NAME        STATUS    AGE       LABELS
machine-5   Ready     2h        beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/hostname=machine-5
machine-6   Ready     2h        beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/hostname=machine-6
machine-7   Ready     2h        beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/hostname=machine-7
```

You only have 3 clusters and different regions (AWS is US West 2, Azure is EU West, and GKE is US East 1), so we will fake a little bit

```
# Labelling the nodes of AWS for US West 2a (random pick)
for node in $(kubectl - aws get nodes -o json | jq --raw-output '.items[].metadata.name')
do
  kubectl --context=aws label nodes \
    ${node} \
    failure-domain.beta.kubernetes.io/region=us-west-2
  kubectl --context=aws label nodes \
    ${node} \
    failure-domain.beta.kubernetes.io/zone=us-west-2a
done
# Labelling the nodes of Azure for EU West 2a (random pick)
for node in $(kubectl - azure get nodes -o json | jq --raw-output '.items[].metadata.name')
do
  kubectl --context=azure label nodes \
    ${node} \
    failure-domain.beta.kubernetes.io/region=eu-west-2
  kubectl --context=azure label nodes \
    ${node} \
    failure-domain.beta.kubernetes.io/zone=eu-west-2a
done
```

**Note**: In a real context, you would have a lot more nodes to configure and a better strategy to adopt. This is just to explain that setting this parameter  in k8s is important when you federate clusters in order to manage failure of clusters and clouds. 

## Making sure clusters share the same GLBC

[This page](https://kubernetes.io/docs/user-guide/federation/federated-ingress/) clearly states that our GLBC must absolutely be the same across all clusters. As you deployed 2 clusters with Juju and one with GKE, this is not the case at this point. 

Let's delete the L7 LB on our Azure & AWS clusters to replace them with others similar to GKE

```
for cluster in aws azure
do
  # Delete old ones
  kubectl --context ${cloud} delete \
    rc/default-http-backend \
    rc/nginx-ingress-controller \
    svc/default-http-backend
  # Replace by new ones taken from GKE
  kubectl --context ${cloud} create -f \
    src/manifests/l7-svc.yaml
  kubectl --context ${cloud} create -f \
    src/manifests/l7-deployment.yaml

done
```

## Initializing the Federation 

Now we are ready to federate our clusters, which essentially means we are adding a cross cluster control plane, itself hosted in a third Kubernetes cluster. 

Federating clusters brings some goodness, such as

* Ability to define multi-clusters services, replicasets/deployments, ingresses,
* Failover of services between zones 
* Single point of service definition

Kubefed, which you installed earlier, is the official tool to the lifecycle of Federations, from init to destruction. We are going to use the GKE cluster to manage our 2 clusters in Azure and AWS. 

Initialize the control plane of our "Magic Ring" with

```
kubefed init magicring \
  --host-cluster-context=gke \
  --dns-zone-name="demo.madeden.net."
Federation API server is running at: 130.211.62.225
```

The command is simple, and takes care of installing

* a new namespace in the host cluster (GKE) called federation-system
* a new API server for the Federation
* a new Controller Manager for the Federation
* a new context in your kubeconfig file to interact specifically with this uber layer of Kubernetes, named after the Federation name

To control the Federation, we can now go back to kubectl and switch into its context

```
kubectl config use-context magicring
Switched to context "magicring".
```

Now add our 2 clusters to the Magic Ring

```
# add AWS
kubefed join aws \
  --host-cluster-context=gke
cluster "aws" created
# Now Azure
kubefed join azure \
  --host-cluster-context=gke
cluster "azure" created
```

These commands will create a pair of secrets based on your kubeconfig into the Federation Control Plane, so that it can interact with individual Kube API Servers. If you are planning to build a federation across VPNs or complex networks, this means you will have to make sure the control plane can talk to the various API endpoints you deployed. 

Finally we can query a new construct, "clusters": 

```
kubectl get clusters
NAME            STATUS    AGE
aws             Ready     1m
azure           Ready     1m
```

Congratulations, you have federated a pair of Kubernetes clusters in less than 30min!!! 


