## In the cloud

It's no different in the cloud. The only change is the type of machines we request from AWS:

<pre><code>
juju bootstrap aws/us-east-1 
juju deploy src/bundles/k8s-1cpu-3gpu-aws.yaml
watch -c juju status --color
</code></pre>

Now wait... 

<pre><code>
Model    Controller     Cloud/Region   Version
default  aws-us-east-1  aws/us-east-1  2.2-beta2

App                    Version  Status       Scale  Charm              Store       Rev  OS      Notes
easyrsa                3.0.1    active           1  easyrsa            jujucharms    8  ubuntu
etcd                   2.3.8    active           1  etcd               jujucharms   29  ubuntu
flannel                0.7.0    active           2  flannel            jujucharms   13  ubuntu
kubernetes-master      1.6.1    waiting          1  kubernetes-master  jujucharms   17  ubuntu  exposed
kubernetes-worker-cpu  1.6.1    active           1  kubernetes-worker  jujucharms   22  ubuntu  exposed
kubernetes-worker-gpu           maintenance      3  kubernetes-worker  jujucharms   22  ubuntu  exposed

Unit                      Workload     Agent      Machine  Public address  Ports           Message
easyrsa/0*                active       idle       0/lxd/0  10.0.201.114                    Certificate Authority connected.
etcd/0*                   active       idle       0        52.91.177.229   2379/tcp        Healthy with 1 known peer
kubernetes-master/0*      waiting      idle       0        52.91.177.229   6443/tcp        Waiting for kube-system pods to start
  flannel/0*              active       idle                52.91.177.229                   Flannel subnet 10.1.4.1/24
kubernetes-worker-cpu/0*  active       idle       1        34.207.180.182  80/tcp,443/tcp  Kubernetes worker running.
  flannel/1               active       idle                34.207.180.182                  Flannel subnet 10.1.29.1/24
kubernetes-worker-gpu/0   maintenance  executing  2        54.146.144.181                  (install) Installing CUDA
kubernetes-worker-gpu/1   maintenance  executing  3        54.211.83.217                   (install) Installing CUDA
kubernetes-worker-gpu/2*  maintenance  executing  4        54.237.248.219                  (install) Installing CUDA

Machine  State    DNS             Inst id              Series  AZ          Message
0        started  52.91.177.229   i-0d71d98b872d201f5  xenial  us-east-1a  running
0/lxd/0  started  10.0.201.114    juju-29e858-0-lxd-0  xenial              Container started
1        started  34.207.180.182  i-04f2b75f3ab88f842  xenial  us-east-1a  running
2        started  54.146.144.181  i-0113e8a722778330c  xenial  us-east-1a  running
3        started  54.211.83.217   i-07c8c81f5e4cad6be  xenial  us-east-1a  running
4        started  54.237.248.219  i-00ae437291c88210f  xenial  us-east-1a  running

Relation      Provides               Consumes               Type
certificates  easyrsa                etcd                   regular
certificates  easyrsa                kubernetes-master      regular
certificates  easyrsa                kubernetes-worker-cpu  regular
certificates  easyrsa                kubernetes-worker-gpu  regular
cluster       etcd                   etcd                   peer
etcd          etcd                   flannel                regular
etcd          etcd                   kubernetes-master      regular
cni           flannel                kubernetes-master      regular
cni           flannel                kubernetes-worker-cpu  regular
cni           flannel                kubernetes-worker-gpu  regular
cni           kubernetes-master      flannel                subordinate
kube-dns      kubernetes-master      kubernetes-worker-cpu  regular
kube-dns      kubernetes-master      kubernetes-worker-gpu  regular
cni           kubernetes-worker-cpu  flannel                subordinate
cni           kubernetes-worker-gpu  flannel                subordinate
</code></pre>

I was able to capture the moment where it is installing CUDA so you can see it... When it's done: 

<pre><code>
juju ssh kubernetes-worker-gpu/0 "sudo nvidia-smi"
Tue Apr 18 08:50:23 2017       
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 375.51                 Driver Version: 375.51                    |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|===============================+======================+======================|
|   0  Tesla K80           Off  | 0000:00:1E.0     Off |                    0 |
| N/A   52C    P0    67W / 149W |      0MiB / 11439MiB |     98%      Default |
+-------------------------------+----------------------+----------------------+
                                                                               
+-----------------------------------------------------------------------------+
| Processes:                                                       GPU Memory |
|  GPU       PID  Type  Process name                               Usage      |
|=============================================================================|
|  No running processes found                                                 |
+-----------------------------------------------------------------------------+
Connection to 54.146.144.181 closed.
</code></pre>

That's it, you can see the K80 from the p2.xlarge instance. 