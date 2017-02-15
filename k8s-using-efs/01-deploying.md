# Deploying the cluster
## Boostrap

As usual start with the bootstrap sequence. 

```
juju bootstrap aws/us-east-1 --credential canonical --constraints "cores=4 mem=16G root-disk=64G" 
# Creating Juju controller "aws-us-east-1" on aws/us-east-1
# Looking for packaged Juju agent version 2.1-rc1 for amd64
# Launching controller instance(s) on aws/us-east-1...
#  - i-0d48b2c872d579818 (arch=amd64 mem=16G cores=4)
# Fetching Juju GUI 2.3.0
# Waiting for address
# Attempting to connect to 54.174.129.155:22
# Attempting to connect to 172.31.15.3:22
# Logging to /var/log/cloud-init-output.log on the bootstrap machine
# Running apt-get update
# Running apt-get upgrade
# Installing curl, cpu-checker, bridge-utils, cloud-utils, tmux
# Fetching Juju agent version 2.1-rc1 for amd64
# Installing Juju machine agent
# Starting Juju machine agent (service jujud-machine-0)
# Bootstrap agent now started
# Contacting Juju controller at 172.31.15.3 to verify accessibility...
# Bootstrap complete, "aws-us-east-1" controller now available.
# Controller machines are in the "controller" model.
# Initial model "default" added.

```

## Deploying Kubernetes

As we have a standard reference architecture, let us just use a bundle: 

```
juju deploy src/k8s-aws.yaml
```

This will take about 10min. At the end the status should show: 

```
juju status
```

Great. Now let us see how to add storage. 

