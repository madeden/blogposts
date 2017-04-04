# Installing Kubernetes with Juju

I made a simple workshop document to get anyone started, which can be found [here](https://docs.google.com/presentation/d/1PZt1wmprSM5fhBG_G4XZFHPGpGe0Z-aBjn2pKCyMSKc/edit?usp=sharing)

If this doesn't get you started, shout! 

For those who already know about the Canonical Distribution of Kubernetes, there is a slight change on slide 10 where the model needs configuration: 

```
juju add-model k8s
juju model-config resource-tags="KubernetesCluster=workshop"
```

