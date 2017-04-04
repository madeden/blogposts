# Adding ELB support in Kubernetes

In order for Kubernetes to create ELB resources, you need to 

* Update the Master and add the Cloud Provider to API Server and Controller Manager
* Update the Workers and add the Cloud Provider to Kubelet

## Master Update

Update **/etc/default/kube-apiserver** and**/etc/default/kube-controller-manager** to add the --cloud-provider tag: 

<pre><code>
juju show-status kubernetes-master --format json | \
  jq -r '.applications."kubernetes-master".units | keys[]' | \
  xargs -I UNIT juju ssh UNIT "sudo sed -i 's/KUBE_CONTROLLER_MANAGER_ARGS=\"/KUBE_CONTROLLER_MANAGER_ARGS=\"--cloud-provider=aws\ /' /etc/default/kube-controller-manager && sudo systemctl restart kube-controller-manager.service"

juju show-status kubernetes-master --format json | \
  jq -r '.applications."kubernetes-master".units | keys[]' | \
  xargs -I UNIT juju ssh UNIT "sudo sed -i 's/KUBE_API_ARGS=\"/KUBE_API_ARGS=\"--cloud-provider=aws\ /' /etc/default/kube-apiserver && sudo systemctl restart kube-apiserver.service"
</code></pre>

## Worker nodes

On every worker, **/etc/default/kubelet** to to add the cloud-provider tag:

<pre><code>
juju show-status kubernetes-worker --format json | \
  jq -r '.applications."kubernetes-worker".units | keys[]' | \
  xargs -I UNIT juju ssh UNIT "sudo sed -i 's/KUBELET_ARGS=\"/KUBELET_ARGS=\"--cloud-provider=aws\ /' /etc/default/kubelet && sudo systemctl restart kubelet.service"
</code></pre>

## A few notes

It's important to understand that Kubernetes loads the environment when the API server and the Controller Manager start. If you make any change later on at the AWS level, you will need to restart them again. 

This is why we are doing the changes in the cluster at the end. 