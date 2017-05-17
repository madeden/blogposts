# Introduction

What I am about to say may seem obvious, but a LOT of people out there are using VMWare vSphere to virtualize "stuff". Of course, that means we get a LOT of questions about the integration with vSphere and if it is possible to run the Canonical Distribution of Kubernetes with it. 

Until very recently, it was not so easy. You could do it, but well, you had to spend the time to do some manual tweaks here and there, adjust hostnames... Most of the roadbumps were due to a simple thing: VMWare has always refused to use Cloud Init, the de-facto standard to bootstrap VMs in pretty much any other solution. 

Because this was a common request, the team has spent a fair amount of time improving the UX of Juju for vSphere, and I am pleased to say that it now works pretty well, including activating GPUs to continue our tour of nVidia's goodness !!! 

Let's see what the UX looks like now!

# Requirements

To reproduce this post, you'll need: 

* Basic understanding of the Canonical toolbox: Ubuntu and Juju
* Basic understanding of Kubernetes
* a VMWare vSphere cluster that 
  * can access Internet (at least proxied) and has at least a public (routable) network for the VMs
  * Has a DNS working for all nodes created (or you'll have some edit to /etc/hosts to do)
* the will to leave on the edge of the Canyon! (juju 2.2rc1 and edge charms for etcd needed here)

and for the files, cloning the repo: 

<pre><code>
git clone https://github.com/madeden/blogposts
cd blogposts/k8s-vsphere
</code></pre>

# vSphere setup

I must admit I am no expert in VMWare vSphere, so I didn't change anything to the default setup: 

* Installed ESXi 6.5 from the latest ISO on 3 Dell T630 with 12c / 32GB RAM each
* Installed the vCenter Appliance on the first host using a Windows VM and the UI
* For each host, I activated GPU passthrough using [this guide](http://www.dell.com/support/article/us/en/4/SLN288103/how-to-enable-a-vmware-virtual-machine-for-gpu-pass-through?lang=EN)
* Create a datacenter in the vCenter, which I called "Region1"

That's it, really the default setup for everything else: I didn't touch networking or storage. 

# Juju experience
## Connecting to vSphere

Once you have vSphere installed, you need to let Juju know about it: 

<pre><code>
$ juju add-cloud vsphere
Cloud Types
  maas
  manual
  openstack
  oracle
  vsphere

Select cloud type: vsphere

Enter the vCenter address or URL: 192.168.1.164

Enter datacenter name: Region1

Enter another datacenter? (Y/n): n

Cloud "vSphere-test" successfully added
You may bootstrap with 'juju bootstrap vsphere'
</code></pre>

Now you need to configure the credentials for this cloud:

<pre><code>
$ juju add-credential vsphere
Enter credential name: canonical

Using auth-type "userpass".

Enter user: administrator@vsphere.local

Enter password: 

Credentials added for cloud vsphere.
</code></pre>

## Bootstrapping

Nothing special here, 

<pre><code>
juju bootstrap vsphere/Region1 --bootstrap-constraints "cores=2 mem=4G root-disk=32G"
Creating Juju controller "vsphere-Region1" on vsphere/Region1
Looking for packaged Juju agent version 2.2-rc1 for amd64
No packaged binary found, preparing local Juju agent binary
Launching controller instance(s) on vsphere/Region1...
 - juju-9c9d0a-0 (arch=amd64 mem=4G cores=2)dk: 97.76% (26.2MiB/s)ases/xenial/release-20170330/ubuntu-16.04-server-cloudimg-amd64.ova
Fetching Juju GUI 2.6.0
Waiting for address
Attempting to connect to 192.168.1.165:22
Attempting to connect to fe80::250:56ff:fe87:d44c:22
Bootstrap agent now started
Contacting Juju controller at 192.168.1.165 to verify accessibility...
Bootstrap complete, "vsphere-Region1" controller now available.
Controller machines are in the "controller" model.
Initial model "default" added.
</code></pre>

I prepared a small bundle in the src folder, which you can install with: 

<pre><code>
juju deploy src/k8s-vsphere.yaml
</code></pre>

then you can wait for the model to converge to a stable state: 

<pre><code>
watch -c juju status --color
</code></pre>

Then you can download the credentials are query the cluster: 

<pre><code>
juju scp kubernetes-master/0:config ~/.kube/config

kubectl get nodes --show-labels
NAME            STATUS    AGE       VERSION   LABELS
juju-428e55-1   Ready     1h        v1.6.2    beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/hostname=juju-428e55-1
juju-428e55-2   Ready     1h        v1.6.2    beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/hostname=juju-428e55-2
</code></pre>

OK!! You now have a Kubernetes cluster up & running on VMWare vSphere. Wasn't too complicated, was it? Should we say it was boring? 

# Adding GPUs
## On vSphere

OK so the cool stuff now. Using the same guide as before, add GPUs to the VMs running the Kubernetes workers. 

You'll first need to stop them, then add the PCI device, and restart them. 

## In Kubernetes

At this point, Juju should pick up and discover the nVidia board and install the CUDA drivers all by itself. For some reason it did not, and we are investigating. But we don't stop at a small glitch. Let's install that manually, which will also give me the occasion to answer questions I got about managing CDK now that the control plane has been fully snapped. 

Google has this simple script to install the drivers: 

<pre><code>
#!/bin/bash
echo "Checking for CUDA and installing."
# Check for CUDA and try to install.
if ! dpkg-query -W cuda; then
  curl -O http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/cuda-repo-ubuntu1604_8.0.61-1_amd64.deb
  dpkg -i ./cuda-repo-ubuntu1604_8.0.61-1_amd64.deb
  apt-get update
  apt-get install cuda -y
fi
</code></pre>

Just run that on the 2 workers (eventually make use of "juju scp" and "juju ssh")

Now on each worker, you need to activate the accelerators. There is a new procedure to do so as GPUs are now "Accelerators" in K8s: 

<pre><code>
sudo snap set kubelet experimental-nvidia-gpus=1
sudo snap set kubelet feature-gates="Accelerators=true"
sudo systemctl restart snap.kubelet.daemon.service 
</code></pre>

**Note**: If you read my other (old) posts, maybe you remember in the past we were editing files with sed, awk and all the nice text edition foo. Now it is a set command for the snap. It **DOES** matter. Suddenly as the admin, you're not in charge of managing idempotency anymore, you delegate that to snapd. It is a game changer, and that is even without mentioning the new upgrade path made soooo simple. 

Now on the master, 

<pre><code>
sudo snap set kube-controller-manager feature-gates="Accelerators=true"
sudo snap set kube-scheduler feature-gates="Accelerators=true"
sudo snap set kube-apiserver feature-gates="Accelerators=true"
sudo systemctl restart snap.kube-apiserver.daemon.service 
sudo systemctl restart snap.kube-scheduler.daemon.service 
sudo systemctl restart snap.kube-controller-manager.daemon.service 
</code></pre>

OK, you're good to go, you now have GPUs activated in K8s

## Testing the results

A classic to start with: 

<pre><code>
kubectl install -f src/nvidia-smi.yaml
</code></pre>

There you go, it just works :)

# More cryptocurrencies?

I noticed you guys LOVE cryptocurrencies, so I wrote a new chart for Minergate, which you'll find in https://github.com/madeden/charts

It's not the fastest miner ever, but it's OK, and it can do CUDA mining out of the box, making it very cool for testing. 

Have a look at the config file, create an account on https://minergate.com and start playing: 

<pre><code>
helm init
helm install path/to/charts/minergate --name minergate
</code></pre>

You can configure the following values: 

* clusterName: (ob) just a way to run several times the same chart and still id workers easily
* pool: (minergate) also a differenciator
* coin: (-qcn) the crypto currency you want to mine, with a "-" before it. 
* nodes: (2): How many nodes are in the cluster to welcome miners
* workersPerNode: (1) How many workers you want to deploy per node
* cpusPerWorker: (1): How many CPU cores do you want to allocate per miner
* gpuComplexity: (4): If using GPU, how much stress to put on the GPU? Use 0 if you want to do CPU mining only
* username: (samnco@gmail.com) Your Minergate ID

Enjoy! Of course this is Helm, so you are only limited by Kubernetes, not being on VMWare or any other substrate. 

# Conclusion

The Juju experience on VMWare has drastically improved over the last few weeks. It is now particularly easy to operate big software on it. 

The Canonical Distribution of Kubernetes is one example, but [Spicule](http://spicule.co.uk/), a long time partner of Canonical, does Big Data and integration with Pentaho. 

Note also that MAAS can integrate VMWare as a "bare metal layer", so you can essentially record VMs from VMWare in MAAS, and use it to start them or stop them. 

Any question, you know where to find me. If you liked this, feel free to press the little heart, it will make mine smile!


