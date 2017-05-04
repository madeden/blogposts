## In GCE

As we want to use GPUs, exactly as for AWS, we need to be careful about the AZ we are using. For example, in us-east1, only us-east1-d has GPU enablement. Google provides documentation about the locations on [this page](https://cloud.google.com/compute/docs/gpus/?authuser=1).

GCE has a very specific way of managing AZs and subnets, and also doesn't provide instance types for GPU enabled machines (GPUs can be added to pretty much any instance).

Therefore, in order to deploy K8s on GPUs on GCE, you have to 

0. Bootstrap and deploy the control plane of Kubernetes 
1. Create the GPU instances manually
2. Add these machines to Juju once they are started
3. Tell Juju to deploy the worker on them

This forbids the use of a bundle, so most of the deployment will be manual. Let's see how that works: 

<pre><code>
juju bootstrap google/us-east1 
juju add-model k8s

# Manually deploy the control plane and a first worker for CPU only base
juju deploy cs:~containers/kubernetes-master-17
juju deploy cs:~containers/etcd-29 --to 0
juju deploy cs:~containers/easyrsa-8 --to lxd:0
juju deploy cs:~containers/flannel-13
juju deploy cs:~containers/kubernetes-worker-22
juju expose kubernetes-master
juju expose kubernetes-worker

# Add Juju SSH key to project
gcloud compute project-info add-metadata \
	--metadata-from-file sshKeys=~/.local/share/juju/ssh/juju_id_rsa_gce.pub

# Note: this .pub is a copy of the juju_id_rsa.pub file adapted for gce, looking like
# ubuntu:ssh-rsa [KEY VALUE] ubuntu
# See documentation [here](https://cloud.google.com/compute/docs/instances/adding-removing-ssh-keys#project-wide)

# Create machines
for i in $(seq 1 1 3)
do 
	gcloud beta compute instances create kubernetes-worker-gpu-${i} \
		--machine-type n1-standard-2 \
		--zone us-east1-d \
		--accelerator type=nvidia-tesla-k80,count=1 \
		--image-family ubuntu-1604-lts \
		--image-project ubuntu-os-cloud \
		--maintenance-policy TERMINATE \
		--metadata block-project-ssh-keys=FALSE \
		--restart-on-failure
	sleep 5
done

# For each machine, we get an answer like: 
## Created [https://www.googleapis.com/compute/beta/projects/jaas-151616/zones/us-east1-d/instances/kubernetes-worker-gpu-2].
## NAME                     ZONE        MACHINE_TYPE   PREEMPTIBLE  INTERNAL_IP  EXTERNAL_IP   STATUS
## kubernetes-worker-gpu-2  us-east1-d  n1-standard-2               10.142.0.5   35.185.74.56  RUNNING

# Take good note of the public IP of each, then, for each machine

juju add-machine ssh:ubuntu@35.185.74.56 # use the Public IP

# You'll get answers like
## WARNING Skipping CA server verification, using Insecure option
## created machine 2
</code></pre>

At this stage, the status of Juju will look like: 

<pre><code>
$ juju status
Model  Controller  Cloud/Region     Version      SLA
k8s    k8s         google/us-east1  2.2-beta4.1  unsupported

App                Version  Status   Scale  Charm              Store       Rev  OS      Notes
easyrsa            3.0.1    active       1  easyrsa            jujucharms    8  ubuntu  
etcd               2.3.8    blocked      1  etcd               jujucharms   29  ubuntu  
kubernetes-master  1.6.1    blocked      1  kubernetes-master  jujucharms   17  ubuntu  exposed
kubernetes-worker  1.6.1    blocked      1  kubernetes-worker  jujucharms   22  ubuntu  exposed

Unit                  Workload  Agent  Machine  Public address  Ports  Message
easyrsa/0*            active    idle   0/lxd/0  10.0.19.96             Certificate Authority ready.
etcd/0*               blocked   idle   0        35.185.1.113           Missing relation to certificate authority.
kubernetes-master/0*  blocked   idle   0        35.185.1.113           Relate kubernetes-master:kube-control kubernetes-worker:kube-control
kubernetes-worker/0*  blocked   idle   1        35.185.118.158         Relate kubernetes-worker:kube-control kubernetes-master:kube-control

Machine  State    DNS             Inst id                Series  AZ          Message
0        started  35.185.1.113    juju-f1c96a-0          xenial  us-east1-b  RUNNING
0/lxd/0  started  10.0.19.96      juju-f1c96a-0-lxd-0    xenial              Container started
1        started  35.185.118.158  juju-f1c96a-1          xenial  us-east1-c  RUNNING
2        started  35.185.22.159   manual:35.185.22.159   xenial              Manually provisioned machine
3        started  35.185.74.56    manual:35.185.74.56    xenial              Manually provisioned machine
4        started  35.185.112.159  manual:35.185.112.159  xenial              Manually provisioned machine

Relation  Provides  Consumes  Type
cluster   etcd      etcd      peer
</code></pre>

You can note that we have machines 2 to 4 being added as manual instances. Now we can tell juju to use these for the additional workers: 

<pre><code>
# Adding all machines as workers
for unit in $(seq 2 1 4)
do
	juju add-unit kubernetes-worker --to ${unit}
done

# Add Relations between charms
juju add-relation kubernetes-master:kube-api-endpoint  kubernetes-worker:kube-api-endpoint
juju add-relation kubernetes-master:kube-control  kubernetes-worker:kube-control
juju add-relation kubernetes-master:certificates  easyrsa:client
juju add-relation kubernetes-master:etcd  etcd:db
juju add-relation kubernetes-worker:certificates  easyrsa:client
juju add-relation etcd:certificates  easyrsa:client
juju add-relation flannel:etcd  etcd:db
juju add-relation flannel:cni  kubernetes-master:cni
juju add-relation flannel:cni  kubernetes-worker:cni

# Watch results
watch -c juju status --color
</code></pre>

Now wait... 

<pre><code>
$ juju status
Model  Controller  Cloud/Region     Version      SLA
k8s    k8s         google/us-east1  2.2-beta4.1  unsupported

App                Version  Status  Scale  Charm              Store       Rev  OS      Notes
easyrsa            3.0.1    active      1  easyrsa            jujucharms    8  ubuntu  
etcd               2.3.8    active      1  etcd               jujucharms   29  ubuntu  
flannel            0.7.0    active      5  flannel            jujucharms   13  ubuntu  
kubernetes-master  1.6.1    active      1  kubernetes-master  jujucharms   17  ubuntu  
kubernetes-worker  1.6.1    active      4  kubernetes-worker  jujucharms   22  ubuntu  

Unit                  Workload  Agent  Machine  Public address  Ports           Message
easyrsa/0*            active    idle   0/lxd/0  10.0.199.102                    Certificate Authority connected.
etcd/0*               active    idle   0        35.185.22.159   2379/tcp        Healthy with 1 known peer
kubernetes-master/0*  active    idle   0        35.185.22.159   6443/tcp        Kubernetes master running.
  flannel/0           active    idle            35.185.22.159                   Flannel subnet 10.1.96.1/24
kubernetes-worker/0*  active    idle   1        35.185.74.56    80/tcp,443/tcp  Kubernetes worker running.
  flannel/1           active    idle            35.185.74.56                    Flannel subnet 10.1.59.1/24
kubernetes-worker/1   active    idle   2        35.185.112.159  80/tcp,443/tcp  Kubernetes worker running.
  flannel/2*          active    idle            35.185.112.159                  Flannel subnet 10.1.77.1/24
kubernetes-worker/2   active    idle   3        35.185.1.113    80/tcp,443/tcp  Kubernetes worker running.
  flannel/4           active    idle            35.185.1.113                    Flannel subnet 10.1.22.1/24
kubernetes-worker/3   active    idle   4        35.185.118.158  80/tcp,443/tcp  Kubernetes worker running.
  flannel/3           active    idle            35.185.118.158                  Flannel subnet 10.1.53.1/24

Machine  State    DNS             Inst id              Series  AZ          Message
0        started  35.185.22.159   juju-27aae9-0        xenial  us-east1-d  RUNNING
0/lxd/0  started  10.0.199.102    juju-27aae9-0-lxd-0  xenial              Container started
1        started  35.185.74.56    juju-27aae9-1        xenial  us-east1-d  RUNNING
2        started  35.185.112.159  juju-27aae9-2        xenial  us-east1-d  RUNNING
3        started  35.185.1.113    juju-27aae9-3        xenial  us-east1-d  RUNNING
4        started  35.185.118.158  juju-27aae9-4        xenial  us-east1-d  RUNNING

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
kube-control  kubernetes-master  kubernetes-worker  regular
cni           kubernetes-worker  flannel            subordinate

</code></pre>

I was able to capture the moment where it is installing CUDA so you can see it... When it's done: 

<pre><code>
juju ssh 2 "sudo nvidia-smi"
Thu May  4 07:20:37 2017       
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 375.51                 Driver Version: 375.51                    |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|===============================+======================+======================|
|   0  Tesla K80           Off  | 0000:00:04.0     Off |                    0 |
| N/A   74C    P0    77W / 149W |      0MiB / 11439MiB |    100%      Default |
+-------------------------------+----------------------+----------------------+
                                                                               
+-----------------------------------------------------------------------------+
| Processes:                                                       GPU Memory |
|  GPU       PID  Type  Process name                               Usage      |
|=============================================================================|
|  No running processes found                                                 |
+-----------------------------------------------------------------------------+
</code></pre>

That's it, you can see the K80 from the instance. Now let's see from the Kubernetes perspective: 

<pre><code>
juju scp kubernetes-master/0:config ~/.kube/config
kubectl get nodes --show-labels
NAME                      STATUS    AGE       VERSION   LABELS
juju-f1c96a-1             Ready     28m       v1.6.1    beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/hostname=juju-f1c96a-1
kubernetes-worker-gpu-1   Ready     17m       v1.6.1    beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,cuda=true,gpu=true,kubernetes.io/hostname=kubernetes-worker-gpu-1
kubernetes-worker-gpu-2   Ready     17m       v1.6.1    beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,cuda=true,gpu=true,kubernetes.io/hostname=kubernetes-worker-gpu-2
kubernetes-worker-gpu-3   Ready     17m       v1.6.1    beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,cuda=true,gpu=true,kubernetes.io/hostname=kubernetes-worker-gpu-3
</code></pre>

As you can see, labels have been added to the nodes with cuda=true and gpu=true. 

Now as usual we can deploy our nvidia-smi job


<pre><code>
kubectl create -f ./src/nvidia-smi.yaml
</code></pre>

Then after some time...
