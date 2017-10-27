#!/bin/bash

set -ex

function register-vrouter {

	/usr/share/contrail-utils/provision_vrouter.py \
	  --api_server_ip {{ .Values.conf.global_config.GLOBAL.controller_ip }} \
	  --host_name $HOST_NAME \
	  --host_ip $HOST_IP \
	  --admin_user {{ .Values.conf.keystone_config.KEYSTONE.admin_user }} \
	  --admin_password {{ .Values.conf.keystone_config.KEYSTONE.admin_password }} \
	  --admin_tenant_name {{ .Values.conf.keystone_config.KEYSTONE.admin_tenant }} \
          --openstack_ip keystone-api.{{ .Release.Namespace }} \
	   || echo "Contrail api server is not up" && return 1

	return ""
}

while ! [[ -z $(register-vrouter) ]];do
	echo "Waiting for contrail api server to come up"
        sleep 1s
done

