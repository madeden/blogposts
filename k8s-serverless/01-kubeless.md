  # Kubeless
## Intro 

Kubeless is the most recent and maybe less mature of all the frameworks. It advertizes itself as a PoC, so we will not spend a lot of time on it. 

On the good side

* Electing a well known messaging platform such as Kafka can be a good idea as it is robust, fast and has a big community, as well as enterprise support. Ticks all the boxes to increase adoption. 

* On the "I cannot blame you for being new" side, the go code has a lot of hard coded stuff such as the Kafka command lines, which means you have a strong dependency between packages. As there is no helm chart, this carries a high risk of problems, which I am sure will be resolved with time. 

On the less good side, 

* Helm chart? Kubeless has its own installer but Kubernetes also has a packaging format. Why create an installer when you have a tool available to make that easy for you? This means essentially becoming responsible for compatibility of the solution with Kubernetes, but also for providing Kafka images and manifests.
* Functions are written as Third Party Resources called LambDa (yes, there is an uppercase D), and that is part of the marketing of the solution. This is an example function from the repo: 

```
--- 
apiVersion: k8s.io/v1
kind: LambDa
metadata: 
  name: function
spec: 
  handler: hello.handler
  runtime: python2.7
  lambda: |
    import json
    def handler():
            return "hello world"
```

Honestly, why not use a ConfigMap with labels for the handler and runtime? In French, we call that a "false good idea". Below an alternative that would work and does not require adding stuff: 

---
apiVersion: "v1"
kind: "ConfigMap"
metadata:
  name: "function"
  labels:
    kind "function"
    handler: "hello.handler"
    runtime: "python"
data:
  lambda: |
    import json
    def handler():
          return "hello world"
```

# Conclusion

Kubeless is a PoC and may never become a product. If you are looking for a robust solution, pass. 
  
