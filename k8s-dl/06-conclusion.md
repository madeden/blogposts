# Conclusion

Another looong blog post. But I think it was worth it. Essentially, you have: 

1. Deployed Kubernetes 1.5.X using the Canonical Distribution of Kubernetes (CDK)
2. Activated GPU workloads in it
3. Added storage
4. Modeled Tensorflow in a scalable and easy to operate Helm Chart
5. Deployed that Helm chart
6. Learnt how to reproduce this for yourself

At this stage, you should be able to use CDK for your own science. I truly hope so, and if not, just ping me and we'll sort you out. 

Big, Huge thanks to Amy who published the initial workshop that inspired this Helm chart, and to the folks at Google, open sourcing so much content. This is awesome, and I hope this will help others to adopt the tech.

# Next Steps

This Tensorflow Helm chart is far from perfect, but it’s better than nothing. I intend to kindly ask to add it to the kubeapps and iterate from there. 
This idea of building blocks around k8s is really powerful, so I will now be working on building more stacks. First next target is DeepLearning4j with my friends from Skymind! 
You have a question, a request, a bug report, or you want to operate a GPU cluster? tweet  me @SaMnCo_23 and let’s talk.