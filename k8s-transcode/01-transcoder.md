# Charting a simple transcoder
## Transcoding with ffmpeg and Docker

When I want to do something with a video, the first thing I do is call my friend Ronan Delacroix (@ronan_delacroix). He built so many transcoders and scale out solutions for this I lost count. 

So I asked him something pretty straightforward: I want the most CPU intensive ffmpeg transcoding one liner you can think of. 

He came back with not only the one liner, but also found a very neat [docker image](https://github.com/jrottenberg/ffmpeg) for it, kudos to Julien for making this. 

All together you get: 

```
docker run --rm -v $PWD:/tmp/workdir jrottenberg/ffmpeg:ubuntu \
	-i /tmp/workdir/source.mp4 \
	-stats -c:v libx264 \
	-s 1920x1080 \
	-crf 22 \
	-profile:v main \
	-pix_fmt yuv420p \
	-threads 0 \
	-f mp4 -ac 2 \
	-c:a aac -b:a 128k \
	-strict -2 \
	/tmp/workdir/output.mp4
```

The key of this setup is the "-threads 0" which tells ffmpeg that it's an all you can eat buffet. 

For test videos, [HD Trailers](http://www.hd-trailers.net/) is a great source. We can use a video of 40 to 60MB to make it long enough to encode but not too long

## Helm Chart

Transcoding maps directly to the notion of Job in Kubernetes. Jobs are batch processes that can be orchestrated very easily, and configured so that Kubernetes will not restart them when the job is done. 

The equivalent to Deployment Replicas is Job Parallelism. 

To add concurrency, I thought I first experimented with it. It proved a bad approach, making things more complicated than necessary to analyze the output. So I built a chart that creates many (numbered) jobs that run a single pod, so I can easily track them and their logs. 

```
{{- $type := .Values.type -}}
{{- $parallelism := .Values.parallelism -}}
{{- $cpu := .Values.resources.requests.cpu -}}
{{- $memory := .Values.resources.requests.memory -}}
{{- $maxCpu := .Values.resources.max.cpu -}}
{{- $requests := .Values.resources.requests -}}
{{- $multiSrc := .Values.multiSource -}}
{{- $src := .Values.defaultSource -}}
{{- $burst := .Values.burst -}}

---
{{- range $job, $nb := until (int .Values.parallelism) }}
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ $type | lower }}-{{ $parallelism }}-{{ $cpu | lower }}-{{ $memory | lower }}-{{ $job }}
spec:
  parallelism: 1
  template:
    metadata:
      labels:
        role: transcoder
    spec:
      containers:
      - name: transcoder-{{ $job }}
        image: jrottenberg/ffmpeg:ubuntu
        args: [
          "-y",
          "-i", "/data/{{ if $multiSrc }}source{{ add 1 (mod 23 (add 1 (mod $parallelism (add $job 1)))) }}.mp4{{ else }}{{ $src }}{{ end }}",
          "-stats",
          "-c:v",
          "libx264",
          "-s", "1920x1080",
          "-crf", "22",
          "-profile:v", "main",
          "-pix_fmt", "yuv420p",
          "-threads", "0",
          "-f", "mp4",
          "-ac", "2",
          "-c:a", "aac",
          "-b:a", "128k",
          "-strict", "-2",
          "/data/output-{{ $job }}.mp4"
        ]
        volumeMounts:
          - mountPath: /data
            name: hostpath
        resources:
          requests: 
{{ toYaml $requests | indent 12 }}
          limits:
            cpu: {{ if $burst }}{{ max (mul 2 (atoi $cpu)) (atoi $maxCpu) | quote }}{{ else }}{{ $cpu }}{{ end }}
            memory: {{ $memory }}
      restartPolicy: Never
      volumes:
        - name: hostpath
          hostPath:
            path: /mnt
---
{{- end }}

``` 

The values.yaml file that goes with this is very very simple: 

```
# Number of // tasks
parallelism: 8
# Separator name
type: bm
# Do we want several input files
# if yes, the chart will use source${i}.mp4 with up to 24 sources
multiSource: false
# If not multi source, name of the default file
defaultSource: sintel_trailer-1080p.mp4
# Do we want to burst. If yes, resource limit will double request. 
burst: false
resources:
  requests:
    cpu: "4"
    memory: 8Gi
```

That's all you need. 

Of course, all sources are in the repo for your usage, you don't have to copy paste this. 

## Creating test files

Now we need to generate a LOT of values.yaml files to cover many use cases. The reachable values would vary depending on your context. My home cluster has 6 workers with 4 cores and 32GB RAM each, so I used 

* 1, 6, 12, 18, 24, 48, 96 and 192 concurrent jobs (up to 32/worker)
* reverse that for the CPUs (from 3 to 0.1 in case of parallelism=192)
* 1 to 16GB RAM

Didn't do anything clever here, just a few bash loops: 

```
mkdir -p values
cat > values/values.tmpl << EOF
# Total number of jobs we run
parallelism: PARALLELISM
# To separate context: aws, bare metal, lxd...
type: TYPE
# strict allocation of resources
resources:
  requests:
    cpu: "CPU"
    memory: MEMORYGi
  limits:
    cpu: "CPU"
    memory: MEMORYGi

EOF

for type in aws bm lxd; do 
	for cpu in 0.1 0.2 0.4 0.8 1 2 3 4 5 6 7; do 
		for memory in 0.8 1 2 4 8; do 
			for para in 1 2 3 4 6 8 12 16 24 48 96 192; do 
				sed -e s#TYPE#${type}#g \
          -e s#CPU#${cpu}#g \
          -e s#MEMORY#${memory}#g \
          -e s#PARALLELISM#${para}#g \
        values/values.tmpl \
        > values/values-${para}-${type}-${cpu}-${memory}.yaml
			done
		done
	done
done
```

OK, now we can move to the next step, which is deploying Kubernetes. 