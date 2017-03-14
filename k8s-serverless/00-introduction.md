# Serverless and Kubernetes
## Serverless and Kubernetes

Serverless, for those new to the concept, is essentially reinventing the enterprise message bus in the new world. Very high level, the idea is to provide a message bus, watched by an orchestrator that can execute functions in reaction to the transiting messages. 
The message bus is fed by connectors that can read from various endpoints, including webhooks or other pubsub systems. 
The orchestrator reacts to the messages, spawns a pod that is specifically prepared to execute the required workload (pre mashed nodejs, python, <name your language>), pass it the arguments from the message. 
Eventually the pod exits successfully, and a strictly minimal amount of compute resources has been consumed to execute the code (as in, almost everything is batch here)

There is a great deal of love between Serverless and Kubernetes, for rightful reasons. The fact it is possible to very easily watch the API from inside of the cluster and react to changes to create new resources provides an elegant yet powerful way of creating a dynamic setup that matches the Serverless vision. 

Serverless is also the new buzzword. Freeing the developer from ops is the moto these days, no wonder a concept where the later does not even exist but when the whole thing fails would get some traction. It is PaaS^1000, the dynamism/async embedded. 
Looking a bit further than the hype, I think Serverless can be a game changer for HPC. Being an elegant way of controlling a flow of interdependent actions, allocating resources "just right" thus optimizing compute orchestration, powered by a very efficient Kubernetes, you essentially get the graal of any scientist (if I side away the effort to adopt the technology) willing to write efficient compute. 

As a result, several frameworks are now maturing, usually pushed by Kubernetes vendors. This post is a review of the ones I could identify, with a very opinionated analysis of their pros and cons. Opinions are my own, and do not represent in any way my employer's, including for the above HPC statement. 

## Evaluation method

For each framework, the objective part of the post is listing and comparing capabilities of each in terms of connectors, function languages available, ease of deployment and operation...

There is also a subjective part, which essentially is my understanding of the level of integration with Kubernetes the developer of the solution has brought into the development. 

Let us take for example, Third Party Resource. Is it good or is it bad? To me, most of the time, it is lazyness. Not in a bad way, but I consider Kubernetes provides 99.9% of the constructs that are needed. Adding a new resource means that either there is a corner case justifying being in the 0.1% that remains, or maybe that k8s is not used to its full potential, or just not understood properly. Third Party Resources are the sort of things that essentially will drive Kubernetes to vendor lockin and Bullshit as a Service as Mark Shuttleworth pointed out for some OpenStack projects. As you will have understood, I will require a lot of data to accept the use of these primitives. 

## Frameworks

For this blog, I have identified the following frameworks: 

* Funktion
* Fission
* OpenWhisk
* Kubeless

Let us find out if one stands out. 

## Requirements

You will need a working Kubernetes development cluster. if you run Ubuntu 16.04, fastest way to get that done is [conjure-up](https://conjure-up.io), which can deploy on your laptop to reduce your cloud costs. 

Then, 

<include all the things to deploy all frameworks> 

## Foreplay

## TL;DR

If you do not have time to read the whole thing, here is a table summary of my findings:

<include image>







