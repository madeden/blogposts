#!/bin/bash



if [ -z ${PURPOSE+x} || -z ${SERVICE_NAME+x} || -z ${ALT_NAMES+x} ]; then 
	echo "You need to set PURPOSE, SERVICE_NAME and ALT_NAMES first"
	echo "PURPOSE can be serving/server, client, or requestheader-client"
	echo "SERVICE_NAME is the name of the service you want to deploy"
	echo "ALT_NAMES are the alt names of the service. Set it to \"SERVICE_NAME.namespace\",\"SERVICE_NAME.namespace.svc\""
	exit 1
else
	echo "var is set to '$var'"; fi
fi



openssl req -x509 -sha256 -new -nodes -days 365 -newkey rsa:2048 -keyout ${PURPOSE}-ca.key -out ${PURPOSE}-ca.crt -subj "/CN=ca"
echo '{"signing":{"default":{"expiry":"43800h","usages":["signing","key encipherment","'${PURPOSE}'"]}}}' > "${PURPOSE}-ca-config.json"

# Service Name is the name of your specific server
export ALT_NAMES='"<service>.<namespace>","<service>.<namespace>.svc"'
echo '{"CN":"'${SERVICE_NAME}'","hosts":['${ALT_NAMES}'],"key":{"algo":"rsa","size":2048}}' | cfssl gencert -ca=${PURPOSE}-ca.crt -ca-key=${PURPOSE}-ca.key -config=${PURPOSE}-ca-config.json - | cfssljson -bare apiserver



