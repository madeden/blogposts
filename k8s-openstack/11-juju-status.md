Model      Controller  Cloud/Region  Version
openstack  openstack   maas          2.1.2

App                    Version       Status       Scale  Charm                  Store       Rev  OS      Notes
ceph-mon                             waiting        0/3  ceph-mon               jujucharms    9  ubuntu
ceph-osd               10.2.6        blocked          3  ceph-osd               jujucharms  241  ubuntu
ceph-radosgw                         waiting        0/1  ceph-radosgw           jujucharms  247  ubuntu
cinder                               waiting        0/1  cinder                 jujucharms  260  ubuntu
cinder-ceph                          waiting          0  cinder-ceph            jujucharms  223  ubuntu
glance                               waiting        0/1  glance                 jujucharms  256  ubuntu
keystone                             waiting        0/1  keystone               jujucharms  264  ubuntu
mysql                                waiting        0/1  percona-cluster        jujucharms  249  ubuntu
neutron-api                          waiting        0/1  neutron-api            jujucharms  249  ubuntu
neutron-gateway                      maintenance      1  neutron-gateway        jujucharms  234  ubuntu
neutron-openvswitch    9.2.0         waiting          2  neutron-openvswitch    jujucharms  240  ubuntu
nova-cloud-controller                waiting        0/1  nova-cloud-controller  jujucharms  294  ubuntu
nova-compute           14.0.4        waiting          3  nova-compute           jujucharms  264  ubuntu
ntp                    4.2.8p4+dfsg  active           2  ntp                    jujucharms   17  ubuntu
openstack-dashboard                  waiting        0/1  openstack-dashboard    jujucharms  245  ubuntu
rabbitmq-server                      waiting        0/1  rabbitmq-server        jujucharms   61  ubuntu

Unit                      Workload     Agent       Machine  Public address  Ports    Message
ceph-mon/0                waiting      allocating  1/lxd/0                           waiting for machine
ceph-mon/1                waiting      allocating  2/lxd/0                           waiting for machine
ceph-mon/2                waiting      allocating  3/lxd/0                           waiting for machine
ceph-osd/0                blocked      idle        1        172.27.13.102            Missing relation: monitor
ceph-osd/1*               blocked      idle        2        172.27.13.103            Missing relation: monitor
ceph-osd/2                blocked      idle        3        172.27.13.104            Missing relation: monitor
ceph-radosgw/0            waiting      allocating  0/lxd/0                           waiting for machine
cinder/0                  waiting      allocating  1/lxd/1                           waiting for machine
glance/0                  waiting      allocating  2/lxd/1                           waiting for machine
keystone/0                waiting      allocating  3/lxd/1                           waiting for machine
mysql/0                   waiting      allocating  0/lxd/1                           waiting for machine
neutron-api/0             waiting      allocating  1/lxd/2                           waiting for machine
neutron-gateway/0*        maintenance  executing   0        172.27.13.105            (install) Installing apt packages
nova-cloud-controller/0   waiting      allocating  2/lxd/2                           waiting for machine
nova-compute/0            maintenance  executing   1        172.27.13.102            (install) Installing apt packages
nova-compute/1*           waiting      idle        2        172.27.13.103            Incomplete relations: messaging, image, storage-backend
  neutron-openvswitch/1   waiting      idle                 172.27.13.103            Incomplete relations: messaging
  ntp/1                   active       idle                 172.27.13.103   123/udp  Unit is ready
nova-compute/2            waiting      idle        3        172.27.13.104            Incomplete relations: messaging, image, storage-backend
  neutron-openvswitch/0*  waiting      idle                 172.27.13.104            Incomplete relations: messaging
  ntp/0*                  active       idle                 172.27.13.104   123/udp  Unit is ready
openstack-dashboard/0     waiting      allocating  3/lxd/2                           waiting for machine
rabbitmq-server/0         waiting      allocating  0/lxd/2                           waiting for machine
