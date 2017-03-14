# Intro

The 3 Docker images provide 

* Inception Data Ingest for Imagenet (CPU only)
* Distributed Inception Training for Imagenet (CPU and/or GPU)
* Inception Evaluation for Imagenet (GPU only)
* Inception Serving for Imagenet (CPU only)

They constitute the core of a Kubernetes implementation of the [official tutorial](https://github.com/tensorflow/models/blob/master/inception/README.md) provided by Google. Additionally the tensorboard can be used to monitor the process, and doesn't require specific a image. 

# Inception Deep Learning Workflow
## Data Ingest

ImageNet requires a significant dataset to operate. It is downloaded using a CPU-only job in Kubernetes based on the default Dockerfile. 

You must set the following variables: 

DATA_DIR (defaults to /var/tensorflow/)
IMAGENET_USERNAME (defaults to username)
IMAGENET_ACCESS_KEY (defaults to api_key)

Username and API Key can be obtained directly from [ImageNet](http://www.image-net.org/). 

Then you need at the very minimum 500GB of storage to download the dataset. It is advised to use an EFS mount point in AWS or equivalent. 

The process takes a couple of days to complete, so get prepared for a lot of coffee. 

## Training

Training requires a new set of options to run. As we consider that any training should be distributed, we have a set of ps and workers distributing the load over the cluster. 

This is modeled around Kubernetes configMaps, which are then exposed in the containers as ENV variables. I didn't find a way to properly construct json on the fly with Helm packages, hence I rely on TF being relax on JSON format, and accept: 

```
{
    "ps": [
        "ps-0.default.svc.cluster.local:8080",
        "ps-1.default.svc.cluster.local:8080",
    ],
    "worker": [
        "worker-0.default.svc.cluster.local:8080",
        "worker-1.default.svc.cluster.local:8080",
        "worker-2.default.svc.cluster.local:8080",
    ],
}
```

as a valid format. However, if you plan to use Docker natively, it will also accept properly formated JSON. 

The ENV variable to expose in the container are: 

CLUSTER_CONFIG: the above JSON file with the definition of the cluster to use
POD_NAME: <job type>-<task id>, like worker-0, or ps-2. 
DATA_DIR: defaults to /var/tensorflow. A new folder in there called **imagenet-checkpoints** will appear. 

As a result, for the above cluster definition, you would have to define 5 containers (2x ps, 3x workers). 

If you want to use this in a docker-compose environment you will have to change the format of the hostnames in the cluster configuration, but the rest should work ootb. 

Note that the container will expect to find the ImageNet data, formatted as the output of the previous step, in ${DATA_DIR}/imagenet. 

2 images are available for this: 

* The normal image for CPU only, where the default command must be changed to start on /train.sh
* The GPU image, based on Tensorflow 1.0.0 GPU, where the default command must be changed to start on /train.sh

## Evaluation

Evaluation is a standalone process, that also runs on GPUs. It takes as ENV

DATA_DIR: defaults to /var/tensorflow. A new folder in there called **imagenet-eval** will appear. 

It will expect to find ${DATA_DIR}/imagenet-checkpoints with models being exported by the training task in that folder. The evaluations will be written to the eval folder, where they can be consumed by a tensorboard. The tensorboard is a secondary pod based on the native Tensorflow 1.0.0 image started with the command: 

```
tensorboard --logdir /var/tensorflow/imagenet-eval
```

## Serving

Serving is a little more complicated. We use the [example](https://tensorflow.github.io/serving/serving_inception.html) provided by Google slightly modified to avoid any direct action inside of the container itself. 

The image to build is generated via Dockerfile.serving, and takes a loooong time to build. 

# Last words

This project is to demonstrate how to run complete Deep Learning setups in Kubernetes. A secondary version is available using the workshop code as well, and showing how data scientists can quickly leverage Kubernetes, Helm and Tensorflow to train models at scale. 

For more information, don't hesitate to contact me at samuel.cozannet@madeden.com




