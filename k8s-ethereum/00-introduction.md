# How we commoditized GPUs for Kubernetes

Over the last 6 months I have blogged 4 times about the enablement of GPUs in Kubernetes. Each time I did so, I spent several days building and destroying clusters until it was just right, trying to make the experience as fluid as possible for my followers if by any chance they wanted to replicate my work. 

It was not the easiest task as  the environments were different (cloud, bare metal), the hardware was different (g2.xlarge have old K20s, p2 instances have K80s, I had 1060GTX at home but on Intel NUC, and Quadro on my desktop but with a different OS). As a result, I also spent several hours supporting people to set up the clusters. Usually with success, but I must admit some environments have been challenging.

Hopefully the team at Canonical in charge of developing the Canonical Distribution of Kubernetes have productized my GPU skunk work and made it so easy to use that it would just be a shame not to talk about it. 

And as of course happiness never comes alone, I was lucky enough to be allocated 3 brand new, production grade nVidia Pascal P5000 by our nVidia friends. 

I could have installed these in my playful rig to replace the 1060GTX boards. But this would have showed little gratitude for the exceptional gift from nVidia. Instead, I decided to go for a full blown "production grade" bare metal cluster, which will allow me to replicate most of the environments customers and partners have. I chose to go for 3x Dell T630 servers, which can be GPU enabled and are very capable machines. 

So here I am, posting again about GPUs and how easy it is now to integrate them in Kubernetes!

# What it was in the past

If you remember the other posts, the sequence was: 

1. Deploy a "normal" K8s cluster with Juju
2. Add a CUDA charm and relate it to the right group of Kubernetes workers
3. Connect on each node, and activate privileged containers, and add the experimental-nvidia-gpu tag to the kubelet. Restart kubelet. 
4. Connect on the API Server, add the experimental-nvidia-gpu tag and restart the API server. 
5. Test that the drivers were installed OK and made available in k8s with Juju and Kubernetes commands

Overall, on top of the Kubernetes installation, with all the scripting in the world, no less than 30 to 45min were lost to perform the specific maintenance for GPU enablement. 

It is better than having no GPUs, but it is often too much for the operators of the clusters who want an instant solution. 

# How is it now? 

I am happy to say that the requests of our community has been heard loud and clear. 

As of Kubernetes 1.6.1, and the matching GA release of the Canonical Distribution of Kubernetes, the new experience is : 

1. Deploy a "normal" K8s cluster with Juju

Yes, you read that well. GPUs are the new normal. 

Since 1.6.1, the charms will now: 

* watch for GPU availability every 5min. For clouds like GCE, where GPUs can be added on the fly to instances, this makes sure that no GPU will ever be forgotten
* If one or more GPUs are detected on a worker, the latest and greated CUDA drivers will be installed on the node, the kubelet reconfigured and restarted automagically.
* Then the worker will communicate its new state to the master, which will in return also reconfigure the API server and accept GPU workloads. 
* In case you have a mixed cluster with some nodes with GPUs and others without, only the right nodes will attempt to install CUDA and accept privileged containers. 

You don't believe me? Watch and learn...

# Requirements

For the following, you'll need: 

* Basic understanding of the Canonical toolbox: Ubuntu, Juju, MAAS
* Basic understanding of Kubernetes

and for the files, cloning the repo: 

<pre><code>
git clone https://github.com/madeden/blogposts
cd blogposts/k8s-ethereum
</code></pre>
