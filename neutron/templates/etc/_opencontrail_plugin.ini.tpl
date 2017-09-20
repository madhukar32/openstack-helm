{{- include "neutron.conf.opencontrail_values_skeleton" .Values.conf.opencontrail | trunc 0 -}}
{{- include "neutron.conf.opencontrail" .Values.conf.opencontrail -}}

{{- define "neutron.conf.opencontrail_values_skeleton" -}}

{{- if not .default -}}{{- set . "default" dict -}}{{- end -}}
{{- if not .default.apiserver -}}- set .default "apiserver" dict -}}{{- end -}}
{{- if not .default.analytics -}}- set .default "analytics" dict -}}{{- end -}}
{{- if not .default.keystone_auth -}}- set .default "keystone_auth" dict -}}{{- end -}}

{{- end -}}

{{- define "neutron.conf.opencontrail" -}}

[APISERVER]
{{ if not .default.apiserver.ip }}#{{ end }}api_server_ip = {{ .default.apiserver.ip | default "127.0.0.1" }}
{{ if not .default.apiserver.port }}#{{ end }}api_server_port = {{ .default.apiserver.port | default 8082 }}
#
{{ if not .default.apiserver.extensions }}#{{ end }}contrail_extensions = {{ .default.apiserver.extensions | default "ipam:neutron_plugin_contrail.plugins.opencontrail.contrail_plugin_ipam.NeutronPluginContrailIpam,policy:neutron_plugin_contrail.plugins.opencontrail.contrail_plugin_policy.NeutronPluginContrailPolicy,route-table:neutron_plugin_contrail.plugins.opencontrail.contrail_plugin_vpc.NeutronPluginContrailVpc,contrail:None,service-interface:None,vf-binding:None" }}

[COLLECTOR]
{{ if not .default.analytics.ip }}#{{ end }}analytics_api_ip = {{ .default.analytics.ip | default "127.0.0.1" }}
{{ if not .default.analytics.port }}#{{ end }}analytics_api_port = {{ .default.analytics.port | default 8081 }}

[KEYSTONE]
auth_url = https://keystone-api.openstack:35357/v3
admin_user = {{ .default.keystone_auth.admin_user }}
admin_password = {{ .default.keystone_auth.admin_password }}
admin_tenant_name = {{ .default.keystone_auth.admin_project_name }}
{{- end }}
