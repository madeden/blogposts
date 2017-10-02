# Adding GPU support in Kubernetes

If CUDA is discovered, CDK will also take action to configure the API server and the Kubelet to welcome GPU workloads. There is nothing to do from an operator perspective. 

Also, nodes with GPUs will be labeled in Kubernetes with "cuda=true" in order to allow nodeSelectors. 

# Testing our setup

Now we want to know if the cluster actually has GPU enabled. To validate, run a job with an nvidia-smi pod: 

```
kubectl create -f src/nvidia-smi.yaml
```

Then wait a little bit and run the log command: 

```
kubectl logs $(kubectl get pods -l name=nvidia-smi -o=name -a)
Tue Feb 14 14:14:57 2017       
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 375.26                 Driver Version: 375.26                    |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|===============================+======================+======================|
|   0  Tesla K80           Off  | 0000:00:17.0     Off |                    0 |
| N/A   47C    P0    56W / 149W |      0MiB / 11439MiB |      0%      Default |
+-------------------------------+----------------------+----------------------+
|   1  Tesla K80           Off  | 0000:00:18.0     Off |                    0 |
| N/A   39C    P0    70W / 149W |      0MiB / 11439MiB |      0%      Default |
+-------------------------------+----------------------+----------------------+
|   2  Tesla K80           Off  | 0000:00:19.0     Off |                    0 |
| N/A   48C    P0    57W / 149W |      0MiB / 11439MiB |      0%      Default |
+-------------------------------+----------------------+----------------------+
|   3  Tesla K80           Off  | 0000:00:1A.0     Off |                    0 |
| N/A   41C    P0    70W / 149W |      0MiB / 11439MiB |      0%      Default |
+-------------------------------+----------------------+----------------------+
|   4  Tesla K80           Off  | 0000:00:1B.0     Off |                    0 |
| N/A   47C    P0    58W / 149W |      0MiB / 11439MiB |      0%      Default |
+-------------------------------+----------------------+----------------------+
|   5  Tesla K80           Off  | 0000:00:1C.0     Off |                    0 |
| N/A   40C    P0    69W / 149W |      0MiB / 11439MiB |      0%      Default |
+-------------------------------+----------------------+----------------------+
|   6  Tesla K80           Off  | 0000:00:1D.0     Off |                    0 |
| N/A   48C    P0    59W / 149W |      0MiB / 11439MiB |      0%      Default |
+-------------------------------+----------------------+----------------------+
|   7  Tesla K80           Off  | 0000:00:1E.0     Off |                    0 |
| N/A   41C    P0    72W / 149W |      0MiB / 11439MiB |    100%      Default |
+-------------------------------+----------------------+----------------------+
                                                                               
+-----------------------------------------------------------------------------+
| Processes:                                                       GPU Memory |
|  GPU       PID  Type  Process name                               Usage      |
|=============================================================================|
|  No running processes found                                                 |
+-----------------------------------------------------------------------------+
```

Ẁhat is intersting here is that the pod sees all the cards, even if we only shared the /dev/nvidia0 char device. 
If you want to run multi GPU containers, you need to share all char devices like we do in the second yaml file (nvidia-smi-8.yaml)


