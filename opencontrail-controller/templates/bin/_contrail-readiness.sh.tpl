#!/bin/bash

{{- $readiness_context := .Values.readiness_context }}

set -x

{{- if eq $readiness_context "controller" }}
{{- $check_readiness_of_svcs := .Values.contrail.readiness_check_svcs.controller | join " " }}
contrail_services=({{ $check_readiness_of_svcs }})
{{- else if eq $readiness_context "analytics" }}
{{- $check_readiness_of_svcs := .Values.contrail.readiness_check_svcs.analytics | join " " }}
contrail_services=({{ $check_readiness_of_svcs }})
{{- else if eq $readiness_context "analyticsdb" }}
{{- $check_readiness_of_svcs := .Values.contrail.readiness_check_svcs.analyticsdb | join " " }}
contrail_services=({{ $check_readiness_of_svcs }})
{{- else if eq $readiness_context "kubemanager" }}
{{- $check_readiness_of_svcs := .Values.contrail.readiness_check_svcs.kubemanager | join " " }}
contrail_services=({{ $check_readiness_of_svcs }})
{{- end }}



for service in "${contrail_services[@]}"
do
    echo "Checking contrail $service status"
    contrail_status=$(contrail-status | grep $service | grep  ' active' | wc -l)
    loop_counter=0
    while [ $contrail_status -eq 0 -a $loop_counter -lt 60 ]
    do
        service_status=$(contrail-status | grep $service | awk {'print $2'})
        let loop_counter=loop_counter+1
        echo "waiting for $service to be active"
        sleep 1
        contrail_status=$(contrail-status | grep $service | grep  ' active' | wc -l)
    done
    echo "$service is active"
done
