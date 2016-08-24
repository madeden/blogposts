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
