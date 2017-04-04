#!/bin/bash

CORES=$1

MYNAME="$(readlink -f "$0")"
MYDIR="$(dirname "${MYNAME}")"

for MACHINE in 1 2
do
	juju scp ${MYDIR}/../lxd/kubernetes-worker-profile ${MACHINE}:
	juju ssh ${MACHINE} "sudo apt install -yqq --no-install-recommends jq"
	juju ssh ${MACHINE} "sudo lxc profile create kubernetes-worker && sudo lxc profile edit kubernetes-worker < ./kubernetes-worker-profile"
	juju ssh ${MACHINE} "sudo lxc list --format json | jq --raw-output '.[].name' | xargs -I {} sudo lxc profile apply {} kubernetes-worker"
	juju ssh ${MACHINE} "sudo lxc list --format json | jq --raw-output '.[].name' | xargs -I {} sudo lxc restart {} "
	juju ssh ${MACHINE} "wget https://download.blender.org/durian/trailer/sintel_trailer-1080p.mp4"
	juju ssh ${MACHINE} "sudo lxc list --format json | jq --raw-output '.[].name' | xargs -I {} sudo lxc file push /home/ubuntu/sintel_trailer-1080p.mp4 {}/mnt/sintel_trailer-1080p.mp4"
	juju ssh ${MACHINE} "sudo lxc list --format json | jq --raw-output '.[].name' | xargs -I {} sudo lxc config set {} limits.cpu ${CORES}"
	juju ssh ${MACHINE} "sudo lxc list --format json | jq --raw-output '.[].name' | xargs -I {} sudo lxc restart {}"
done

