#!/bin/bash

kubectl create clusterrolebinding super-admin-binding \
   --clusterrole=cluster-admin \
   --user=$(gcloud info --format json | jq -r '.config.account')

