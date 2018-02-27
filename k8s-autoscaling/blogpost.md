# Opportunistic Autoscaling with the Kubernetes HPA

Since the version 1.6 of Kubernetes it is possible to use custom metrics to autoscale an application within a cluster. 

It means you can expose metrics such as the number of hits on an API or the latency of an API, and scale the serving pods according to that metric instead of the CPU load. 

Now let's say you are operating a cluster which you rent to your customers via a Serverless Framework such as Kubeless, Nuclio or Fission. You charge your customers by the GB-s used and the number of invocations. But on the other end, your cost is really that you run the machines. So you would like to make sure that the cluster is used as much as possible. 

You notice over time that the cluster is in fact only used at 60% in average, but there are peaks at certain times of the day where it loads at 90%. These peaks are really hard to predict because they depend on your customers' business.  

You would like to leverage the remainer of the capacity, so that the cluster is permanently used at its max capacity. You found that [NiceHash](https://www.nicehash.com/) would be happy to buy it. Now you need to find a way to dynamically allocate the right amount of resources.

## "Opportunistic Scaling"

You create an application that can look into the cluster and extract the capacity currently being used, and computes the remaining capacity.

This remaining capacity is fed to an autoscaler, which will scale an app to consume it. 

As a result: 
* If the "paid" load on your cluster goes UP, the remaining resources go DOWN, and you DOWNSCALE the mining app.
* If on the contrary your paid load goes DOWN, the remaining capacity goes UP, and you SCALE UP the number of mining containers. 

The target is to have a load that is as constant as possible around a threshold you define (85% let's say), thus collecting an average of 25% unused power and monetize it. 

It may look a silly application but I can definitely tell you that the mining pools seem to have a load variation when office hours finish, showing that business resources are definitely being used for mining at night! 

In any case, this is what I define here as **Opportunistic Scaling**: the fact for an application to consume only resources available, and not overrule other apps.

In a real life scenario, crypto mining is effectively adding resources to a compute grid, hence it does also make sense beyond the hype and fun. There are also a lot of other interesting use cases. Among others: 

* Lambda on the edges using a serverless framework (Telco / Cloud Operator)
* Elastic transcoding (Media Lab / Cloud): Think of what Ikea is doing on workstations but in a compute cluster
* AI on the edges (Media Lab / Cloud)
* Caching (CDN)
* The cool use case you'll share in comments1 

Now let's see how we can do that with Kubernetes.   

## Using Reversed Custom Metrics

In this blog, we will create a K8s cluster with a custom metrics API on bare metal. 

We then create an app that exposes (among others) a metric 

Remaining CPU = (total amount of CPU requested in cluster) - (total requested by all applications but myself)

This metrics decreases when the load of the cluster grows, and grows when the load shrinks. This effectively will make the metric a "client" of the requested load on a server.  

Then we will use this metric to configure a Horizontal Pod Autoscaler (HPA) in Kubernetes. This will result in keeping the load in the cluster as high as possible. 

## Information about this post

This blog post has been sponsored by my friends at [Kontron](https://www.kontron.com/) who gracefully allowed me to play with a 6 nodes cluster of their latest SymKloud Platform. Each node has 24 to 32 cores, and some of them have nVidia P4 cards. 

<insert Kontron Content> 


</insert Kontron Content> 

In addition, my friend [Ronan Delacroix](@ronhanson) helped me with the code based and wrote most of the python needed for this experiment. 

<insert Ronan Content> 


</insert Ronan Content> 

# Setup
## Kubernetes Cluster

There are so many solutions out there to build one that we cannot even count them anymore. But as usual for my posts on bare metal I will use a [Canonical Distribution of Kubernetes](https://www.ubuntu.com/kubernetes) (CDK), in its version 1.8. 

So we assume that you have a K8s Cluster in version 1.8, with RBAC active, and an admin role. 

**Important Note**: The APIs we will be using here are very unstable and subject to big changes. I really recommend you read the K8s change log to check on them. 
* For example, there was a [change in 1.8](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG-1.8.md) on the name of the APIs. If you run a 1.7 cluster, this will impact you. 
* There are also changes in 1.9 and the custon.metrics.k8s.io moves from v1alpha1 to v1beta1.  

There are some details of the configuration we will see today that are done in a certain way on [CDK](https://www.ubuntu.com/kubernetes) and may be slightly different on clusters that are self hosted. I will try to mention them whenever possible. 

## Foreplay

Make sure you installed

* a [CDK](https://www.ubuntu.com/kubernetes) cluster deployed, and access to the Juju Tooling. In this post, I use Juju 2.3.1
* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
* [helm](https://github.com/kubernetes/helm/blob/master/docs/install.md)
* [stern](https://github.com/wercker/stern)
* [jq](https://stedolan.github.io/jq/download/)
* [cfssl and cfssljson](https://github.com/cloudflare/cfssl)

### RBAC Configuration 

**NOTE**: this applies to CDK, and will apply to GKE when the API Aggregation is GA with K8s 1.9. 

On CDK and GKE the default user is not a real admin from an RBAC perspective, so you need to update it before you can create other Cluster Role Bindings that extend your own role. 

First make sure you know your identity with 

* CDK: you are the user admin 

```
$ export ADMIN_USER=admin
```

* On GKE: 

```
$ export ADMIN_USER=$(gcloud info --format json | jq -r '.config.account')
you@your-domain.com
```

Now grant yourself the cluster-admin role: 

```
$ kubectl create clusterrolebinding super-admin-binding \
   --clusterrole=cluster-admin \
   --user=${ADMIN_USER}
clusterrolebinding "super-admin-binding" created
```

You can then check it out with: 

```
$ kubectl get clusterrolebinding super-admin-binding -o yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  creationTimestamp: 2018-01-15T09:34:11Z
  name: super-admin-binding
  resourceVersion: "825179"
  selfLink: /apis/rbac.authorization.k8s.io/v1/clusterrolebindings/super-admin-binding
  uid: 3e244e73-f9d7-11e7-bdb6-42010a9a0027
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: User
  name: admin
```

### Helm Install

In order for Helm to operate in a RBAC cluster, we need to add it as a cluster-admin as well: 

```
$ kubectl create -f src/rbac-helm.yaml
serviceaccount "tiller" created
clusterrolebinding "tiller" created
$ helm init --service-account tiller
```

OK, we are done with prepping our cluster

**Note**: By default Helm deploys without resource constraints. When trying to surcharge a cluster and maximize its usage, it means that Tiller will be part of the pods that may go away because resources are exhausted. If you do not want that to happen, you can edit the manifest and reapply it: 

```
$ kubectl get deploy -n kube-system tiller -o yaml > manifest-tiller.yaml
# edit the manifest and add resource constraints 
$ kubectl apply -f manifest-tiller.yaml
```

## AutoScaling: Preparing the cluster
### Introduction & References  

First of all, I recommend you have a look at the [documentation](https://kubernetes.io/docs/concepts/overview/extending/) about extending Kubernetes. 

Then also look at the [documentation](https://kubernetes.io/docs/concepts/api-extension/apiserver-aggregation/) about extending Kubernetes with the Aggregation Layer. 

The last theorical doc is about setting up an API Server, and you can find it [here](https://kubernetes.io/docs/tasks/access-kubernetes-api/setup-extension-api-server/).

Once the aggregation is active, we will deploy 2 custom APIs: the [Metric Server](https://github.com/kubernetes-incubator/metrics-server) and a [Custom Metric Adapter](https://github.com/DirectXMan12/k8s-prometheus-adapter)

OK now that you are versed in what we need to do, let's get started. 

### Configuring the control plane

In order to activate the Aggregation Layer, we must add a few flags to our API Server: 

```
$ juju config kubernetes-master \
    api-extra-args="enable-aggregator-routing=true \
    requestheader-client-ca-file=/root/cdk/ca.crt \
    requestheader-allowed-names=aggregator \
    requestheader-extra-headers-prefix=X-Remote-Extra- \
    requestheader-group-headers=X-Remote-Group \
    requestheader-username-headers=X-Remote-User \
    enable-aggregator-routing=true \
    client-ca-file=/root/cdk/ca.crt"
```

You will note that we do not activate the flags 

```
--proxy-client-cert-file=<path to aggregator proxy cert>
--proxy-client-key-file=<path to aggregator proxy key>
```

This is because the proxy in CDK uses a Kubeconfig and not a client certificate. 

However, we do enable the aggregator routing because the control plane of Kubernetes is not self hosted and we fall in the case "If you are not running kube-proxy on a host running the API server, then you must make sure that the system is enabled with the enable-aggregator-routing flag". 

Also we added the client-ca-file flag to export the CA of the API server in the cluster.

Now for the Controller Manager, we must tell it to use the HPA, which we do with: 

```
$ juju config kubernetes-master \
    controller-manager-extra-args="enable-aggregator-routing=true \
    horizontal-pod-autoscaler-sync-period='10s' \
    horizontal-pod-autoscaler-use-rest-clients=true \
    horizontal-pod-autoscaler-downscale-delay=30s \
    horizontal-pod-autoscaler-upscale-delay=30s
    " 
```

Note that the 2 last options here are really for demos to make it quick to observe the results of actions. You may not need change them for your use case (they default to 3m and 5m)

Just to make sure the settings are apply restart the 2 services with 

```
$ for service in apiserver controller-manager; do
  juju run --application kubernetes-master 'sudo systemctl restart snap.kube-${service}.daemon.service'
done 
```

This will make Kubernetes create a configmap in the kube-system namespace called extension-apiserver-authentication, which contains all the additional flags we generated and their configuration. You can have a look at it via 

```
$ kubectl get cm -n kube-system extension-apiserver-authentication -o yaml
apiVersion: v1
data:
  client-ca-file: |-
    -----BEGIN CERTIFICATE-----
    ...
    -----END CERTIFICATE-----
  requestheader-allowed-names: '["aggregator"]'
  requestheader-client-ca-file: |-
    -----BEGIN CERTIFICATE-----
    ...
    -----END CERTIFICATE-----
  requestheader-extra-headers-prefix: '["X-Remote-Extra-"]'
  requestheader-group-headers: '["X-Remote-Group"]'
  requestheader-username-headers: '["X-Remote-User"]'
kind: ConfigMap
metadata:
  creationTimestamp: 2018-01-22T06:44:08Z
  name: extension-apiserver-authentication
  namespace: kube-system
  resourceVersion: "1230442"
  selfLink: /api/v1/namespaces/kube-system/configmaps/extension-apiserver-authentication
  uid: a5ed7645-ff3f-11e7-895c-00a0a59b0704
```

Each of API servers will now need to have an RBAC authorization to read this Config Map. Thankfully K8s will also automatically create a role for it: 

```
$ kubectl get roles -n kube-system extension-apiserver-authentication-reader -o yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  creationTimestamp: 2018-01-18T13:54:04Z
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: extension-apiserver-authentication-reader
  namespace: kube-system
  resourceVersion: "214114"
  selfLink: /apis/rbac.authorization.k8s.io/v1/namespaces/kube-system/roles/extension-apiserver-authentication-reader
  uid: 0b9376b6-fc57-11e7-a156-00a0a59b05e9
rules:
- apiGroups:
  - ""
  resourceNames:
  - extension-apiserver-authentication
  resources:
  - configmaps
  verbs:
  - get
```

Last but not least, you won't need Heapster for now, so make sure it is not there via: 

```
$ juju config kubernetes-master enable-dashboard-addons=false
```

### Initial API State 

Before you start having fun with API Servers, have a look to the status of your cluster with: 

```
$ kubectl api-versions
apiextensions.k8s.io/v1beta1
apiregistration.k8s.io/v1beta1
apps/v1beta1
apps/v1beta2
authentication.k8s.io/v1
authentication.k8s.io/v1beta1
authorization.k8s.io/v1
authorization.k8s.io/v1beta1
autoscaling/v1
autoscaling/v2beta1
batch/v1
batch/v1beta1
certificates.k8s.io/v1beta1
extensions/v1beta1
networking.k8s.io/v1
policy/v1beta1
rbac.authorization.k8s.io/v1
rbac.authorization.k8s.io/v1beta1
storage.k8s.io/v1
storage.k8s.io/v1beta1
v1
```

At the end of the next sections, you will have 3 more APIs in this list: 

* monitoring.coreos.com/v1, for the Prometheus Operator 
* metrics.k8s.io, for the Metrics Server that collects metrics for CPU and Memory
* custom.metrics.k8s.io, for the custom metrics you want to expose 

### Adding the Metrics Server API

There are 2 implementations of the Metrics API (metrics.k8s.io) at this stage: Heapster and the Metrics Server. At the time of this writing, the Metrics Server has a simple deployment method, while Heapster required some work on my end, and I was too lazy to write the code.

We can simply deploy it with 

```
kubectl create -f src/manifest-metrics-server.yaml
```

This manifest contains: 

* the Service Account for the Metrics Server
* a RoleBinding so that the Metrics Server can read the configmap above
* a ClusterRoleBinding so that the Metrics Server inherits the system:auth-delegator ClusterRole (you can find documetation about that [here](https://kubernetes.io/docs/admin/authorization/rbac/).
* a Deployment and ClusterIP Service for the Metrics Server
* an APIService object, which is a registration of the new API into the API Server. 

Now check our APIs again: 

```
$ kubectl api-versions
apiextensions.k8s.io/v1beta1
apiregistration.k8s.io/v1beta1
apps/v1beta1
apps/v1beta2
authentication.k8s.io/v1
authentication.k8s.io/v1beta1
authorization.k8s.io/v1
authorization.k8s.io/v1beta1
autoscaling/v1
autoscaling/v2beta1
batch/v1
batch/v1beta1
certificates.k8s.io/v1beta1
extensions/v1beta1
***
* metrics.k8s.io/v1beta1
***
networking.k8s.io/v1
policy/v1beta1
rbac.authorization.k8s.io/v1
rbac.authorization.k8s.io/v1beta1
storage.k8s.io/v1
storage.k8s.io/v1beta1
v1
```

Awesome... But does it really work? Query the endpoint of the API via kubectl to make sure

```
$ kubectl get --raw /apis/metrics.k8s.io/v1beta1 | jq .
{
  "kind": "APIResourceList",
  "apiVersion": "v1",
  "groupVersion": "metrics.k8s.io/v1beta1",
  "resources": [
    {
      "name": "nodes",
      "singularName": "",
      "namespaced": false,
      "kind": "NodeMetrics",
      "verbs": [
        "get",
        "list"
      ]
    },
    {
      "name": "pods",
      "singularName": "",
      "namespaced": true,
      "kind": "PodMetrics",
      "verbs": [
        "get",
        "list"
      ]
    }
  ]
}

```

Good job, NodeMetrics and PodMetrics are exposed. Look into what you can use from there:  

```
$ METRICS_POD=$(kubectl get pods -n kube-system -l k8s-app=metrics-server -o name | cut -f2 -d/)
$ kubectl get --raw /apis/metrics.k8s.io/v1beta1/namespaces/kube-system/pod/${METRICS_POD}
{
  "kind": "PodMetrics",
  "apiVersion": "metrics.k8s.io/v1beta1",
  "metadata": {
    "name": "metrics-server-77b9cb679-7s8b2",
    "namespace": "kube-system",
    "selfLink": "/apis/metrics.k8s.io/v1beta1/namespaces/kube-system/pods/metrics-server-77b9cb679-7s8b2",
    "creationTimestamp": "2018-01-26T06:31:10Z"
  },
  "timestamp": "2018-01-26T06:31:00Z",
  "window": "1m0s",
  "containers": [
    {
      "name": "metrics-server",
      "usage": {
        "cpu": "1m",
        "memory": "27676Ki"
      }
    }
  ]
}
```

And

```
$ RANDOM_NODE=$(kubectl get nodes -o name | tail -n 1)
$ kubectl get --raw /apis/metrics.k8s.io/v1beta1/${RANDOM_NODE} | jq .
{
  "kind": "NodeMetrics",
  "apiVersion": "metrics.k8s.io/v1beta1",
  "metadata": {
    "name": "worker-n5-a6ayds",
    "selfLink": "/apis/metrics.k8s.io/v1beta1/nodes/worker-n5-a6ayds",
    "creationTimestamp": "2018-01-26T06:41:49Z"
  },
  "timestamp": "2018-01-26T06:41:00Z",
  "window": "1m0s",
  "usage": {
    "cpu": "12436m",
    "memory": "4991296Ki"
  }
}

```


No big surprise here, you can access the CPU and memory consumption in real time. Refer to the docs for more details about how to query the API. 

### Installing the Custom Metrics Pipeline

Right before we have taken a shortcut, having a metric pipeline that is directly exposable as the aggregated API. Unfortunately, in the case of custom metrics, we must do this in 2 distinct steps. 

First of all we must deploy the custom metrics pipeline, which will give us the ability to collect metrics. We use Prometheus for that part as the canonical example of metrics collection system on K8s. 

Then we will expose these metrics via a specific API Server. We will use the work of Sully (@DirectXMan12) that can be found [here](https://github.com/DirectXMan12/k8s-prometheus-adapter) for that. 

Prometheus has many installation methods. My personal favorite is the [Prometheus Operator](https://github.com/coreos/prometheus-operator). It takes a lot of efforts to architect a piece of software using traditional solution. But crafting a software model that ties to the underlying distributed solution beautifully is closer to art than anything else. 

That is essentially what the operator is. The operator models how Prometheus should be given a set of conditions, then realizes that in Kubernetes. Whaow, good job @CoreOS. 

Note that you can create an Operator for anything, and that something similar is coming for Tensorflow as far as I can see the APIs coming up... Anyway, let's not get distracted. 

Install the Prometheus Operator with: 

```
$ kubectl create -f src/manifest-prometheus-operator.yaml
```

This contains: 

* a Service Account for the operator
* a ClusterRole and ClusterRoleBinding that are fairly extensive, so that the Operator can deploy Custom Resource Definitions for Prometheus (instances of), Alert Managers and Service Monitors. 
* a Deployment for the Operator pod. 

This will let the Operator add the monitoring API as well: 

```
$ kubectl api-versions
apiextensions.k8s.io/v1beta1
apiregistration.k8s.io/v1beta1
apps/v1beta1
apps/v1beta2
authentication.k8s.io/v1
authentication.k8s.io/v1beta1
authorization.k8s.io/v1
authorization.k8s.io/v1beta1
autoscaling/v1
autoscaling/v2beta1
batch/v1
batch/v1beta1
certificates.k8s.io/v1beta1
extensions/v1beta1
metrics.k8s.io/v1beta1
***
* monitoring.coreos.com/v1
***
networking.k8s.io/v1
policy/v1beta1
rbac.authorization.k8s.io/v1
rbac.authorization.k8s.io/v1beta1
storage.k8s.io/v1
storage.k8s.io/v1beta1
v1
```

Now create an instance of Prometheus with: 

```
$ kubectl create -f src/rbac-prometheus.yaml
$ kubectl create -f src/manifest-prometheus-instance.yaml
```

The RBAC manifest will allow Prometheus to read the metrics it needs in the cluster and /metrics endpoints of any object (pod or service). The Prometheus manifest defines an instance and a service to expose it as a nodePort (so we can have a look at the UI). 

What is important in this second file is the section: 

```
  serviceMonitorSelector:
    matchLabels:
      demo: autoscaling
```

This essentially dedicates the Prometheus instance to Service Monitors with this label (or set of labels). When we will define the applications we want to monitor and how, we will need that information. 

Note that this is a trivial example of deployment, with no persistent storage or any fancy thingy. If you are contemplating using this for a more production grade usage, you will need to spend some time on this. 

OK, now you can connect on the UI and check that you have everything deployed correctly. It is pretty empty for now...

![image](img/prometheus-ui.png)

### Installing the Custom Metrics Adapter

Now that we have the ability to collect metrics via our Prometheus pipeline, we want to expose them under the aggregated API.  

First of all, you will need some certificates. Joy. This is all documented [here](https://github.com/kubernetes-incubator/apiserver-builder/blob/master/docs/concepts/auth.md). Run the following commands to generate your precious: 

```
mkdir -p certs
cd certs 

# First create the CA and csr with
export PURPOSE=serving
openssl req -x509 -sha256 -new -nodes -days 365 -newkey rsa:2048 -keyout ${PURPOSE}-ca.key -out ${PURPOSE}-ca.crt -subj "/CN=ca"
echo '{"signing":{"default":{"expiry":"43800h","usages":["signing","key encipherment","'${PURPOSE}'"]}}}' > "${PURPOSE}-ca-config.json"

# Now generate the certificate keys and cert: 
export SERVICE_NAME=custom-metrics-apiserver
export ALT_NAMES='"custom-metrics-apiserver.custom-metrics","custom-metrics-apiserver.custom-metrics.svc"'
echo '{"CN":"'${SERVICE_NAME}'","hosts":['${ALT_NAMES}'],"key":{"algo":"rsa","size":2048}}' | cfssl gencert -ca=${PURPOSE}-ca.crt -ca-key=${PURPOSE}-ca.key -config=${PURPOSE}-ca-config.json - | cfssljson -bare apiserver

cd ..
```

In order to authenticate our extended API server against the Kubernetes API Server, we have several options: 

* Using a client certificate
* Using a Kubeconfig file
* Using BasicAuth or Token authentication

Adding users with certificates in CDK is a project in itself and would deserve its own blog post. If interested, ping me in questions and we can discuss this in DMs. BasicAuth and Tokens are easy, but they also require to edit /root/cdk/known_tokens.csv or /root/cdk/basic_auth.csv on all masters and restart the API server daemon everywhere. 

So the solution with the least complexity is actually the Kubeconfig file. Thanks to RBAC, the only thing we need to create a new user is a service account, which will give us access to an authentication token, which we can then put into our kubeconfig. 

```
# Create the SA
$ kubectl create sa custom-metrics-apiserver
serviceaccount "custom-api-server" created
# Extract the secret name for the token
$ export CMA_TOKEN_SECRET=$(kubectl get sa custom-api-server -o jsonpath='{.secrets[0].name}')
# Extract the auth token
$ export CMA_TOKEN=$(kubectl get secret custom-api-server-token-hj4qz -o jsonpath='{.data.token}')
```

You can then create a copy of your .kube/config file and edit the user section to add the custom-api-server: 

```
      users:
      - name: custom-metrics-apiserver
        user:
          token: <Copy here the $CMA_TOKEN content>
```

Do not forget to also edit the contexts to map to this user instead of admin. 

Now edit a cm-values.yaml file for the helm chart: 

```
replicaCount: 1
image:
  repository: luxas/k8s-prometheus-adapter
  tag: v0.2.0-beta.0
  pullPolicy: IfNotPresent
service:
  name: custom-metrics-apiserver
  type: ClusterIP
  externalPort: 443
  internalPort: 6443
  # Current version of the custom-metrics API for K8s 
  version: v1beta1
  tls:
    enable: true
    ca: |-
      <insert here the key you just created>
    key: |-
      <insert here the key you just created>
    certificate: |-
      <insert here the certificate you just created>
  authentication:
    method: kubeconfig
    kubeconfig: |-
      <insert here the kubeconfig file you just created> 

rbac: 
  install: true
  apiVersion: v1beta1

resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 100m
    memory: 128Mi

prometheus: 
  service: 
    name: prometheus
    port: 9090
  namespace: default

```

OK you are now ready to download the chart and install it

```
# Download the charts
$ git clone https://github.com/madeden/charts.git 

# Install the chart with our values file: 
$ helm install charts/custom-metrics-adapter \
    --name cma \
    --values cm-values.yaml \
    --namespace custom-metrics
LAST DEPLOYED: Wed Jan 17 07:54:59 2018
NAMESPACE: custom-metrics
STATUS: DEPLOYED

RESOURCES:
==> v1/Secret
NAME                               TYPE               DATA  AGE
cm-custom-metrics-apiserver-certs  kubernetes.io/tls  2     25m

==> v1beta1/ClusterRole
NAME                             AGE
custom-metrics-server-resources  25m
custom-metrics-resource-reader   25m

==> v1beta1/ClusterRoleBinding
NAME                                  AGE
custom-metrics:system:auth-delegator  25m
hpa-controller-custom-metrics         25m
custom-metrics-resource-reader        25m

==> v1/Service
NAME                         TYPE       CLUSTER-IP     EXTERNAL-IP  PORT(S)  AGE
cm-custom-metrics-apiserver  ClusterIP  10.51.250.135  <none>       443/TCP  25m

==> v1/Pod(related)
NAME                                          READY  STATUS   RESTARTS  AGE
cm-custom-metrics-apiserver-7975b9d9f6-6ptnf  1/1    Running  0         25m

==> v1beta1/RoleBinding
NAME                        AGE
custom-metrics-auth-reader  25m

==> v1beta1/Deployment
NAME                         DESIRED  CURRENT  UP-TO-DATE  AVAILABLE  AGE
cm-custom-metrics-apiserver  1        1        1           1          25m

==> v1beta1/APIService
NAME                           AGE
v1beta1.custom.metrics.k8s.io  25m


NOTES:
This chart is an application of the Custom Metrics API as documented in https://github.com/DirectXMan12/k8s-prometheus-adapter

It requires a prometheus installation to be active and running at http://prometheus.default.svc:9090/

It will then create a custom-metrics API server in order to permit the creation of HPAs based on custom metrics, such as number of hits on an API. 

```

And we check that the new API is registered in Kubernetes: 

```
$ kubectl api-versions
apiextensions.k8s.io/v1beta1
apiregistration.k8s.io/v1beta1
apps/v1beta1
apps/v1beta2
authentication.k8s.io/v1
authentication.k8s.io/v1beta1
authorization.k8s.io/v1
authorization.k8s.io/v1beta1
autoscaling/v1
autoscaling/v2beta1
batch/v1
batch/v1beta1
certificates.k8s.io/v1beta1
***********
* custom.metrics.k8s.io/v1beta1
***********
extensions/v1beta1
metrics.k8s.io/v1beta1
monitoring.coreos.com/v1
networking.k8s.io/v1
policy/v1beta1
rbac.authorization.k8s.io/v1
rbac.authorization.k8s.io/v1beta1
storage.k8s.io/v1
storage.k8s.io/v1beta1
v1
```

Great. Now let us check that everything works properly by querying the K8s endpoint for it: 

```
kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1"
```

At this point of our development, if we get a 200 answer and NOT a 404 we are good and we have our autoscaling up & running. If you get a 404, then it did not work properly. 

### Summary

In the long section above, we have done the following

1. Install the new Metrics Server and add the metrics.k8s.io API to the cluster. This gave us access to an equivalent of heapster, but exposing metrics under the classic API. 
2. Install a Custom Metrics pipeline to be able to collect any metrics. We did this via Prometheus, using the Operator to create a Prometheus Instance
3. Install the Custom Metrics API custom.metrics.k8s.io via the installation of a Prometheus Adapter. 

For each step, we validated that the cluster worked properly and as intended. Now we need to put it to good use. 

## Using Custom Metrics
### Demo Application: http_requests

First of all we will test our set up with a very simple application written by @luxas that exposed a http_request metric on /metric. You can deploy it with 

```
$ kubectl create -f src/manifest-sample-app.yaml
```

This manifest contains: 

* the Deployment and Service so we can query the application
* a Service Monitor, which will indicate to the prometheus instance that it should scrap the metrics of the application
* An Horizontal Pod Autoscaler (HPA), which will consume the number of http_requests and use it to scale the application. 

Let us look into the HPA for a moment: 

```
kind: HorizontalPodAutoscaler
apiVersion: autoscaling/v2beta1
metadata:
  name: sample-metrics-app-hpa
spec:
  scaleTargetRef:
    kind: Deployment
    name: sample-metrics-app
  minReplicas: 2
  maxReplicas: 30
  metrics:
  - type: Pod
    pods:
      metricName: http_requests
      targetAverageValue: 500m
```

As you can see, we have here 

* a Target (our deployment), with a minReplicas and a maxReplicas. 
* a metrics of type pod which tries to make sure that pods get an average 500m queries (which slightly above what the standard load from Kubernetes + Prometheus is)

So this means that you do not need the application to rely on its own metrics. You could potentially target any application metrics and use them to manage another application. Very powerful principles. 

Let us say for example that you manage an application based on the principle of decoupled invocation, such as a chat or an order management solution. 
Some day, you start getting a peak of requests on the front end, and the backend does not follow. The queue fills up, and you start experimenting delays in processing of the requests. 
Well now you can scale the workers that process the queue based on the requests made on the front end. You create a target object that monitors the number of http_requests on the frontend, but the scale target may be your application. It is as simple as that. 

Now look at how Custom API reacts to this (it may take a couple of minutes before this works)

```
$ kubectl get --raw /apis/custom.metrics.k8s.io/v1beta1 | jq .
{
  "kind": "APIResourceList",
  "apiVersion": "v1",
  "groupVersion": "custom.metrics.k8s.io/v1beta1",
  "resources": [
    {
      "name": "jobs.batch/http_requests",
      "singularName": "",
      "namespaced": true,
      "kind": "MetricValueList",
      "verbs": [
        "get"
      ]
    },
    {
      "name": "pods/http_requests",
      "singularName": "",
      "namespaced": true,
      "kind": "MetricValueList",
      "verbs": [
        "get"
      ]
    },
    {
      "name": "namespaces/http_requests",
      "singularName": "",
      "namespaced": false,
      "kind": "MetricValueList",
      "verbs": [
        "get"
      ]
    },
    {
      "name": "services/http_requests",
      "singularName": "",
      "namespaced": true,
      "kind": "MetricValueList",
      "verbs": [
        "get"
      ]
    }
  ]
}
```

And we can then query the service itself: 

```
$ kubectl get --raw /apis/custom.metrics.k8s.io/v1beta1/namespaces/default/services/*/http_requests | jq .
{
  "kind": "MetricValueList",
  "apiVersion": "custom.metrics.k8s.io/v1beta1",
  "metadata": {
    "selfLink": "/apis/custom.metrics.k8s.io/v1beta1/namespaces/default/services/%2A/http_requests"
  },
  "items": [
    {
      "describedObject": {
        "kind": "Service",
        "namespace": "default",
        "name": "sample-metrics-app",
        "apiVersion": "/__internal"
      },
      "metricName": "http_requests",
      "timestamp": "2018-01-28T20:00:22Z",
      "value": "3033m"
    }
  ]
}
```

And we then look at our HPA: 

```
$ kubectl get hpa
NAME                     REFERENCE                       TARGETS      MINPODS   MAXPODS   REPLICAS   AGE
sample-metrics-app-hpa   Deployment/sample-metrics-app   433m / 500m   2         30        2          4d
```

We can see here that just the requests for status account for 866m. Now deploy a shell app so we can create some load: 

```
$ kubectl create -f https://k8s.io/docs/tasks/debug-application-cluster/shell-demo.yaml
```

Now prepare 2 shells. In the first one, connect into your container with 

```
$ kubectl exec -it shell-demo -- /bin/bash
root@shell-demo:/# apt update && apt install -yqq curl 
root@shell-demo:/# for i in $(seq 1 1 3000); do curl -sL http://sample-metrics-app.default.svc; sleep 0.1; done
```

And in the second one, track the HPA with

```
$ kubectl get hpa -w
$ kubectl get hpa -w
NAME                     REFERENCE                       TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
sample-metrics-app-hpa   Deployment/sample-metrics-app   433m / 500m   2         30        2          4d
sample-metrics-app-hpa   Deployment/sample-metrics-app   433m / 500m   2         30        2         4d
sample-metrics-app-hpa   Deployment/sample-metrics-app   433m / 500m   2         30        2         4d
# Load Starts to grow here
sample-metrics-app-hpa   Deployment/sample-metrics-app   443m / 500m   2         30        2         4d
sample-metrics-app-hpa   Deployment/sample-metrics-app   478m / 500m   2         30        2         4d
sample-metrics-app-hpa   Deployment/sample-metrics-app   594m / 500m   2         30        2         4d

# Scale Out Event
sample-metrics-app-hpa   Deployment/sample-metrics-app   710m / 500m   2         30        5         4d
sample-metrics-app-hpa   Deployment/sample-metrics-app   822m / 500m   2         30        5         4d
sample-metrics-app-hpa   Deployment/sample-metrics-app   912m / 500m   2         30        5         4d

# Impact -> Load goes down but not enough
sample-metrics-app-hpa   Deployment/sample-metrics-app   795m / 500m   2         30        5         4d
sample-metrics-app-hpa   Deployment/sample-metrics-app   890m / 500m   2         30        5         4d
sample-metrics-app-hpa   Deployment/sample-metrics-app   984m / 500m   2         30        5         4d

# Second Scale Out
sample-metrics-app-hpa   Deployment/sample-metrics-app   1128m / 500m   2         30        10        4d
sample-metrics-app-hpa   Deployment/sample-metrics-app   1127m / 500m   2         30        10        4d
sample-metrics-app-hpa   Deployment/sample-metrics-app   806m / 500m   2         30        10        4d
sample-metrics-app-hpa   Deployment/sample-metrics-app   786m / 500m   2         30        10        4d
sample-metrics-app-hpa   Deployment/sample-metrics-app   749m / 500m   2         30        10        4d

# Third Scale Out
sample-metrics-app-hpa   Deployment/sample-metrics-app   803m / 500m   2         30        15        4d
sample-metrics-app-hpa   Deployment/sample-metrics-app   847m / 500m   2         30        15        4d
sample-metrics-app-hpa   Deployment/sample-metrics-app   847m / 500m   2         30        15        4d
...
sample-metrics-app-hpa   Deployment/sample-metrics-app   751m / 500m   2         30        22        4d
sample-metrics-app-hpa   Deployment/sample-metrics-app   777m / 500m   2         30        22        4d
sample-metrics-app-hpa   Deployment/sample-metrics-app   808m / 500m   2         30        22        4d

# Now we stop the load generator
...
# Average load goes down
sample-metrics-app-hpa   Deployment/sample-metrics-app   545m / 500m   2         30        26         4d
sample-metrics-app-hpa   Deployment/sample-metrics-app   543m / 500m   2         30        26        4d
...
sample-metrics-app-hpa   Deployment/sample-metrics-app   504m / 500m   2         30        26        4d
sample-metrics-app-hpa   Deployment/sample-metrics-app   497m / 500m   2         30        26        4d
...

# Scale Down event
sample-metrics-app-hpa   Deployment/sample-metrics-app   446m / 500m   2         30        24        4d

# Second Scale Down
sample-metrics-app-hpa   Deployment/sample-metrics-app   433m / 500m   2         30        21        4d
...
sample-metrics-app-hpa   Deployment/sample-metrics-app   433m / 500m   2         30        13        4d
sample-metrics-app-hpa   Deployment/sample-metrics-app   433m / 500m   2         30        12        4d
sample-metrics-app-hpa   Deployment/sample-metrics-app   433m / 500m   2         30        11        4d
...

# Back to Normal
sample-metrics-app-hpa   Deployment/sample-metrics-app   433m / 500m   2         30        2         4d
``` 

and we have successfully triggered an up scale and downscale of an application

### Main Application: Optimizing the infrastructure

OK! Now we have an application that can generate load in our cluster and consume resources. Now let us look at how to use the remaining resources. 

So first of all let's look at our metrics harvesting application [Ronan](@ronhanson) wrote. It exposes the following metrics: 

```
# HELP cpu_capacity_total CPU Total Capacity (milli)
# TYPE cpu_capacity_total gauge
cpu_capacity_total 184000.0
# HELP mem_capacity_total Memory Total Capacity (Ki)
# TYPE mem_capacity_total gauge
mem_capacity_total 494264720.0
# HELP pod_capacity_total Pod Total Capacity
# TYPE pod_capacity_total gauge
pod_capacity_total 660.0
# HELP cpu_allocatable_total CPU Total Allocatable (milli)
# TYPE cpu_allocatable_total gauge
cpu_allocatable_total 184000.0
# HELP mem_allocatable_total Memory Total Allocatable (Ki)
# TYPE mem_allocatable_total gauge
mem_allocatable_total 493650320.0
# HELP pod_allocatable_total Pod Total Allocatable
# TYPE pod_allocatable_total gauge
pod_allocatable_total 660.0
# HELP cpu_requests_total CPU Requests Total (milli)
# TYPE cpu_requests_total gauge
cpu_requests_total 84870.0
# HELP mem_requests_total Memory Requests Total (Ki)
# TYPE mem_requests_total gauge
mem_requests_total 75112448.0
# HELP cpu_capacity_remaining CPU Remaining Capacity (milli)
# TYPE cpu_capacity_remaining gauge
cpu_capacity_remaining 99130.0
# HELP mem_capacity_remaining Memory Remaining Capacity (Ki)
# TYPE mem_capacity_remaining gauge
mem_capacity_remaining 418537872.0
```

In addition, he created a nice UI that presents the values in real time.  

This requires a Grafana installation. You can install both apps with: 

```
$ kubectl apply -f src/manifest-graphana.yaml
$ kubectl apply -f src/manifest-cluster-metrics.yaml
```

These manifests contain

* Cluster Roles and bindings for collecting metrics 
* Deployments for both Grafana and the python application
* Nodeports services on ports 30505 (app) and 30902 (Grafana)
* Config maps to configure both

What is of interest to us in this example is the "cpu_capacity_remaining". As mentioned in the intro, I had access thanks to Kontron to a 184-core cluster. I decided to "reserve" 30 cores, or 15% of my capacity to give room for load peaks. This gave me an autoscaler looking like:

```
kind: HorizontalPodAutoscaler
apiVersion: autoscaling/v2beta1
metadata:
  name: electroneum
  # namespace: etn2
spec:
  scaleTargetRef:
    kind: Deployment
    name: electroneum
  minReplicas: 15
  maxReplicas: 150
  metrics:
  - type: Object
    object:
      target:
        kind: Service
        name: cluster-metrics
      metricName: cpu_capacity_remaining
      targetValue: 30000
```

You will note I am using [Electroneum](https://electroneum.com/) as my crypto. The reason for this is practical. It is a very new cryptocurrency, with limited mining resources allocated to it right now, which means you can directly measure your impact and see daily returns, which is cool for demos. In case you wonder, as this currency requires a Monero miner, this setup can easily be converted into something more lucrative by pointing it to a real monero pool. 

To replicate this blog with your own machines, edit the src/manifest-etn.yaml file according to your own cluster then deploy with : 

```
$ kubectl apply -f src/manifest-etn.yaml

```

This manifest contains: 

* a Deployment of the miner
* a Horizontal Pod Autoscaler as seen above 
* a service to expose the UI on port 30500 of nodes.

Now let us check on our HPAs with: 

```
$ kubectl get hpa -w
```

Alright, we are all set! Now we can finally check how our application reacts to load. 

### Opportunistic Load Balancer in motion

In order to supercharge our cluster, we reuse our shell-demo application, and generate 10 hits per second on the API for 5 min. Because we are expecting only 0.5 hits, this will quickly trigger the scale out: 

```
root@shell-demo:/# for i in $(seq 1 1 3000); do curl -sL http://sample-metrics-app.default.svc; sleep 0.1 ; done
Hello! My name is sample-metrics-app-85b4c48ff-pgmm5. I have served 23528 requests so far.
Hello! My name is sample-metrics-app-85b4c48ff-pgmm5. I have served 23530 requests so far.
Hello! My name is sample-metrics-app-85b4c48ff-pgmm5. I have served 23532 requests so far.
Hello! My name is sample-metrics-app-85b4c48ff-gskxw. I have served 4 requests so far.
Hello! My name is sample-metrics-app-85b4c48ff-gskxw. I have served 5 requests so far.
Hello! My name is sample-metrics-app-85b4c48ff-8lpt5. I have served 23524 requests so far.
Hello! My name is sample-metrics-app-85b4c48ff-gskxw. I have served 6 requests so far.
Hello! My name is sample-metrics-app-85b4c48ff-pgmm5. I have served 7 requests so far.
Hello! My name is sample-metrics-app-85b4c48ff-pgmm5. I have served 23534 requests so far.
...
```

There you go, we can see the new pod coming in. Each new pod requests 4 CPU cores to the cluster. This unbalances the HPA, that tries to counter by releasing miners. Over 5 minutes, our app will scale up to 17 replicas, thus claiming 68 cores to the cluster, which will be freed from the mining app. 
After 5 minutes, the load is now normal and we see a scale down of the simple app from 17 pods down to its stable version at 2 replicas. The HPA for the miner will react and start harvesting the capacity. 

This can be seen in the UI on the CPU capacity graph: 

![capacity graph](img/prometheus-hpa-full-cycle-annotations.png)

That's it, we have an application that is self opportunistically adjusting to the load created by other applications in the cluster. 

## Some thoughts about the HPA

While creating this blog, I had a huge hard time configuring the HPA to make it stable and convergent and not completely erratic. One must understant that the HPA in K8s is, so far, pretty dumb. It is not exactly learning from the past, rather systematically repeating the same reaction patterns regardless of the fact they failed or succeeded in the past. 

Let's say a custom metric is at 150% of its target value, then the cluster will perform a 150% capacity increase. This means that if your application is creating 2% HPA resource value for 1% increase of scale, you will enter into a turbulence zone, with the HPA proving incapable of converging. 

For our application, this means that the mining application was designed so that each replica consumes 1 CPU Core, and the max value was set on the max we could use for this specific app. Other things were running there consuming ~30 cores, hence the fact we have a max replicas at 150 ~= (184 - 30). 

Long Story short: if you do this at home, be thoughtful about your HPA design, and do some experiments. If the HPA does not learn, you certainly should.  

## References

I would like to thank @Luxas and @DirectXMan12 for inspiring this work and for the fantastic walkthrough they wrote [here](https://github.com/luxas/kubeadm-workshop) and [there](https://github.com/DirectXMan12/k8s-prometheus-adapter/blob/master/docs/walkthrough.md) that helped me a lot while writing this. 




