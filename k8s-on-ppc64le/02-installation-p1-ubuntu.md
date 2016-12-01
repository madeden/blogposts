# Upgrading Ubuntu

I had done this in the past, so I was not particularly afraid of upgrading 14.04 to 16.04 on all the machines. Everything went pretty well with no hurdle. 

Note that at the time of this writing, 16.04 is not an officially  supported option on IBM ppc64. Hence consider this an experiment. 

<pre><code>
$ sudo do-release-upgrade
</pre></code>

This takes about 20min and requires to answer a few questions, then reboot, during which you can keep your fingers crossed (remember, our machines here are remote...)

Now we have our 3 machines up & running on Ubuntu 16.04, with the latest and greatest security updates. 

# The Fan
## Installation

On each machine, run 

<pre><code>
$ sudo apt install -yqq --no-install-recommend ubuntu-fan
</pre></code>


Then we have to configure it by just accepting default settings: 

<pre><code>
$ sudo fanatic
Welcome to the fanatic fan networking wizard.  This will help you set
up an example fan network and optionally configure docker and/or LXD to
use this network.  See fanatic(1) for more details.

Configure fan underlay (hit return to accept, or specify alternative) [192.168.0.0/16]: 
Configure fan overlay (hit return to accept, or specify alternative) [250.0.0.0/8]: 
Create LXD networking for underlay:192.168.0.0/16 overlay:250.0.0.0/8 [Yn]: Y
Profile fan-250 created
Docker not installed, unable to configure
Test LXD networking for underlay:192.168.1.178/16 overlay:250.0.0.0/8
(NOTE: potentially triggers large image downloads) [Yn]: Y
local lxd test: creating test container (Ubuntu:lts) ...
Creating fanatic-test
Retrieving image: 100%
Starting fanatic-test
lxd test: Waiting for addresses on eth0 ...
lxd test: Waiting for addresses on eth0 ...
lxd test: Waiting for addresses on eth0 ...
test master: ping test (250.1.178.99) ...
test slave: ping test (250.1.178.1) ...
test master: ping test ... PASS
test master: short data test (250.1.178.1 -> 250.1.178.99) ...
test slave: ping test ... PASS
test slave: short data test (250.1.178.99 -> 250.1.178.1) ...
test master: short data ... PASS
test master: long data test (250.1.178.1 -> 250.1.178.99) ...
test slave: short data ... PASS
test slave: long data test (250.1.178.99 -> 250.1.178.1) ...
test master: long data ... PASS
test slave: long data ... PASS
local lxd test: destroying test container ...
local lxd test: test complete PASS (master=0 slave=0)
This host IP address: 192.168.1.178
Remote test host IP address (none to skip): 
/usr/sbin/fanatic: Testing skipped
</pre></code>

**Notes**: You can notice that the IP address of the host here is 192.168.1.178, and the fan created a 250.1.178.0/24 network for this machine. For each machine of the network, we have therefore a /24 available for each host, or 254 times more IP addresses we had before in an addressable space. Pretty awesome, especially as is a mathematical computation only, hence it is extremely fast and doesn't require a server or anything. Neat and extremely easy to configure. 

To further this, the configuration for the fan is stored in **/etc/network/fan** 

For more information, [The Fan Wiki](https://wiki.ubuntu.com/FanNetworking)

## Test

At the end of our installation, we can run on each node: 

<pre><code>
$ ip addr show fan-250
3: fan-250: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue state UP group default qlen 1000
    link/ether 76:ce:91:53:9d:de brd ff:ff:ff:ff:ff:ff
    inet 250.1.178.1/8 scope global fan-250
       valid_lft forever preferred_lft forever
    inet 250.178.0.1/8 scope global secondary fan-250
       valid_lft forever preferred_lft forever
    inet6 fe80::74ce:91ff:fe53:9dde/64 scope link 
       valid_lft forever preferred_lft forever
</pre></code>

In my context, I found the 3 IP addresses: 250.1.178.1, 250.1.179.1 and 250.1.176.1

Now I can try to ping one another and see if I have a direct connection: 

<pre><code>
$ ping 250.1.179.1 -c 3
PING 250.1.179.1 (250.1.179.1) 56(84) bytes of data.
64 bytes from 250.1.179.1: icmp_seq=1 ttl=64 time=1.67 ms
64 bytes from 250.1.179.1: icmp_seq=2 ttl=64 time=0.606 ms
64 bytes from 250.1.179.1: icmp_seq=3 ttl=64 time=0.713 ms

--- 250.1.179.1 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2010ms
rtt min/avg/max/mdev = 0.606/0.997/1.674/0.481 ms
</pre></code>

# Password-less interconnections

We don't have access to a proper DNS so we update the /etc/hosts file for all nodes so they each know about the 2 other ones: 

<pre><code>
ubuntu@node01:~$ cat /etc/hosts
127.0.0.1 localhost
127.0.1.1 node01

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters

250.1.179.1 node02
250.1.180.1 node03
</pre></code>

Now we create a SSH key for our ubuntu user 

<pre><code>
ubuntu@node01:~$ ssh-keygen 
Generating public/private rsa key pair.
Enter file in which to save the key (/home/ubuntu/.ssh/id_rsa): 
Enter passphrase (empty for no passphrase): 
Enter same passphrase again: 
Your identification has been saved in /home/ubuntu/.ssh/id_rsa.
Your public key has been saved in /home/ubuntu/.ssh/id_rsa.pub.
The key fingerprint is:
SHA256:dL0Vdrk5qT9PlOnX3cEc2BSsZCRXXMhfVRjQjVQS2Wc ubuntu@node01
The key's randomart image is:
+---[RSA 2048]----+
|           .oB@#%|
|           .o+@BE|
|        . . +.o=*|
|       . .   +o==|
|        S   . .*o|
|             ...=|
|              ..*|
|               +.|
|                +|
+----[SHA256]-----+
</pre></code>

And finally we create our accesses to the other nodes. For node02 and node03 we do 

<pre><code>
$ ssh-copy-id ubuntu@node02
/usr/bin/ssh-copy-id: INFO: Source of key(s) to be installed: "/home/ubuntu/.ssh/id_rsa.pub"
The authenticity of host 'node02 (250.1.179.1)' can't be established.
ECDSA key fingerprint is SHA256:Wr5ekSVxlgqd4J/VpVEXljz/V4AfN5LBWuIx/rgCZGY.
Are you sure you want to continue connecting (yes/no)? yes
/usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s), to filter out any that are already installed
/usr/bin/ssh-copy-id: INFO: 1 key(s) remain to be installed -- if you are prompted now it is to install the new keys
ubuntu@node02's password: 

Number of key(s) added: 1

Now try logging into the machine, with:   "ssh 'ubuntu@node02'"
and check to make sure that only the key(s) you wanted were added.
</pre></code>