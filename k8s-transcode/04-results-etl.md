# Collecting and aggregating results
## Raw Logs

This is where it becomes a bit tricky. We could use an ELK stack and extract the logs there, but I couldn't find a way to make it really easy to measure our KPIs. 

Looking at what Docker does in terms of logging, you need to go on each machine and look into /var/lib/docker/containers/<uuid>/<uuid>-json.log

Here we can see that each job generates exactly 82 lines of log, but only some of them are interesting: 

* First line: gives us the start time of the log

```
{"log":"ffmpeg version 3.1.2 Copyright (c) 2000-2016 the FFmpeg developers\n","stream":"stderr","time":"2017-03-17T10:24:35.927368842Z"}
```

* line 13: name of the source

```
{"log":"Input #0, mov,mp4,m4a,3gp,3g2,mj2, from '/data/sintel_trailer-1080p.mp4':\n","stream":"stderr","time":"2017-03-17T10:24:35.932373152Z"}
```

* last line: 

```
{"log":"[aac @ 0x3a99c60] Qavg: 658.896\n","stream":"stderr","time":"2017-03-17T10:39:13.956095233Z"}
```

For advanced performance geeks, line 64 also gives us the transcode speed per frame, which can help profile the complexity of the video. For now, we don't really need that. 

## Mapping to jobs

The raw log is only a Docker uuid, and does not help use very much to understand to what job it relates. Kubernetes gracefully creates links in /var/log/containers/ mapping the pod names to the docker uuid. 

```
bm-1-0.8-1gi-0-t8fs5_default_POD-51de6e782777cb0e2b52a3d9d4604e0b5abf5e7a4fc418358b93984044bc1364.log
bm-1-0.8-1gi-0-t8fs5_default_transcoder-0-a39fb10555134677defc6898addefe3e4b6b720e432b7d4de24ff8d1089aac3a.log
```

the link with "POD" points to single lines logs which are not interesting to us. The other ones point to real jobs and can be used 

So here is what we do: 

1. Collect the list of logs on each host: 

```
for i in $(seq 0 1 1); do 
  [ -d logs/aws/node0${i} ] || mkdir -p logs/aws/node0${i}
  juju ssh kubernetes-worker-cpu/${i} "ls /var/log/containers | grep -v POD | grep -v 'kube-system'" > logs/aws/node0${i}/links.txt
  juju ssh kubernetes-worker-cpu/${i} "sudo tar cfz logs.tgz /var/lib/docker/containers"
  juju scp kubernetes-worker-cpu/${i}:logs.tgz logs/aws/node0${i}/
  cd logs/aws/node0${i}/
  tar xfz logs.tgz --strip-components=5 -C ./
  rm -rf config.v2.json host* resolv.conf* logs.tgz var shm
  cd ../../..
done
```

2. Extract import log lines (adapt per environment for nb of nodes...)

```
ENVIRONMENT=aws
MAX_NODE_ID=1
cd logs/${ENVIRONMENT}
echo "Host,Type,Concurrency,CPU,Memory,JobID,PodID,JobPodID,DockerID,TimeIn,TimeOut,Source" | tee ../db-${ENVIRONMENT}.csv
for node in 0 1
do
  cd node0${node}
  while read line; do
    echo "processing ${line}"

    NODE="node0${node}"
    CSV_LINE="$(echo ${line} | head -c-6 | tr '-' ',')"
    UUID="$(echo ${CSV_LINE} | cut -f9 -d',')"
    JSON="$(sed -ne '1p' -ne '13p' -ne '82p' ${UUID}-json.log)"
    TIME_IN="$(echo $JSON | jq --raw-output '.time' | head -n1 | xargs -I {} date --date='{}' +%s)"
    TIME_OUT="$(echo $JSON | jq --raw-output '.time' | tail -n1 | xargs -I {} date --date='{}' +%s)"
    SOURCE=$(echo $JSON | grep from | cut -f2 -d"'")

    echo "${NODE},${CSV_LINE},${TIME_IN},${TIME_OUT},${SOURCE}" | tee -a ../../db-${ENVIRONMENT}.csv

  done < links.txt
  cd ..
done
cd ../..
```

Once we have all the results, we load to Google Spreadsheet (public file here) INSERT FILE 