# Adding ELB support to the Canonical Distribution of Kubernetes
## Creating the AWS IAM policies and Instance roles

Before we can think of adding ELBs to the cluster, we need to create roles and primitives in AWS. 

First create the policies for the workers and master: 

<pre><code>
aws iam create-policy \
  --policy-name k8sMaster \
  --description "Let CDK create ELBs and access S3" \
  --policy-document file://src/iam/policy-k8s-master.json

aws iam create-policy \
  --policy-name k8sWorker \
  --description "Let CDK create ELBs and access S3" \
  --policy-document file://src/iam/policy-k8s-worker.json
</code></pre>

Now create the roles: 

<pre><code>
aws iam create-role \
  --role-name k8sMaster \
  --assume-role-policy-document file://src/iam/assume-role.json

aws iam create-role \
  --role-name k8sWorker \
  --assume-role-policy-document file://src/iam/assume-role.json
</code></pre>

Attach the roles to the policies: 

<pre><code>
aws iam attach-role-policy \
	--role-name k8sMaster \
	--policy-arn arn:aws:iam::YourAccountID:policy/k8sMaster

aws iam attach-role-policy \
	--role-name k8sWorker \
	--policy-arn arn:aws:iam::YourAccountID:policy/k8sWorker
</code></pre>

Create the Instance Profiles and link the roles to the profiles

<pre><code>
aws iam create-instance-profile --instance-profile-name k8sMaster-Instance-Profile

aws iam create-instance-profile --instance-profile-name k8sWorker-Instance-Profile

aws iam add-role-to-instance-profile --role-name k8sMaster --instance-profile-name k8sMaster-Instance-Profile

aws iam add-role-to-instance-profile --role-name k8sWorker --instance-profile-name k8sWorker-Instance-Profile
</code></pre>

## Attaching IAM Roles to instances

Attach the Instance Roles to the instances deployed previously: 

<pre><code>
aws ec2 describe-instances \
	--filters "Name=tag:juju-units-deployed,Values=*kubernetes-master*" | \
	jq --raw-output '.[][].Instances[].InstanceId' | \
	xargs -I {} aws ec2 associate-iam-instance-profile \
		--iam-instance-profile Name=k8sMaster-Instance-Profile \
		--instance-id {}

aws ec2 describe-instances --filters "Name=tag:juju-units-deployed,Values=kubernetes-worker*" | \
	jq --raw-output '.[][].Instances[].InstanceId' | \
	xargs -I {} aws --profile=canonical --region=us-east-1 ec2 associate-iam-instance-profile --iam-instance-profile Name=k8sWorker-Instance-Profile --instance-id {}
</code></pre>

## Creating the right AWS Tags for Kubernetes

Kubernetes only wants a single Security Group with tags, so we remove all tags from all non critical SGs: 

First filter out all Security Groups for individual machines: 

<pre><code>
for KEY in KubernetesCluster juju-controller-uuid juju-model-uuid; do
	aws ec2 describe-instances | \
		jq --raw-output '.[][].Instances[] | select( .Tags[].Value  | contains ("k8s")) | .SecurityGroups[1].GroupId' | \
		sort | uniq | \
		xargs -I {} aws ec2 delete-tags --resources {}  --tags "Key="${KEY}
done
</code></pre>

And now only keep the KubernetesCluster tag on the common SG: 

<pre><code>
aws ec2 describe-instances | \
	jq --raw-output '.[][].Instances[] | select( .Tags[].Value  | contains ("k8s")) | .SecurityGroups[0].GroupId' | \
	sort | uniq | \
	xargs -I {} aws ec2 delete-tags --resources {} --tags "Key=juju-model-uuid"

aws ec2 describe-instances | \
	jq --raw-output '.[][].Instances[] | select( .Tags[].Value  | contains ("k8s")) | .SecurityGroups[0].GroupId' | \
	sort | uniq | \
	xargs -I {} aws ec2 delete-tags --resources {} --tags "Key=juju-controller-uuid"
</code></pre>

Now let's tag the subnets we're using for the workers with this KubernetesCluster tag as well: 

<pre><code>
juju status kubernetes-worker --format json | \
	jq -r '.machines[]."instance-id"' | \
	xargs -I {} aws ec2 describe-instances --instance-ids {} | \
	jq --raw-output '.[][].Instances[].SubnetId' | sort | uniq | \
	xargs -I {} aws ec2 create-tags --resources {} --tags "Key=KubernetesCluster,Value=workshop"
</code></pre>

