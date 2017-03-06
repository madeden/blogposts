# Evaluation & Monitoring
## Architecture

Evaluation is a specific process, that consumes GPU, amd which output allows measuring the quality of the model. It outputs data that can be consumed by Tensorflow's GUI, the Tensorboard. Without the tensorboard, it is very hard for a human being to understand how the training evolves and if the parameters are OK. 


The tensorboard itself is a simple process that exposes a web application to present the graphs & data. Therefore we need to plan a service and am ingress point for it, in order to let the world see it. 

## Implementation

In order to keep this blog as short as possible, I'll leave it to you to review the content of **src/charts/tensorflow/eval-deployment.yaml** and **src/charts/tensorflow/tensorboard-service.yaml**, which follow the same ideas as the previous ones. 

The values.yaml section looks like:

```
evaluating:
  deploy: true
  replicaCount: 1
  image: 
    repo: samnco
    name: tf-models
    dockerTagCpu: train-0.11-0.0.8
    dockerTagGpu: train-0.11-gpu-0.0.8
  service:
    name: eval
    command: '[ "/eval.sh" ]'
  settings:
    dataset: imagenet
    isGpu: true
    nbGpuPerNode: 1
  resources:
    requests:
      cpu: 1000m
      memory: 1Gi
    limits:
      cpu: 2000m
      memory: 4Gi

tensorboard:
  deploy: true
  replicaCount: 1
  image: 
    repo: gcr.io/tensorflow
    name: tensorflow
    dockerTag: 1.0.0
  service:
    name: tensorboard
    dns: tensorboard.madeden.net
    type: ClusterIP
    externalPort: 6006
    internalPort: 6006
    command: '[ "tensorboard", "--logdir", "/var/tensorflow/imagenet-eval" ]'
  settings:
  resources:
    requests:
      cpu: 2000m
      memory: 4Gi
    limits:
      cpu: 4000m
      memory: 8Gi
```

You'll note 

* The amount of compute given to Tensorboard is high. Even this may be too small, I found this system very resource consuming. It often crashes or becomes unresponsive if the model is kept training for a long time. 
* The fact we include the GPU as an option, like we did in the cluster context. 
* The DNS Record for the tensorboard (here tensorboard.madeden.net): You will need to prepare a DNS round robin that points to the public addresses of your worker nodes in order to access this. My recommendation is to have a generic record like workers.yourdomain.com then a CNAME to this for the tensorboard. 

## How to adapt for yourself? 

You'll need to prepare an eval.sh script and/or a specific image that will handle the evaluation of the model. It shall have the following properties: 

* Read files from a predictable location
* Write evaluation from a predictable location

In our context we start the evaluation with: 

```
bazel-bin/inception/${DATASET}_eval \
	--checkpoint_dir="${DATA_DIR}/${DATASET}-checkpoints" \
	--eval_dir="${DATA_DIR}/${DATASET}-eval" \
    --data_dir="${DATA_DIR}/${DATASET}" \
	--subset="validation"
```

which means we expect the training to write in ${DATA_DIR}/${DATASET}-checkpoints, the evaluation to write from ${DATA_DIR}/${DATASET}-eval and the evaluation dataset to lie in ${DATA_DIR}/${DATASET}

You will also need to adjust the Tensorboard command to adjust the location of the logs. 

## Why don't we deploy now? 

We will not deploy now, but soon. We just need to review the serving process. 


