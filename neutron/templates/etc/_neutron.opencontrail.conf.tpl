# Copyright 2017 The Openstack-Helm Authors.
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

[DEFAULT]
debug = {{ .Values.neutron.default.debug }}
use_syslog = False
use_stderr = True

allow_overlapping_ips = True
dhcp_agent_notification = False

bind_host = {{ .Values.network.ip_address }}
bind_port = {{ .Values.network.port.server }}

auth_strategy = keystone

api_workers = {{ .Values.neutron.workers }}

core_plugin = neutron_plugin_contrail.plugins.opencontrail.contrail_plugin.NeutronPluginContrailCoreV2
service_plugins = neutron_plugin_contrail.plugins.opencontrail.loadbalancer.v2.plugin.LoadBalancerPluginV2
api_extensions_path = extensions:/usr/lib/python2.7/site-packages/neutron_plugin_contrail/extensions:/usr/lib/python2.7/site-packages/neutron_lbaas/extensions

transport_url = rabbit://{{ .Values.rabbitmq.admin_user }}:{{ .Values.rabbitmq.admin_password }}@{{ .Values.rabbitmq.address }}:{{ .Values.rabbitmq.port }}

[nova]
memcached_servers = "{{ .Values.memcached.host }}:{{ .Values.memcached.port }}"
auth_version = v3
auth_url = {{ tuple "identity" "internal" "api" . | include "helm-toolkit.keystone_endpoint_uri_lookup" }}
auth_type = password
region_name = {{ .Values.keystone.nova_region_name }}
project_domain_name = {{ .Values.keystone.nova_project_domain }}
project_name = {{ .Values.keystone.nova_project_name }}
user_domain_name = {{ .Values.keystone.nova_user_domain }}
username = {{ .Values.keystone.nova_user }}
password = {{ .Values.keystone.nova_password }}

[oslo_concurrency]
#lock_path = /var/lib/neutron/tmp

[agent]

[database]
connection = mysql+pymysql://{{ .Values.database.neutron_user }}:{{ .Values.database.neutron_password }}@{{ include "helm-toolkit.mariadb_host" . }}/{{ .Values.database.neutron_database_name }}
max_retries = -1

[keystone_authtoken]
memcached_servers = "{{ .Values.memcached.host }}:{{ .Values.memcached.port }}"
auth_version = v3
auth_url = {{ tuple "identity" "internal" "api" . | include "helm-toolkit.keystone_endpoint_uri_lookup" }}
auth_type = password
region_name = {{ .Values.keystone.neutron_region_name }}
project_domain_name = {{ .Values.keystone.neutron_project_domain }}
project_name = {{ .Values.keystone.neutron_project_name }}
user_domain_name = {{ .Values.keystone.neutron_user_domain }}
username = {{ .Values.keystone.neutron_user }}
password = {{ .Values.keystone.neutron_password }}

[oslo_messaging_notifications]
driver = noop
