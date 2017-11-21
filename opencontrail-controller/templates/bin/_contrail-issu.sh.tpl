#!/bin/bash

{{- $suffix_obj_name := "" }}
{{- if .Values.conf.suffix_obj_name }}
{{- $suffix_obj_name := .Values.conf.suffix_obj_name }}
{{- end }}

set -x

old_controller_pod_list=()
new_controller_pod_list=()
vrouter_pod_list=()

old_controller_ip_list=()
new_controller_ip_list=()
vrouter_ip_list=()

new_conf='/tmp/new-api.conf'
old_conf='/tmp/old-api.conf'
final_conf='/tmp/contrail-issu.conf'

conf_file='/etc/contrail/contrail-api.conf'
controller_file='/tmp/controller.conf'

vrouter_agent='/etc/contrail/contrail-vrouter-agent.conf'
vrouter_nodemgr='/etc/contrail/contrail-vrouter-nodemgr.conf'

api_node_user_name=''
api_node_password=''

function get_old_controller_pod_list {

	old_controller_pod_list=($(kubectl get pods -n {{ .Release.Namespace }} | grep $1 | awk {'print $1'}))
	old_controller_ip_list=($(kubectl get pods -n {{ .Release.Namespace }} -o wide | grep $1 | awk {'print $6'}))
    echo ${old_controller_pod_list[*]}
    echo ${old_controller_ip_list[*]}

}

function get_new_controller_pod_list {

    new_controller_pod_list=($(kubectl get pods -n {{ .Release.Namespace }} | grep $1 | awk {'print $1'}))
    new_controller_ip_list=($(kubectl get pods -n {{ .Release.Namespace }} -o wide | grep $1 | awk {'print $6'}))
    echo ${new_controller_pod_list[*]}
    echo ${new_controller_ip_list[*]}

}

function get_vrouter_pod_list {

    vrouter_pod_list=($(kubectl get pods -n {{ .Release.Namespace }} | grep $1 | awk {'print $1'}))
    vrouter_ip_list=($(kubectl get pods -n {{ .Release.Namespace }} -o wide | grep $1 | awk {'print $6'}))
    echo ${vrouter_pod_list[*]}
    echo ${vrouter_ip_list[*]}

}

function update-vrouter {

    get_new_controller_pod_list 'contrail-controller{{ .Values.conf.suffix_obj_name | default "" }}-'
    get_vrouter_pod_list 'contrail-vrouter-agent'

    for vrouter_pod in "${vrouter_pod_list[@]}"; do
        echo $vrouter_pod
        set_vrouter_agent_conf  $vrouter_agent $vrouter_pod
        set_vrouter_nodemgr_conf $vrouter_nodemgr $vrouter_pod
        kubectl exec -i $vrouter_pod -n {{ .Release.Namespace }} -- service contrail-vrouter-agent restart
        kubectl exec -i $vrouter_pod -n {{ .Release.Namespace }} -- service contrail-vrouter-nodemgr restart

    done

}

function get_pod_name {
    pod_prefix=$1
    pod_ip=$2

    echo $(kubectl get pods -n {{ .Release.Namespace }} -o wide | grep $pod_prefix | grep $pod_ip | awk {'print $1'})

}

function get_ip_port_list {
    local conval=""
    local ip_array=("${!1}")

    for i in "${ip_array[@]}"; do
        if [ "$conval" == "" ]
        then
           conval="$i:$2"
        else
           conval="$conval $i:$2"
        fi
    done
    echo $conval
}

function set_vrouter_agent_conf {
    local set_cmd="kubectl exec -i $2 -n {{ .Release.Namespace }} -- crudini --set $1"

    control_nodes=$(get_ip_port_list new_controller_ip_list[@] 5269)
    $set_cmd CONTROL-NODE servers $control_nodes

    collectors=$(get_ip_port_list new_controller_ip_list[@] 8086)
    $set_cmd DEFAULT collectors $collectors

    dns_servers=$(get_ip_port_list new_controller_ip_list[@] 53)
    $set_cmd DNS servers $dns_servers

}

function set_vrouter_nodemgr_conf {
    local set_cmd="kubectl exec -i $2 -n {{ .Release.Namespace }} -- crudini --set $1"

    collectors=$(get_ip_port_list new_controller_ip_list[@] 8086)
    $set_cmd COLLECTOR server_list $collectors
}

function generate_api_host_conf {
    local get_cmd="crudini --get  $1  GLOBAL"
    local set_cmd="crudini --set $2 DEFAULTS"
    local conval=""

    cmd="$get_cmd config_nodes"
    val=$($cmd)
    if [[ $val ]]
    then

        val=$(sed s"/[\[' ]//g" <<<$val)
        val=$(sed s'/]//g'<<<$val)
        echo $val
        for i in ${val//,/ }; do
            echo $i;
            if [ "$conval" == "" ]
            then
               conval="'$i':['$api_node_user_name','$api_node_password']"
            else
               conval=$conval,"'$i':['$api_node_user_name','$api_node_password']"
            fi
         done
    fi
    $set_cmd new_api_info "{$conval}"
}

function generate-conf {

    local set_cmd="crudini --set $final_conf DEFAULTS"

    rm -f $final_conf
    touch $final_conf

    api_node_user_name=$1
    api_node_password=$2

    $set_cmd api_node_user_name $api_node_user_name
    $set_cmd api_node_password $api_node_password

    get_new_controller_pod_list 'contrail-controller{{ .Values.conf.suffix_obj_name | default "" }}-'

    get_old_controller_pod_list 'contrail-controller-'

    $set_cmd v1_api_server_ip ${old_controller_ip_list[0]}

    kubectl exec -i ${new_controller_pod_list[0]} -n {{ .Release.Namespace }} \
        -- cat /etc/contrailctl/controller.conf >  $controller_file

    kubectl exec -i ${new_controller_pod_list[0]} -n {{ .Release.Namespace }} \
        -- /tmp/controller-readiness.sh

    kubectl cp {{ .Release.Namespace }}/${new_controller_pod_list[0]}:/etc/contrail/contrail-api.conf $new_conf

    kubectl cp {{ .Release.Namespace }}/${old_controller_pod_list[0]}:/etc/contrail/contrail-api.conf $old_conf

    issu_contrail_generate_conf $old_conf $new_conf
    generate_api_host_conf $controller_file $final_conf
    generate_more_conf $controller_file $final_conf
    generate_keystone_params $controller_file $final_conf

    kubectl cp $final_conf {{ .Release.Namespace }}/${new_controller_pod_list[0]}:/etc/contrailctl/contrail-issu.conf
    kubectl exec -i ${new_controller_pod_list[0]} -n {{ .Release.Namespace }} \
        -- contrailctl config sync -c contrailissu --tags="set_conf" -F
}


function generate_keystone_params {
    local get_cmd="crudini --get  $1  KEYSTONE"
    local set_cmd="crudini --set $2 DEFAULTS"

    #Since the below values are not available in controller.conf
    #taking the default values for now.
    $set_cmd admin_user "admin"
    $set_cmd admin_tenant_name "admin"

    cmd="$get_cmd ip"
    val=$($cmd)
    $set_cmd openstack_ip "$val"

    cmd="$get_cmd admin_password"
    val=$($cmd)
    $set_cmd admin_password "$val"
}



function issu_contrail_generate_conf {
    issu_contrail_get_and_set_old_conf $1 $final_conf
    issu_contrail_get_and_set_new_conf $2 $final_conf
    echo $1 $2
}

function issu_contrail_get_and_set_old_conf {
    local get_cmd="crudini --get  $1  DEFAULTS"
    local set_cmd="crudini --set $2 DEFAULTS"

    cmd="$get_cmd cassandra_server_list"
    val=$($cmd)
    $set_cmd   old_cassandra_address_list "$val"

    cmd="$get_cmd zk_server_ip"
    val=$($cmd)
    $set_cmd old_zookeeper_address_list "$val"

    cmd="$get_cmd rabbit_user"
    val=$($cmd)
    if [[ $val ]]
    then
        $set_cmd old_rabbit_user "$val"
    fi

    cmd="$get_cmd rabbit_password"
    val=$($cmd)
    if [[ $val ]]
    then
        $set_cmd old_rabbit_password "$val"
    fi

    cmd="$get_cmd rabbit_vhost"
    val=$($cmd)
    if [[ $val ]]
    then
        $set_cmd old_rabbit_vhost "$val"
    fi

    cmd="$get_cmd rabbit_ha_mode"
    val=$($cmd)
    if [[ $val ]]
    then
        $set_cmd old_rabbit_ha_mode "$val"
    fi

    cmd="$get_cmd rabbit_port"
    val=$($cmd)
    if [[ $val ]]
    then
        $set_cmd old_rabbit_port "$val"
    fi

    cmd="$get_cmd rabbit_server"
    val=$($cmd)
    if [[ $val ]]
    then
        $set_cmd old_rabbit_address_list "$val"
    fi

    cmd="$get_cmd cluster_id"
    val=$($cmd)
    if [[ $val ]]
    then
        $set_cmd odb_prefix "$val"
    fi


}

function issu_contrail_get_and_set_new_conf {
    local get_new_cmd="crudini --get $1 DEFAULTS"
    local set_cmd="crudini --set $2 DEFAULTS"

    cmd="$get_new_cmd cassandra_server_list"
    val=$($cmd)
    $set_cmd new_cassandra_address_list "$val"

    cmd="$get_new_cmd zk_server_ip"
    val=$($cmd)
    $set_cmd new_zookeeper_address_list "$val"

    cmd="$get_new_cmd rabbit_user"
    val=$($cmd)
    if [[ $val ]]
    then
        $set_cmd new_rabbit_user "$val"
    fi

    cmd="$get_new_cmd rabbit_password"
    val=$($cmd)
    if [[ $val ]]
    then
        $set_cmd new_rabbit_password "$val"
    fi

    cmd="$get_new_cmd rabbit_vhost"
    val=$($cmd)
    if [[ $val ]]
    then
        $set_cmd new_rabbit_vhost "$val"
    fi

    cmd="$get_new_cmd rabbit_ha_mode"
    val=$($cmd)
    if [[ $val ]]
    then
        $set_cmd new_rabbit_ha_mode "$val"
    fi

    cmd="$get_new_cmd rabbit_port"
    val=$($cmd)
    if [[ $val ]]
    then
        $set_cmd new_rabbit_port "$val"
    fi

    cmd="$get_new_cmd rabbit_server"
    val=$($cmd)
    if [[ $val ]]
    then
        $set_cmd new_rabbit_address_list "$val"
    fi

    cmd="$get_new_cmd cluster_id"
    val=$($cmd)
    if [[ $val ]]
    then
        $set_cmd ndb_prefix "$val"
    fi
}

function convert_format {
    conval=""
    val=$(sed s"/[\[' ]//g" <<<$val)
    val=$(sed s'/]//g'<<<$val)
    echo $val
    for i in ${val//,/ }; do
        echo $i;
        pod_name=$(get_pod_name 'contrail-controller{{ .Values.conf.suffix_obj_name | default "" }}' $i)
        myhost_name="$(echo -e $(kubectl exec -i $pod_name -n {{ .Release.Namespace }} -- hostname) | tr -d '[:space:]' )"
        if [ "$conval" == "" ]
        then
           conval="'$i':'$myhost_name'"
        else
           conval=$conval,"'$i':'$myhost_name'"
        fi
     done
     #echo {$conval}
}

function generate_more_conf {
    local get_cmd="crudini --get  $1  GLOBAL"
    local set_cmd="crudini --set $2 DEFAULTS"
    local newval=""

    cmd="$get_cmd analyticsdb_nodes"
    val=$($cmd)
    if [[ $val ]]
    then
        convert_format $val
    fi
    $set_cmd db_host_info "{$conval}"

    cmd="$get_cmd config_nodes"
    val=$($cmd)
    if [[ $val ]]
    then
        convert_format $val
    fi
    $set_cmd config_host_info "{$conval}"

    cmd="$get_cmd analytics_nodes"
    val=$($cmd)
    if [[ $val ]]
    then
        convert_format $val
    fi
    $set_cmd analytics_host_info "{$conval}"

    cmd="$get_cmd controller_nodes"
    val=$($cmd)
    if [[ $val ]]
    then
        convert_format $val
    fi
    $set_cmd control_host_info "{$conval}"
}

function migrate-config {

    get_new_controller_pod_list 'contrail-controller{{ .Values.conf.suffix_obj_name | default "" }}'

    kubectl exec -i ${new_controller_pod_list[0]} -n {{ .Release.Namespace }} \
        -- contrailctl config sync -c contrailissu --tags="peer_control_nodes" -F

    echo "sleep for 10s"
    sleep 10

    for new_controller in "${new_controller_pod_list[@]}"; do


       kubectl exec -i $new_controller -n {{ .Release.Namespace }} \
           -- contrailctl config sync -c contrailissu --tags="prepare" -F

       echo "sleep for 10s"
       sleep 10

    done

    kubectl exec -i ${new_controller_pod_list[0]} -n {{ .Release.Namespace }} \
        -- contrailctl config sync -c contrailissu --tags="migrate_config" -F

    echo "sleep for 180s"
    sleep 180

    kubectl exec -i ${new_controller_pod_list[0]} -n {{ .Release.Namespace }} \
        -- service contrail-control restart
}

function finalize-config {

    get_new_controller_pod_list 'contrail-controller{{ .Values.conf.suffix_obj_name | default "" }}'

    kubectl exec -i ${new_controller_pod_list[0]} -n {{ .Release.Namespace }} \
        -- contrailctl config sync -c contrailissu --tags="finalize" -F

    sleep 60

    for new_controller in "${new_controller_pod_list[@]}"; do

       kubectl exec -i ${new_controller_pod_list[0]} -n {{ .Release.Namespace }} \
           -- contrailctl config sync -c contrailissu --tags="post" -F


    done

}

ARGC=$#

echo -e "Num of args $ARGC"
if [ $ARGC == 0 ]
then
    echo "Usage: $0 <function> <optional arguments>"
    echo "functions: generate-conf, migrate-config, finalize-config, update-router"
    exit;
fi

case $1 in
    myfunc)
      if [ $ARGC == 2 ]
      then
        $1 $2
        exit
      fi
      echo "Usage: $0 $1 <arguments>"
      ;;
    generate-conf)
      if [ $ARGC == 3 ]
      then
        $1 $2 $3
        exit
      fi
      echo "Usage: $0 <generate-conf> <new-node-username> <new-node-password>"
      ;;

    migrate-config)
      if [ $ARGC == 1 ]
      then
        $1
        exit
      fi
      echo "Usage: $0 <migrate-config>"
      ;;

    finalize-config)
      if [ $ARGC == 1 ]
      then
        $1
        exit
      fi
      echo "Usage: $0 <finalize-config>"
      ;;

    update-vrouter)
      if [ $ARGC == 1 ]
      then
        $1
        exit
      fi
      echo "Usage: $0 <update-vrouter>"
      ;;

esac
