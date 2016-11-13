# Conclusion

There are several things to remember from this experiment:

First of all, on the hardware side: 

* The M.2 port on many machines such as Intel NUCs can easily be converted into a fully fledge 4x PCI-e port. This is interesting because beyond GPUs many other cards meant to be used with bigger machines can now be enabled in small form factors.
* It is also possible to use a standard ATX PSU to power multiple GPUs, plugged to different computers, using tricks taken from mining crypto currencies
* I need to dig into this, but running the cards at 4x is probably not a very good idea. I had issues sometimes with the machines blocking completely while under load

Now on the software side: 

* MAAS is OK to manage bare metal machines but not perfect in a lab environent. 
  * On the + side, 
    * The GUI is OK and displays useful info. 
    * The OOTB experience is ok and documented, making it easy to onboard
    * DHCP, DNS and PXE pre-configured is a nice bonus over other solutions, even if their configuration is harder to find and not extremely powerful. 
  * On the - side
    * I can only regret the removal of Wake-on-LAN. I understand the comment that WoL does not allow for complete power management but this does not justify removing it from my perspective. It is widely spread and used in lab environments, hence this is sort of heightening the entry barrier with no benefit. 
    * GPUs are not managed by default. Can't blame on this one, litterally no tool seems to handle these devices at this stage but DC/OS
    * the UX could be improved. There is no context on errors, no pointers to the right files. Drop down menus with 3 choices could easily be spred over buttons to reduce clicks by 1 (at least). 
    * Why not offer the routing OOTB? This means the boxes need to use DHCP and DNS from one end, but a router from another. Again this sounds like an unecessary barrier for users without network admin skills. 
  * Overall it took me a couple of days to get it running, understand the logic and have my first units deployed successfully. As a comparison point, 
    * The CoreOS tooling is much more lightweight, runs in 2 containers only, but requires editing JSON/YAML files, on x86 only, and has no GUI. Better for experiments, much worse for the datacenter. 
    * I did not yet try Stacki but it is on my list. 
* Juju and the CDK charms work nicely, and the setup is fairly easy to understand
  * On the + side, 
    * Juju plugs natively to MAAS, so you have a set of tools that works out of the box, with little overhead, and allows to manage small or large fleets of machines. 
    * There is litterally nothing to know about k8s to get started. It just works, and that is really cool even if k8s is not the hardest piece of software I have worked with in the past.
    * Everything follows the "normal" way of running software on Ubuntu, with services in /etc/systemd, configuration in /etc/default and /etc/kubernetes hence it is easy to manage once deployed. 
    * The architecture can scale from the simple, no scale out system we deployed here to much more complex setups. Also, it respects best practices such as separating the kubelet plane from the Docker plane (/name your container runtime) plane, having etcd separated and secured, TLS everywhere... That is pretty deep for a distribution that is very young (only a couple of months). 
  * On the - side
    * No GPU! Again it is not a blame but just a note as no other system supports GPUs either, not to mention running CUDA in containers on CoreOS is a lot more painful than on Ubuntu
    * Documentation is not there yet for the implementation. It is nice to be able to deploy in one command, it would be better to have the whole infrastructure documented clearly to know where all the files are and so on.  
    * Sometimes it seems the Juju charms lose control of the workload. The juju status would report problems that do not exist, while k8s works fine. That happened to me once but I could not replicate. 

# Next Steps

Now that we have a cluster up and running, we'll put it to good use. We'll see two different use cases: 

* **Crypto Currency Mining**: See how we can scale a simple mining app to consume a maximum of power on our cluster
* **Tensorflow**: the Google Deep Learning framework is a very good complement of Kubernetes. We will see how to deploy and operate it at the scale of our cluster. 

# Last words

Thanks for reading this article, I hope you liked it. I welcome all questions and notes, do not hesitate to ask if I forgot anything. The project is hosted on GitHub as well so you can post issues or PR there. 




