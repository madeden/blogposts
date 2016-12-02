# Introduction

I was lucky enough to be loaned a couple of Firestones servers  along with a third server without GPUs, all in the same LAN.

Firestone are pretty brutal machines. They use 2x Power8 (ppc64) processors, each packing 10 cores. When Intel x86 has 2 threads per core, Power8 has 8 via SMT-8. When you do "top" on these machines, you see 2x10x8 = 160 cores!  
In addition, Firestone machines have 2x nVidia K80 for GPU workloads. 

For those seeking even more performance, the new iteration of Firestone is [Minsky](http://www.tomshardware.com/news/ibm-power8-nvidia-tesla-p100-minsky,32661.html). 

Minsky is the answer to nVidia DGX-1 in the world of ppc64 architecture. It has also 2 CPU sockets, but this time with the Power8+ architecture. That hads support for nVLink, a new communication protocol from nVidia accelerating data transfer between CPU and GPUs. This allows to embark 4 nVidia Tesla P100! This is to date the most powerful machine you can buy (unless you are into mainframes), which is probably why it's dubbed "for High Performance Computing". 

I was lucky enough to be loaned a couple of  from IBM, along with a third server without GPUs, all in the same LAN. 

For the record, Minsky is the answer to nVidia DGX-1 in the world of ppc64 architecture. It offers a mind blowing 160 CPU cores spread over 2 Power8 sockets, and 4 nVidia P100. This is to date the most powerful machine you can buy (unless you are into mainframes)

All 3 machines were pre installed with [Ubuntu 14.04](https://www.ubuntu.com/download/server/power8). As you may know, there is a great deal of effort at Ubuntu put into making sure the UX on ppc64 is the same as on any x86 box. It means, among other things, that the main packages are all built on ppc64. 

Finally, while this was temporarily stopped after the 1.4 release, there were binaries of Kubernetes available for ppc64 at some point in the past. The latest that we had was 1.3.8 at the time of this experiment. 

So what could we do with 3 nodes, 2 of them having GPUs in there? Same we did with our mini cluster! Install Kubernetes, and see if and how we could leverage GPUs in workloads. 




