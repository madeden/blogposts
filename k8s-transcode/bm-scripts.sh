#!/bin/bash

echo "labelling nodes"
kubectl label $(kubectl get nodes -o name | head -n2) computePlane=true


echo "cloning repo"
git clone https://github.com/madeden/blogposts

cd blogposts/k8s-transcode/src

kubectl delete $(kubectl get jobs -o name)

echo "Generating values files"
for type in lxd56; do 
  for cpu in 2 3 4 5 6; do 
    for memory in 2; do 
      for para in $(seq 2 1 18); do 
        sed -e s#MAX_CPU#${CPU}#g \
          -e s#MULTISOURCE#false#g \
          -e s#BURST#false#g \
          -e s#TYPE#${type}#g \
          -e s#CPU#${cpu}#g \
          -e s#MEMORY#${memory}#g \
          -e s#PARALLELISM#${para}#g \
          values/values.tmpl > values/values-${para}-${type}-${cpu}-${memory}.yaml
      done
    done
  done
done

echo "Running first batch"
for type in lxd56; do 
  for cpu in 2 3 4 5 6; do 
    for memory in 2; do 
      for para in $(seq 2 1 18); do 
        [ -f values/values-${para}-${type}-${cpu}-${memory}.yaml ] && { \
          helm install transcoder \
            --values values/values-${para}-${type}-${cpu}-${memory}.yaml
          sleep 45
          while [ "$(kubectl get pods -l role=transcoder | wc -l)" -ne "0" ]; do
            sleep 10
          done
        }
      done
    done
  done
done

echo "Downloading results"
for MACHINE in 1 2 
do
  [ -d logs/lxd56/node0${MACHINE} ] || mkdir -p logs/lxd56/node0${MACHINE}
  juju ssh ${MACHINE} "sudo lxc list --format json | jq --raw-output '.[].name' | xargs -I {} sudo lxc exec {} tar cfz logs-{}.tgz /var/lib/docker/containers"
  juju ssh ${MACHINE} "sudo lxc list --format json | jq --raw-output '.[].name' | xargs -I {} sudo lxc file pull {}/root/logs-{}.tgz ./"
  juju scp ${MACHINE}:/home/ubuntu/logs-*.tgz logs/lxd56/node0${MACHINE}/
  juju ssh ${MACHINE} "sudo lxc list --format json | jq --raw-output '.[].name' | xargs -I {} sudo lxc exec {} -- ls /var/log/containers" > logs/lxd56/node0${MACHINE}/links-${MACHINE}.txt
done

for i in $(seq 0 1 1); do 
  [ -d logs/lxd56/node0${i} ] || mkdir -p logs/lxd56/node0${i}
  juju ssh kubernetes-worker-cpu/${i} "ls /var/log/containers | grep -v POD | grep -v 'kube-system'" > logs/lxd56/node0${i}/links.txt
  juju ssh kubernetes-worker-cpu/${i} "sudo tar cfz logs.tgz /var/lib/docker/containers"
  juju scp kubernetes-worker-cpu/${i}:logs.tgz logs/lxd56/node0${i}/
done

###
###

kubectl delete $(kubectl get jobs -o name)

for type in lxd56burst; do 
  for cpu in 2 3 4 5 6; do 
    for memory in 2; do 
      for para in $(seq 2 1 18); do 
        sed -e s#MAX_CPU#54#g \
          -e s#MULTISOURCE#false#g \
          -e s#BURST#false#g \
          -e s#TYPE#${type}#g \
          -e s#CPU#${cpu}#g \
          -e s#MEMORY#${memory}#g \
          -e s#PARALLELISM#${para}#g \
          values/values.tmpl > values/values-${para}-${type}-${cpu}-${memory}.yaml
      done
    done
  done
done

for type in lxd56burst; do 
  for cpu in 2 3 4 5 6; do 
    for memory in 2; do 
      for para in $(seq 2 1 18); do 
        [ -f values/values-${para}-${type}-${cpu}-${memory}.yaml ] && { \
          helm install transcoder \
            --values values/values-${para}-${type}-${cpu}-${memory}.yaml
          sleep 45
          while [ "$(kubectl get pods -l role=transcoder | wc -l)" -ne "0" ]; do
            sleep 10
          done
        }
      done
    done
  done
done

for i in $(seq 0 1 1); do 
  [ -d logs/lxd56burst/node0${i} ] || mkdir -p logs/lxd56burst/node0${i}
  juju ssh kubernetes-worker-cpu/${i} "ls /var/log/containers | grep -v POD | grep -v 'kube-system'" > logs/lxd56burst/node0${i}/links.txt
  juju ssh kubernetes-worker-cpu/${i} "sudo tar cfz logs.tgz /var/lib/docker/containers"
  juju scp kubernetes-worker-cpu/${i}:logs.tgz logs/lxd56burst/node0${i}/
done

