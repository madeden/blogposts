# Bootstrapping Juju 

Now bootstrap a Juju Controller with : 

```
juju bootstrap aws/us-west-2 k8s-us-west-2 \
	--config vpc-id=vpc-fa6dfa9d --config vpc-id-force=true \
	--to "subnet=subnet-bb1ab2dc" \
	--bootstrap-constraints "root-disk=128G mem=8G" \
	--credential canonical \
	--bootstrap-series xenial
```

Which will output something like: 

```
WARNING! The specified vpc-id does not satisfy the minimum Juju requirements,
but will be used anyway because vpc-id-force=true is also specified.

Using VPC "vpc-fa6dfa9d" in region "us-west-2"
Creating Juju controller "k8s-us-west-2" on aws/us-west-2
Looking for packaged Juju agent version 2.1-beta5 for amd64
Launching controller instance(s) on aws/us-west-2...
 - i-001a9dce9beb162fd (arch=amd64 mem=8G cores=2)
Fetching Juju GUI 2.2.7
Waiting for address
Attempting to connect to 52.34.249.95:22
Attempting to connect to 10.0.1.254:22
Logging to /var/log/cloud-init-output.log on the bootstrap machine
Running apt-get update
Running apt-get upgrade
Installing curl, cpu-checker, bridge-utils, cloud-utils, tmux
Fetching Juju agent version 2.1-beta5 for amd64
Installing Juju machine agent
Starting Juju machine agent (service jujud-machine-0)
Bootstrap agent now started
Contacting Juju controller at 10.0.1.254 to verify accessibility...
Bootstrap complete, "k8s-us-west-2" controller now available.
Controller machines are in the "controller" model.
Initial model "default" added.
```

At this point, Juju doesn't know about the mapping of private and public subnets. Create 2 **spaces** with

```
juju add-space public 
added space "public" with no subnets
juju add-space private
added space "private" with no subnets
```

Now identify the subnets that are private from those that are public. Use the MapPublicIpOnLaunch property of the subnet as a discriminating factor

```
# Resolves private subnets: 
aws ec2 describe-subnets \
	--filter Name=vpc-id,Values=vpc-56416e32 \
	| jq --raw-output \
	'.[][] | select(.MapPublicIpOnLaunch == false) | .SubnetId'
subnet-ba1ab2dd
subnet-f44486bd
```

And 

```
# Resolves private subnets: 
aws ec2 describe-subnets \
	--filter Name=vpc-id,Values=vpc-56416e32 \
	| jq --raw-output \
	'.[][] | select(.MapPublicIpOnLaunch == true) | .SubnetId'
subnet-bb1ab2dc
subnet-f24486bb
```

Add the subnets to their respective space

```
juju add-subnet subnet-ba1ab2dd private
added subnet with ProviderId "subnet-ba1ab2dd" in space "private"
juju add-subnet subnet-f44486bd private
added subnet with ProviderId "subnet-f44486bd" in space "private"
juju add-subnet subnet-bb1ab2dc public
added subnet with ProviderId "subnet-bb1ab2dc" in space "public"
juju add-subnet subnet-f24486bb public
added subnet with ProviderId "subnet-f24486bb" in space "public"
```

Now Juju knows the mapping of your design in AWS. You are now ready to deploy Kubernetes. 
