# Deploying Kubernetes
## MAAS / AWS

The method to deploy on MAAS is the same I described in my previous blog about [DIY GPU Cluster](https://hackernoon.com/installing-a-diy-bare-metal-gpu-cluster-for-kubernetes-364200254187#.si47g6h7e)

Once you have MAAS installed and Juju configured to talk to it, you can adapt and use the bundle file in src/juju/

```
juju deploy k8s-maas.yaml
```

for AWS, use the k8s-aws.yaml bundle, which specifies c4.4xlarge as the default instances. 

When it's done, download he configuration for kubectl then initialize Helm with

```
for WORKER_TYPE in cpu
do
  juju show-status kubernetes-worker-${WORKER_TYPE} --format json | \
    jq --raw-output '.applications."kubernetes-worker-'${WORKER_TYPE}'".units | keys[]' | \
    xargs -I UNIT juju ssh UNIT "sudo wget https://download.blender.org/durian/trailer/sintel_trailer-1080p.mp4 -O /mnt/sintel_trailer-1080p.mp4" 
done

juju scp kubernetes-master/0:config ~/.kube/config
helm init
```

## Variation for LXD 

LXD is a bit special, because the networking model is another overlay on top of the default. It breaks some of the primitives that are frequently used with Kubernetes such as the proxying of pods, which have to go through 2 layers of networking instead of 1. 

As a result, by default, 

* kubectl proxy doesn't work
* more importantly, helm doesn't work because it consumes a proxy to the Tiller pod by default

However, transcoding doesn't require network access but merely a pod doing some work on the file system, so that is not a problem. 

The least expensive path to resolve the issue I found is to deploy a specific node that is NOT in LXD but a "normal" VM or node. This node will be labeled as a control plane node, and we modify the deployments for tiller-deploy and kubernetes-dashboard to have a nodeSelector pointing to the controlPlane. Making this node small enough will ensure no transcoding get ever scheduled on it. 

I could not find a way to fully automate this, so here is a sequence of actions to run: 

```
juju deploy src/juju/k8s-lxd-<nb cores per lxd>c-<max concurrency>.yaml
```

This deploys the whole thing and you need to wait until it's done for the next step. Closely monitor ```juju status``` until you see that the deployment is OK, but flannel doesn't start. 

The adjust the LXD profile for each LXD node must to allow nested containers. In a near future (roadmapped for 2.3), Juju will gain the ability to declare the profiles it wants to use for LXD hosts. But for now, we need to build that manually: 

```
NB_CORES_PER_LXD=6 #This is the same number used above to deploy
for MACHINE in $(seq 1 1 2)
do
  ./src/bin/setup-worker.sh ${MACHINE} ${NB_CORES_PER_LXD}
done
```

If you're watching ```juju status``` you will see that flannel suddenly starts working. All good! Now download he configuration for kubectl then initialize Helm with

```
juju scp kubernetes-master/0:config ~/.kube/config
helm init
```

We need to identify the Worker that is not a LXD container, then label it as our control plane node, and all the others as compute plane:

```
kubectl label $(kubectl get nodes -o name | grep -v lxd) controlPlane=true
kubectl label $(kubectl get nodes -o name | grep lxd) computePlane=true
```

Now this is where it become manual we need to edit successively rc/monitoring-influxdb-grafana-v4, deploy/heapster-v1.2.0.1, deploy/tiller-deploy and deploy/kubernetes-dashboard, to add

```
      nodeSelector:
        controlPlane: "true"
```

that can be done with 

```
kubectl edit -n kube-system rc/monitoring-influxdb-grafana-v4
```

K8s will take care of restarting the containers for you. After that, the cluster is ready to run!

## Next step

We are now ready to run some benchmarks. Let us get going. 

