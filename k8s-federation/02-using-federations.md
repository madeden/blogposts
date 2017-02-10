# Deploying a multi cloud application

Now that the federation is running, let us deploy a cross cloud application and see if it really works. For this, we are going to use a slightly modified version of the demo application provided with the Canonical Distribution of Kubernetes, Microbots, and try to deploy each of the primitives from the subset Federations can manage. 

## Namespaces

Let us deploy a test NameSpace:

```
# Creation
kubectl --context=magicring create -f src/manifests/test-ns.yaml 
namespace "test-ns" created
# Check AWS
kubectl --context=aws get ns
NAME             STATUS    AGE
ns/default       Active    3d
ns/kube-system   Active    3d
ns/test-ns       Active    50s
# Check Azure
kubectl --context=azure get ns
NAME             STATUS    AGE
ns/default       Active    2d
ns/kube-system   Active    2d
ns/test-ns       Active    1m
```

OK, the basic of quotas and resource management is globally available. 

## Config Maps

Push a test configmap to the cluster to assert it works: 

```
# Publish
kubectl --context magicring create -f src/manifests/test-configmap.yaml 
configmap "test-configmap" created
# Check AWS
kubectl --context aws get cm 
NAME       DATA      AGE
test-configmap   1         55s
# Check Azure
kubectl --context azure get cm 
NAME       DATA      AGE
test-configmap   1         1m
```

OK, so our configmap has been shared across all the clouds. We can have a single point of control for configuration. 

This also works for secrets. 

## Deployments / ReplicaSets / DaemonSets

First of all, deploy 10 replicas of the microbots: 

```
# Note we are still in the Magic Ring context...
kubectl create -f src/manifests/microbots-deployment.yaml 
deployment "microbot" created
```

Let us see where they went: 

```
# Querying the Federation control planed does not work
kubectl get pods -o wide
the server doesn't have a resource type "pods"
# Querying AWS cluster directly
kubectl --context=aws get pods 
NAME                             READY     STATUS    RESTARTS   AGE
default-http-backend-wqrmm       1/1       Running   0          1d
microbot-1855935831-6n08n        1/1       Running   0          1m
microbot-1855935831-fvd7q        1/1       Running   0          1m
microbot-1855935831-gg5ql        1/1       Running   0          1m
microbot-1855935831-kltf0        1/1       Running   0          1m
microbot-1855935831-z7zp1        1/1       Running   0          1m

# Now querying Azure directly
kubectl --context=azure get pods 
NAME                             READY     STATUS    RESTARTS   AGE
default-http-backend-04njk       1/1       Running   0          1h
microbot-1855935831-19m1p        1/1       Running   0          1m
microbot-1855935831-2gwjt        1/1       Running   0          1m
microbot-1855935831-8k3hc        1/1       Running   0          1m
microbot-1855935831-fgrn0        1/1       Running   0          1m
microbot-1855935831-ggvvf        1/1       Running   0          1m
```

The federation shared our Microbots evenly between clouds. This is the expected behavior. If we had more clusters, each one would get a fair share of the pods.

However it is to be noted that not everything worked, though I am unclear at this stage what went wrong and the consequences. The logs show:

```
E0210 10:35:53.691358       1 deploymentcontroller.go:516] Failed to ensure delete object from underlying clusters finalizer in deployment microbot: failed to add finalizer orphan to deployment : Operation cannot be fulfilled on deployments.extensions "microbot": the object has been modified; please apply your changes to the latest version and try again
E0210 10:35:53.691566       1 deploymentcontroller.go:396] Error syncing cluster controller: failed to add finalizer orphan to deployment : Operation cannot be fulfilled on deployments.extensions "microbot": the object has been modified; please apply your changes to the latest version and try again
```

You can test DaemonSets with: 

```
kubectl --context=magicring create -f src/manifests/microbots-ds.yaml 
daemonset "microbot-ds" created

kubectl --context aws get po -n test-ns
NAME                READY     STATUS    RESTARTS   AGE
microbot-ds-5c25n   1/1       Running   0          48s
microbot-ds-cmvtj   1/1       Running   0          48s
microbot-ds-lp0j0   1/1       Running   0          48s

kubectl --context azure get po -n test-ns
NAME                READY     STATUS    RESTARTS   AGE
microbot-ds-bkj34   1/1       Running   0          53s
microbot-ds-r85z4   1/1       Running   0          53s
microbot-ds-w8kxg   1/1       Running   0          53s
```

## Services 

Now let us create the service : 

```
# Service first...
kubectl --context=magicring create -f src/manifests/microbots-svc.yaml 
service "microbot" created
```

Do not rush this, as it can take a few minutes...

```
# On AWS
$ kubectl --context=aws get svc
NAME                   CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
default-http-backend   10.152.183.100   <none>        80/TCP         3d
kubernetes             10.152.183.1     <none>        443/TCP        3d
microbot               10.152.183.173   <none>        80/TCP         1d
On Azure
$ kubectl --context=azure get svc
NAME                   CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
default-http-backend   10.152.183.103   <none>        80/TCP    2d
kubernetes             10.152.183.1     <none>        443/TCP   2d
microbot               10.152.183.153   <none>        80/TCP    1d
```

Good! We can see again that the service has been duplicated on both clusters as expected. The Federation is sharding services all over the place. 

Even better, it also synchronized our DNS Zone in Google Cloud DNS:

```
$ gcloud dns record-sets list --zone demo-madeden
NAME                                                                   TYPE   TTL    DATA
demo.madeden.net.                                                      NS     21600  ns-cloud-a1.googledomains.com.,ns-cloud-a2.googledomains.com.,ns-cloud-a3.googledomains.com.,ns-cloud-a4.googledomains.com.
demo.madeden.net.                                                      SOA    21600  ns-cloud-a1.googledomains.com. cloud-dns-hostmaster.google.com. 2 21600 3600 259200 300
microbot.default.magicring.svc.eu-west-2a.eu-west-2.demo.madeden.net.  CNAME  180    microbot.default.magicring.svc.eu-west-2.demo.madeden.net.
microbot.default.magicring.svc.eu-west-2.demo.madeden.net.             CNAME  180    microbot.default.magicring.svc.demo.madeden.net.
microbot.default.magicring.svc.us-west-2.demo.madeden.net.             CNAME  180    microbot.default.magicring.svc.demo.madeden.net.
microbot.default.magicring.svc.us-west-2a.us-west-2.demo.madeden.net.  CNAME  180    microbot.default.magicring.svc.us-west-2.demo.madeden.net.
```

So we can see our region configuration being used to create the records. 

Also worth nothing the change in the DNS structure from <service>.<namespace>.svc.cluster.local to <service>.<namespace>.<federation>.svc.<failure-zone>.<dns-zone>

So now, microbot.default.magicring.svc.demo.madeden.net connects to the 2 clusters transparently, meaning we have **global DNS resolution of the services**. Pretty awesome!  

## Ingresses

Unfortunately this is not going to go as well... 

```
# deploying Ingress...
kubectl --context=magicring create -f 
  src/manifests/microbots-ing.yaml 
ingress "microbot-ingress" created
```

Checking the results: 

```
# Querying ing on AWS
kubectl --context=aws get ing
NAME               HOSTS                        ADDRESS            PORTS     AGE
microbot-ingress   microbots.demo.madeden.net   10.0.1.95,10....   80        1d
# On AWS
kubectl --context=azure get ing
No resources found.
# Oups!! 
kubectl --context=magicring get ing
NAME               HOSTS                        ADDRESS            PORTS     AGE
microbot-ingress   microbots.demo.madeden.net   10.0.1.95,10....   80        1d
kubectl --context=magicring describe ing microbot-ingress
Name:     microbot-ingress
Namespace:    default
Address:    10.0.1.95,10.0.2.43,10.0.2.43
Default backend:  default-http-backend:80 (<none>)
Rules:
  Host        Path  Backends
  ----        ----  --------
  microbots.demo.madeden.net  
            /   microbot:80 (<none>)
Annotations:
  first-cluster:  aws
Events:
  FirstSeen LastSeen  Count From        SubObjectPath Type    Reason    Message
  --------- --------  ----- ----        ------------- --------  ------    -------
  1d    3m    2 {federated-ingress-controller }     Normal    CreateInCluster Creating ingress in cluster azure
  1d    1m    1 {federated-ingress-controller }     Normal    UpdateInCluster Updating ingress in cluster azure
  1d    1m    6 {federated-ingress-controller }     Normal    CreateInCluster Creating ingress in cluster aws
```

Clearly there is a problem here. The Ingress has not been pushed to all clusters. This is a known bug when clusters are not deployed in GCE/GKE (which is to date the only environment where Federation is tested)

You can checkout 

* https://github.com/kubernetes/kubernetes/issues/33943
* https://github.com/kubernetes/kubernetes/issues/34291

for more details about this. 

If you want to intercept this error from the logs, 

```
# log from the Federation Controller Manager 
## And specific for the ingress creation
E0210 08:54:08.464928       1 ingress_controller.go:725] Failed to ensure delete object from underlying clusters finalizer in ingress microbot-ingress: failed to add finalizer orphan to ingress : Operation cannot be fulfilled on ingresses.extensions "microbot-ingress": the object has been modified; please apply your changes to the latest version and try again
E0210 08:54:08.472338       1 ingress_controller.go:672] Failed to update annotation ingress.federation.kubernetes.io/first-cluster:aws on federated ingress "default/microbot-ingress", will try again later: Operation cannot be fulfilled on ingresses.extensions "microbot-ingress": the object has been modified; please apply your changes to the latest version and try again
```

It eventually gets worse if you try to delete your ing, at which point it doesn't disappear at all and you have to delete on each cluster. 

You still want to have access to my Ingress Endpoint! The only workaround I found is to deploy individually 

```
for cloud in aws azure
do
  kubectl --context=${cloud} create -f src/manifests/microbots-ing.yaml 
done
```

You can then expose this service directly in the managed zone

```
# Identify the public addresses of the workers
juju switch aws
AWS_INSTANCES="$(juju show-status kubernetes-worker --format json | jq --raw-output '.applications.kubernetes-worker".units[]."public-address"' | tr '\n' ' ')"
juju switch azure
AZURE_INSTANCES="$(juju show-status kubernetes-worker --format json | jq --raw-output '.applications."kubernetes-worker".units[]."public-address"' | tr '\n' ' ')"
# Create the Zone File
touch /tmp/zone.list
for instance in ${AWS_INSTANCES} ${AZURE_INSTANCES}; 
do 
  echo "microbots.demo.madeden.net. IN A ${instance}" | tee -a /tmp/zone.list
done
# Add a A record to the zone
gcloud dns record-sets import -z demo-madeden \
      --zone-file-format \
      /tmp/zone.list
```

After a few minutes, when you point your browser to this endpoint, you will see the Microbot web page, evenly displaying podnames from AWS and Azure instances. 


