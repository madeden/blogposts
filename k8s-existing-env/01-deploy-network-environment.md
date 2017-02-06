# Deploying Network with CloudFormation

The target is to deploy a multi AZ cluster to achieve a proper level of HA between our worker nodes and control plane. 

The design below shows 

* 2x public subnets, in 2 different AZs
* 2x private subnets, also in 2 different AZs
* 1 public gateway, that will be used to connect the public subnets to Internet
* 1x private NAT gateway, to allow connectivity from the private subnets to Internet

![AWS Network Stack](/img/simple-multi-subnet-vpc.png)

The attached Cloudformation template defines all these. We deploy it using the GUI of AWS, going to *CloudFormation* and creating a new stack as shown on the images below. 

Juju will require the following setup: 

1. VPC should be in "available" state and contain one or more subnets.
2. An Internet Gateway (IGW) should be attached to the VPC.
3. The main route table of the VPC should have both a default route
   to the attached IGW and a local route matching the VPC CIDR block.
4. At least one of the VPC subnets should have MapPublicIPOnLaunch
   attribute enabled (i.e. at least one subnet needs to be 'public').
5. All subnets should be implicitly associated to the VPC main route
   table, rather than explicitly to per-subnet route tables.

First let us select the JSON file

![CloudFormation - Select Stack](/img/cf-00.png)

Add a few information

![CloudFormation - Setup](/img/cf-01.png)

Add a few options

![CloudFormation - Set Options](/img/cf-02.png)

and voilàààà! 

![CloudFormation - Deploy](/img/cf-03.png)

Now we have a nice setup with private and public subnets in a given VPC. 