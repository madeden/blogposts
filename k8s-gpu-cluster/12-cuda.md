# Enabling CUDA in Kubernetes

By default, CDK will not activate GPUs when starting the API server and the Kubelet on workers. We need to do that manually (though updates in the charms could fix that for us if we had a specific relation implementation)

## Master Update

On the master node, update **/etc/default/kube-apiserver** to add: 

```
# Security Context
KUBE_ALLOW_PRIV="--allow-privileged=true"
```

Then restart the API service via

```
$ sudo systemctl restart kube-apiserver
```
So now the Kube API will accept requests to run privileged containers, which are required for GPU workloads.

## Worker nodes

On every worker, **/etc/default/kubelet** to to add the GPU tag, so it looks like:

```
# Security Context
KUBE_ALLOW_PRIV="--allow-privileged=true"

# Add your own!
KUBELET_ARGS="--experimental-nvidia-gpus=1 --require-kubeconfig --kubeconfig=/srv/kubernetes/config --cluster-dns=10.1.0.10 --cluster-domain=cluster.local"
```

Then restart the service via

```
$ sudo systemctl restart kubelet
```

# Testing the setup

Now that we have CUDA GPUs enabled in k8s, let us test that everything works. We take a very simple job that will just run nvidia-smi from a pod and exit on success. 

The job definition is 

```
apiVersion: batch/v1
kind: Job
metadata:
  name: nvidia-smi
  labels:
    name: nvidia-smi
spec:
  template:
    metadata:
      labels:
        name: nvidia-smi
    spec:
      containers:
      - name: nvidia-smi
        image: nvidia/cuda
        command: [ "nvidia-smi" ]
        imagePullPolicy: IfNotPresent
        securityContext:
          privileged: true
        resources:
          requests:
            alpha.kubernetes.io/nvidia-gpu: 1 
          limits:
            alpha.kubernetes.io/nvidia-gpu: 1 
        volumeMounts:
        - mountPath: /dev/nvidia0
          name: nvidia0
        - mountPath: /dev/nvidiactl
          name: nvidiactl
        - mountPath: /dev/nvidia-uvm
          name: nvidia-uvm
        - mountPath: /usr/local/nvidia/bin
          name: bin
        - mountPath: /usr/lib/nvidia
          name: lib
      volumes:
        - name: nvidia0
          hostPath: 
            path: /dev/nvidia0
        - name: nvidiactl
          hostPath: 
            path: /dev/nvidiactl
        - name: nvidia-uvm
          hostPath: 
            path: /dev/nvidia-uvm
        - name: bin
          hostPath: 
            path: /usr/lib/nvidia-367/bin
        - name: lib
          hostPath: 
            path: /usr/lib/nvidia-367
      restartPolicy: Never
```

What is interesting here is 

* We do not have the abstraction provided by nvidia-docker, so we have to specify manually the mount points for the char devices
* We also need to share the drivers and libs folders
* In the resources, we have to both request and limit the resources with 1 GPU
* The container has to run privileged

Now if we run this: 

```
$ kubectl create -f nvidia-smi-job.yaml
$ # Wait for a few seconds so the cluster can download and run the container
$ kubectl get pods -a -o wide
NAME                             READY     STATUS      RESTARTS   AGE       IP          NODE
default-http-backend-8lyre       1/1       Running     0          11h       10.1.67.2   node02
nginx-ingress-controller-bjplg   1/1       Running     1          10h       10.1.83.2   node04
nginx-ingress-controller-etalt   0/1       Pending     0          6m        <none>      
nginx-ingress-controller-q2eiz   1/1       Running     0          10h       10.1.14.2   node05
nginx-ingress-controller-ulsbp   1/1       Running     0          11h       10.1.67.3   node02
nvidia-smi-xjl6y                 0/1       Completed   0          5m        10.1.14.3   node05
```

We see the last container has run and completed. Let us see the output of the run

```
$ kubectl logs nvidia-smi-xjl6y
Wed Nov  9 07:52:42 2016       
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 367.57                 Driver Version: 367.57                    |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|===============================+======================+======================|
|   0  GeForce GTX 106...  Off  | 0000:02:00.0     Off |                  N/A |
| 28%   33C    P0    29W / 120W |      0MiB /  6072MiB |      0%      Default |
+-------------------------------+----------------------+----------------------+
                                                                               
+-----------------------------------------------------------------------------+
| Processes:                                                       GPU Memory |
|  GPU       PID  Type  Process name                               Usage      |
|=============================================================================|
|  No running processes found                                                 |
+-----------------------------------------------------------------------------+
```

Perfect, we have the same result as if we had run nvidia-smi from the host, which means we are all good to operate GPUs! 

