# Deploying with Juju
## Bootstrapping the environment

Juju needs to "bootstrap" which brings up a first control node, which will host the Juju Controller, the initial database and various other requirements. This node is the reason we have 2 management nodes. The second one will be our k8s Master. 

In our setup our nodes have only manual power since WoL was removed from MAAS with v2.0. This means we'll need to trigger the bootstrap, wait for the node to be allocated, then start it manually. 

```
$ juju bootstrap maas-controller maas
Creating Juju controller "maas-controller" on maas
Bootstrapping model "controller"
Starting new instance for initial controller
Launching instance # This is where we start the node manually
WARNING no architecture was specified, acquiring an arbitrary node
 - 4y3h8w
Installing Juju agent on bootstrap instance
Preparing for Juju GUI 2.2.2 release installation
Waiting for address
Attempting to connect to 192.168.23.2:22
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
IT IS POSSIBLE THAT SOMEONE IS DOING SOMETHING NASTY!
Someone could be eavesdropping on you right now (man-in-the-middle attack)!
It is also possible that a host key has just been changed.
The fingerprint for the ECDSA key sent by the remote host is
SHA256:KLWhTUgPpRw0DHC5V7R9R1HlUcp+hiv2dlcn82ftkm8.
Please contact your system administrator.
Add correct host key in /home/scozannet/.ssh/known_hosts to get rid of this message.
Offending ECDSA key in /home/scozannet/.ssh/known_hosts:6
  remove with:
  ssh-keygen -f "/home/scozannet/.ssh/known_hosts" -R 192.168.23.2
Keyboard-interactive authentication is disabled to avoid man-in-the-middle attacks.
Logging to /var/log/cloud-init-output.log on remote host
Running apt-get update
Running apt-get upgrade
Installing package: curl
Installing package: cpu-checker
Installing package: bridge-utils
Installing package: cloud-utils
Installing package: tmux
Fetching tools: curl -sSfw 'tools from %{url_effective} downloaded: HTTP %{http_code}; time %{time_total}s; size %{size_download} bytes; speed %{speed_download} bytes/s ' --retry 10 -o $bin/tools.tar.gz <[https://streams.canonical.com/juju/tools/agent/2.0-beta15/juju-2.0-beta15-xenial-amd64.tgz]>
Bootstrapping Juju machine agent
Starting Juju machine agent (jujud-machine-0)
Bootstrap agent installed
Bootstrap complete, maas-controller now available.
```

And the MAAS GUI: 

![MAAS GUI](/pics/bootstrapping.png)

## Initial bundle deployment

We deploy the bundle file **k8s.yaml** below: 

```
series: xenial
services:
  "kubernetes-master":
    charm: "cs:~containers/kubernetes-master-6"
    num_units: 1
    to:
      - "0"
    expose: true
    annotations:
      "gui-x": "800"
      "gui-y": "850"
    constraints: tags=cpu-only
  flannel:
    charm: "cs:~containers/flannel-5"
    annotations:
      "gui-x": "450"
      "gui-y": "750"
  easyrsa:
    charm: "cs:~containers/easyrsa-3"
    num_units: 1
    to:
      - "0"
    annotations:
      "gui-x": "450"
      "gui-y": "550"
  "kubernetes-worker":
    charm: "cs:~containers/kubernetes-worker-8"
    num_units: 1
    to:
      - "1"
    expose: true
    annotations:
      "gui-x": "100"
      "gui-y": "850"
    constraints: tags=gpu
  etcd:
    charm: "cs:~containers/etcd-14"
    num_units: 1
    to:
      - "0"
    annotations:
      "gui-x": "800"
      "gui-y": "550"
relations:
  - - "kubernetes-master:kube-api-endpoint"
    - "kubernetes-worker:kube-api-endpoint"
  - - "kubernetes-master:cluster-dns"
    - "kubernetes-worker:kube-dns"
  - - "kubernetes-master:certificates"
    - "easyrsa:client"
  - - "kubernetes-master:etcd"
    - "etcd:db"
  - - "kubernetes-master:sdn-plugin"
    - "flannel:host"
  - - "kubernetes-worker:certificates"
    - "easyrsa:client"
  - - "kubernetes-worker:sdn-plugin"
    - "flannel:host"
  - - "flannel:etcd"
    - "etcd:db"
machines:
  "0":
    series: xenial
  "1":
    series: xenial
```

We can see that we have constraints on the nodes to force MAAS to pick up GPU nodes for the workers, and CPU node for the master. We pass the command

```
$ juju deploy k8s.yaml
```

That is it. This is the only command we will need to get a functional k8s running! 

The output is 

```
added charm cs:~containers/easyrsa-3
application easyrsa deployed (charm cs:~containers/easyrsa-3 with the series "xenial" defined by the bundle)
added resource easyrsa
annotations set for application easyrsa
added charm cs:~containers/etcd-14
application etcd deployed (charm cs:~containers/etcd-14 with the series "xenial" defined by the bundle)
annotations set for application etcd
added charm cs:~containers/flannel-5
application flannel deployed (charm cs:~containers/flannel-5 with the series "xenial" defined by the bundle)
added resource flannel
annotations set for application flannel
added charm cs:~containers/kubernetes-master-6
application kubernetes-master deployed (charm cs:~containers/kubernetes-master-6 with the series "xenial" defined by the bundle)
added resource kubernetes
application kubernetes-master exposed
annotations set for application kubernetes-master
added charm cs:~containers/kubernetes-worker-8
application kubernetes-worker deployed (charm cs:~containers/kubernetes-worker-8 with the series "xenial" defined by the bundle)
added resource kubernetes
application kubernetes-worker exposed
annotations set for application kubernetes-worker
created new machine 0 for holding easyrsa, etcd and kubernetes-master units
created new machine 1 for holding kubernetes-worker unit
related kubernetes-master:kube-api-endpoint and kubernetes-worker:kube-api-endpoint
related kubernetes-master:cluster-dns and kubernetes-worker:kube-dns
related kubernetes-master:certificates and easyrsa:client
related kubernetes-master:etcd and etcd:db
related kubernetes-master:sdn-plugin and flannel:host
related kubernetes-worker:certificates and easyrsa:client
related kubernetes-worker:sdn-plugin and flannel:host
related flannel:etcd and etcd:db
added easyrsa/0 unit to machine 0
added etcd/0 unit to machine 0
added kubernetes-master/0 unit to machine 0
added kubernetes-worker/0 unit to machine 1
deployment of bundle "k8s.yaml" completed
```

Which translates in the GUI as: 

![MAAS GUI](/pics/deploying-k8s.png)

```
$ juju status
MODEL    CONTROLLER       CLOUD/REGION  VERSION
default  maas-controller  maas          2.0-beta15

APP                VERSION  STATUS  EXPOSED  ORIGIN      CHARM              REV  OS
easyrsa            3.0.1    active  false    jujucharms  easyrsa            3    ubuntu
etcd               2.2.5    active  false    jujucharms  etcd               14   ubuntu
flannel            0.6.1            false    jujucharms  flannel            5    ubuntu
kubernetes-master  1.4.5    active  true     jujucharms  kubernetes-master  6    ubuntu
kubernetes-worker           active  true     jujucharms  kubernetes-worker  8    ubuntu

RELATION      PROVIDES           CONSUMES           TYPE
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

UNIT                 WORKLOAD  AGENT       MACHINE  PUBLIC-ADDRESS  PORTS           MESSAGE
easyrsa/0            active    idle        0        192.168.23.3                    Certificate Authority connected.
etcd/0               active    idle        0        192.168.23.3    2379/tcp        Healthy with 1 known peers. (leader)
kubernetes-master/0  active    idle        0        192.168.23.3    6443/tcp        Kubernetes master running.
  flannel/0          active    idle                 192.168.23.3                    Flannel subnet 10.1.57.1/24
kubernetes-worker/0  active    idle        1        192.168.23.4    80/tcp,443/tcp  Kubernetes worker running.
  flannel/1          active    idle                 192.168.23.4                    Flannel subnet 10.1.67.1/24
kubernetes-worker/1  active    executing   2        192.168.23.5                    (install) Container runtime available.
kubernetes-worker/2  unknown   allocating  3        192.168.23.7                    Waiting for agent initialization to finish
kubernetes-worker/3  unknown   allocating  4        192.168.23.6                    Waiting for agent initialization to finish

MACHINE  STATE    DNS           INS-ID  SERIES  AZ
0        started  192.168.23.3  4y3h8x  xenial  default
1        started  192.168.23.4  4y3h8y  xenial  default
2        started  192.168.23.5  4y3ha3  xenial  default
3        pending  192.168.23.7  4y3ha6  xenial  default
4        pending  192.168.23.6  4y3ha4  xenial  default
```

or 

![MAAS GUI](/pics/deploying-k8s-2.png)

At the end of the process we have: 

```
$ $ juju status
MODEL    CONTROLLER       CLOUD/REGION  VERSION
default  maas-controller  maas          2.0-beta15

APP                VERSION  STATUS  EXPOSED  ORIGIN      CHARM              REV  OS
cuda                                false    local       cuda               0    ubuntu
easyrsa            3.0.1    active  false    jujucharms  easyrsa            3    ubuntu
etcd               2.2.5    active  false    jujucharms  etcd               14   ubuntu
flannel            0.6.1            false    jujucharms  flannel            5    ubuntu
kubernetes-master  1.4.5    active  true     jujucharms  kubernetes-master  6    ubuntu
kubernetes-worker  1.4.5    active  true     jujucharms  kubernetes-worker  8    ubuntu

RELATION      PROVIDES           CONSUMES           TYPE
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

UNIT                 WORKLOAD  AGENT  MACHINE  PUBLIC-ADDRESS  PORTS           MESSAGE
easyrsa/0            active    idle   0        192.168.23.3                    Certificate Authority connected.
etcd/0               active    idle   0        192.168.23.3    2379/tcp        Healthy with 1 known peers. (leader)
kubernetes-master/0  active    idle   0        192.168.23.3    6443/tcp        Kubernetes master running.
  flannel/0          active    idle            192.168.23.3                    Flannel subnet 10.1.57.1/24
kubernetes-worker/0  active    idle   1        192.168.23.4    80/tcp,443/tcp  Kubernetes worker running.
  flannel/1          active    idle            192.168.23.4                    Flannel subnet 10.1.67.1/24
kubernetes-worker/1  active    idle   2        192.168.23.5    80/tcp,443/tcp  Kubernetes worker running.
  flannel/2          active    idle            192.168.23.5                    Flannel subnet 10.1.100.1/24
kubernetes-worker/2  active    idle   3        192.168.23.7    80/tcp,443/tcp  Kubernetes worker running.
  flannel/3          active    idle            192.168.23.7                    Flannel subnet 10.1.14.1/24
kubernetes-worker/3  active    idle   4        192.168.23.6    80/tcp,443/tcp  Kubernetes worker running.
  flannel/4          active    idle            192.168.23.6                    Flannel subnet 10.1.83.1/24

MACHINE  STATE    DNS           INS-ID  SERIES  AZ
0        started  192.168.23.3  4y3h8x  xenial  default
1        started  192.168.23.4  4y3h8y  xenial  default
2        started  192.168.23.5  4y3ha3  xenial  default
3        started  192.168.23.7  4y3ha6  xenial  default
4        started  192.168.23.6  4y3ha4  xenial  default

```


```
$ $ kubectl get nodes --show-labels
NAME      STATUS    AGE       LABELS
node02    Ready     1h        beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/hostname=node02
node03    Ready     1h        beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/hostname=node03
node04    Ready     57m       beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/hostname=node04
node05    Ready     58m       beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/hostname=node05

```

## Adding CUDA

CUDA does not have an official charm yet, so I wrote a hacky bash script to make it work, which you can find on [GitHub](https://github.com/SaMnCo/layer-nvidia-cuda)

### Building the charm

You'll want to do that on a x86 computer rather than the Rpi. You will need juju, charm and charm-tools installed there, and the ENV set

```
export JUJU_REPOSITORY=${HOME}/charms
export LAYER_PATH=${JUJU_REPOSITORY}/layers
export INTERFACE_PATH=${JUJU_REPOSITORY}/interfaces
```

```
$ cd ${LAYER_PATH}
$ git clone https://github.com/SaMnCo/layer-nvidia-cuda cuda
$ cd juju-layer-cuda
$ charm build
```

Which will create a new folder called **builds** JUJU_REPOSITORY, and another called **cuda** in there. Just scp that to the Raspberry Pi in a **charms** subfolder of your home. 

```
$ scp ${JUJU_REPOSITORY}/builds/cuda ${USER}@raspberrypi:/home/${USER}/charms/cuda
$ git clone https://github.com/SaMnCo/layer-nvidia-cuda cuda
$ cd juju-layer-cuda
$ charm build
```

### Deploying the charm

```
$ juju deploy --series xenial $HOME/charms/cuda
$ juju add-relation cuda kubernetes-worker
```

This will take some time (CUDA downloads gigabytes of code and binaries...), but ultimately we get to

```
$ juju status
MODEL    CONTROLLER       CLOUD/REGION  VERSION
default  maas-controller  maas          2.0-beta15

APP                VERSION  STATUS  EXPOSED  ORIGIN      CHARM              REV  OS
cuda                                false    local       cuda               0    ubuntu
easyrsa            3.0.1    active  false    jujucharms  easyrsa            3    ubuntu
etcd               2.2.5    active  false    jujucharms  etcd               14   ubuntu
flannel            0.6.1            false    jujucharms  flannel            5    ubuntu
kubernetes-master  1.4.5    active  true     jujucharms  kubernetes-master  6    ubuntu
kubernetes-worker  1.4.5    active  true     jujucharms  kubernetes-worker  8    ubuntu

RELATION      PROVIDES           CONSUMES           TYPE
juju-info     cuda               kubernetes-worker  regular
certificates  easyrsa            kubernetes-master  regular
certificates  easyrsa            kubernetes-worker  regular
cluster       etcd               etcd               peer
etcd          etcd               flannel            regular
etcd          etcd               kubernetes-master  regular
sdn-plugin    flannel            kubernetes-master  regular
sdn-plugin    flannel            kubernetes-worker  regular
host          kubernetes-master  flannel            subordinate
kube-dns      kubernetes-master  kubernetes-worker  regular
juju-info     kubernetes-worker  cuda               subordinate
host          kubernetes-worker  flannel            subordinate

UNIT                 WORKLOAD  AGENT  MACHINE  PUBLIC-ADDRESS  PORTS           MESSAGE
easyrsa/0            active    idle   0        192.168.23.3                    Certificate Authority connected.
etcd/0               active    idle   0        192.168.23.3    2379/tcp        Healthy with 1 known peers. (leader)
kubernetes-master/0  active    idle   0        192.168.23.3    6443/tcp        Kubernetes master running.
  flannel/0          active    idle            192.168.23.3                    Flannel subnet 10.1.57.1/24
kubernetes-worker/0  active    idle   1        192.168.23.4    80/tcp,443/tcp  Kubernetes worker running.
  cuda/2             active    idle            192.168.23.4                    CUDA installed and available
  flannel/1          active    idle            192.168.23.4                    Flannel subnet 10.1.67.1/24
kubernetes-worker/1  active    idle   2        192.168.23.5    80/tcp,443/tcp  Kubernetes worker running.
  cuda/0             active    idle            192.168.23.5                    CUDA installed and available
  flannel/2          active    idle            192.168.23.5                    Flannel subnet 10.1.100.1/24
kubernetes-worker/2  active    idle   3        192.168.23.7    80/tcp,443/tcp  Kubernetes worker running.
  cuda/3             active    idle            192.168.23.7                    CUDA installed and available
  flannel/3          active    idle            192.168.23.7                    Flannel subnet 10.1.14.1/24
kubernetes-worker/3  active    idle   4        192.168.23.6    80/tcp,443/tcp  Kubernetes worker running.
  cuda/1             active    idle            192.168.23.6                    CUDA installed and available
  flannel/4          active    idle            192.168.23.6                    Flannel subnet 10.1.83.1/24

MACHINE  STATE    DNS           INS-ID  SERIES  AZ
0        started  192.168.23.3  4y3h8x  xenial  default
1        started  192.168.23.4  4y3h8y  xenial  default
2        started  192.168.23.5  4y3ha3  xenial  default
3        started  192.168.23.7  4y3ha6  xenial  default
4        started  192.168.23.6  4y3ha4  xenial  default
```

Pretty awesome, we now have **CUDERNETES**!

### Validating the deployment

We can individually connect on every GPU node and run ```sudo nvidia-smi``` which returns: 

```
$ sudo nvidia-smi 
Wed Nov  9 06:06:44 2016       
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 367.57                 Driver Version: 367.57                    |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|===============================+======================+======================|
|   0  GeForce GTX 106...  Off  | 0000:02:00.0     Off |                  N/A |
| 28%   31C    P0    27W / 120W |      0MiB /  6072MiB |      0%      Default |
+-------------------------------+----------------------+----------------------+
                                                                               
+-----------------------------------------------------------------------------+
| Processes:                                                       GPU Memory |
|  GPU       PID  Type  Process name                               Usage      |
|=============================================================================|
|  No running processes found                                                 |
+-----------------------------------------------------------------------------+
```

