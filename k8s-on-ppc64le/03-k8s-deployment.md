# Kubernetes Deployment
## Pre requisites

We will be running on ppc64le architecture which requires specific packages. Juju has the ability to manage "resources", which are essentially links to resources that will be userd in the deployment. Resources can be local or any http(s) downloadable content. 

You will find attached the tar files for the master, worker and flannel that work on ppc64le, which need to be locally present on the client node

<pre><code>
ubuntu@node01:~$ wget https://github.com/madeden/blogposts/blob/master/k8s-on-ppc64le/resources/kubernetes-master-v1.3.8-ppc64le.tar.gz
ubuntu@node01:~$ wget https://github.com/madeden/blogposts/blob/master/k8s-on-ppc64le/resources/kubernetes-worker-v1.3.8-ppc64le.tar.gz
ubuntu@node01:~$ wget https://github.com/madeden/blogposts/blob/master/k8s-on-ppc64le/resources/flannel.tar.gz
</pre></code>

## Deployment

After the download, you can start deploying and adding the right resources to the right charms

<pre><code>
juju deploy --to 0 cs:~containers/etcd-14
juju deploy --to 0 cs:~containers/kubernetes-master-4
juju deploy --to 0 cs:~containers/easyrsa-2
juju deploy --to 1 cs:~containers/kubernetes-worker-5
juju deploy cs:~containers/flannel-4
juju attach kubernetes-master kubernetes=./kubernetes-master-v1.3.8-ppc64le.tar.gz
juju attach kubernetes-worker kubernetes=./kubernetes-worker-v1.3.8-ppc64le.tar.gz
juju attach flannel flannel=./flannel.tar.gz
juju add-relation kubernetes-master:kube-api-endpoint kubernetes-worker:kube-api-endpoint
juju add-relation kubernetes-master:cluster-dns kubernetes-worker:kube-dns
juju add-relation kubernetes-master:certificates easyrsa:client
juju add-relation kubernetes-master:etcd etcd:db
juju add-relation kubernetes-master:sdn-plugin flannel:host
juju add-relation kubernetes-worker:certificates easyrsa:client
juju add-relation kubernetes-worker:sdn-plugin flannel:host
juju add-relation flannel:etcd etcd:db
</pre></code>

This will take quite a long time, but in the end: 

<pre><code>
ubuntu@node01:~$ juju status
Model    Controller  Cloud/Region         Version
default  k8s         localhost/localhost  2.0.0

App                Version  Status  Scale  Charm              Store       Rev  OS      Notes
easyrsa            3.0.1    active      1  easyrsa            jujucharms    2  ubuntu  
etcd               2.2.5    active      1  etcd               jujucharms   14  ubuntu  
flannel            0.6.2    active      2  flannel            jujucharms    4  ubuntu  
kubernetes-master  1.3.8    active      1  kubernetes-master  jujucharms    4  ubuntu  
kubernetes-worker  1.3.8    active      1  kubernetes-worker  jujucharms    5  ubuntu  

Unit                  Workload  Agent  Machine  Public address  Ports           Message
easyrsa/0*            active    idle   0        node02                          Certificate Authority connected.
etcd/0*               active    idle   0        node02          2379/tcp        Healthy with 1 known peers. (leader)
kubernetes-master/0*  active    idle   0        node02          6443/tcp        Kubernetes master running.
  flannel/0*          active    idle            node02                          Flannel subnet 10.1.88.1/24
kubernetes-worker/0*  active    idle   1        node03          80/tcp,443/tcp  Kubernetes worker running.
  flannel/1           active    idle            node03                          Flannel subnet 10.1.9.1/24

Machine  State    DNS     Inst id        Series  AZ
0        started  node02  manual:node02  xenial  
1        started  node03  manual:node03  xenial  

Relation      Provides           Consumes           Type
certificates  easyrsa            kubernetes-master  regular
certificates  easyrsa            kubernetes-worker  regular
cluster       etcd               etcd               peer
etcd          etcd               flannel            regular
etcd          etcd               kubernetes-master  regular
sdn-plugin    flannel            kubernetes-master  regular
sdn-plugin    flannel            kubernetes-worker  regular
host          kubernetes-master  flannel            subordinate
kube-dns      kubernetes-master  kubernetes-worker  regular
host          kubernetes-worker  flannel            subordinate
</pre></code>

Sweeeet! We have Kubernetes up & running

## Adding CUDA

<pre><code>

</pre></code>



