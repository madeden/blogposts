# Conclusion

This was a rather short blog post, but it will be instrumental for what is coming in the upcoming weeks. 

What did we learn? 

1. Deploy a simple dev cluster on AWS in a few commands (nothing new here for veterans!)
2. Automate the creation and connection of an EFS volume from the CLI
3. Consuming EFS from the Canonical Distribution of Kubernetes

Anything special about this? Yes. 

1. EFS presents itself as a NFS endpoint, hence it remains extremely portable across deployments. CDK on premises uses Ceph as a backend, most if this still works
2. EFS does not require IAM roles to get consumed from instances (S3 for example requires either credentials or an IAM role), making it extremely easy to consume
3. We saw the PV has a size, but we did not set anything in the EFS definition. EFS will scale indefinitely, this limit is a Kubernetes property for the PVs. 

In a future occurence, we will mix this post, GPUs and start investigating various Deep Learning frameworks on Kubernetes. 

Stay Tuned! 


