# MAAS
## tgt failing

tgt is the tool to manage the iSCSI endpoints used to start machines. It uses a configuration file in **/etc/tgt/conf.d/maas.conf** to retain configuration. 

Each mount point consumes a little bit of memory, so having too many is not a good idea, especially on a little rpi. It seems MAAS creates a lot of replication in this file, hence on the raspberry pi can crash. This translates into log lines in **/var/log/maas/maas.log** showing: 

```
Nov  8 15:47:56 maasberry maas.service_monitor: [ERROR] While monitoring service 'tgt' an error was encountered: Unable to parse the active state from systemd for service 'tgt', active state reported as 'deactivating'.
Nov  8 15:48:56 maasberry maas.service_monitor: [ERROR] While monitoring service 'tgt' an error was encountered: Unable to parse the active state from systemd for service 'tgt', active state reported as 'deactivating'.
Nov  8 15:49:56 maasberry maas.service_monitor: [ERROR] While monitoring service 'tgt' an error was encountered: Unable to parse the active state from systemd for service 'tgt', active state reported as 'deactivating'.
```

also journalctl would show: 

```
$ sudo journalctl -xe
 08 15:48:47 maasberry tgtd[2919]: tgtd: bs_thread_open(423) failed to create a worker thread, 12 Resource temporarily unavailable
Nov 08 15:48:47 maasberry tgtd[2919]: tgtd: bs_thread_open(437) stopped the worker thread 11
Nov 08 15:48:47 maasberry tgtd[2919]: tgtd: bs_thread_open(437) stopped the worker thread 10
Nov 08 15:48:47 maasberry tgtd[2919]: tgtd: bs_thread_open(437) stopped the worker thread 9
Nov 08 15:48:47 maasberry tgtd[2919]: tgtd: bs_thread_open(437) stopped the worker thread 8
Nov 08 15:48:47 maasberry tgtd[2919]: tgtd: bs_thread_open(437) stopped the worker thread 7
Nov 08 15:48:47 maasberry tgtd[2919]: tgtd: bs_thread_open(437) stopped the worker thread 6
Nov 08 15:48:47 maasberry tgtd[2919]: tgtd: bs_thread_open(437) stopped the worker thread 5
Nov 08 15:48:47 maasberry tgtd[2919]: tgtd: bs_thread_open(437) stopped the worker thread 4
Nov 08 15:48:47 maasberry tgtd[2919]: tgtd: bs_thread_open(437) stopped the worker thread 3
Nov 08 15:48:47 maasberry tgtd[2919]: tgtd: bs_thread_open(437) stopped the worker thread 2
Nov 08 15:48:47 maasberry tgtd[2919]: tgtd: bs_thread_open(437) stopped the worker thread 1
Nov 08 15:48:47 maasberry tgtd[2919]: tgtd: bs_thread_open(437) stopped the worker thread 0
Nov 08 15:48:47 maasberry systemd[1]: tgt.service: Control process exited, code=exited status=22
Nov 08 15:48:47 maasberry tgt-admin[2928]: tgtadm: out of memory
Nov 08 15:48:47 maasberry tgt-admin[2928]: Command:
Nov 08 15:48:47 maasberry tgt-admin[2928]:         tgtadm -C 0 --lld iscsi --op new --mode logicalunit --tid 16 --lun 1 -b /var/lib/maas/boot-resources/sn
Nov 08 15:48:47 maasberry tgt-admin[2928]: exited with code: 22.
Nov 08 15:48:54 maasberry sudo[3268]: scozannet : TTY=pts/0 ; PWD=/home/scozannet ; USER=root ; COMMAND=/bin/systemctl status tgt
Nov 08 15:48:54 maasberry sudo[3268]: pam_unix(sudo:session): session opened for user root by scozannet(uid=0)
Nov 08 15:48:56 maasberry sudo[3274]:     maas : TTY=unknown ; PWD=/ ; USER=root ; COMMAND=/bin/systemctl status tgt
Nov 08 15:48:56 maasberry sudo[3274]: pam_unix(sudo:session): session opened for user root by (uid=0)
Nov 08 15:48:56 maasberry sudo[3275]:     maas : TTY=unknown ; PWD=/ ; USER=root ; COMMAND=/bin/systemctl status maas-dhcpd6
Nov 08 15:48:56 maasberry sudo[3275]: pam_unix(sudo:session): session opened for user root by (uid=0)
Nov 08 15:48:56 maasberry sudo[3276]:     maas : TTY=unknown ; PWD=/ ; USER=root ; COMMAND=/bin/systemctl status maas-dhcpd
Nov 08 15:48:56 maasberry sudo[3276]: pam_unix(sudo:session): session opened for user root by (uid=0)
Nov 08 15:48:56 maasberry sudo[3274]: pam_unix(sudo:session): session closed for user root
Nov 08 15:48:56 maasberry maas.service_monitor[1410]: [ERROR] While monitoring service 'tgt' an error was encountered: Unable to parse the active state fr
Nov 08 15:48:56 maasberry sudo[3275]: pam_unix(sudo:session): session closed for user root
Nov 08 15:48:56 maasberry sudo[3276]: pam_unix(sudo:session): session closed for user root
```

If that happens, have a look and remove all the lines but the first ones, which should look like:

```
<target iqn.2004-05.com.ubuntu:maas:ephemeral-ubuntu-amd64-generic-trusty-daily>
    readonly 1
    allow-in-use yes
    backing-store "/var/lib/maas/boot-resources/snapshot-20161108-154718/ubuntu/amd64/generic/trusty/daily/root-image"
    driver iscsi
</target>
<target iqn.2004-05.com.ubuntu:maas:ephemeral-ubuntu-amd64-generic-xenial-daily>
    readonly 1
    allow-in-use yes
    backing-store "/var/lib/maas/boot-resources/snapshot-20161108-154718/ubuntu/amd64/generic/xenial/daily/root-image"
    driver iscsi
</target>
```

As you can see, it only happens after there are about a dozen of entries in the list, so it's not immediate (on the Raspberry Pi)

# CUDA
## Devices not found

```
ubuntu@node04:~$ sudo nvidia-smi
No devices were found
```

This is a "common" problem, mostly due to our installation which is pretty specific. I didn't find a solution for it as it sort of appears randomly. Help welcome! 


