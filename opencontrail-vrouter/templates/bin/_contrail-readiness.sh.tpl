#!/bin/bash

contrail_services=(contrail-vrouter-agent)

for service in "${contrail_services[@]}"
do
    echo "Check contrail $service status"
    contrail_status=$(contrail-status | grep $service | grep  ' active' | wc -l)
    loop_counter=0
    while [ $contrail_status -eq 0 -a $loop_counter -lt 60 ]
    do
        service_status=$(contrail-status | grep $service | awk {'print $2'})
        let loop_counter=loop_counter+1
        echo "waiting for $service to be active !!!!"
        sleep 1
    	contrail_status=$(contrail-status | grep $service | grep  ' active' | wc -l)
    done
    echo "$service is active"
done
