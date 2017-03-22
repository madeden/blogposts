# Running transcoding jobs
## Starting jobs

We have a lot of tests to run, and we do not want to spend too long managing them, so we build a simple automation around them

```
cd src 
TYPE=awslxd
for cpu in 2 3 ; do 
  for memory in 2; do 
    for para in 1 2 3 4 5 6 7; do 
    [ -f values/values-${para}-${TYPE}-${cpu}-${memory}.yaml ] && \
      { helm install transcoder --values values/values-${para}-${TYPE}-${cpu}-${memory}.yaml
        sleep 15
        while [ "$(kubectl get pods -l role=transcoder | wc -l)" -ne "0" ]; do
          sleep 10
        done
      }
    done
  done
done

```

This will run the tests about as fast as possible. 

## First approach to Scheduling

Without any tuning or configuration, Kubernetes makes a decent job of spreading the load over the hosts. Essentially, all jobs being equal, it spreads them like a round robin on all nodes. Below is what we observe for a concurrency of 12. 

```
NAME                   READY     STATUS    RESTARTS   AGE       IP             NODE
bm-12-1-2gi-0-9j3sh    1/1       Running   0          9m        10.1.70.162    node06
bm-12-1-2gi-1-39fh4    1/1       Running   0          9m        10.1.65.210    node07
bm-12-1-2gi-11-261f0   1/1       Running   0          9m        10.1.22.165    node01
bm-12-1-2gi-2-1gb08    1/1       Running   0          9m        10.1.40.159    node05
bm-12-1-2gi-3-ltjx6    1/1       Running   0          9m        10.1.101.147   node04
bm-12-1-2gi-5-6xcp3    1/1       Running   0          9m        10.1.22.164    node01
bm-12-1-2gi-6-3sm8f    1/1       Running   0          9m        10.1.65.211    node07
bm-12-1-2gi-7-4mpxl    1/1       Running   0          9m        10.1.40.158    node05
bm-12-1-2gi-8-29mgd    1/1       Running   0          9m        10.1.101.146   node04
bm-12-1-2gi-9-mwzhq    1/1       Running   0          9m        10.1.70.163    node06
```

The same spread is realized also for larger concurrencies, and at 192, we observe 32 jobs per host in every case. 

Below a few images of Grafana and KubeUI at run time, showing how the tests load the cluster: 

INSERT IMAGES HERE

Running these tests takes some time, especially on bare metal as my cluster is a bit underpowered with the Core i5. 

Time to collect answers now!

