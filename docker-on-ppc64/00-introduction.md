# Introduction

Using Docker containers on other platforms than x86_64 has been floating in the air for quite some time now. There is work being done around [manifest list](https://docs.docker.com/registry/spec/manifest-v2-2/#manifest-list), which landed in Docker 1.10 earlier this year. IBM released a [tool](https://integratedcode.us/2016/04/22/a-step-towards-multi-platform-docker-images/) to create manifest lists using simple yaml. 

Hence we are at a stage where multi arch images can be represented by a single entry in the registry, and the docker client supposedly can then manage the architecture automagically. 

Images still have to be built on each architecture separately. Here we will focus on a specific set of images that are very important for people working with Deep Learning: [nvidia-docker](https://github.com/NVIDIA/nvidia-docker/tree/master)!

As the time of this writing, there is a ppc64le branch, but it is only to build the nvidia-docker wrapper tool, and there is limited support for Power8 CPUs as far as docker images go. Let's fix this. 

