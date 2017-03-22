# Introduction

A few days ago, I was made aware of an interesting Kubernetes use case by a media company. They want to use a cluster for video transcoding, something that is easy to scale per file or type of output, but also extremely CPU intensive, and that can benefit from GPUs. 

During their tests, made on a default Kubernetes installation on machines with 40 cores, they allocated 5 full CPU cores to each of the transcoding pods, then scaled up to 6 concurrent tasks per node. 

Their result was underwelming: while concurrency was going up, performance on individual task was going down. At maximum concurrency, they actually lose 50% performance. 

I did some research to understand this problem. It is referenced in several Kubernetes issues such as [#10570](https://github.com/kubernetes/kubernetes/issues/10570), [#171](https://github.com/kubernetes/community/pull/171), in general via a [Google Search](https://www.google.com/search?q=cpuset%20kubernetes&*&rct=j). 

The [documentation](https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/) clarifies a little bit how the default scheduler and Docker work and why the performance can be impacted by concurrency on intensive tasks. 

There are different methods to allocate CPU time to containers: 

* Physical slicing: if the host has enough CPU cores available, allocate 5 "physical cores" that will be dedicated to this pod/container;
* Temporal slicing: considering the host has N cores, they collectively represent an amount of compute time which you allocate to containers. Allocating 5% of CPU time to a pod means that every 100ms, 5ms of compute are dedicated to this pod. 

<include Picture>

Obviously, the physical slicing that is interesting for some specific workloads is pretty limited at scale: you could not run more pods than you have cores in your cluster. 
As a result, Docker defaults to the second one, which also ensures you can have less than 1 CPU allocated to a container. 

<include Picture>

This impacts on the compute cycles and how the L1 - L3 cache memory is addressed. Typically, this will cause competition between the containers, and reduce performance. 

As far as I can find, while there are projects to fix this on the roadmap, there is no way to actually fix it right now. 

Or maybe there is. LXD containers have the ability to be allocated physical cores, in an automated fashion, as explained in this [blog post](https://stgraber.org/2016/03/26/lxd-2-0-resource-control-412/) by [@stgraber](https://twitter.com/stgraber)

Does this mean we could slice hosts to have multiple Kubernetes workers powered by LXD, and enable some kind of "dual scheduling" to bypass the problem? 

Let's see! 

# The Plan

In this blog post, we will do the following: 

1. Setup various Kubernetes clusters: pure bare metal, pure cloud, in LXD containers with strict CPU allocation. Make sure they can run privileged containers (to share hostpath)
2. Design a minimalistic Helm chart to easily create some parallelism
3. Run benchmarks to scale concurrency (up to 32 threads/node)
4. Extract and process logs from these runs to see how concurrency impacts performance per core

# Requirements

For this blog post, it is assumed that 

* You are familiar with Kubernetes
* You have notions of Helm charting or of Go Templates, as well as using Helm to deploy stuff
* Having preliminary knowledge of the Canonical Distribution of Kubernetes (CDK) is a plus, but not required. 
* Downloading the code for this post

```
git clone https://github.com/madeden/blogposts
cd k8s-transcode
```


# Methodology

Our benchmark is a transcoding task. It uses a ffmpeg workload, designed to minimize time to encode by exhausting all the resources allocated to compute as fast as possible. 
We use a single video for the encoding, so that all transcoding tasks can be compared. To minimize bottlenecks other than pure compute, we use a relatively low bandwidth video, stored locally on each host. 

The transcoding job is run multiple times, varying: 

* CPU allocation from 0.1 to 7 CPU Cores
* Memory from 0.5 to 8GB RAM
* Concurrency from 1 to 32 concurrent threads per core
* (Concurrency * CPU Allocation) never exceeds the number of cores of a single host

We measure for each pod how long the encoding takes, then look at correlations between that and our other variables. 


