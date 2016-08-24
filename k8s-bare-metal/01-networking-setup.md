# Configuring iPXE and other network aspects

Our target will be to install k8s from scratch on our machines. We do not want to spend time installing the OSes, we just want everything to be automated. 

The main benefit of this will be that the whole procedure is repeatable. Build once, deploy many. 

The most convenient way to do this is to use PXE boot or iPXE boot. However it requires a bit of work, as iPXE/PXE depend on the DHCP capability to forward the PXE boot to a proper host. 

## DHCP Configuration
### [Fixed Leases](https://www.ubnt.com/edgemax/edgerouter/)

First thing is that want to make sure our machines have a fixed and predictable IP address. So we configure static mappings in our DHCP server: 

```
ubnt@ubnt# configure
ubnt@ubnt# edit service dhcp-server shared-network-name dhcp subnet 192.168.1.0/24
```

Then, for each of the machines (including the laptop), we do

```
ubnt@ubnt# set static-mapping <machine-anme> mac-address <xx:xx:xx:xx:xx:xx>
ubnt@ubnt# set static-mapping <machine-anme> ip-address <Ip.Ad.Dr.eSs>
```

For example, 

```
ubnt@ubnt# set static-mapping kube-master mac-address 00:00:00:00:00:01
ubnt@ubnt# set static-mapping kube-master ip-address 192.168.1.201
```

Finally commit and save

```
ubnt@ubnt# commit
ubnt@ubnt# save
```

Now we know that our machines will be allocated the right IP addresses. On the laptop, donc forget to restart the dhcp client to map to the right address if you do all this in one batch. 

### iPXE Boot Configuration

This comes from a set of posts found [here](https://blog.laslabs.com/2013/05/pxe-booting-with-ubiquiti-edgerouter/) and [there](http://forum.ipxe.org/showthread.php?tid=7874)

So first we create [2 scripts](/router/config/scripts). The [first](/router/config/scripts/ipxe-green.conf) advertizes that the boot images will be downloaded from http://192.168.1.250 in the case of iPXE, or from TFTP from the same server for "classic" PXE boot. 

```
ubnt@ubnt# vi /config/ipxe-green.conf

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

and the [second](/router/config/scripts/ipxe-green.conf) is a generic configuration file for iPXE options on the router. 

```
ubnt@ubnt# vi /config/ipxe-option-space.conf

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

```
ubnt@ubnt# configure
ubnt@ubnt# set service dhcp-server global-parameters "deny bootp;"
ubnt@ubnt# set service dhcp-server global-parameters "include &quot;/config/scripts/ipxe-option-space.conf&quot;;"
ubnt@ubnt# set service dhcp-server shared-network-name dhcp subnet 192.168.1.0/24 subnet-parameters "include &quot;/config/scripts/ipxe-green.conf&quot;;"
ubnt@ubnt# set service dhcp-server shared-network-name dhcp authoritative enable
```

In the end, our configuration section for DHCP looks like: 

```
service {
    dhcp-server {
        disabled false
        global-parameters "option option-deco code 240 = string;"
        global-parameters "class &quot;decos&quot; { match if substring (option vendor-class-identifier , 0, 5) = &quot;[IAL]&quot;; }"
        global-parameters "deny bootp;"
        global-parameters "include &quot;/config/scripts/ipxe-option-space.conf&quot;;"
        hostfile-update disable
        shared-network-name dhcp {
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
                subnet-parameters "include &quot;/config/scripts/ipxe-green.conf&quot;;"
            }
        }
    }
```

## Laptop Setup

You will have noted that we published our "next-server" to 192.168.1.250, which is our laptop. That means we will have to serve a our images from the laptop. Fortunately, CoreOS provides us with [a set of tools](https://github.com/coreos/coreos-baremetal/blob/master/Documentation/dev/develop.md) to help us deploy CoreOS on bare metal, which we will leverage here: 

### Pre requisites

OK first let have a look at the tftpboot files we cloned in the home directory

```
.
├── assets
│   ├── tftpboot
│   │   ├── grub.efi
│   │   ├── ipxe.efi
│   │   ├── ipxe.lkrn
│   │   ├── ipxe.pxe
│   │   ├── pxelinux.cfg
│   │   │   └── default
│   │   └── undionly.kpxe
  
```

the pxelinux.cfg/default is a very simple no menu PXE boot, and we have all the necessary EFI, PXE and iPXE boot files there so you do not have to download them from [ipxe.org](http://ipxe.org)

Now let's download the CoreOS repository & gather the CoreOS images for PXE boot. You'll need to check the latest versions on [this page](https://github.com/coreos/coreos-baremetal/tree/master/examples), the ones here are given as the current recommended elements.

```
cd ~/k8s-bare-metal/src
export COREOS_BRANCH=alpha
export LASTEST_COREOS=1053.2.0
git clone https://github.com/coreos/coreos-baremetal.git
./coreos-baremetal/scripts/get-coreos ${COREOS_BRANCH} ${LASTEST_COREOS} ~/k8s-bare-metal/assets
```

This will take a few minutes depending on your connection, so feel free to open another terminal. In the end, your assets directory will look like: 

```
.
├── assets
│   ├── coreos
│   │   └── 1053.2.0
│   │       ├── CoreOS_Image_Signing_Key.asc
│   │       ├── coreos_production_image.bin.bz2
│   │       ├── coreos_production_image.bin.bz2.sig
│   │       ├── coreos_production_pxe_image.cpio.gz
│   │       ├── coreos_production_pxe_image.cpio.gz.sig
│   │       ├── coreos_production_pxe.vmlinuz
│   │       └── coreos_production_pxe.vmlinuz.sig
│   ├── tftpboot
│   │   ├── .....
```

Now we need to download a few Docker images 

```
docker pull quay.io/coreos/bootcfg:latest
docker pull quay.io/coreos/dnsmasq:latest
docker pull cfssl/cfssl:latest
```

And finally let us download the cfssljson binary: 

```
curl -s -L -o cfssljson https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
chmod +x cfssljson
sudo mv cfssljson /usr/local/bin/
```

At this point we have the ground installation work covered, but we need to configure the various services that will install our machines. 

## Ignition Boot Configuration

Ignition is the mini service created by CoreOS to quickly install machines from PXE boot. It uses groups of machines, profiles and ignition configuration files. 

The installation sequence comes in 2 phases

1. Installation of CoreOS on the metal: this is just dumping the OS on the first disk, downloading config files and rebooting
2. Configuration of CoreOS to become master, worker, or even other things on the second boot (it is a cloud init file like on the cloud, so this blog can be adapted to other setups)

Let us look at the files required for this in our tree: 

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

If we look into the other group files (below example of the groups/kube-mater.json), we see that there is a selector by MAC Address and installation status. 

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

So our first CoreOS node, running the PXE version of CoreOS, will now get access this group as it declares it is installed and gives away its MAC address, which will direct it to the k8s-master-install.json profile, and finally render the k8s-master.yaml ignition file. 

The same will happen with different profiles for our worker nodes. 

## Ignition Init Files

The ignition init files are extremely similar to cloud init file **BUT THEY ARE NOT THE SAME** (and it is a shame as I cannot find any thing that prevents them from being shared beyond references to the underlying file system for each and every file)

They essentially declare what units will run on our beloved nodes and so on. The setup we have here installs: 

* **etcd cluster**: as we have 3 machines, why not have them operate an HA etcd ring? However, this is not (yet) a TLS enabled etcd cluster, so communications will be in clear at this point
* **k8s cluster**: 1 master and 2 workers as discussed. TLS is enabled for the API Server so communications are encrypted at least at this level.

If you are familiar with k8s, you should not have any surprise there as this is essentially what CoreOS ships as examples with the core-baremetal project. Note however 

* the additional dropin for Docker to enable unsecure registries. You do not have to accept that and can safely remove that item. I use it as the next stage of the cluster is to run a Deis PaaS and by default an unsecure registry is needed. This also adds a k8s startup option. 
* some log rotate information inherited from a few experiences with small disks on AWS. 

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

# It's RUNTIME!!
## Starting services on laptop

On our laptop, let us start the required tools

* **tftpboot**: we use the CoreOS dnsmasq image, but limit it to only run TFTP. This container must run privileged, and access our TFTP files. As it will use a privileged port on the host system we have to sudo its run: 

```
sudo docker run \
  --rm \
  --cap-add=NET_ADMIN \
  -p 69:69/udp \
  -v ~/k8s-bare-metal/assets/tftpboot:/var/lib/tftpboot \
  quay.io/coreos/dnsmasq -d -q --enable-tftp --tftp-root=/var/lib/tftpboot
```

**Note**: this dnsmasq image from CoreOS can also do all the dhcp management and serve a mini DNS server. We did not use it because in traditional home setups the DHCP is provided by the router and it could create DHCP conflicts. If you operate in a separate LAN and do not want to configure a specific DHCP system, this might be a good option. 

* **bootcfg**: we use the CoreOS bootcfg image. This container must run privileged, and access our assets and Ignitionn files. As it will use a privileged port on the host system we have to sudo its run: 

In a separate terminal, run

```
sudo docker run \
  -p 80:80 \
  --rm \
  -v ~/k8s-bare-metal:/var/lib/bootcfg:Z \
  -v ~/k8s-bare-metal/groups:/var/lib/bootcfg/groups:Z \
  quay.io/coreos/bootcfg:latest -address=0.0.0.0:80 -log-level=debug
```

At this point, we are serving TFTP files and the Ignition server from our 192.168.1.250 laptop. 

## Starting the nodes

Start what is supposed to become the master, and access the BIOS. From there, double click on the network boot option. It reboots into PXE mode. After a little while you should see some logs popping up in the 2 docker containers serving TFTP and bootcfg. 

You should then on the NUC screen if there is one see that it is dumping CoreOS to disk, and, after about 1min, rebooting. On the second boot, it will apply the configuration and you should have the traditional CLI welcome screen. 

Repeat the operation with the 2 slaves. When they all have installed their systems, open a third terminal and 

```
$ kubectl --kubeconfig=~/k8s-bare-metal/assets/tls/kubeconfig get nodes
NAME            STATUS    AGE
192.168.1.201   Ready     23d
192.168.1.211   Ready     23d
192.168.1.212   Ready     23d
```

and 

```
$ kubectl --kubeconfig=~/k8s-bare-metal/assets/tls/kubeconfig get svc --all-namespaces
NAMESPACE         NAME                     CLUSTER-IP   EXTERNAL-IP   PORT(S)                            AGE
default           kubernetes               10.3.0.1     <none>        443/TCP                            23d
kube-system       heapster                 10.3.0.51    <none>        80/TCP                             23d
kube-system       kube-dns                 10.3.0.10    <none>        53/UDP,53/TCP                      23d
```

# Changing the configuration

Let us say you would like to replicate this setup at home, but your setup is a bit different. This is what you need to take care of: 

* replace the MAC Addresses of the machines: For each MAC, run something like: 

```
cd ~/k8s-bare-metal
find . -type f -exec sed -i #00:00:00:00:00:01#aa:bb:cc:dd:ee:ff# {} \;
```

* replace the IP Addresses of the machines: For each IP, run something like: 

```
cd ~/k8s-bare-metal
find . -type f -exec sed -i #192.168.1.201#192.168.123.231# {} \;
```

* Replace SSH Keys: In each of the **groups/kube-*.json** there is a **PutYourSshKeyHere** word. Replace it with your public key to add yourself to the nodes

* Update CFSSL Configuration: Edit the **cfssl/ca*.json** files to adapt

* Update k8s configuration: Edit the **ignition/*.yaml** files

# Conclusion

This was a pretty long post, and we only covered the first phase of our journey. Remember, the initial reason why we did all this was to understand how k8s on Bare Metal would handle exposing services on the network, and understand how we could setup a cloud-like storage service for it. Well, now we have a bare metal k8s cluster, so we can certainly move forward and start playing with it. 

Next on the roadmap is deploying a Ceph cluster on the same set of hosts, to expose a scale out storage system to our mini cluster. 

Then we will see how we can use some k8s contrib projects to expose services on the network. 

And finally, once we will have done all that, we will install Deis and have a pure self hosted, stateful-compliant PaaS for our beloved developers! 

# References 
## PXE Configuration

http://forum.ipxe.org/showthread.php?tid=7874
http://projects.theforeman.org/projects/foreman/wiki/Fetch_boot_files_via_http_instead_of_TFTP
http://ipxe.org/howto/chainloading
https://docs.oracle.com/cd/E19045-01/b200x.blade/817-5625-10/Linux_Troubleshooting.html

## Ubiquity Edge Configuration

https://blog.laslabs.com/2013/05/pxe-booting-with-ubiquiti-edgerouter/

## CoreOS

https://coreos.com/
https://github.com/coreos/coreos-baremetal/blob/master/Documentation/kubernetes.md

## CloudFlare SSL 

https://cfssl.org/
