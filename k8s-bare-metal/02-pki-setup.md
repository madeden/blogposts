# Setup Security

So the CoreOS bootcfg comes with a script to generate certificates that uses openssl, but CoreOS now recommends to use [CloudFlare SSL](https://github.com/cloudflare/cfssl). So we will do that instead of using the default scripts. 

In the cfssl folder, you will find a series of json files that can be used in combination with cfssl to create a root CA and the certificates required to run k8s. 

Let us first create an alias to run the cfssl container in an easier way: 

```
alias cfssl="docker run --rm --name cfssl -v ~/k8s-bare-metal/cfssl:/etc/cfssl cfssl/cfssl"
```

## Initialize a root CA

First of all we need a Certificate Authority to generate more certs

```
$ cd ~/k8s-bare-metal/cfssl
$ cfssl gencert -initca /etc/cfssl/ca-csr.json | cfssljson -bare ca
```

Settings can be changed in the ca-csr.json file. The most important is the validity, which is set here at 10 years but you can certainly change that. Note also the profiles that are set

* **server**: for server side certs
* **client**: for client side only
* **client-server**: does both. It is the profile used for etcd peer network for example (not used in our setup)

## Generate Server and Client Certs

* API Server

```
cd ~/k8s-bare-metal-assets/cfssl
cfssl gencert \
  -ca=/etc/cfssl/ca.pem \
  -ca-key=/etc/cfssl/ca-key.pem \
  -config=/etc/cfssl/ca-config.json \
  -profile=server \
  /etc/cfssl/apiserver-csr.json | cfssljson -bare apiserver
```

This will generate 3 files in the current directory:

```
apiserver-key.pem
apiserver.csr
apiserver.pem
```

Now let us do the same for the other roles.

* Kubelet / Proxy (Workers)

```
cfssl gencert \
  -ca=/etc/cfssl/ca.pem \
  -ca-key=/etc/cfssl/ca-key.pem \
  -config=/etc/cfssl/ca-config.json \
  -profile=client \
  /etc/cfssl/worker-csr.json | cfssljson -bare worker
```

* kubectl CLI (Users)

```
cfssl gencert \
  -ca=/etc/cfssl/ca.pem \
  -ca-key=/etc/cfssl/ca-key.pem \
  -config=/etc/cfssl/ca-config.json \
  -profile=client \
  /etc/cfssl/admin.csr.json | cfssljson -bare admin
```

## Move assets to TLS folder

```
mv *.pem *.csr ~/k8s-bare-metal-assets/tls/
```

## Creating the kubeconfig file

```
cd ~/k8s-bare-metal-assets/
./bin/kube-conf.sh ./assets/tls 192.168.1.201
```

# Summary before the action

So far we have 

* Installed and plugged our devices and assets into the network, but let them off
* Configured our router to handle iPXE/PXE boot and forward these requests to our laptop
* Configured all the files on the laptop to handle installation and configuration of 3 CoreOS devices into an etcd and k8s, with 1 master and 2 workers
* Downloaded a few docker containers to operate the CoreOS main systems
* Created all security assets (CA + certs) to secure communication between the various k8s components
* Created a kubeconfig file to be able to communicate with our cluster

We are now ready to start!! 


