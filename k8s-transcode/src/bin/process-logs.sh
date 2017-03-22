#!/bin/sh

ENVIRONMENT=$1
MAX_LXD_ID=$2
MAX_NODE_ID=1
LXD_ID=$3

echo "Host,Type,Concurrency,CPU,Memory,JobID,PodID,JobPodID,DockerID,TimeIn,TimeOut,Source" | tee ../db-${ENVIRONMENT}.csv


for node in 1 2; do 
  for lxd in 0 1 2; do 
    mkdir -p logs/lxd/node0${node} 
    cp logs-juju-${LXC_ID}-${node}-${ENVIRONMENT}-${lxd}.tgz logs/lxd/node0${node}/logs.tgz
    cd logs/lxd/node0${node}
    tar xfz logs.tgz --strip-components=5 -C ./
    rm -rf config.v2.json host* resolv.conf* logs.tgz var shm
    cd ../../..
  done
done


for node in 1 2
do
  cat links-${node}.txt | grep -v POD | grep -v 'kube-system' \
  	> logs/lxd/node0${node}/links.txt

  cd node0${node}
  while read line; do
    echo "processing ${line}"

    NODE="node0${node}"
    CSV_LINE="$(echo ${line} | head -c-6 | tr '-' ',')"
    UUID="$(echo ${CSV_LINE} | cut -f8 -d',')"
    JSON="$(sed -ne '1p' -ne '13p' -ne '82p' ${UUID}-json.log)"
    TIME_IN="$(echo $JSON | jq --raw-output '.time' | head -n1 | xargs -I {} date --date='{}' +%s)"
    TIME_OUT="$(echo $JSON | jq --raw-output '.time' | tail -n1 | xargs -I {} date --date='{}' +%s)"
    SOURCE=$(echo $JSON | grep from | cut -f2 -d"'")

    echo "${NODE},${CSV_LINE},${TIME_IN},${TIME_OUT},${SOURCE}" | tee -a ../../db-${ENVIRONMENT}.csv

  done < links.txt
  cd ..
done
