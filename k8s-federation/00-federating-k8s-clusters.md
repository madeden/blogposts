# Kubernetes Federation across clouds
## What / why?

In a previous [post](https://medium.com/@samnco/automate-the-deployment-of-kubernetes-in-existing-aws-infrastructure-aa369df2f651) I presented a way to deploy a cluster in an existing AWS environment as an answer to questions about integrability. 

So what is the next most frequent question that I get? You read the title so you know, **Can I span Kubernetes across multiple environments / clouds?**. As more and more people consider k8s as the next big platform, that allows them to abstract a lot of the cloud / bare metal infrastructure, it is only fair that this question pops up regularly. 

It's ever fairer since there is a huge community effort to make it happen, and huge progress has been made over the last 6 months. 

So theorically... Yes. Now, How does it work practically? Let's check it out! 

Let me be clear about the rest of this article: we will not reach a complete automation of a multi-cloud Kubernetes. However, we will get to a point where you can at a moderate cost operate a multi-cloud federation of clusters, and manipulate the basic primitives. At least, hopefully you'll have learnt something about the current state of k8s Federation. 

## Preliminary words about Federation

What is a Kubernetes Federation? To answer this question, let's just say that spanning a unique cluster all over the world is, to say the least, absolutely impossible. That's why clouds have regions, AZs, cells, racks... You have to split your infrastructure so that specific geographic areas are the unit of construction to build the bigger solution. 

Nevertheless, when you connect on AWS, Azure or GCP, you can create and manage resources across all regions. Even better, some services are global (DNS, Object Storage...) and shared between the complete environment? 

If, as many, you consider Kubernetes as a solution to scalability problems, then you have considered or will consider spinning several clusters in several regions and AZs. 
The "over the Kubernetes" plane to control all the clusters is  the Federation. It provides a centralized control, and distributes commands across all the federated clouds.

TL;DR: if you use Kubernetes, if you want a World Wide app spread across many regions and clouds, Federation is how you do it. 

Now Federation is also a very young subproject of the Kubernetes ecosystem, and there is a long road before it is mature enough. Let us see where we stand now for anyone starting up on k8s or considering it. 

## The Plan

In this blog, we are going to do the following things: 

1. Deploy Kubernetes clusters in Amazon, Azure and GKE
2. Create a Google Cloud DNS Zone with a domain we control
3. Install a federation control plane in GKE
4. Have a look at what works and what doesn't out of the box
5. Look at some one liners and more advanced scripts to operate our system

## Requirements

For what follows, it is important that: 

* You understand Kubernetes 101
* You understand k8s Federation concepts
* You have admin credentials for AWS, GCP and Azure
* You are familiar with tooling available to deploy Kubernetes
* You have notions of GKE and Google Cloud DNS (or route53 or Azure DNS)

# Foreplay

* Make sure you have Juju installed. 

On Ubuntu, 

```
sudo apt-add-repository ppa:juju/stable
sudo apt update && apt upgrade -yqq
sudo apt install -yqq juju 
```

for other OSes, lookup the [official docs](https://jujucharms.com/docs/2.0/getting-started-general)

Then to connect to the AWS cloud with your credentials, read [this page](https://jujucharms.com/docs/2.0/help-aws)

Finally, connect to Azure via [this page](https://jujucharms.com/docs/2.0/help-azure)

* Make sure you have the [Google Cloud SDK suite](https://cloud.google.com/sdk/docs/quickstart-debian-ubuntu) installed 

* Finally copy this repo to have access to all the sources

```
git clone https://github.com/madeden/blogposts ./
cd blogposts/k8s-federation
```

OK! Let's federate now! 