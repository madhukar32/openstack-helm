#!/bin/bash

set -x
for CHART_DIR in ceph dns-helper etcd ingress ldap mariadb memcached rabbitmq keystone glance libvirt nova neutron; do
  if [ -e ${CHART_DIR}/values.yaml ]; then
    for IMAGE in $(cat ${CHART_DIR}/values.yaml | yq '.images.tags | map(.) | join(" ")' | tr -d '"'); do
      sudo docker inspect $IMAGE >/dev/null|| sudo docker pull $IMAGE
    done
  fi
done
