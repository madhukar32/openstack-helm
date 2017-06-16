{{ include "neutron.conf.opencontrail" .Values }}

{{- define "neutron.conf.opencontrail" -}}

{{- with .conf.opencontrail.default.apiserver }}
[APISERVER]
api_server_ip = {{ .api_server_ip }}
api_server_port = {{ .api_server_port }}
contrail_extensions = "ipam:neutron_plugin_contrail.plugins.opencontrail.contrail_plugin_ipam.NeutronPluginContrailIpam,policy:neutron_plugin_contrail.plugins.opencontrail.contrail_plugin_policy.NeutronPluginContrailPolicy,route-table:neutron_plugin_contrail.plugins.opencontrail.contrail_plugin_vpc.NeutronPluginContrailVpc,contrail:None,service-interface:None,vf-binding:None"
{{- end }}

{{- with .conf.opencontrail.default.collector }}
[COLLECTOR]
analytics_api_ip = {{ .analytics_api_ip }}
analytics_api_port = {{ .analytics_api_port }}
{{- end }}

[KEYSTONE]
auth_url = https://keystone-api.openstack:35357/v3
admin_user = {{ .keystone.admin_user }}
admin_password = {{ .keystone.admin_password }}
admin_tenant_name = {{ .keystone.admin_project_name }}

{{- end -}}
