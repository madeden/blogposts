# Adding support for ELBs in Kubernetes deployments

If I got a dollar for every time I get a question about using AWS ELBs with the Canonical Distribution of Kubernetes (CDK), I would probably be a millionaire right now. And that is without counting the questions I've been asking myself about it for the last few months. 

It is a fair question. When deploying Kubernetes, people expect to get ELB integration out of the box. That is to say, when they create a service  with a LoadBalancer type, they hope to get a Load Balancer endpoint at the cloud level, with the right security groups automagically created. 

On paper, this sounds normal / natural / native / trivial / pick your common word. In reality, it's not that easy! Let's dig into the requirements of adding ELB support, the limitations of Kubernetes itself, then how to activate the feature with CDK to enjoy full integration with AWS. 

# Communicating with the cloud API

The are 2 options for "something" to programmatically consume the API of AWS. 

Either it has a set of credentials, with the right role/group/user attached to them, and it passes each command with the API Key and Secret. This is the usual approach when the "something" in question does not live in EC2 itself. It carries a security question about the validity, therefore about the update policy of the credentials. 
In short, give someone a pair of credentials that has unlimited validity, there is a probability very close to 1 that these will be lost at some point, and you'll have to regenerate them. This is trivial for human beings (set policy for password expiration at 30 days), but not so much for robots. 

The second option is to give an instance a specific Instance Role. This will allow the machine to programmatically get short lived credentials to pass requests to the API. This is much better for security as there are no exchanges of credentials, and it's easy to add, change, remove policies from instances. 
The fallback is that it works only for machines that live in EC2. But it's a key to fluid security in the AWS cloud. 

# Automation and Tooling in EC2

The consequence of using such a primitive is that you'll have one primitive per cloud. Azure will not have the same roles, neither will GCE, OpenStack, or anything else. The benefit you get on one end will drastically reduce the portability of operations across other substrates. 

For people designing automation tools like Canonical, this is a daily, or even hourly question: to what extend shall the tools leverage deep primitives of individual clouds? 

Juju, the motus operandi of our Big Software stacks takes a radical approach: it only consumes Compute, Storage and Network. Anything else is out of scope. 
It is the cost to pay to have a single automation tool that works across all substrate, including bare metal, without changing anything. 

Does that prevent you from going deeper in automation? Not at all. It's just a gentle reminder that using advanced cloud primitives means giving up on something else. And this has also bears a cost on the long run. 

# Cloud Automation at the Kubernetes level

For tools like Kubernetes which vision is to unify the clouds, the same question also matters. How deep should you go? 

And the approach here is different. Because Load Balancing is a primitive that k8s cares a lot about, there is an abstraction layer for (some) clouds in it. It's all in the [Cloud Provider Tree](https://github.com/kubernetes/kubernetes/blob/master/pkg/cloudprovider/providers/) in the repo. 

To be fair, it's not really an abstraction as they are all mostly different. Looking at the [AWS Integration](https://github.com/kubernetes/kubernetes/blob/master/pkg/cloudprovider/providers/aws/aws.go) you find plenty of annotations to specialize constructs (deployments, services, ingresses...) to make them work in AWS, and the same is true for other clouds. 

What can we learn from it? 

1. Kubernetes expects to have access to an IAM Instance Role. It uses the ec2 metadata service to get it's token. 

According to [Kops](https://github.com/kubernetes/kops/blob/master/docs/iam_roles.md), a working policy for the masters for full blown access would be 

<pre><code>
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [ "ec2:*" ],
      "Resource": [ "*" ]
    },
    {
      "Effect": "Allow",
      "Action": [ "elasticloadbalancing:*" ],
      "Resource": [ "*" ]
    },
    {
      "Effect": "Allow",
      "Action": [ "route53:*" ],
      "Resource": [ "*" ]
    },
    {
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": [ "arn:aws:s3:::kubernetes-*" ]
    }
  ]
}
</code></pre>

while the workers also get attachment and detachment of EBS drives (for persistent volumes)

<pre><code>{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": [ "arn:aws:s3:::kubernetes-*" ]
    },
    {
      "Effect": "Allow",
      "Action": "ec2:Describe*",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "ec2:AttachVolume",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "ec2:DetachVolume",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [ "route53:*" ],
      "Resource": [ "*" ]
    }
  ]
}
</code></pre>


2. It consumes it to label each node with information about themselves such as Instance Type, Region, Zone... 

<pre><code>$ kubectl get nodes --show-labels
NAME                           STATUS    AGE       LABELS
ip-172-31-3-211.ec2.internal   Ready     1h        beta.kubernetes.io/arch=amd64,beta.kubernetes.io/instance-type=m3.medium,beta.kubernetes.io/os=linux,failure-domain.beta.kubernetes.io/region=us-east-1,failure-domain.beta.kubernetes.io/zone=us-east-1a,kubernetes.io/hostname=ip-172-31-3-211
ip-172-31-8-28.ec2.internal    Ready     1h        beta.kubernetes.io/arch=amd64,beta.kubernetes.io/instance-type=m3.medium,beta.kubernetes.io/os=linux,failure-domain.beta.kubernetes.io/region=us-east-1,failure-domain.beta.kubernetes.io/zone=us-east-1a,kubernetes.io/hostname=ip-172-31-8-28
ip-172-31-9-154.ec2.internal   Ready     1h        beta.kubernetes.io/arch=amd64,beta.kubernetes.io/instance-type=m3.medium,beta.kubernetes.io/os=linux,failure-domain.beta.kubernetes.io/region=us-east-1,failure-domain.beta.kubernetes.io/zone=us-east-1a,kubernetes.io/hostname=ip-172-31-9-154
</code></pre>

3. Kubernetes expects a whole lot of resources to be tagged with "KubernetesCluster", but one and only one Security Group must be tagged (see [this section](https://github.com/kubernetes/kubernetes/blob/master/pkg/cloudprovider/providers/aws/aws.go#L2830))

This last comment generates a LOT of issues [here](https://github.com/kubernetes/kubernetes/issues/23562) and [there](https://github.com/kubernetes/kubernetes/issues/26787), [comments](https://github.com/cncf/demo/issues/144). Probably many more to be found, this is an aspect where k8s is very very (too?) picky. 

# Juju and AWS

We already know Juju doesn't want to go deep into individual clouds properties. But what can we do to bridge the gap?

1. Custom Tags

Juju can, at the model level, create custom tags to every cloud object. That is how we can add the "KubernetesCluster" tag. 

2. Enforced tags

Juju creates a set of tags that apply to every cloud object: 

* juju-model-uuid
* juju-controller-uuid

In addition, for EC2 instances, juju creates the below tags: 

* juju-is-controller
* Name, with the format juju-<model name>-machine-<machine id>

3. Security Groups

For each control plane, Juju creates a SG, juju-<uuid of control plane> that is common to all controllers. Then each controller in that plane gets a secondary juju-<uuid of control plane>-<machine id>. 

Then for each model, Juju creates another SG, juju-<uuid of model plane> that is common to all machines deployed in the model. Each of them will then get a secondary SG, juju-<uuid of model plane>-<machine id>, for uncommon settings (exposing resources mainly)

That's about all we need to manage our system. Let's dig into the deployment. 

# Requirements

For the following, you'll be expected to

* Know about Kubernetes 101
* Know about Juju and Canonical's tooling
* Understand the AWS command line
* some jq foo!

You'll need to clone this repository as well: 

<pre><code>
git clone https://github.com/madeden/blogposts
cd blogposts/k8s-existing-env-2-elb
</code></pre>

