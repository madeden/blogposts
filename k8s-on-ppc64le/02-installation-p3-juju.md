# Juju
## Introduction

If you read our [previous post](http://www.madeden.com/single-post/2016/11/14/Building-a-bare-metal-GPU-enabled-cluster-for-Kubernetes) about building a bare metal GPU cluster, you know about [Juju](https://jujucharms.com). 

Juju is a "modelling language", that targets sharing deep knowledge of IT operations in an open source manner. Ultimately, the goal is to lower the entry operational cost of complex "Big Software", such as OpenStack, Kubernetes, Hadoop and any stack made of many pieces that are not necessarily cattle but more pets. 

Juju uses primitives such as 

* **charms** which are unitary elements of knowledge of how to install and operate a service (say, the Kubernetes Master layer)
* **relations**, which is code embedded in the charms that expresses how a service reacts when it is connected to another service (what needs to be configured, changed, restarted...)
* **layers**, which are elementary reusable bricks across different charms (eg. 2 charms for Java software both can use the java layer, which will install Java in a similar way, allowing developers to focus on their bits rather than the full stack)
* **bundles** which are sets of **charms** combined together to form a solution (OpenStack, Canonical Distribution of Kubernetes, Hadoop + Spark on 3 nodes...)

Juju is widely used in B2B environments, especially in Telco & retail environments, to model large scale data center grade solutions. 

## Setup
### Installation

We are in a very "non controlled" environment, with our 3 nodes completely separated, without any provisioning API for them but the LXD nodes. 

Juju has a "manual provider" setting which allows to add nodes manually to the setup. We will use this feature extensively to add our nodes to the setup. 

First of all, we need to install the Juju client on our node01


<pre><code>
$ sudo apt install -yqq --no-install-recommends juju charm charm-tools
</pre></code>

### Bootstrapping

The first step with Juju is to "bootstrap", which creates a control node. We will use the LXD provider to do that. All that is needed it to run a blank "juju bootstrap" command and we will be driven through the process :

<pre><code>
ubuntu@node01:~$ juju bootstrap
Since Juju 2 is being run for the first time, downloading latest cloud information.
Fetching latest public cloud list...
Updated your list of public clouds with 1 cloud region added:

    added cloud region:
        - aws/us-east-2
Clouds
aws
aws-china
aws-gov
azure
azure-china
cloudsigma
google
joyent
localhost
rackspace

Select a cloud [localhost]: 

Enter a name for the Controller [localhost-localhost]: k8s

Creating Juju controller "k8s" on localhost/localhost
Looking for packaged Juju agent version 2.0.0 for ppc64le
To configure your system to better support LXD containers, please see: https://github.com/lxc/lxd/blob/master/doc/production-setup.md
Launching controller instance(s) on localhost/localhost...
 - juju-954081-0 (arch=ppc64le)          
Fetching Juju GUI 2.2.3
Waiting for address
Attempting to connect to 250.1.178.249:22
Logging to /var/log/cloud-init-output.log on the bootstrap machine
Running apt-get update
Running apt-get upgrade
Installing curl, cpu-checker, bridge-utils, cloud-utils, tmux
Fetching Juju agent version 2.0.0 for ppc64le
Installing Juju machine agent
Starting Juju machine agent (service jujud-machine-0)
Bootstrap agent now started
Contacting Juju controller at 250.1.178.249 to verify accessibility...
Bootstrap complete, "k8s" controller now available.
Controller machines are in the "controller" model.
Initial model "default" added.
</pre></code>

Good. Now we can query the status for the first time: 

<pre><code>
ubuntu@node01:~$ juju status
Model    Controller  Cloud/Region         Version
default  k8s         localhost/localhost  2.0.0

App  Version  Status  Scale  Charm  Store  Rev  OS  Notes

Unit  Workload  Agent  Machine  Public address  Ports  Message

Machine  State  DNS  Inst id  Series  AZ
</pre></code>

### Adding other machines

Now that we have a juju system running, we need to add our other instances to the system manually

<pre><code>
ubuntu@node01:~$ juju add-machine ssh:ubuntu@node02
Logging to /var/log/cloud-init-output.log on the bootstrap machine
Running apt-get update
Running apt-get upgrade
Installing curl, cpu-checker, bridge-utils, cloud-utils, tmux
Fetching Juju agent version 2.0.0 for ppc64le
Starting Juju machine agent (service jujud-machine-0)
created machine 0
ubuntu@node01:~$ juju add-machine ssh:ubuntu@node03
Logging to /var/log/cloud-init-output.log on the bootstrap machine
Running apt-get update
Running apt-get upgrade
Installing curl, cpu-checker, bridge-utils, cloud-utils, tmux
Fetching Juju agent version 2.0.0 for ppc64le
Starting Juju machine agent (service jujud-machine-1)
created machine 1
ubuntu@node01:~$ juju status
Model    Controller  Cloud/Region         Version
default  k8s         localhost/localhost  2.0.0

App  Version  Status  Scale  Charm  Store  Rev  OS  Notes

Unit  Workload  Agent  Machine  Public address  Ports  Message

Machine  State    DNS     Inst id        Series  AZ
0        started  node02  manual:node02  xenial  
1        started  node03  manual:node03  xenial  
</pre></code>

Perfect, we now have our 2 nodes added as machines 0 and 1, and we are ready to deploy Kubernetes charms


