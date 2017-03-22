#!/bin/bash

CORES=$1

MYNAME="$(readlink -f "$0")"
MYDIR="$(dirname "${MYNAME}")"

for MACHINE in 1 2 
do
	juju ssh ${MACHINE} "sudo lxc list --format json | jq --raw-output '.[].name' | xargs -I {} sudo lxc config unset {} limits.cpu"
	juju ssh ${MACHINE} "sudo lxc list --format json | jq --raw-output '.[].name' | xargs -I {} sudo lxc config set {} limits.cpu ${CORES}"
	juju ssh ${MACHINE} "sudo lxc list --format json | jq --raw-output '.[].name' | xargs -I {} sudo lxc restart {}"
done
