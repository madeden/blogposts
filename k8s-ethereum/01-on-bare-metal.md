# Putting it to the test
## on Bare Metal

Adding the T630 to MAAS is a breeze. If you don't change the default iDRAC username password (root/calvin), the only thing you have to do it connect them to a network (a specific VLAN for management is preferred of course), set the IP address, and add to MAAS with an IPMI Power type. 

Then commission the nodes as you would with any other. This time, you won't need to press the power button like I had to with the NUC cluster: MAAS will trigger via the IPMI card directly, request a PXE boot, and register the node. 

Once that is done, I tagged them "gpu" to make sure to recognize them. 

Then 

<pre><code>
juju bootstrap maas
juju deploy src/bundles/k8s-1cpu-3gpu.yaml
watch -c juju status --color
</code></pre>

Now wait... You will see at some point that the charm is now installing CUDA drivers. At the end, 

<pre><code>
Model    Controller  Cloud/Region  Version
default  k8s         maas          2.1.2.1

App                    Version  Status  Scale  Charm              Store       Rev  OS      Notes
easyrsa                3.0.1    active      1  easyrsa            jujucharms    8  ubuntu
etcd                   2.3.8    active      1  etcd               jujucharms   29  ubuntu
flannel                0.7.0    active      5  flannel            jujucharms   13  ubuntu
kubernetes-master      1.6.1    active      1  kubernetes-master  jujucharms   17  ubuntu  exposed
kubernetes-worker-cpu  1.6.1    active      1  kubernetes-worker  jujucharms   22  ubuntu  exposed
kubernetes-worker-gpu  1.6.1    active      3  kubernetes-worker  jujucharms   22  ubuntu  exposed

Unit                      Workload  Agent  Machine  Public address  Ports           Message
easyrsa/0*                active    idle   0/lxd/0  172.16.0.8                      Certificate Authority connected.
etcd/0*                   active    idle   0        172.16.0.4      2379/tcp        Healthy with 1 known peer
kubernetes-master/0*      active    idle   0        172.16.0.4      6443/tcp        Kubernetes master running.
  flannel/1               active    idle            172.16.0.4                      Flannel subnet 10.1.9.1/24
kubernetes-worker-cpu/0*  active    idle   1        172.16.0.5      80/tcp,443/tcp  Kubernetes worker running.
  flannel/0*              active    idle            172.16.0.5                      Flannel subnet 10.1.20.1/24
kubernetes-worker-gpu/0   active    idle   2        172.16.0.6      80/tcp,443/tcp  Kubernetes worker running.
  flannel/2               active    idle            172.16.0.6                      Flannel subnet 10.1.91.1/24
kubernetes-worker-gpu/1   active    idle   3        172.16.0.7      80/tcp,443/tcp  Kubernetes worker running.
  flannel/4               active    idle            172.16.0.7                      Flannel subnet 10.1.19.1/24
kubernetes-worker-gpu/2*  active    idle   4        172.16.0.3      80/tcp,443/tcp  Kubernetes worker running.
  flannel/3               active    idle            172.16.0.3                      Flannel subnet 10.1.15.1/24

Machine  State    DNS         Inst id              Series  AZ
0        started  172.16.0.4  br68gs               xenial  default
0/lxd/0  started  172.16.0.8  juju-5a80fa-0-lxd-0  xenial
1        started  172.16.0.5  qkrh4t               xenial  default
2        started  172.16.0.6  4y74eg               xenial  default
3        started  172.16.0.7  w3pgw7               xenial  default
4        started  172.16.0.3  se8wy7               xenial  default

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

And now: 

<pre><code>
juju ssh kubernetes-worker-gpu/0 "sudo nvidia-smi"
Tue Apr 18 06:08:35 2017       
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 375.51                 Driver Version: 375.51                    |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|===============================+======================+======================|
|   0  GeForce GTX 106...  Off  | 0000:04:00.0     Off |                  N/A |
| 28%   37C    P0    28W / 120W |      0MiB /  6072MiB |      0%      Default |
+-------------------------------+----------------------+----------------------+
|   1  Quadro P5000        Off  | 0000:83:00.0     Off |                  Off |
|  0%   43C    P0    39W / 180W |      0MiB / 16273MiB |      2%      Default |
+-------------------------------+----------------------+----------------------+
                                                                               
+-----------------------------------------------------------------------------+
| Processes:                                                       GPU Memory |
|  GPU       PID  Type  Process name                               Usage      |
|=============================================================================|
|  No running processes found                                                 |
+-----------------------------------------------------------------------------+
</code></pre>

That's it, my 2 cards are in there: 1060GTX and P5000. I didn't do anything about it, it was completely automated. 

The important option in the bundle is: 

<pre><code>
    options: 
      "allow-privileged": "true"
</code></pre>   

If you want to prevent privileged containers until absolutely necessary, you can use the tag "auto", which will only activate them if GPUs are detected. 

