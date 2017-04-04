# Conclusion

It may sounds like a normal thing to get ELBs out of the box with any Kubernetes you deploy. It is not. Actually, the fact you natively get an ELB with various deployment methods other than Juju hides the fact that this integration is using some primitives of AWS (or any other cloud) that you should be aware of, to measure the portability of your applications. 

The Canonical Distribution of Kubernetes offers Ingress endpoints out of the box, which can be load balanced via DNS Round Robin or other load balancing methods. From a practical point of view, this means the configuration of the load balancing is effectively managed by Kubernetes, via configuration passed to nginx. 
It also means this methods works on any substrate, public cloud, private cloud, bare metal, laptop…

While I was initially against this choice, it is in practice much more efficient than native ELBs. The routing to the services is easier, and the performance is waaaaay better (I've seen 10x improvement on the latency web APIs). 

However, it is also “less easy”, as some integration must be done. And that’s why we are also getting support for ELBs and other load balancers out of the box very soon.

If you are considering using Kubernetes in production, I would advise considering both options (ingress / ELB), testing them, then make a choice rather than accepting that ELBs are the "only" good way of exposing services to the world. Note that regardless of the distribution you use, both options are available. This will not create any lock-in of any sort. 

Any questions about this integration, feel free to contact me here, via @SaMnCo_23 or [LinkedIn](https://www.linkedin.com/in/scozannet/).

