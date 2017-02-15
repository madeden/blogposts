# Adding and connecting an EFS Storage Backend
## Pre requisite 

In order to manage EFS, you will need: 

* the region where you deploy. In our case, us-east-1
* the VPC you run into. Juju uses the default VPC by default, so you can look that up in AWS GUI, or if you did not deploy more VPCs with

```
VPC_ID=$(aws --region us-east-1 ec2 describe-vpcs \
    | jq --raw-output '.[][].VpcId')
# vpc-b4ce2bd1
```

* All subnets you have instances deployed in

```
SUBNET_IDS=$(aws --region us-east-1 ec2 describe-subnets \
    | jq --raw-output '.[][].SubnetId')
# subnet-26300e52
# subnet-418dea7b
# subnet-0cc0984a
# subnet-645b204c
```

* The security group to allow access from

```
SG_ID=$(aws --region us-east-1 ec2 describe-instances \
    | jq --raw-output '.[][].Instances[] \
        | select( .Tags[].Value \
        | contains ("juju-default-machine-0")) \
        | .SecurityGroups[1].GroupId')
# sg-bc4101c0
```

Here we cheat a little bit. For each model you create, Juju will create a Security Group, which will be named with the format **juju-<uuid>** where uuid is a randomly generated 32 char UUID. Then each machine will inheritate a secondary security group with the format **juju-<uuid>-<id>**, where uuid is the same as the generic SG, and id is the machine ID in the model. 

As a result, straight after a deployment, each Juju machine will only have 2 SGs. We use this property and the default sorting method of jq to extract the correct value. 

## Creation of the EFS 

```
EFS_ID=$(aws canonical --region us-east-1 efs create-file-system --creation-token $(uuid) \
    | jq --raw-values '.FileSystemId'
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
```

Now you need to create mount points for each of the subnets you have instances in: 

```
for subnet in ${SUBNET_IDS}
do 
    aws --region us-east-1 efs create-mount-target \
        --file-system-id ${EFS_ID} \
        --subnet-id ${subnet} \
        --security-groups ${SG_ID}
done
{
    "LifeCycleState": "creating",
    "IpAddress": "172.31.24.140",
    "OwnerId": "131768076974",
    "NetworkInterfaceId": "eni-8c0bb86c",
    "MountTargetId": "fsmt-d900b590",
    "SubnetId": "subnet-26300e52",
    "FileSystemId": "fs-69de7c20"
}
{
    "OwnerId": "131768076974",
    "NetworkInterfaceId": "eni-265845ce",
    "SubnetId": "subnet-418dea7b",
    "FileSystemId": "fs-69de7c20",
    "LifeCycleState": "creating",
    "MountTargetId": "fsmt-da00b593",
    "IpAddress": "172.31.63.172"
}
{
    "IpAddress": "172.31.6.243",
    "NetworkInterfaceId": "eni-8d930649",
    "SubnetId": "subnet-0cc0984a",
    "FileSystemId": "fs-69de7c20",
    "OwnerId": "131768076974",
    "MountTargetId": "fsmt-dc00b595",
    "LifeCycleState": "creating"
}
{
    "SubnetId": "subnet-645b204c",
    "FileSystemId": "fs-69de7c20",
    "NetworkInterfaceId": "eni-17f676e5",
    "OwnerId": "131768076974",
    "IpAddress": "172.31.44.34",
    "LifeCycleState": "creating",
    "MountTargetId": "fsmt-df00b596"
}
```

And you are now ready to add storage in CDK

# Consuming from a different host

If you want to consume EFS fron a different node, you can via: 

```
sudo apt install -yqq nfs-common
mkdir efs
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 EFS_SERVICE_HOST:/ efs

```

