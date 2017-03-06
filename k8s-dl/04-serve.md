# Serving
## Architecture

Serving is the ability to present the trained model for consumption by third party users. This process, which can be done via tensorflow-serving, consumes the output of the training process, which we store in imagenet-checkpoints, and offers to query it via an API. 

Anyone can then submit an image, and get an JSON file as an answer, which contains the things that have been identified and the probability that model is right about them. 

Serving a model does not require a lot of processing power and can run on a reasonable CPUonly instance. However it must be able to scale quite a lot horizontally, especially if the model is served to numerous clients. Therefore, we are going to take a deployment approach, and serve the model via a service and an ingress point. 

On the docker side, this is also a bit complicated. Tensorflow serving is very new, and less mature than the rest of the TF ecosystem. The official docker image provided by Google is very intricated, and rebuilds Bazel at image build, which is suboptimal. I made a secondary image that builds from the official tensorflow image, add the bazel binaries, then installs the serving part. A little faster to build, especially after building all the other images from the repo. 

Because the model evolves over time, we have to add a few parameters to the launch command, which perspire via the ENV we set: 

```
ENV PORT=8500
ENV MODEL_NAME=inception
ENV MODEL_PATH=/var/tensorflow/output
ENV BATCHING="--enable_batching"
```

the **--enable_batching** setting is the key here, and will have TF Serving to reload the model on a cron bases, by default every 5min. As we also keep the default at training, which is to export a new checkpoint every 10min, this makes sure that the latest model is always served. 

## Implementation

The implementation is done via the files **src/charts/tensorflow/serving-deployment.yaml** and **src/charts/tensorflow/serving-service.yaml**, which I'll leave to you to review. You can also review the serving part of values.yaml to understand the configuration. 

the values.yaml file deserves a review: 

```
serving:
  deploy: true
  replicaCount: 3
  image: 
    repo: samnco
    name: tf-models
    dockerTag: serving-1.0.2
  service:
    name: serving
    dns: inception.madeden.net
    type: ClusterIP
    externalPort: 8500
    internalPort: 8500
    command: '[ "/serve.sh" ]'
  settings:
    dataset: imagenet
  resources:
    requests:
      cpu: 50m
      memory: 256Mi
    limits:
      cpu: 200m
      memory: 512Mi
```

here again we have a DNS record to manage, which you'll be expected to add as a CNAME if following the previous advice, or a round robin to all workers otherwise. 

## How to adapt for yourself? 

You'll need to prepare a serve.sh script and a specific image that will handle serving of the model, which you can base on the Dockerfile-1.0.0-serving provided. It shall have the following properties: 

* Read files from a predictable location
* Have a predictable model name

In our context we start the evaluation with: 

```
/serving/bazel-bin/tensorflow_serving/model_servers/tensorflow_model_server \
    --port=${PORT}\
    ${BATCHING} \
    --model_name=${MODEL_NAME} \
    --model_base_path=${MODEL_PATH}
```

Which give you an indication of what to modify in your context. 

