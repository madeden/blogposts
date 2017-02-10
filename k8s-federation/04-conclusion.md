# Conclusion

Is it worth engaging with Federation right now on multicloud / world scale solutions? 
Definitely yes. This part of Kubernetes is the one any enterprise is looking at right now, and having understanding of its behavior and architecture is definitely a plus.

As a company, should you already prepare your production for this? At your own risks.

The Federation control plane that Kubefed deploys (as of this day) works, but relies on a single etcd pod, backed by a PV. Not good enough to ensure production stability and reliability. As a result, you would need engineering to make that more robust. 

It’s not so hard so, etcd being relatively easy to manage thanks to the Juju charms to deploy at scale. But it is still an effort.

Moreover, some of the key features such as ingress distribution are not ready yet for prime time out of AWS and GKE/GCE, meaning unless you put serious efforts into developing your own solution, there is a good chance you’ll suffer.

Finally, out of Google Cloud DNS or Route53, there is no solution available today. It’s coming, but it’s not there yet. Stay tuned*!

What you can and should do though is really add depth to your k8s by deploying on every single cloud using CDK, and learn how the solution adapts in these environments, the pros and cons of each cloud and types of machines. 
As an individual in the DevOps community, should you engage with K8s and Federation? YES!!! 
First of all, it’s really a game changer for anyone who has any form of experience with releasing applications, and it’s not that hard to deploy, even at medium scale.

So what's next? Until now, we have covered

* [Building a DYI GPU cluster for k8s](https://hackernoon.com/installing-a-diy-bare-metal-gpu-cluster-for-kubernetes-364200254187)
* [Integrating k8s with existing infrastructure](https://medium.com/@samnco/automate-the-deployment-of-kubernetes-in-existing-aws-infrastructure-aa369df2f651)
* State of the art of Federation (this article)

Now is the time for actual applications on top of Kubernetes. If you have any idea of something cool I should build... By all means, comment and find me on GitHub (SaMnCo) or the Kubernetes Slack (samuel-me)


