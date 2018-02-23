# Serverless and Kubernetes
## Serverless and Kubernetes

Serverless, for those new to the concept, is essentially reinventing the enterprise message bus in the new world. Very high level, the idea is to provide a message bus, watched by an orchestrator that can execute functions in reaction to the transiting messages. 
The message bus is fed by connectors that can read or get written to from various endpoints, including webhooks, time or other pubsub systems. 
The controller reacts to the messages, spawns a function that is specifically prepared to execute the required workload (pre mashed nodejs, python, <name your language>), pass it the arguments from the message. This is the Function as a Service (FaaS) model. 
Eventually the function exits successfully, and a strictly minimal amount of compute resources has been consumed to execute the code (as in, almost everything is batch here). 
In more advanced setups, such as AWS Lambda, it is possible to map a function's output to the input of another, and therefore create workflows. 
And finally the last resort for serverless is to rely on a third party backend to execute advanced actions. This is the Backend as a Service (BaaS) part. 
In a nutshell, this is the very extreme way of looking at micro services, down to the point they are just individual functions, and let the framework completely abstract communication.  

There is a great deal of love between Serverless and Kubernetes, for rightful reasons. The fact it is possible to very easily watch the API from inside of the cluster and react to changes to create new resources provides an elegant yet powerful way of creating a dynamic setup that matches the Serverless vision. 

Serverless is also the new buzzword. Freeing the developer from operations to focus on the code is the moto these days, no wonder a concept where the later does not even exist gets some traction. It is PaaS^1000, the dynamism/async embedded. 
Looking a bit further than the hype, I think Serverless can be a game changer for a number of applications. Being an elegant way of controlling a flow of interdependent actions, allocating resources "just right" thus optimizing compute orchestration, powered by a very efficient Kubernetes, you essentially get the graal of any data driven or form driven application.  

As a result, several frameworks are now maturing, usually pushed by Kubernetes vendors. This post is a review of the ones I could identify, and an attempt to run a simplified workflow in each of them. Opinions are my own, and do not represent in any way my employer. 

## High Level Architecture

Serverless is essentially based on 

* a pub/sub messaging system that stores state and allows functions to communicate together and with the rest of the world. 
* an executin framework that will spawn the functions
* a proxy that will handle communication between the functions and the message bus (usually a small web server)

Additionally you may expect to find: 

TBD

## Evaluation method

For each framework, the objective part of the post is listing and comparing capabilities of each in terms of connectors, function languages available, ease of deployment and operation...

There is also a subjective part, which essentially is my analysis of the level of integration with Kubernetes the developer of the solution has brought into the development. 

Let us take for example, Custom Resource Definition. Is it good or is it bad? To me, most of the time, it is lazyness. Not in a bad way, but I consider Kubernetes provides 80% of the constructs that are needed. Adding a new resource means that either there is a corner case justifying being in the 20% that remains, or maybe that k8s is not used to its full potential. There is a fine line there that is easy to cross, so I will try to be as understanding as can be.   

## Frameworks

For this blog, I have identified the following frameworks: 

* Funktion
* Fission
* OpenWhisk
* Kubeless

I am voluntarily pushing OpenFaaS out because at this point it remains a pure open source project with no commercial support available. 
I am also keeping Fn outside of my scope because it is a very early stage effort. Very promising on paper, but still very young. 

Let us find out if one stands out. 

## Requirements

You will need a working Kubernetes development cluster. Most of these frameworks require persisten storage, so this time I will recommend to use GKE just to make it easier. You can start with 2 nodes but 3 will give your more muscles. Make sure you have at the very least 4 cores available for the frameworks. 


# TL;DR

If you do not have time to read the whole thing, here is a table summary of my findings:

<include image>







