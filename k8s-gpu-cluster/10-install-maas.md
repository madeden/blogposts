# Install MAAS on rpi2

For the rest of this, we will assume that you have ready: 

* a Raspberry Pi 2 or 3 installed with Ubuntu Server 16.04
* The board ethernet port connected to a network that connects to internet, and configured
* an additional USB to ethernet adapter, connected to our cluster switch

# Pre Requisites
## Network setup

Out of the box our Ubuntu image here will not auto install the USB adapter. We need to do it ourselves. Here is how:

```
$ ifconfig -a
```

will show us if our adapter was recognized or not. If yes, we shall see a eth1 (or other name) in addition to our eth0 interface. For example: 

```
$ /sbin/ifconfig -a
eth0      Link encap:Ethernet  HWaddr b8:27:eb:4e:48:c6  
          inet addr:192.168.1.138  Bcast:192.168.1.255  Mask:255.255.255.0
          inet6 addr: fe80::ba27:ebff:fe4e:48c6/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:150573 errors:0 dropped:0 overruns:0 frame:0
          TX packets:39702 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000 
          RX bytes:217430968 (217.4 MB)  TX bytes:3450423 (3.4 MB)

eth1      Link encap:Ethernet  HWaddr 00:0e:c6:c2:e6:82  
          BROADCAST MULTICAST  MTU:1500  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000 
          RX bytes:0 (0.0 B)  TX bytes:0 (0.0 B)

...
...
```

We can now edit **/etc/network/interfaces.d/eth1.cfg** with 

```
# hwaddress 00:0e:c6:c2:e6:82
auto eth1
iface eth1 inet static
    address 192.168.23.1
    netmask 255.255.255.0
```

then start eth1 with ```sudo ifup eth1``` and now we have a secondary interface setup. 

## Software installation

Let's install first the requirements: 

```
$ sudo apt update && sudo apt upgrade -yqq
$ sudo apt install -yqq --no-install-recommends \
    maas \
    bzr \
    isc-dhcp-server \
    wakeonlan \
    amtterm \
    wsmancli \
    juju \
    zram-config
```

Let's also use the occasion to fix the very annoying Perl Locales bug that affects pretty much every Rapsberry Pi around:

```
$ sudo locale-gen en_US.UTF-8
```

Now let's activate zram to virtually increase our RAM by 1GB by adding the below in **/etc/rc.local**

```
modprobe zram && \
  echo $((1024*1024*1024)) | tee /sys/block/zram0/disksize && \
  mkswap /dev/zram0 && \
  swapon -p 10 /dev/zram0 && \
  exit 0
```

and do an immediate activation via

```
$ sudo modprobe zram && \
  echo $((1024*1024*1024)) | sudo tee /sys/block/zram0/disksize && \
  sudo mkswap /dev/zram0 && \
  sudo swapon -p 10 /dev/zram0
```

## DHCP Configuration

DHCP will be handled by MAAS directly, so we don't have to handle it. However the way it configures the default settings is pretty brutal, so you might want to tune that a little bit. Below is a **/etc/dhcp/dhcpd.conf ** file that would work and is a little fancier 

```
authoritative;
ddns-update-style none;
log-facility local7;

option subnet-mask 255.255.255.0;
option broadcast-address 192.168.23.255;
option routers 192.168.23.1;
option domain-name-servers 192.168.23.1;
option domain-name "maas";
default-lease-time 600;
max-lease-time 7200;

subnet 192.168.23.0 netmask 255.255.255.0 {
  range 192.168.23.10 192.168.23.49;

  host node00 {
    hardware ethernet B8:AE:ED:7A:B6:92;
    fixed-address 192.168.23.10;
  }

  host node01 {
    hardware ethernet F4:4D:30:64:ED:72;
    fixed-address 192.168.23.13;
  }

  host node02 {
    hardware ethernet F4:4D:30:64:4D:43;
    fixed-address 192.168.23.13;
  }

  host node03 {
    hardware ethernet B8:AE:ED:EB:87:27;
    fixed-address 192.168.23.11;
  }

  host node04 {
    hardware ethernet B8:AE:ED:6E:4C:E6;
    fixed-address 192.168.23.14;
  }

  host node05 {
    hardware ethernet F4:4D:30:63:47:C8;
    fixed-address 192.168.23.13;
  }

  host node06 {
    hardware ethernet B8:AE:ED:EB:2C:74;
    fixed-address 192.168.23.12;
  }
}

```

We need also to tell dhcpd to only serve requests on  eth1 to prevent flowding our other networks. We do that by editing **/etc/default/isc-dhcp-server** so it looks like

```
# Path to dhcpd's config file (default: /etc/dhcp/dhcpd.conf).
#DHCPD_CONF=/etc/dhcp/dhcpd.conf

# Path to dhcpd's PID file (default: /var/run/dhcpd.pid).
#DHCPD_PID=/var/run/dhcpd.pid

# Additional options to start dhcpd with.
#	Don't use options -cf or -pf here; use DHCPD_CONF/ DHCPD_PID instead
#OPTIONS=""

# On what interfaces should the DHCP server (dhcpd) serve DHCP requests?
#	Separate multiple interfaces with spaces, e.g. "eth0 eth1".
INTERFACES="eth1"
```

and finally we restart DHCP with 

```
$ sudo systemctl restart isc-dhcp-server.service
```

## Simple Router Configuration

In our setup, the Raspberry Pi is the point of contention of the network. While MAAS provides DNS and DHCP by default it does not operate as a gateway. Hence our nodes may very well end up blind from the Internet, which we obviously do not want. 

So first we activate IP forwarding in sysctl: 

```
sudo touch /etc/sysctl.d/99-maas.conf
echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/99-maas.conf
sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
```

Then we need to link our eth0 and eth1 interfaces to allow traffic between them

```
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo iptables -A FORWARD -i eth0 -o eth1 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i eth1 -o eth0 -j ACCEPT
```

OK so now we have traffic passing, which we can test by plugging anything on the LAN interface and trying to ping some internet website.

And we save that in order to make it survive a reboot

```
sudo sh -c "iptables-save > /etc/iptables.ipv4.nat"
```

and add this line in /etc/network/interfaces.d/eth1.conf

```
up iptables-restore < /etc/iptables.ipv4.nat
```

# MAAS Configuration
## Initial Configuration

First of all create your administrative user: 

```
$ sudo maas createadmin --username=admin --email=it@madeden.com
```

Then let's get access to our API key, and login from the CLI: 

```
$ sudo maas-region apikey --username=admin
```

Armed with the result of this command, just do:

```
$ # maas login <profile-name> <hostname> <key>
$ maas login admin http://localhost/MAAS/api/2.0 <key>
```

Or you can just in one command: 

```
$ sudo maas-region apikey --username=admin | \
    maas login admin http://localhost/MAAS/api/2.0 -
```

Now via the GUI, in the network tab, we rename our **fabrics** to match LAN, WAN and WLAN. 

Then we hit the LAN network, and via the **Take Action** button, we enable DHCP on it. 

## Adding nodes

The only thing we have to do is to start the nodes once. They will be handled by MAAS directly, and will appear in the GUI after a few minutes. 

They will have a random name, and nothing configured. 

First of all we will rename them. To ease things up, in our experiment, we will use node00 and node01 for the first non GPU nodes, then node02 to 04 being the gpu nodes. 

After we name them, we will also 

* tag them **cpu-only** for the 2 first management nodes
* tag them **gpu** for the 4 workers. 
* Set the power method to **Manual**

We then have something like 

![this screen](/pics/all-6-nodes-new.png)

## Commissioning nodes

This is where the fun begins. We need to "commission nodes", said otherwise to record information about them (HDD, CPU count...)

### Hacketty Hack

There is a [bug](https://bugs.launchpad.net/maas/+bug/1604962) in MAAS that blocks the deployment of systems. Look at comment #14 and apply it by editing **/etc/maas/preseeds/curtin_userdata**. In the reboot section to add a delay so it looks like: 

```
power_state:
  mode: reboot
  delay: 30
```

### Commissioning

This is done via the **Take Action** button and selecting **commission**, and leave unticked the all 3 other options. 

We will then need to manually start the nodes. They will automagically be powered down by MAAS at the end of the process. 

During the process, the status of the node will change from **New** to **Commissioning** like in the below pics:

![Single Node](/pics/commissioning.png)

![List View](/pics/commissioning-2.png)

When commissioning is successful, we see all the values for HDD size, nb cores and memory filled. There is no column for GPU though. The node also becomes **Ready**

![View of all statuses](/pics/commissioning-nodes.png)

# Next Steps

At the end of this exercise, we have a cluster of 6 nodes ready to be deployed via any tool talking to the MAAS API for provisioning. 

In our context we will use Juju, the default tool from Canonical to deploy Big Software.



