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

: ${KS_USER:="admin"}
: ${KS_PROJECT:="admin"}
: ${KS_PASSWORD:="password"}
: ${KS_USER_DOMAIN:="default"}
: ${KS_PROJECT_DOMAIN:="default"}
: ${KS_URL:="http://keystone.openstack/v3"}

# Setup openstack clients
KEYSTONE_CREDS="--os-username ${KS_USER} \
  --os-project-name ${KS_PROJECT} \
  --os-auth-url ${KS_URL} \
  --os-project-domain-name ${KS_PROJECT_DOMAIN} \
  --os-user-domain-name ${KS_USER_DOMAIN} \
  --os-password ${KS_PASSWORD}"

HEAT_POD=$(kubectl get -n openstack pods -l application=heat,component=engine --no-headers -o name | awk -F '/' '{ print $NF; exit }')
HEAT="kubectl exec -n openstack ${HEAT_POD} -- heat ${KEYSTONE_CREDS}"
NEUTRON_POD=$(kubectl get -n openstack pods -l application=heat,component=engine --no-headers -o name | awk -F '/' '{ print $NF; exit }')
NEUTRON="kubectl exec -n openstack ${NEUTRON_POD} -- neutron ${KEYSTONE_CREDS}"
NOVA_POD=$(kubectl get -n openstack pods -l application=heat,component=engine --no-headers -o name | awk -F '/' '{ print $NF; exit }')
NOVA="kubectl exec -n openstack ${NOVA_POD} -- nova ${KEYSTONE_CREDS}"
OPENSTACK_POD=$(kubectl get -n openstack pods -l application=heat,component=engine --no-headers -o name | awk -F '/' '{ print $NF; exit }')
OPENSTACK="kubectl exec -n openstack ${OPENSTACK_POD} -- openstack ${KEYSTONE_CREDS} --os-identity-api-version 3 --os-image-api-version 2"

function wait_for_ping {
  # Default wait timeout is 180 seconds
  set +x
  PING_CMD="ping -q -c 1 -W 1"
  end=$(date +%s)
  if ! [ -z $2 ]; then
   end=$((end + $2))
  else
   end=$((end + 180))
  fi
  while true; do
      $PING_CMD $1 > /dev/null && \
          break || true
      sleep 1
      now=$(date +%s)
      [ $now -gt $end ] && echo "Could not ping $1 in time" && exit -1
  done
  set -x
  $PING_CMD $1
}

function openstack_wait_for_vm {
  # Default wait timeout is 180 seconds
  set +x
  end=$(date +%s)
  if ! [ -z $2 ]; then
   end=$((end + $2))
  else
   end=$((end + 180))
  fi
  while true; do
      STATUS=$($OPENSTACK server show $1 -f value -c status)
      [ $STATUS == "ACTIVE" ] && \
          break || true
      sleep 1
      now=$(date +%s)
      [ $now -gt $end ] && echo VM failed to start. && \
          $OPENSTACK server show $1 && exit -1
  done
  set -x
}

function wait_for_ssh_port {
  # Default wait timeout is 180 seconds
  set +x
  end=$(date +%s)
  if ! [ -z $2 ]; then
   end=$((end + $2))
  else
   end=$((end + 180))
  fi
  while true; do
      # Use Nmap as its the same on Ubuntu and RHEL family distros
      nmap -Pn -p22 $1 | awk '$1 ~ /22/ {print $2}' | grep -q 'open' && \
          break || true
      sleep 1
      now=$(date +%s)
      [ $now -gt $end ] && echo "Could not connect to $1 port 22 in time" && exit -1
  done
  set -x
}

function openstack_wait_for_stack {
  # Default wait timeout is 180 seconds
  set +x
  end=$(date +%s)
  if ! [ -z $2 ]; then
   end=$((end + $2))
  else
   end=$((end + 180))
  fi
  while true; do
      STATUS=$($OPENSTACK stack show $1 -f value -c stack_status)
      [ $STATUS == "CREATE_COMPLETE" ] && \
          break || true
      sleep 1
      now=$(date +%s)
      [ $now -gt $end ] && echo Stack failed to start. && \
          $OPENSTACK stack show $1 && exit -1
  done
  set -x
}

function openstack_wait_for_volume {
  # Default wait timeout is 180 seconds
  set +x
  end=$(date +%s)
  if ! [ -z $3 ]; then
   end=$((end + $3))
  else
   end=$((end + 180))
  fi
  while true; do
      STATUS=$($OPENSTACK volume show $1 -f value -c status)
      [ $STATUS == "$2" ] && \
          break || true
      sleep 1
      now=$(date +%s)
      [ $now -gt $end ] && echo "Volume did not become $2 in time." && \
          $OPENSTACK volume show $1 && exit -1
  done
  set -x
}

function check_vm {
  local floating_ip=$1
  local keypair_loc="$2"

  route -n

  # Ping our VM
  wait_for_ping ${floating_ip} ${SERVICE_TEST_TIMEOUT}

  # Wait for SSH to come up
  wait_for_ssh_port ${floating_ip} ${SERVICE_TEST_TIMEOUT}

  # SSH into the VM and check it can reach the outside world
  ssh-keyscan "$floating_ip" >> ~/.ssh/known_hosts
  ssh -i ${keypair_loc} cirros@${floating_ip} ping -q -c 1 -W 2 ${OSH_BR_EX_ADDR%/*}

  # SSH into the VM and check it can reach the metadata server
  ssh -i ${keypair_loc} cirros@${floating_ip} curl -sSL 169.254.169.254

  # Bonus round - display a Unicorn
  ssh -i ${keypair_loc} cirros@${floating_ip} curl http://artscene.textfiles.com/asciiart/unicorn || true
}
