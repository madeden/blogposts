# Deploying!!
## Deploying Tensorflow

At last!!

Let's assume you have 

* prepared your my-values.yaml file
* Added tensorboard.yourdomain.com and serving.yourdomain.com DNS records pointing to the workers
* Have deployed the dataloader

Then you can just do: 

```
helm install tensorflow --name tensorflow --values /path/to/my-values.yaml --debug
```

and watch your cluster start. After a few minutes, you can go to your tensorboard and you should see: 

## A few words before concluding

To prepare this blog I worked on 2 models: Imagenet and a Distributed CNN from a workshop Google made last August. The Distributed CNN is nice because it uses a small dataset, therefore works very nicely and quickly OOTB. 

Imagenet is the one I would really have loved to see working, and all the images are meant to leverage it. Unfortunately at this stage, everything starts nicely, but it doesn't seem to actually train. PS and workers start, then do nothing without failing, and do not output any logs. I'm working on it, but I didn't want to have you wait too long for the post... 

Contact me in PMs to discuss and if you'd like to experiment with it or share ideas to fix this, I will gladly mention your help :)

In addition, if you use the 1.0.0 Tensorflow images for Imagenet, you will encounter an [issue](https://github.com/tensorflow/tensorflow/issues/6202) due to the transition from 0.11 to 0.12, which essentially returns something like: 

```
$ kubectl logs worker-0-2134621739-2qd0j
Extracting Bazel installation...
.........
____Loading package: inception
...
____Found 1 target...
____Building...
____[0 / 1] BazelWorkspaceStatusAction stable-status.txt
____Building complete.
...
I tensorflow/stream_executor/dso_loader.cc:135] successfully opened CUDA library libcurand.so.8.0 locally
INFO:tensorflow:PS hosts are: ['ps-0.default.svc.cluster.local:8080']
INFO:tensorflow:Worker hosts are: ['worker-0.default.svc.cluster.local:8080', 'worker-1.default.svc.cluster.local:8080']
...
I tensorflow/core/common_runtime/gpu/gpu_device.cc:885] Found device 0 with properties: 
name: Tesla K80
major: 3 minor: 7 memoryClockRate (GHz) 0.8235
pciBusID 0000:00:1e.0
Total memory: 11.17GiB
Free memory: 11.11GiB
I tensorflow/core/common_runtime/gpu/gpu_device.cc:906] DMA: 0 
I tensorflow/core/common_runtime/gpu/gpu_device.cc:916] 0:   Y 
I tensorflow/core/common_runtime/gpu/gpu_device.cc:975] Creating TensorFlow device (/gpu:0) -> (device: 0, name: Tesla K80, pci bus id: 0000:00:1e.0)
I tensorflow/core/distributed_runtime/rpc/grpc_channel.cc:200] Initialize GrpcChannelCache for job ps -> {0 -> ps-0.default.svc.cluster.local:8080}
I tensorflow/core/distributed_runtime/rpc/grpc_channel.cc:200] Initialize GrpcChannelCache for job worker -> {0 -> localhost:8080, 1 -> worker-1.default.svc.cluster.local:8080}
I tensorflow/core/distributed_runtime/rpc/grpc_server_lib.cc:221] Started server with target: grpc://localhost:8080
Traceback (most recent call last):
  File "/models/inception/bazel-bin/inception/imagenet_distributed_train.runfiles/inception/inception/imagenet_distributed_train.py", line 65, in <module>
    tf.app.run()
...
TypeError: __init__() got multiple values for keyword argument 'dtype'
```

If you have this issue, use a 0.11 or anterior image. 



