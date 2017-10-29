#!/bin/bash
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
set -xe
: ${WORK_DIR:="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/.."}
source ${WORK_DIR}/tools/gate/vars.sh
source ${WORK_DIR}/tools/gate/funcs/network.sh
source ${WORK_DIR}/tools/gate/funcs/openstack.sh

# Turn on ip forwarding if its not already
if [ $(cat /proc/sys/net/ipv4/ip_forward) -eq 0 ]; then
  sudo bash -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
fi

if [ "x$SDN_PLUGIN" != "xopencontrail" ]; then
  # Assign IP address to br-ex
  sudo ip addr add ${OSH_BR_EX_ADDR} dev br-ex
  sudo ip link set br-ex up
  # Setup masquerading on default route dev to public subnet
  sudo iptables -t nat -A POSTROUTING -o $(net_default_iface) -s ${OSH_EXT_SUBNET} -j MASQUERADE
elif [ "x$SDN_PLUGIN" == "xopencontrail" ]; then
  # Using Simple Gateway feature for OpenContrail
  CONTRAIL_AGENT_POD=$(kubectl get -n openstack pods -l application=opencontrail --no-headers -o name | grep vrouter-agent | head -1 | cut -d '/' -f 2)
  kubectl exec -n openstack ${CONTRAIL_AGENT_POD} -- /opt/contrail/utils/provision_vgw_interface.py --oper create --interface vgw --subnets ${OSH_EXT_SUBNET} --routes 0.0.0.0/0 --vrf default-domain:admin:${OSH_EXT_NET_NAME}:${OSH_EXT_SUBNET_NAME}
fi

if [ "x$SDN_PLUGIN" == "xovs" ]; then
  # Disable In-Band rules on br-ex bridge to ease debugging
  OVS_VSWITCHD_POD=$(kubectl get -n openstack pods -l application=openvswitch,component=openvswitch-vswitchd --no-headers -o name | head -1 | awk -F '/' '{ print $NF }')
  kubectl exec -n openstack ${OVS_VSWITCHD_POD} -- ovs-vsctl set Bridge br-ex other_config:disable-in-band=true
fi


if ! $OPENSTACK service list -f value -c Type | grep -q orchestration; then
  net_params=""
  if [ "x$SDN_PLUGIN" != "xopencontrail" ]; then
    # This paramter is used to create SRIOV network in OpenContrail. Use it only for other SND-s
    net_params="--provider:physical_network=public"
  fi
  echo "No orchestration service active: creating public network via CLI"
  $NEUTRON net-create ${OSH_EXT_NET_NAME} -- --is-default \
    --router:external \
    --provider:network_type=flat \
    ${net_params}
  $NEUTRON subnet-create \
    --name ${OSH_EXT_SUBNET_NAME} \
    --ip-version 4 \
    $($NEUTRON net-show ${OSH_EXT_NET_NAME} -f value -c id) ${OSH_EXT_SUBNET} -- \
        --enable_dhcp=False

  if [ "x$SDN_PLUGIN" != "xopencontrail" ]; then
    # Subnet pools are not supported in Contrail
    # Create default subnet pool
    $NEUTRON subnetpool-create \
      ${OSH_PRIVATE_SUBNET_POOL_NAME} \
      --default-prefixlen ${OSH_PRIVATE_SUBNET_POOL_DEF_PREFIX} \
      --pool-prefix ${OSH_PRIVATE_SUBNET_POOL} \
      --shared \
      --is-default=True
  fi
else
  echo "Orchestration service active: creating public network via Heat"
  if [ "x$SDN_PLUGIN" != "xopencontrail" ]; then
    # This paramter is used to create SRIOV network in OpenContrail. Use it only for other SND-s
    net_params="--parameter physical_network_name=public"
    tpl="${WORK_DIR}/tools/gate/files/${OSH_PUB_NET_STACK}.yaml"
  else
    net_params=""
    tpl="${WORK_DIR}/tools/gate/files/${OSH_PUB_NET_STACK}-${SDN_PLUGIN}.yaml"
  fi
  HEAT_TEMPLATE=$(cat ${tpl} | base64 -w 0)
  kubectl exec -n openstack ${OPENSTACK_POD} -- bash -c "echo $HEAT_TEMPLATE | base64 -d > /tmp/${OSH_PUB_NET_STACK}.yaml"
  $OPENSTACK stack create \
    --parameter network_name=${OSH_EXT_NET_NAME} \
    ${net_params} \
    --parameter subnet_name=${OSH_EXT_SUBNET_NAME} \
    --parameter subnet_cidr=${OSH_EXT_SUBNET} \
    --parameter subnet_gateway=${OSH_BR_EX_ADDR%/*} \
    -t /tmp/${OSH_PUB_NET_STACK}.yaml \
    ${OSH_PUB_NET_STACK}
  openstack_wait_for_stack ${OSH_PUB_NET_STACK}

  if [ "x$SDN_PLUGIN" != "xopencontrail" ]; then
    # Subnet pools are not supported in Contrail
    HEAT_TEMPLATE=$(cat ${WORK_DIR}/tools/gate/files/${OSH_SUBNET_POOL_STACK}.yaml | base64 -w 0)
    kubectl exec -n openstack ${OPENSTACK_POD} -- bash -c "echo $HEAT_TEMPLATE | base64 -d > /tmp/${OSH_SUBNET_POOL_STACK}.yaml"
    $OPENSTACK stack create \
      --parameter subnet_pool_name=${OSH_PRIVATE_SUBNET_POOL_NAME} \
      --parameter subnet_pool_prefixes=${OSH_PRIVATE_SUBNET_POOL} \
      --parameter subnet_pool_default_prefix_length=${OSH_PRIVATE_SUBNET_POOL_DEF_PREFIX} \
      -t /tmp/${OSH_SUBNET_POOL_STACK}.yaml \
      ${OSH_SUBNET_POOL_STACK}
    openstack_wait_for_stack ${OSH_SUBNET_POOL_STACK}
  fi
fi
