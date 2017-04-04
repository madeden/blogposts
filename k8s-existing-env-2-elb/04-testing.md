# Does it work?

Deploy and expose some Hello World to our cluster: 


<pre><code>
kubectl run hello-world --replicas=5 --labels="run=load-balancer-example" --image=gcr.io/google-samples/node-hello:1.0  --port=8080

kubectl expose deployment hello-world --type=LoadBalancer --name=hello

# wait a bit
$ kubectl get svc -o wide
NAME                   CLUSTER-IP       EXTERNAL-IP					PORT(S)          AGE       SELECTOR
default-http-backend   10.152.183.165   <none> 						80/TCP           1h        app=default-http-backend
hello                  10.152.183.202   ...-.....elb.amazonaws.com  8080:31870/TCP   1m        run=load-balancer-example
kubernetes             10.152.183.1     <none>						443/TCP          1h        <none>


</code></pre>


There you go, an ELB from a Juju deployed Kubernetes! How cool is that? 

