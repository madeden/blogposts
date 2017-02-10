# End of the experiment, tearing down

Tear down the federation is quick and simple: you just have to destroy the namespace! Efficient even if efforts are being done to make this process a bit nicer. 

```
kubectl --context=magicring delete clusters \
  aws azure
kubectl --context=gke delete namespace \
  federation-system
```

Destroy the GKE cluster and the DNS zone

```
gcloud dns managed-zones delete demo-madeden
gcloud container clusters delete gce --zone=us-east1-b
```

Destroy the 2 Juju clusters

```
juju switch aws
juju kill-controller aws --destroy-all-models
juju switch azure
juju kill-controller azure --destroy-all-models
```

Et voilààà! You're done with today's experiment on Federating Kubernetes

