# Deploying Kubernetes 

Juju uses a notion of Bundle to represent applications. Bundles are yaml files that describe what you want to deploy and also the constraints of the deployment. It's really the point where design meets reality. 

Quick summary of the design targets

* etcd, PKI must be in a private subnet
* Master will be in a public subnet to expose the API. In a more production environment, you may want to deploy it in the private space, and add a public ELB to expose 6443. 
* Workers must be in a public subnet. Again, in a more production environment, you will want to put it in a private space, and expose a public ELB.
* etcd 
  * must be HA so 3 units;
  * can fit on t2.small but for resilience m3.medium is better suited (t2.small tend to get shot in the head pretty often by AWS).
* Workers 
  * must be scaled so 3 units as well;
  * m4.large instances for a standard combination of CPU/RAM/Network;
  * 64GB root disk to welcome many Docker images.
* Single Master for this simple deployment but need to scale later, hence adding a load balancer. 


Ready? In juju 2.0.x, you have to deploy manually so network spaces constraints are taken into account 

First, deploy your support applications with: 

```
juju deploy --constraints "instance-type=m3.medium spaces=private" cs:~containers/etcd-23
juju deploy --constraints "instance-type=m3.medium spaces=private" cs:~containers/easyrsa-6
```

Enforce the constraints and scale out etcd

juju set-constraints etcd "instance-type=m3.medium spaces=private"
juju add-unit -n2 etcd
```

Now, deploy the Kubernetes Core applications, enforce constraints and scale out: 

```
juju deploy --constraints "cpu-cores=2 mem=8G root-disk=32G spaces=public" cs:~containers/kubernetes-master-11
juju deploy --constraints "instance-type=m4.xlarge spaces=public" cs:~containers/kubernetes-worker-13
juju deploy cs:~containers/flannel-10
juju set-constraints kubernetes-worker "instance-type=m4.xlarge spaces=public"
juju add-unit -n2 kubernetes-worker
```

Create the relations between the components: 

```
juju add-relation kubernetes-master:cluster-dns kubernetes-worker:kube-dns
juju add-relation kubernetes-master:certificates easyrsa:client
juju add-relation etcd:certificates easyrsa:client
juju add-relation kubernetes-master:etcd etcd:db
juju add-relation kubernetes-worker:certificates easyrsa:client
juju add-relation flannel:etcd etcd:db
juju add-relation flannel:cni kubernetes-master:cni
juju add-relation flannel:cni kubernetes-worker:cni
juju add-relation kubernetes-worker:kube-api-endpoint kubernetes-master:kube-api-endpoint
```

and expose the master, to connect to the API, and the workers, to get access to the workloads: 

```
juju expose kubernetes-master
juju expose kubernetes-worker
```

You can track the deployment with

```
watch -c juju status --color
```

and get a dynamic view on: 

```
# juju status                    
Model    Controller     Cloud/Region   Version
default  k8s-us-west-2  aws/us-west-2  2.1-beta5

App                Version  Status  Scale  Charm              Store       Rev  OS      Notes
easyrsa            3.0.1    active      1  easyrsa            jujucharms    6  ubuntu  
etcd               2.2.5    active      3  etcd               jujucharms   23  ubuntu  
flannel            0.7.0    active      4  flannel            jujucharms   10  ubuntu  
kubernetes-master  1.5.2    active      1  kubernetes-master  jujucharms   11  ubuntu  exposed
kubernetes-worker  1.5.2    active      3  kubernetes-worker  jujucharms   13  ubuntu  

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

Here we can see how our nodes are spread across private and public subnets. 

* All etcd and easyrsa have private IP addresses displayed like 10.0.X.Y where X is randomly distributed between 251 and 252 and Y is DHCP from AWS
* All Master and Worker units have public IP addresses in 35.xx (first AZ) or 52.yy (second AZ). 

As you can scale network spaces and subnets by your own, you can also label nodes in specific areas, in order to run specific workloads on them. 

# Getting control of the cluster

First download kubectl & the kubeconfig file from the master

```
mkdir ~/.kube
juju scp kubernetes-master/0:/home/ubuntu/kubectl ./
juju scp kubernetes-master/0:/home/ubuntu/config ./.kube/
chmod +x kubectl && mv kubectl /usr/local/bin/
```

Test that the connection is ok with: 

```
kubectl get nodes --show-labels
NAME           STATUS    AGE       LABELS
ip-10-0-1-54   Ready     18m       beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/hostname=ip-10-0-1-54
ip-10-0-1-95   Ready     18m       beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/hostname=ip-10-0-1-95
ip-10-0-2-43   Ready     18m       beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/hostname=ip-10-0-2-43
```

Perfect, we are good to go. Deploy the demo application (microbots)

```
juju run-action kubernetes-worker/0 microbot replicas=5
Action queued with id: 1a76d3f7-f82c-48ee-84f4-c4f77f3a453d
```

and

```
juju show-action-output 1a76d3f7-f82c-48ee-84f4-c4f77f3a453d
results:
  address: microbot.52.27.16.150.xip.io
status: completed
timing:
  completed: 2017-02-06 15:51:54 +0000 UTC
  enqueued: 2017-02-06 15:51:52 +0000 UTC
  started: 2017-02-06 15:51:53 +0000 UTC
```

Now you can go to the DNS endpoint, refresh the app and see how the the application is deployed. 

# Conclusion

