# Bare Metal Kubernetes

I have been working with Kubernetes on the cloud for quite some time now, on GKE and Amazon, using Ubuntu or CoreOS as the hosts. I got a first class experience every time, with a pretty short learning curve to get started, but a lot of depth once the basic notions are understood. 

One of the most peculiar aspects of k8s is that it is clearly born in the cloud, and meant to live there. However, there are 2 aspects of it still remained sort of magical to me: 

* Storage: public clouds have a notion of block storage (like EBS), which gets attached to machines. If the machine dies, the disk remains and can be allocated to another instance. Your database is safe, we can keep the data away from the compute and it will survive even dramatic events. In the world of k8s, containers live and die regardless of the underlying hardware, making the construct of EBS somewhat irrelevant (and the emergence of EFS is I guess a consequence of this). 
* Networking: Once a service is created in k8s as a load balancer, its sole purpose is to be consumed from the outside world. Which means opening an external Load Balancer, and mapping it to the instances and ports that are allocated to its pods. 

Both these aspects are interesting because while they are abstract from the metal, they are not abstract from the cloud. So how do they work when you deploy k8s on bare metal? What are the constructs are needed to offer the same integration? How can I have resilient storage in an easy way for my stateful containers? How can I easily expose functionality to the outside world on a bare metal cluster? Ultimately, can I build a mini PaaS on metal for a startup, or should I stick to the cloud? 

Interestingly enough, there is little information about building a "production like" k8s on metal. Hence the only way to find out is DIY! 

Here start our journey to install k8s on bare metal. In this blog, we will use the toolbox created by CoreOS

[In a next part, we will study the installation of a resilient storage cluster to make sure we manage can stateful containers, and create a proxy / LB for services]

# Requirements

For this setup, we will need: 

* a home router that can offer some advanced configuration. In my case, I use a Ubiquity EdgeRouter. Any OpenWRT system should work (and feel free to propose configs for this). If you do not have such machine, then you can emulate what is needed, but you will have to disable DHCP on your network while you do the setup, or do it on a separate VLAN/network. You will need at least 4 available ethernet ports. 
* 3 Intel NUCs: we will want one master and 2 workers for a basic setup. k8s is not power so you should be ok with 4 to 8GB RAM and core i5 systems. For my setup, I re used a former  Gen5 5i7RYH (core i7, 16GB RAM, 256GB SSD + 250GB M.2 SSD), and I added 2 Gen6 6i5SYH (core i5 6400, 32GB RAM, 480GB SSD + 250GB M.2 SSD)
* A laptop connected to the same network with a cable (no wireless) and with the below capabilities:
  * Running docker containers 
  * Go 1.5+ installed and GOPATH configured, Go binaries folder added to PATH
  * Ports 80/tcp and 69/udp available
  * This repository cloned locally: ```cd ~ && git clone https://github.com/madeden/blogposts && ln -sf ~/blogposts/k8s-bare-metal ./k8s-bare-metal```

For the rest of this document, we assume these requirements are met, and that the NUCs are connected to the network, powered off and ready to start. 

# Conventions

For the sake of simplicity we will adopt the following conventions: 

## Network

We assume a classic Home Network, configured with a 192.168.1.0/24 subnet. Our router is 192.168.1.1 and acts as gateway, DHCP and DNS. 

## Servers

* Our laptop is node00, its MAC address is 00:00:00:00:00:00, IP address 192.168.1.250
* Our Master Node will be kube-master, and its MAC address is 00:00:00:00:00:01, IP address 192.168.1.201
* Our Worker nodes are
  * kube-worker-1, MAC address 00:00:00:00:00:11, IP address 192.168.1.211
  * kube-worker-2, with MAC address 00:00:00:00:00:12, IP address 192.168.1.212

# Configuring iPXE 

So our target will be to install k8s from scratch on our machines. We do not want to spend time installing the OSes, we just want everything to be automated. 

The main benefit of this will be that the whole procedure is repeatable. Build once, deploy many. 

The best way to do this at the moment is to use PXE boot or iPXE boot. Fortunately our Intel NUCs are compliant with iPXE, so we are good with that. 

## DHCP Configuration
### Fixed Leases

First thing is that want to make sure our machines have a fixed and predicatble IP address. So we configure static mappings in our DHCP server: 

[insert commands here]

### iPXE Boot Configuration

This comes from a set of posts found [here]() and [there]()

So first we create [2 scripts](/router/config/scripts). The first advertizes that the boot images will be downloaded from http://192.168.1.250 in the case of iPXE, or from TFTP from the same server for "classic" PXE boot. 

```
$ cat /config/ipxe-green.conf

allow bootp;
allow booting;

option ipxe.no-pxedhcp 1;

if exists user-class and option user-class = "iPXE" {
    filename "http://192.168.1.250/boot.ipxe";
} elsif option arch = 00:07 {
    filename "ipxe.efi";
} elsif option arch = 00:00 {
    filename "undionly.kpxe";
} else {
    filename "ipxe.efi";
}

next-server 192.168.1.250;
```

and the second is a generic configuration file for iPXE boot on the router. 

```
$ cat /config/ipxe-option-space.conf

# Declare the iPXE/gPXE/Etherboot option space
option space ipxe;
option ipxe-encap-opts code 175 = encapsulate ipxe;

# iPXE options, can be set in DHCP response packet
option ipxe.priority         code   1 = signed integer 8;
option ipxe.keep-san         code   8 = unsigned integer 8;
option ipxe.skip-san-boot    code   9 = unsigned integer 8;
option ipxe.syslogs          code  85 = string;
option ipxe.cert             code  91 = string;
option ipxe.privkey          code  92 = string;
option ipxe.crosscert        code  93 = string;
option ipxe.no-pxedhcp       code 176 = unsigned integer 8;
option ipxe.bus-id           code 177 = string;
option ipxe.bios-drive       code 189 = unsigned integer 8;
option ipxe.username         code 190 = string;
option ipxe.password         code 191 = string;
option ipxe.reverse-username code 192 = string;
option ipxe.reverse-password code 193 = string;
option ipxe.version          code 235 = string;
option iscsi-initiator-iqn   code 203 = string;

# iPXE feature flags, set in DHCP request packet
option ipxe.pxeext    code 16 = unsigned integer 8;
option ipxe.iscsi     code 17 = unsigned integer 8;
option ipxe.aoe       code 18 = unsigned integer 8;
option ipxe.http      code 19 = unsigned integer 8;
option ipxe.https     code 20 = unsigned integer 8;
option ipxe.tftp      code 21 = unsigned integer 8;
option ipxe.ftp       code 22 = unsigned integer 8;
option ipxe.dns       code 23 = unsigned integer 8;
option ipxe.bzimage   code 24 = unsigned integer 8;
option ipxe.multiboot code 25 = unsigned integer 8;
option ipxe.slam      code 26 = unsigned integer 8;
option ipxe.srp       code 27 = unsigned integer 8;
option ipxe.nbi       code 32 = unsigned integer 8;
option ipxe.pxe       code 33 = unsigned integer 8;
option ipxe.elf       code 34 = unsigned integer 8;
option ipxe.comboot   code 35 = unsigned integer 8;
option ipxe.efi       code 36 = unsigned integer 8;
option ipxe.fcoe      code 37 = unsigned integer 8;
option ipxe.vlan      code 38 = unsigned integer 8;
option ipxe.menu      code 39 = unsigned integer 8;
option ipxe.sdi       code 40 = unsigned integer 8;
option ipxe.nfs       code 41 = unsigned integer 8;

# Other useful general options
# http://www.ietf.org/assignments/dhcpv6-parameters/dhcpv6-parameters.txt
option arch code 93 = unsigned integer 16;
```

Then we configure the DHCP Server with: 

[insert configuration items]


In the end, our configuration section for DHCP should look like: 

```
service {
    dhcp-server {
        disabled false
        global-parameters "option option-deco code 240 = string;"
        global-parameters "class &quot;decos&quot; { match if substring (option vendor-class-identifier , 0, 5) = &quot;[IAL]&quot;; }"
        global-parameters "deny bootp;"
        global-parameters "include &quot;/config/scripts/ipxe-option-space.conf&quot;;"
        hostfile-update disable
        shared-network-name dhcp1 {
            authoritative enable
            subnet 192.168.1.0/24 {
                default-router 192.168.1.1
                dns-server 192.168.1.1
                lease 86400
                start 192.168.1.100 {
                    stop 192.168.1.199
                }
                static-mapping kube-master {
                    ip-address 192.168.1.201
                    mac-address 00:00:00:00:00:01
                }
                static-mapping kube-worker-1 {
                    ip-address 192.168.1.211
                    mac-address 00:00:00:00:00:11
                }
                static-mapping kube-worker-2 {
                    ip-address 192.168.1.212
                    mac-address 00:00:00:00:00:12
                }
                static-mapping node00 {
                    ip-address 192.168.1.250
                    mac-address 00:00:00:00:00:00
                }
                subnet-parameters "option option-deco &quot;:::::239.0.2.10:22222:v6.0:239.0.2.30:22222&quot;;"
                subnet-parameters "filename &quot;/boot.ipxe&quot;;"
                subnet-parameters "include &quot;/config/scripts/ipxe-green.conf&quot;;"
                tftp-server-name 192.168.1.250
            }
        }
    }
```

## Laptop Setup

You will have noted that we published our "next-server" to 192.168.1.250, which is our laptop. That means we will have to serve a our images from the laptop. Fortunately, CoreOS provides us with [a set of tools](https://github.com/coreos/coreos-baremetal/blob/master/Documentation/dev/develop.md) to help us deploy CoreOS on bare metal, which we will leverage here: 

### Pre requisites

OK first let us build a tree to store our files in the home directory

```
cd ~
mkdir -p \
    k8s-bare-metal/assets \
    k8s-bare-metal/assets/tftpboot \
    k8s-bare-metal/assets/tls \
    k8s-bare-metal/ignition \
    k8s-bare-metal/groups \
    k8s-bare-metal/profiles \
    k8s-bare-metal/src    
```

Now let's download the repository & gather the images for PXE boot. You'll need to check the latest versions on [this page](https://github.com/coreos/coreos-baremetal/tree/master/examples), the ones here are given as the current recommended elements.

```
cd ~/k8s-bare-metal/src
COREOS_BRANCH=alpha
LASTEST_COREOS=1053.2.0
git clone https://github.com/coreos/coreos-baremetal.git
./coreos-baremetal/scripts/get-coreos ${COREOS_BRANCH} ${LASTEST_COREOS} ~/k8s-bare-metal/assets
```

This will take a few minutes depending on your connection, so feel free to open another terminal 

We also need a set of boot files for PXE, which are freely available on the [PXE website]. They are present on the GitHub of this blog post, so you can just use them instead of downloading them all.

Now we need to download a couple of Docker images 

```
docker pull quay.io/coreos/bootcfg:latest
docker pull quay.io/coreos/dnsmasq:latest
docker pull cfssl/cfssl:latest

```

At this point we have the ground work covered, but we need to configure the various services that will install our machines. 

## Ignition Boot Configuration

Ignition is the mini service created by CoreOS to quickly install machines from PXE boot. It uses groups of machines, profiles and ignition configuration files. 

The installation sequence comes in 2 phases

1. Installation of CoreOS on the metal: this is just dumping the OS on the first disk and rebooting
2. Configuration of CoreOS to become master, worker, or even other things (it is a cloud init file like on the cloud, so this blog can be adapted to other setups)

Let us create the files required for this: 

```
.
├── groups
│   ├── install.json
│   ├── kube-master.json
│   ├── kube-worker-1.json
│   └── kube-worker-2.json
├── ignition
│   ├── install-reboot.yaml
│   ├── k8s-master.yaml
│   └── k8s-worker.yaml
├── profiles
│   ├── install-reboot.json
│   ├── k8s-master-install.json
│   └── k8s-worker-install.json
```
What is important is the link between these files: 

[Insert Schema here]

* k8s-bare-metal/groups/install.json

```
{
  "id": "coreos-install",
  "name": "CoreOS Install",
  "profile": "install-reboot",
  "metadata": {
    "coreos_channel": "alpha",
    "coreos_version": "1053.2.0",
    "ignition_endpoint": "http://192.168.1.250/ignition",
    "baseurl": "http://192.168.1.250/assets/coreos"
  }
}
```

* k8s-bare-metal/ignition/install-reboot.yaml

```
---
systemd:
  units:
    - name: install.service
      enable: true
      contents: |
        [Unit]
        Requires=network-online.target
        After=network-online.target
        [Service]
        Type=oneshot
        ExecStart=/usr/bin/curl {{.ignition_endpoint}}?{{.query}}&os=installed -o ignition.json
        ExecStart=/usr/bin/coreos-install -d /dev/sda -C {{.coreos_channel}} -V {{.coreos_version}} -i ignition.json {{if index . "baseurl"}}-b {{.baseurl}}{{end}}
        ExecStart=/usr/bin/udevadm settle
        ExecStart=/usr/bin/systemctl reboot
        [Install]
        WantedBy=multi-user.target

{{ if index . "ssh_authorized_keys" }}
passwd:
  users:
    - name: core
      ssh_authorized_keys:
        {{ range $element := .ssh_authorized_keys }}
        - {{$element}}
        {{end}}
{{end}}
```

* k8s-bare-metal/profiles/install-reboot.json

```
{
  "id": "install-reboot",
  "name": "Install CoreOS and Reboot",
  "boot": {
    "kernel": "/assets/coreos/1053.2.0/coreos_production_pxe.vmlinuz",
    "initrd": ["/assets/coreos/1053.2.0/coreos_production_pxe_image.cpio.gz"],
    "cmdline": {
      "coreos.config.url": "http://192.168.1.250/ignition?uuid=${uuid}&mac=${net0/mac:hexhyp}",
      "coreos.autologin": "",
      "coreos.first_boot": ""
    }
  },
  "cloud_id": "",
  "ignition_id": "install-reboot.yaml"
}
```

What happens? When we will boot the Intel NUCs in iPXE mode, they will initially "know nothing", therefore be directed to the install.json group. This will tell them to use the profile "install-reboot.json", which will then be used to render the ignition profile "install-reboot.yaml"

This will run the coreos_production_pxe_image, with a config file downloaded from the ignition server, and trigger the coreos-install script

```
/usr/bin/coreos-install -d /dev/sda -C {{.coreos_channel}} -V {{.coreos_version}} -i ignition.json {{if index . "baseurl"}}-b {{.baseurl}}{{end}}
```

The arguments are defined by: 

```
-d DEVICE   Install CoreOS to the given device.
-V VERSION  Version to install (e.g. current) [default: ${VERSION_ID}]
-C CHANNEL  Release channel to use (e.g. beta) [default: ${CHANNEL_ID}]
-o OEM      OEM type to install (e.g. ami) [default: ${OEM_ID:-(none)}]
-c CLOUD    Insert a cloud-init config to be executed on boot.
-i IGNITION Insert an Ignition config to be executed on boot.
-t TMPDIR   Temporary location with enough space to download images.
-v          Super verbose, for debugging.
-b BASEURL  URL to the image mirror
-n          Copy generated network units to the root partition.
-h          This ;-)
```

So the command line will run the install.service, which dumps the CoreOS image to /dev/sda, using another ignition profile, downloaded via ```/usr/bin/curl {{.ignition_endpoint}}?{{.query}}&os=installed -o ignition.json```. 

If we look into the other group files (below example of the groups/kube-mater.json, we see that there is a selector by MAC Address and installation status. 

```
{
  "id": "kube-master",
  ...
  "selector": {
    "os": "installed",
    "mac": "b8:ae:ed:7a:b6:92"
  },
  ...
}
```

So our first CoreOS node, running the PXE version of CoreOS, will now get access this group as it declares it is installed and gives away its MAC address, which will direct it to the k8s-master-install.json profile, and finally the k8s-master.yaml ignition file. 

The same will happen with different profiles for our worker nodes. 

## Ignition Init Files

The ignition init files are extremely similar to cloud init file **BUT THEY ARE NOT THE SAME** (and it is a shame as I cannot find any thing that prevents them from being shared beyond references to the underlying file system for each and every file)

They essentially declare waht units will run on our beloved nodes and so on. The setup we have here installs: 

* etcd cluster: as we have 3 machines, why not have them operate an HA etcd ring? However, this is not (yet) a TLS enabled etcd cluster, so communications will be in clear at this point
* k8s cluster: 1 master and 2 workers as discussed. TLS is enabled for the API Server so communications are encrypted at least at this level.

If you are familiar with k8s, you should not have any surprise there. Note however 

* the additional dropin for Docker to enable unsecure registries. You do not have to accept that and can safely remove that item. I use it as the next stage of the cluster is to run a Deis PaaS and by default an unsecure registry is needed. This also adds a k8s startup option. 
* some log rotate information inherited from a few experiences with small disks on AWS. 

# Setup Security

So the CoreOS bootcfg comes with a script to generate certificates that uses openssl, but CoreOS now recommends to use [CloudFlare SSL](https://github.com/cloudflare/cfssl). So we will do that instead of using the default scripts. 

In the cfssl folder, you will find a series of json files that can be used in combination with cfssl to create a root CA and the certificates required to run k8s. 

Let us first create an alias to run the cfssl container in an easier way: 

```
alias cfssl="docker run --rm -name cfssl cfssl/cfssl "
```

## Initialize a root CA

First of all we need a Certificate Authority to generate more certs

```
$ cfssl gencert -initca ca-csr.json | cfssljson -bare ca
```

Settings can be changed in the ca-csr.json file. The most important is the validity, which is set here at 10 years but you can certainly change that. Note also the profiles that are set

* server: for server side certs
* client: for client side only
* client-server: does both. It is the profile used for etcd peer network for example (not used here)

## Generate Server and Client Certs

* API Server

```
cd ~/k8s-bare-metal-assets/cfssl
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=server \
  apiserver-csr.json | cfssljson -bare apiserver
```

Results:

```
apiserver-key.pem
apiserver.csr
apiserver.pem
```

* Kubelet / Proxy (Workers)

```
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=client \
  worker-csr.json | cfssljson -bare worker
```

* kubectl CLI (Users)

```
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=client \
  admin.csr.json | cfssljson -bare admin
```

## Move assets to TLS folder

```
mv *.pem *.csr ~/k8s-bare-metal-assets/tls
```





sudo docker run -p 80:80 --rm -v /home/scozannet/Documents/src/coreos/bootcfg:/var/lib/bootcfg:Z -v /home/scozannet/Documents/src/coreos/bootcfg/groups:/var/lib/bootcfg/groups:Z quay.io/coreos/bootcfg:latest -address=0.0.0.0:80 -log-level=debug

sudo docker run --rm --cap-add=NET_ADMIN -p 69:69/udp -v /home/scozannet/Documents/src/coreos/bootcfg/assets/tftpboot:/var/lib/tftpboot quay.io/coreos/dnsmasq -d -q --enable-tftp --tftp-root=/var/lib/tftpboot

# References 
## PXE Configuration

http://forum.ipxe.org/showthread.php?tid=7874
http://projects.theforeman.org/projects/foreman/wiki/Fetch_boot_files_via_http_instead_of_TFTP
http://ipxe.org/howto/chainloading
https://docs.oracle.com/cd/E19045-01/b200x.blade/817-5625-10/Linux_Troubleshooting.html

## Ubiquity Edge Configuration



## CoreOS on Bare Metal

https://github.com/coreos/coreos-baremetal/blob/master/Documentation/kubernetes.md

## CloudFlare SSL 



