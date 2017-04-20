A little while ago I wrote a series of blog posts about Deep Learning and Kubernetes, using the Canonical Distribution of Kubernetes on Amazon and Bare Metal to deploy Tensorflow. These posts were highly technical, and fairly long and difficult to replicate. 

Yesterday, I published another post, explaining how the recent addition of GPUs as first class citizens in CDK changed the game. This last post has had a lot of success, a lot more than I initially anticipated to be completely honest. Thank you all for that, it is always pleasant to see that content reaches its audience and that people are interested in your work. 

The wide audience it reached also led me to conclude that I should probably revisit my previous Tensorflow work in light of all the comments and feedback I got, and explain how having trivialized GPUs access in Kubernetes can help scientists to deploy scalable, long running Tensorflow jobs (or any other deep learning afaiac). This post is the result of that thought process. 

# The plan

So today, we will:

1. Deploy a GPU enabled Kubernetes cluster, made of 1 CPU node and 3 GPU-enabled nodes. 
2. Add Storage to the cluster, via EFS
3. Deploy a Tensorflow workload
4. Look how you can use this for your own tensorflow

For the sake of clarity, this is an updated, condensed version of [links to former posts] that benefits from the latest and greatest additions to the Canonical Distribution of Kubernetes. 

# Requirements

To replicate this post, you will need: 

* Understanding of the tooling Canonical develops and uses: Ubuntu and Juju
* An admin account (Key and Secret) on AWS and enough credits to run p2 instances for a little while
* Understanding of the tooling for Kubernetes: kubectl and helm. 
* an Ubuntu 16.04 or higher, CentOS 6+, MacOS X, or Windows 7+ machine. This blog will focus on Ubuntu, but you can follow guidelines for other OSes via [this presentation](https://goo.gl/wssxJ1)

If you experience any issue in deploying this, or if you have specific requirements (non default VPCs, subnets...), connect with us on IRC. I am SaMnCo on Freenode #juju, and the rest of the Kubernetes team is also available to help. 

# Preparing your environment

First of all let's deploy Juju on your machine as well as a couple of useful tools: 

<pre><code>
sudo add-apt-repository -y ppa:juju/devel
sudo apt update
sudo apt install -yqq juju jq git python-pip
sudo pip install --upgrade awscli
</code></pre>

Now let's add credentials for AWS so you can deploy there: 

<pre><code>
juju add-credential aws
</code></pre>

Finally, let's download kubectl and helm

<pre><code>
# kubectl
curl -LO https://storage.googleapis.com/kubernetes-release/release/1.6.2/bin/linux/amd64/kubectl
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# helm
wget https://kubernetes-helm.storage.googleapis.com/helm-v2.3.1-linux-amd64.tar.gz
tar xfz helm-v2.3.1-linux-amd64.tar.gz
chmod +x linux-amd64/helm && sudo mv linux-amd64/helm /usr/local/bin/
rm -rf helm-v2.3.1-linux-amd64.tar.gz linux-amd64
</code></pre>

Clone the charts repository

<pre><code>
git clone https://github.com/madeden/charts.git
</code></pre>

Clone the Docker Images repository for inspiration: 

<pre><code>
git clone https://github.com/madeden/docker-images.git
</code></pre>

Clone this repository to access the source documents:

<pre><code>
git clone https://github.com/madeden/blogposts.git
cd blogposts/k8s-tensorflow
</code></pre>

OK! We're good to go. 

# Deploying the cluster

First of all, we need to bootstrap in a region that is GPU-enabled, such as us-east-1

<pre><code>
juju bootstrap aws/us-east-1
</code></pre>


Now deploy with :

<pre><code>
juju deploy src/bundles/k8s-tensorflow.yaml
</code></pre>

This will take some time. You can track how the deployment converges with : 

<pre><code>
watch -c juju status --color
</code></pre>

At the end, you should see all units "idle", all machines "started" and it should look green. 

INSERT IMAGE 

At this point in time, as CUDA enablement is now fully automated, we can safely assume that our cluster is ready to operate GPU workloads. We can download the configuration: 

<pre><code>
mkdir -p ~/.kube
juju scp kubernetes-master/0:config ~/.kube/config
</code></pre>

and query the cluster state: 

<pre><code>
kubectl cluster-info
Kubernetes master is running at https://34.201.171.159:6443
Heapster is running at https://34.201.171.159:6443/api/v1/proxy/namespaces/kube-system/services/heapster
KubeDNS is running at https://34.201.171.159:6443/api/v1/proxy/namespaces/kube-system/services/kube-dns
kubernetes-dashboard is running at https://34.201.171.159:6443/api/v1/proxy/namespaces/kube-system/services/kubernetes-dashboard
Grafana is running at https://34.201.171.159:6443/api/v1/proxy/namespaces/kube-system/services/monitoring-grafana
InfluxDB is running at https://34.201.171.159:6443/api/v1/proxy/namespaces/kube-system/services/monitoring-influxdb

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
</code></pre>

The default username:password for the dashboard or Graphana is "admin:admin". 


Let's have a look: 

INSERT IMAGES HERE

# Connecting an EFS drive

First of all you need to know the VPC ID where you are deploying. You can access it from the AWS UI, or with

<pre><code>
export VPC_ID=$(aws ec2 describe-vpcs | jq -r '.[][].VpcId')
</code></pre>

Now we need to know the subnets where our instances are deployed: 

<pre><code>
export SUBNET_IDS=$(aws ec2 describe-subnets --filter Name=vpc-id,Values=vpc-b4ce2bd1 | jq -r '.[][].SubnetId')
</code></pre>

And now we need the list of Security Groups to add to our EFS access: 

<pre><code>
export SG_ID=$(aws ec2 describe-instances --filter "Name=tag:Name,Values=juju-default-machine-0" | jq -r '.[][].Instances[].SecurityGroups[0].GroupId')
</code></pre>


At this point, if have an EFS already deployed, just store its ID in EFS_ID, and make sure you delete all its mount points. If you do not have an EFS, create one with : 

<pre><code>
export EFS_ID=$(aws efs create-file-system --creation-token $(uuid) \
    | jq --raw-output '.FileSystemId')
# fs-69de7c20
# Note the full output: 
# {
#     "CreationToken": "f2513790-f2c8-11e6-a002-9735d97703bd",
#     "LifeCycleState": "creating",
#     "OwnerId": "131768076974",
#     "FileSystemId": "fs-69de7c20",
#     "NumberOfMountTargets": 0,
#     "PerformanceMode": "generalPurpose",
#     "CreationTime": 1487085556.0,
#     "SizeInBytes": {
#         "Value": 0
#     }
# }
</code></pre>

And finally create the mount endpoint with : 

<pre><code>
for subnet in ${SUBNET_IDS}
do 
    aws --profile canonical --region us-east-1 efs create-mount-target \
        --file-system-id ${EFS_ID} \
        --subnet-id ${subnet} \
        --security-groups ${SG_ID}
done
</code></pre>

From the UI, you can now check that the EFS has mount points available from the Juju Security Group, which should look like "juju-3d57d67a-8603-4161-8fc2-dc7e1ee08eef". 

Note: users of this Tensorflow use case have reported that EFS is a little slow, and that other methods such as SSD EBS are faster. Consider this the easy demo path. If you have an advanced, IO intensive training, then let me know, and we'll sort you out. 

# Connecting EFS as a Persistent Volume in Kubernetes

We are now done with the Juju and AWS side, and can focus on deploying applications via the Helm Charts. Let's switch to our charts folder: 

<pre><code>
cd ../../charts
</code></pre>

Now let's create our configuration file for the EFS volume. Copy efs/values.yaml to ./efs.yaml  

<pre><code>
cp efs/values.yaml ./efs.yaml
</code></pre>

and update the id of the EFS volume. It shall look like:

<pre><code>
global:
  services:
    aws:
      region: us-east-1
      efs:
        id: fs-47cd610e

storage:
  name: tensorflow-fs
  accessMode: ReadWriteMany
  pv: 
    capacity: "900Gi"
  pvc:
    request: "750Gi"
</code></pre>

Now deploy it with Helm

<pre><code>
helm install efs --name efs --values ./efs.yaml
</code></pre>

It will output something like: 

<pre><code>
NAME:   efs
LAST DEPLOYED: Thu Apr 20 13:57:37 2017
NAMESPACE: default
STATUS: DEPLOYED

RESOURCES:
==> v1/PersistentVolumeClaim
NAME           STATUS  VOLUME         CAPACITY  ACCESSMODES  AGE
tensorflow-fs  Bound   tensorflow-fs  900Gi     RWX          1s

==> v1/PersistentVolume
NAME           CAPACITY  ACCESSMODES  RECLAIMPOLICY  STATUS  CLAIM                  REASON  AGE
tensorflow-fs  900Gi     RWX          Retain         Bound   default/tensorflow-fs  1s


NOTES:
This chart has created 

* a PV tensorflow-fs of 900Gi capacity in ReadWriteMany mode
* a PVC tensorflow-fs of 750Gi in ReadWriteMany mode 

They consume the EFS volume fs-47cd610e.efs.us-east-1.amazonaws.com
</code></pre>

In the KubeUI, you can see that the PVC is "bound", which means it is connected and available for consumption by other pods. 

# Running an example Distributed CNN

There is a non GPU workload available in the charts repo called "distributed-cnn". It is an example I took from a Google Tensorflow Workshop and adapted to port it to Helm. 

Let's copy the values.yaml file and adapt it: 

<pre><code>
cp distributed-cnn/values.yaml ./dcnn.yaml
</code></pre>

and update the id of the EFS volume. The different sections are: 


* Data Initialization: this section configures a job to download the data into our EFS drive and uncompress it. If you already have run this example, you can set the "isRequired" to false, and it won't attempt to run it again. If it's your first time, keep it to "true"

<pre><code>
global:
  imagePullPolicy: IfNotPresent

storage:
  name: tensorflow-fs

dataImport:
  isRequired: true
  service:
    name: load-data
  settings:
    url: https://storage.googleapis.com/oscon-tf-workshop-materials/processed_reddit_data/news_aww/prepared_data.tar.gz
  image: 
    repo: gcr.io/google-samples
    name: tf-workshop
    dockerTag: v2
</code></pre>


* Cluster Configuration: This tells if we want to use GPUs, and how many Parameter Servers and Workers we want to use. Note that the code doesn't support GPU, this is really an example of what would happen from a configuration standpoint. 

<pre><code>
tfCluster:
  service:
    name: tensorflow-cluster
    internalPort: 8080
    externalPort: 8080
    type: ClusterIP
  image: 
    repo: gcr.io/google-samples
    name: tf-worker-example
    dockerTag: latest
  settings:
    isGpu: false
    jobs: 
      ps: 8
      worker: 16
</code></pre>

* And the Tensorboard ingress endpoint to monitor the results. Here there is a DNS required. Set it to the result of 

<pre><code>
echo $(juju status kubernetes-worker-cpu --format json | jq -r '.machines[]."dns-name"').xip.io
</code></pre>

<pre><code>
tensorboard:
  replicaCount: 1
  image: 
    repo: gcr.io/tensorflow
    name: tensorflow
    dockerTag: 1.1.0-rc2
  service:
    name: tensorboard
    dns: 34.204.92.163.xip.io
    type: ClusterIP
    externalPort: 6006
    internalPort: 6006
    command: '["tensorboard", "--logdir", "/var/tensorflow/output"]'
  settings:
  resources:
    requests:
      cpu: 1000m
      memory: 1Gi
    limits:
      cpu: 4000m
      memory: 8Gi
</code></pre>

Now deploy it with Helm

<pre><code>
helm install distributed-cnn --name dcnn --values ./dcnn.yaml
</code></pre>

depending on the number of workers and parameter servers, the output will be more or less extensive. At the end, you can see the indications: 

<pre><code>
NOTES:
This chart has deployed a cluster a Distributed CNN. It has: 

* 8 parameter servers
* 16 workers


Enjoy Tensorflow on 34.204.92.163.xip.io when the service is fully deployed, which takes a few minutes. 

You can monitor the status with "kubectl get pods"
</code></pre>

That's it, you can connect to your tensorboard and see the output. 

If you want to compare results, just create several values.yaml files and upgrade your cluster: 

<pre><code>
helm upgrade dcnn distributed-cnn --values ./new-values-files.yaml
</code></pre>

When you are happy and this and ready to get rid of it, you can delete it with 

<pre><code>
helm delete dcnn --purge
</code></pre>

# Running your own code

It's always nice to understand things by copying what others have already done. That's open source. It's also the fastest way to get things done in 90% of the time. Don't reinvent the wheel. 

Then the next step is the DIY, and, if you are reading this post now, you probably want to run your own Tensorflow code. 

So start a new Dockerfile, and fill it with: 

<pre><code>
FROM tensorflow/tensorflow:1.1.0-rc2-gpu

ADD worker.py worker.py

CMD ["python", "worker.py"]
</code></pre>

Adapt this to your need (version...), and write this worker.py file that you'll need. Make sure of: 

1. Following the [guidelines for distributed tensorflow](https://www.tensorflow.org/deploy/distributed)
2. Expect that the environment variable POD_NAME will contain your job name and id (worker or ps, then the task index with the format worker-0)
3. Expect that the environment variable CLUSTER_CONFIG will contain your cluster configuration

the example Google gives looks like: 

<pre><code>
import tensorflow as tf
import os
import logging
import sys
import ast

root = logging.getLogger()
root.setLevel(logging.INFO)
ch = logging.StreamHandler(sys.stdout)
root.addHandler(ch)

POD_NAME = os.environ.get('POD_NAME')
CLUSTER_CONFIG = os.environ.get('CLUSTER_CONFIG')
logging.info(POD_NAME)


def main(job_name, task_id, cluster_def):
    server = tf.train.Server(
        cluster_def,
        job_name=job_name,
        task_index=task_id
    )
    server.join()


if __name__ == '__main__':
    this_job_name, this_task_id, _ = POD_NAME.split('-', 2)
    cluster_def = ast.literal_eval(CLUSTER_CONFIG)
    main(this_job_name, int(this_task_id), cluster_def)
</code></pre>

Once you have that ready, build and publish your images. You can have a CPU only image for the Parameter Servers, and a GPU one for the workers, or just one of them. Up to you to decide. 

Note:  Example Dockerfiles are available in the docker-image repository for this, with several version of Tensorflow

Then copy the values.yaml file from the tensorflow chart, and adapt it by pointing the cluster to your images. Then follow the same practice as before 

<pre><code>
helm install tensorflow --name fs --values ./tf.yaml
</code></pre>

All the files to adjust scripts, python and Dockerfiles are in the Docker Image repository you cloned at the beginning. 

# Tearing down

To tear down the Juju cluster once you are done: 

<pre><code>
juju destroy-controller aws-us-east-1 --destroy-all-models
</code></pre>



# Conclusion 

This blog shows the progress that has been made in 3 months in the Canonical Distribution of Kubernetes to deploy GPU workloads. What used to take 3 posts now takes only 1! 

The Tensorflow chart is being use by various teams right now, and they are all giving very useful feedback. We're now looking into 

* Optionally converting the deployments into jobs, so that training can be a one shot instead of a continuously running action
* Improving placement / scheduling to maximize performance
* Adding more storage backends

Let me how that goes for you, and if you have a use case for Tensorflow and would like to use this, let me know, so we collectively end up with a useful chart for everyone. 


