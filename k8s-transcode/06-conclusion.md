# Conclusion

Using LXD to slice hosts and use more workers is an efficient strategy to mitigate Kubernetes apparent inability to run efficiently with a high concurrency. As the Kubernetes Worker plane consumes less than 5% of resources, this strategy is efficient as soon as expected concurrency is above YY

This is interesting to optimize the use of your cluster, in several contexts: 

* If you know in advance application profile, then you can adapt to make sure that each compute thread is allocated the right amount of resources
* If you want an agile allocation of resources, LXD can dynamically re-allocate resources, so you can dynamically resize worker node depending on the application you are running
* Maintaining HA while running several clusters: if your use case is running a cluster per team but individual clusters are small, it can be challenging to maintain HA for each team. Using the same nodes sliced with LXD offers scalability at no performance penalty for most workloads


