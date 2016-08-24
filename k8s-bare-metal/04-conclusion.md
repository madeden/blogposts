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
