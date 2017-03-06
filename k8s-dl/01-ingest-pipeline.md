# Ingest Pipeline
## Introduction 

Any good data story starts with raw data, carefully preprocessed and published to a known location. 

ImageNet is a massive dataset of images that is used, among other things, to train the Inception model. It is made of a series of files that are managed by imagenet.org, which are not natively compliant with Tensorflow. 

Google open sourced the code to download and pre process ImageNet a little while ago [here](https://github.com/tensorflow/models/blob/master/inception/inception/data/download_and_preprocess_imagenet.sh). To automate the download, we create a simple Docker image (src/docker/tf-models/Dockerfile) that re uses the tensorflow official image to pull the dataset ${DATA_DIR}/imagenet. 

This is where the EFS volume you added earlier will come handy, as this will take about 500GB in the end. By the way, on my AWS instances it took about 3 days to download and pre-process it, so be prepared and patient. 

## Packaging Storage

To deploy this, you need

* a Persistent Volume (see previous blog), oversized to 900GB to also accomodate the models.
* a Persistent Volume Claim (see previous blog), oversized to 750GB
* a Kubernetes construct called a Job, which is essentially a way to run batch or cron jobs in k8s, where we mount our PVC, and that uses the image described above. 

The process of building a helm package is pretty simple: you abstract all the configuration, put all the values in a yaml file and all the keys in a **chart**, which is a set of other yaml templates forming the skeleton of Kubernetes manifests. You add some metadata around it, and voilaaa. See the src/charts folder to get a feel of what it is. 

**Note**: If you had to create a chart, you could do ```helm create foobar``` and it would generate the skeleton for you

The first chart we create is the EFS chart, which will connect our EFS storage to Kubernetes. We create a storage.yaml file in **src/charts/efs/templates** with: 

```
# Creating the PV first
apiVersion: v1
kind: PersistentVolume
metadata:
  name: {{ .Values.storage.name }}
  namespace: {{.Release.Namespace}}
  labels:
    heritage: {{.Release.Service | quote }}
    chart: "{{.Chart.Name}}-{{.Chart.Version}}"
    release: {{.Release.Name | quote }}
  annotations:
    "helm.sh/created": {{.Release.Time.Seconds | quote }}
spec:
  capacity:
    storage: {{ .Values.storage.pv.capacity }}
  accessModes:
  - {{ .Values.storage.accessMode }}
  nfs:
    server: {{.Values.global.services.aws.efs.id}}.efs.{{.Values.global.services.aws.region}}.amazonaws.com
    path: "/"
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: {{ .Values.storage.name }}
  namespace: {{.Release.Namespace}}
  labels:
    heritage: {{.Release.Service | quote }}
    chart: "{{.Chart.Name}}-{{.Chart.Version}}"
    release: {{.Release.Name | quote }}
  annotations:
    "helm.sh/created": {{.Release.Time.Seconds | quote }}
spec:
  accessModes:
  - {{ .Values.storage.accessMode }}
  resources:
    requests:
      storage: {{ .Values.storage.pvc.request }}

```

Yes, you recognized Go Templates!! Now look at the values.yaml file: 

```
global:
  imagePullPolicy: IfNotPresent
  services:
    aws:
      region: us-east-1
      efs:
        id: fs-47cd610e

storage:
  name: tensorflow-fs
  accessMode: ReadWriteMany
  pv: 
    capacity: "900Gi"
  pvc:
    name: tensorflow-fs
    request: "750Gi"
```

Pretty easy: you replace the sub sections by dots, apply a camelCase convention on your variables, and you have your first introduction to Helm. If you then use helm preview the output with ```helm install efs --name release-name --namespace super-ns --debug --dry-run```, you will generate a Kubernetes manifest like: 

```
# Creating the PV first
apiVersion: v1
kind: PersistentVolume
metadata:
  name: tensorflow-fs
  namespace: super-ns
  labels:
    heritage: Tiller
    chart: tensorflow
    release: release-name
  annotations:
    "helm.sh/created": 12345678
    "helm.sh/hook": pre-install
    "helm.sh/resource-policy": keep
spec:
  capacity:
    storage: 900Gi
  accessModes:
  - ReadWriteMany
  nfs:
    server: fs-47cd610e.efs.us-east-1.amazonaws.com
    path: "/"
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: tensorflow-fs
  namespace: super-ns
  annotations:
    "helm.sh/created": 12345678
    "helm.sh/hook": pre-install
    "helm.sh/resource-policy": keep
  labels:
    heritage: Tiller
    chart: tensorflow
    release: release-name
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 750Gi
```

Simple!! If you remove the ```--dry-run``` you'd actually deploy it, but we don't want to do that now. 

You can also override the default values.yaml file by adding ```--values /path/to/my-values.yaml```. You can already start building your own by copying mine and changing the values to adapt to your own environment. 

You get the drill. We prepare templates, we have a value file to instanciate it. Helm mixes both and generates a YAML file that works with Kubernetes. When you ```helm install```, a small server called Tiller in the Kubernetes cluster relays the instanciated manifest to the API for deployment (this Tiller server was created when running ```helm init```. You can create anything Kubernetes can operate. More info on the structure and some tips to start developing on LINK

## Packaging Data Ingest

We create a Helm chart called dataloader, which 

* has a requirement on efs, expressed via a "requirements.yaml" file at the root of the chart
* Adds a job which will download "something" that you can configure. 

Review the content of src/charts/dataloader to understand the structure. 

Now you can use the Makefile in the charts folder to build this package, 

```
cd src/charts
make dataloader
```

Then you can deploy that on your cluster. 

```
helm install dataloader --name dataloader --values /path/to/my-values.yaml

```

## How to adapt for yourself? 

The key of customizing this is your ability to prepare a docker image that makes sense in your context. 

Look in the repo in the folder src/docker/tf-models for a file called download.sh, and modify it to your needs. 

Build it with 

```
./src/docker/tf-models
docker build --rm \
  -t <username>/<name>:<version> \
  -f Dockerfile-1.0.0 \
  .
```

Note that you can use if needed the version 0.11, which I made because of some compatibility problems due to the breaking transition between 0.11 and 0.12 that are still not fixed in 1.0.0 for distributed training. 

Then push that to your repo

```
docker push <username>/<name>:<version>
```

Create the EFS and everything that is needed in AWS by following the previous part instructions. 

Now start a file `my-values.yaml` that contains the global, storage and dataLoader sections: 

```
global:
  imagePullPolicy: IfNotPresent
  services:
    aws:
      region: us-east-1
      efs:
        id: <yourETSID>

storage:
  name: tensorflow-fs
  accessMode: ReadWriteMany
  pv: 
    capacity: "900Gi"
  pvc:
    request: "750Gi"

dataLoader:
  service:
    name: dataloader
    command: '[ "/download.sh" ]'
  settings:
    dataset: flowers
    imagenetUsername: foo
    imagenetApiKey: bar
  image: 
    repo: <username>
    name: <name>
    dockerTag: <version>

```

And publish this to the cluster with: 

```
helm install dataloader --name dataloader --namespace default --values /path/to/my-values.yaml --debug
```

If you had it deployed before, you can do: 

```
helm upgrade dataloader dataloader --values /path/to/my-values.yaml 
```

That's it. You now have a dataset being downloaded. You can go and take 42 coffees while it does so, or continue reading this blog to understand your next steps. 

For now let us focus on bringing all our services up and running. 


