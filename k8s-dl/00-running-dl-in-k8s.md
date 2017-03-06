# Deep Learning in Kubernetes

Here we are. After having spent 21min reading how to build a GPU Kubernetes cluster on AWS, 7min on adding EFS storage, you want to get to the real thing, which is actually DO something with it. So today we are going to define, design, deploy and operate a Deep Learning pipeline. 

So what is a Deep Learning pipeline exactly? Well, my definition is a 4 step pipeline, with a potential retro-action loop, that consists of 4 tasks: 

1. **Data Ingest**: This step is the accumulation and pre processing of the data that will be used to train our model(s). This step is maybe the less fun, but it is one of the most important. Your model will be as good as the data you train it on. 
2. **Training**: this is the part where you play God and create the Intelligence. From your data, you will create a model that you hope will be representative of the reality and capable of describing it (and even why not generate it)
3. **Evaluation**: Unless you can prove your model is good, it is worth just about nothing. The evaluation phase aims at measuring the distance between your model and reality. This can then be fed back to a human being to adjust parameters. In advanced setups, this can essentially be your test in CI/CD of the model, and help auto tune the model even without human intervention. 
4. **Serving**: there is a good chance you will want to update your model from times to times. If you want to recognize threats on the network for example, it is clear that you will have to learn new malware signatures and patterns of behavior, or you can close your business immediately. Serving is this phase where you expose the model for consumption, and make sure your customers always enjoy the latest model. 

Now, what is a good way of modelling an application in Kubernetes? 
A good model must be easy to reproduce, which boils down to how good your packaging is. You would not be using Ubuntu if there wasn't a predictable apt utility to install all the things. Canonical would not spend considerable money and efforts on Ubuntu Core and its Snap Application Containers if it did not believe there was ultimately a benefit to the community on agreeing on a multi-distribution packaging format. Docker would be a lot less successful as it is if it did not solve a fundamental problem of sharing common ground from dev to ops. 

Packaging at scale is a much harder problem than single OS packaging. Canonical solves the packaging of large scale "pet" application with Juju and charms. And Kubernetes solves the problem of large scale "cattle" applications with Helm. 

I did a fair amount of research to prepare this blog, hoping to find a seed to build upon. But all I could find was native Kubernetes manifests for PaddlePaddle or Tensorflow, barely suitable even for a start. Oh and also a simple Tensorflow Serving helm package, but more or less alpha grade. 

If you do not find what you want, do it yourself and share it! That is exactly what we will do now.

The Deep Learning framework we will use is Tensorflow, Google's own open source DL solution. As Google also open sourced Kubernetes, it seems only natural to combine these 2 pieces together. 

# The plan 
## What are we going to do? 

We will reuse the bits and pieces of previous posts to focus on the Deep Learning so

1. Deploy Kubernetes with GPUs: Check! see ..
2. Add EFS storage to the cluster: Check! See ...
3. Data ingest code & package
4. Training code & package
5. Evaluation code & package
6. Serving code & package
7. Deployment process
8. Conclusion

So yes, it will be a long process! I hope you have some time. 

## Requirements

For what follows, it is important that: 

* You understand Kubernetes 101
* You understand the basics of Deep Learning and specifically Tensorflow
* You understand or want to understand the basics of Kubernetes packaging with Helm
* It may sound kindergarden, but you'll also need a bit of Dockerfile writing knowledge

# Foreplay

* It is assumed that you have succesfully deployed reproduced the 2 previous parts. If not or if you have troubles in any step, reach out! 
* Make sure you have Helm installed. At the time of this writing, we are on 2.2.1

```
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh
helm init
```

More advanced instructions are available in the [official docs](https://github.com/kubernetes/helm/blob/master/docs/install.md)

* Copy this repo to have access to all the sources

```
git clone https://github.com/madeden/blogposts ./
cd blogposts/k8s-dl
```

* You will need to serve the Helm Charts, which you can do by: 

```
cd src/charts
helm serve . &
```

