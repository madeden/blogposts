#!/bin/bash 

kubectl create clusterrolebinding super-admin-binding \
   --clusterrole=cluster-admin \
   --user=admin

