#!/bin/bash

MYNAME="$(readlink -f "$0")"
MYDIR="$(dirname "${MYNAME}")"

for MACHINE in 1 2 
do
  juju ssh ${MACHINE} "sudo lxc list --format json | jq --raw-output '.[].name' | xargs -I {} sudo lxc exec {} tar cfz logs-{}.tgz /var/lib/docker/containers"
  juju ssh ${MACHINE} "sudo lxc list --format json | jq --raw-output '.[].name' | xargs -I {} sudo lxc file pull {}/root/logs-{}.tgz ./"
  juju scp ${MACHINE}:/home/ubuntu/logs-*.tgz ./
  juju ssh ${MACHINE} "sudo lxc list --format json | jq --raw-output '.[].name' | xargs -I {} sudo lxc exec {} -- ls /var/log/containers" > links-${MACHINE}.txt
done

