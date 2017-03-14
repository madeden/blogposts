# Fission
## Introduciton

Fission is the latest addition to the club of "Serverless on Kubernetes". And it makes a remarkable entrance. When looking at Serverless, one of the critical aspects of spawning resources is the ability to run them fast. This is what Fission focuses on. By maintaining a pool of pods up & running to execute tasks immediately, it provides very very fast cold start times. 

Fission's architecture is as follows:

INCLUDE IMAGE

The controller relies on etcd to back its state, as well as a volume to store the functions' code. All other components are stateless. 