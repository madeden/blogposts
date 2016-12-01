# LXD
## Installation

LXD comes by default on all Ubuntu 16.04+ versions. You can always install it via apt in case you went through upgrades and it is not pre-installed. In this case, don't forget to initialize it. 

<pre><code>
$ dpkg -l | grep lxd
ii  lxd                                2.0.5-0ubuntu1~ubuntu16.04.1      ppc64le        Container hypervisor based on LXC - daemon
ii  lxd-client                         2.0.5-0ubuntu1~ubuntu16.04.1      ppc64le        Container hypervisor based on LXC - client
</pre></code>

But the profile used by default by LXD is a bridge called lxdbr0. What we want is our containers to use "the fan", so we will have to change the default configuration

Let's have a look at the list of LXC profiles and their differences: 

<pre><code>
ubuntu@node01:~$ lxc profile list
default
docker
fan-250
ubuntu@node01:~$ lxc profile show default
name: default
config:
  environment.http_proxy: http://[fe80::1%eth0]:13128
  user.network_mode: link-local
description: Default LXD profile
devices:
  eth0:
    name: eth0
    nictype: bridged
    parent: lxdbr0
    type: nic
ubuntu@node01:~$ lxc profile show fan-250 
name: fan-250
config:
  user.profile_autoconfig: fanatic
description: ""
devices:
  eth0:
    mtu: "1450"
    nictype: bridged
    parent: fan-250
    type: nic
</pre></code>

So we have to replace the default profile content with fan-250. We edit the content with 

<pre><code>
$ lxc profile edit default
</pre></code>

so it looks like 

<pre><code>
name: default
config:
  user.profile_autoconfig: fanatic
description: Default LXD profile
devices:
  eth0:
    mtu: "1450"
    nictype: bridged
    parent: fan-250
    type: nic
</pre></code>

So now any container we will spawn will have an address in the 250.0.0.0/8 network. 

Let's see how that works: 

<pre><code>
$ lxc launch ubuntu:16.04 test
Creating test
Starting test
ubuntu@node01:~$ lxc exec test ip addr show
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
10: eth0@if11: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue state UP group default qlen 1000
    link/ether 00:16:3e:9b:33:17 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 250.1.178.232/8 brd 250.255.255.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::216:3eff:fe9b:3317/64 scope link 
       valid_lft forever preferred_lft forever
</pre></code>

So yeah, our LXC container on node01 got an IP address 250.1.178.232

Now on node02, we get 

<pre><code>
ubuntu@node02:~$ lxc exec test-node02 ip addr show
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
8: eth0@if9: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue state UP group default qlen 1000
    link/ether 00:16:3e:9a:41:e6 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 250.1.179.8/8 brd 250.255.255.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::216:3eff:fe9a:41e6/64 scope link 
       valid_lft forever preferred_lft forever
</pre></code>

and the second LXC container has an IP Address 250.1.179.8. Our 2 containers therefore have IP addresses on the 250.0.0.0 network. Can they communicate? 

<pre><code>
ubuntu@node01:~$ lxc exec test -- ping 250.1.179.8 -c3
PING 250.1.179.8 (250.1.179.8) 56(84) bytes of data.
64 bytes from 250.1.179.8: icmp_seq=1 ttl=64 time=1.08 ms
64 bytes from 250.1.179.8: icmp_seq=2 ttl=64 time=0.859 ms
64 bytes from 250.1.179.8: icmp_seq=3 ttl=64 time=0.753 ms

--- 250.1.179.8 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2001ms
rtt min/avg/max/mdev = 0.753/0.898/1.083/0.139 ms
</pre></code>

YES! Effectively, we have created an "overlay" network, a network that will give us the ability to communicate directly from container to container, or from container to metal, and we made this the default behavior of our cluster. Now any new container that will spawn up will inherit this, including the containers we will spin thank to Juju. 

