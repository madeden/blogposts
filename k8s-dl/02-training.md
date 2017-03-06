# Training
## Architecture

Training is often the most advertised feature of Deep Learning. It is where the science and the actual magic happens. In about all cases, the performance can be drastically increased if you leverage GPUs, which, by chance, we learnt how to add in a Kubernetes cluster. 

When running locally on your workstation, you do not really care about the scheduling of the code. Tensorflow will try to consume all the resources available. If you have several GPUs, you can ask it to use them all or only some of them. 

However, when you start scaling out your system, things get a bit more intricated. Tensorflow uses 2 types of jobs to distribute compute: Parameter Servers and Workers

* Parameter Servers store and update variables for other nodes. They essentially handle "configuration" traffic. 
* Workers do the hard part and provide compute to cmplete the tasks they are given. One of the worker is given a specific Master role, and is in charge of coordination between all workers. It seems that this always defaults to worker-0 in what I have seen so far.  

Both PS and workers will attempt to use GPUs if they are available, and compete around that. Because PSes have a lesser usage of the GPU and it is usually a scare resource, it makes sense to be careful when allocating resources to the different entities of Tensorflow. On the metal of your machine, this can be a problem. But containers and resource management will help us deal with this elegantly.

A second thing to take into account is a limitation of packaging (and probably my own limitations). When building the package, it is about impossible to know on which cluster it will run, and to predict the number of GPUs that will be available to Tensorflow, especially on asymetric clsuters where some nodes have 1x GPU, others have 2, 8 or more. Because Kubernetes is not very clever at this stage in exposing GPUs like it exposes other resources like CPU or RAM, the only way I have been able to make the packaging work is to assume all nodes equal. 
If you followed last blog and remember the fact we deployed one p2.xlarge and one p2.8xlarge well... Unfortunately we will be limited by the p2.xlarge and only leverage 1 GPU in each server. 

Last but not least, Tensorflow does not seem to have the ability to change its scale dynamically (without restarting the cluster). This actually makes our lives easier when it comes to planning deployment. 

Let us look into the structures we need to design our cluster: 

* Distinguishing between PS and Worker will require a conditional structure
* Managing variable size will require to iterate on a sequence, like a for loop. In Helm, this uses a notion called range

## Implementation - Deployment for Tensorflow jobs

Let us look into **src/charts/tensorflow/values.yaml** and **src/charts/tensorflow/templates/cluster-deployment.yaml** to analyze the different sections: 

```
# Values File, section for the Tensorflow cluster
tfCluster:
  service:
    name: tensorflow-cluster
    internalPort: 8080
    externalPort: 8080
    type: ClusterIP
  image: 
    repo: samnco
    name: tf-models
    dockerTag: train-1.0.0-gpu
  settings:
    isGpu: true
    nbGpuPerNode: 1
    jobs: 
      ps: 8
      worker: 16
```

So here in the values tell us how big our cluster will be (8 PS, 16 Workers, 2 GPUs per node). 

In the deployment template, we start by defining the Configuration File via a configMap: 
```
---
# Defining a generic configuration file for the cluster
apiVersion: v1
kind: ConfigMap
metadata:
  name: tensorflow-cluster-config
  namespace: {{.Release.Namespace}}
data:
  clusterconfig: >
        {
        {{- range $job, $nb := .Values.tfCluster.settings.jobs }}
          {{ $job | quote }}: [
          {{ range $i, $e := until (int $nb) | default 8 }}
            "{{ $job }}-{{$i}}.{{ $relname }}.svc.cluster.local:8080",
          {{ end }}
              ],
        {{- end }}
        }
```

You can see the {{ range }} section, where we iterate over the jobs section. When instanciated, this will create something like: 

```
{
  "ps": [
    "ps-0.default.svc.cluster.local:8080",
    "ps-1.default.svc.cluster.local:8080",
    ...
    "ps-7.default.svc.cluster.local:8080",
  ],
  "worker": [
    "worker-0.default.svc.cluster.local:8080",
    ...
    "worker-15.default.svc.cluster.local:8080",
  ],
}
```

You recognize here that the JSON we form is not clean, we have a last comma that Tensorflow will accept, but that you need to be careful about. 

Also note in the range structure that we iterate with an index starting at 0 on a number of values, hence we go from 0 to 7 for 8 PS jobs. 

Now if we go a little lower in the file, we can see the conditional section: 

```
        {{ if eq $job "worker" }}
        {{ if $isGpu }}
        securityContext:
          privileged: true
        resources:
          requests:
            alpha.kubernetes.io/nvidia-gpu: {{ $nbGpu }}
          limits:
            alpha.kubernetes.io/nvidia-gpu: {{ $nbGpu }} 
        volumeMounts:
          {{ range $j, $f := until (int $nbGpu) | default 1 }}
        - mountPath: /dev/nvidia{{ $j }}
          name: nvidia{{ $j }}
          {{ end }}
        {{ end }}
        {{ end }}
```

if we are building a GPU cluster, we only allocate GPUs to Worker processes, and we allocate to each worker all the GPUs it can access on a given node. We do not forget to share the necessary char devices as well (/dev/nvidia0 and further)

Our training image is taken from the Inception tutorial Google provides, which we operate via a simple bash program that reads the configMap, extracts the proper JSON, and launches the training process from that: 

```
bazel-bin/inception/${DATASET}_distributed_train \
  --batch_size=32 \
  --data_dir=${DATA_DIR}/${DATASET} \
  --train_dir=${DATA_DIR}/${DATASET}-checkpoints \
  --job_name="${JOB_NAME}" \
  --task_id=${TASK_ID} \
  --ps_hosts="${PS_HOSTS}" \
  --worker_hosts="${WORKER_HOSTS}" \
  --subset="train"
```

You will notice that we enforce the data_dir to the output of our ingest phase, to ensure that our training will really read from there. The Dockerfile provides ideas to improve this section that are out of the scope of this article but you are welcome to contribute ;)

## Implementation - Deployment for Tensorflow Job Services

In order to make each of these jobs reachable via Service Discovery, each of them is mapped to its own Kubernetes Service, which is available in the ```cluster-service.yaml``` file.

## Implementation - Configuration

The section of the values.yaml file is 

```
tfCluster:
  deploy: true
  service:
    name: tensorflow-cluster
    internalPort: 8080
    externalPort: 8080
    type: ClusterIP
  image: 
    repo: samnco
    name: tf-models
    dockerTagCpu: train-0.11-0.0.8
    dockerTagGpu: train-0.11-gpu-0.0.8
  settings:
    dataset: imagenet
    isGpu: true
    nbGpuPerNode: 1
    jobs: 
      ps: 8
      worker: 16
```

You can see in the settings section how we are adding a pre-computed number of GPUs per node, and creating our PS and Worker jobs. 

## How to adapt for yourself? 

Again, this is pretty straighforward. You are expected to prepare **any** Image which will receive 

* its cluster configuration from an ENV named CLUSTER_CONFIG, in the format of the JSON described above
* its job name as an ENV named POD_NAME in the format <job name>-<task id>

These are the only requirements really. You can prepare CPU and GPU images, publish them, and adapt the tfCluster section of your values.yaml file to match your configuration. 

## Why don't we deploy now? 

We will not deploy now. First, we'll review the evaluation and serving processes. 

