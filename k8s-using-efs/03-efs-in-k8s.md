# Connecting EFS and CDK

To consume storage like EFS in Kubernetes, you need 2 primitives: 

* Persistent Volumes (PV), which define large storage allocations that can be sliced into separate sub-volumes. Think of this as a disk that you could partition essentially. 
* Persistent Volume Claims (PVC): this is a chunk / partition of a PV that is allocated to one or more pods. If you have several PVs, Kubebernetes will elect the most suitable PV to consume data from. PVCs can have different Read/Write properties: 
    * Read Only: like secrets
    * ReadManyWriteOnce: only one pod can write, but many can read. If you have a master/agent deployment for example
    * ReadWriteMany: everyone can read and write. If you have to exchange files between different micro services, this is a simple way of doing so

A PV will look like 

```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: efs-volume
spec:
  capacity:
    storage: 100Gi
  accessModes:
    - ReadWriteMany
  nfs:
    server: EFS_SERVICE_HOST
    path: "/"
```

where EFS_SERVICE_HOST is **${FS_ID}.${REGION}.amazonaws.com**. Here we can see that this PV uses the NFS primitive to consume EFS. In CDK, all worker nodes have nfs-common installed by default, hence this works ootb. 

You can create this PV with the classic ```kubectl create -f src/pv.yaml```


One PVC consuming this could be: 

```
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: efs-volume
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 50Gi
```

Our PVC requests 50GB out of the 100 that we provisionned earlier. We could have a second one like this. 

You can create this PVC with ```kubectl create -f src/pvc.yaml```

# Consuming the PVC

PVCs are consumed as mount points by pods. Below is an example of job that has a pod consuming a PVC: 

```
apiVersion: batch/v1
kind: Job
metadata:
  name: data-consumer
spec:
  template:
    metadata:
      name: pi
    spec:
      containers:
      - name: data-consumer
        image: super-container:latest
        imagePullPolicy: Always
        volumeMounts:
        - mountPath: "/efs"
          name: efs
      volumes:
        - name: efs
          persistentVolumeClaim:
            claimName: efs-volume
      restartPolicy: Never
```



