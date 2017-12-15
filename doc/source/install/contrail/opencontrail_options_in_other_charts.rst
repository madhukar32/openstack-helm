## Changes to other openstack charts

#### libvirt charts

Enable cgroup_device_acl under conf/qemu config

  ```yaml
  # In libvirt/values.yaml
  conf:
    qemu:
      cgroup_device_acl: ["/dev/null", "/dev/full", "/dev/zero", "/dev/random", "/dev/urandom", "/dev/ptmx", "/dev/kvm", "/dev/kqemu", "/dev/rtc", "/dev/hpet","/dev/net/tun" ]
  ```

#### heat charts

In heat charts we need to change the below config
  * Point to the contrail plugin_dirs
  * Enable the clients_contrail

  ```yaml
  # In heat/values.yaml
  # heat_engine image with contrail plugins
  images:
    tags:
      engine: docker.io/madhukar32/ubuntu-binary-contrail-heat-engine:3.0.4
  ```

  ```yaml
  # In heat/values.yaml
  # set plugin_dirs
  conf:
    heat:
      DEFAULT:
        plugin_dirs: /usr/lib/python2.7/dist-packages/vnc_api/gen/heat/resources,/usr/lib/python2.7/dist-packages/contrail_heat/resources
  ```

  ```yaml
  # In heat/values.yaml
  # set clients_contrail config
  conf:
    heat:
      clients_contrail:
        api_base_url: /
        api_server: 10.87.65.154
        # where api_server respresents IP for contrail-api server
  ```

#### neutron charts

In neutron charts, we need to change the below config

* Change the neutron user id
* pointing the service plugin, core plugin and api's to opencontrail
* point the quota driver to network
* enable the opencontrail plugin
* point it to opencontrail api server and analytics api server

  ```yaml
  # In neutron/values.yaml
  # server image with contrail plugins
  images:
    tags:
      server: madhukar32/ubuntu-neutron-server-contrail-plugin:3.0.4
  ```

  ```yaml
  # In neutron/values.yaml
  # change the neutron uid
  pod:
    user:
      # for opencontrail, set neutron uid to 107
      neutron:
        uid: 107
  ```

  ```yaml
  # In neutron/values.yaml
  # Changing the neutron config to point opencontrail as the background
  conf:
    neutron:
      DEFAULT:
        core_plugin: neutron_plugin_contrail.plugins.opencontrail.contrail_plugin.NeutronPluginContrailCoreV2
        service_plugins: neutron_plugin_contrail.plugins.opencontrail.loadbalancer.v2.plugin.LoadBalancerPluginV2
        l3_ha: False
        api_extensions_path: /usr/lib/python2.7/dist-packages/neutron_plugin_contrail/extensions:/usr/lib/python2.7/dist-packages/neutron_lbaas/extensions
      quotas:
        quota_network: -1
        quota_subnet: -1
        quota_port: -1
        quota_driver: neutron_plugin_contrail.plugins.opencontrail.quota.driver.QuotaDriver
  ```

  ```yaml
  # In neutron/values.yaml
  # Enabling the opencontrail plugin
  conf:
    plugins:
      neutron_plugin_framework: opencontrail
      neutron_plugin_conf: ContrailPlugin.ini
      opencontrail:
        APISERVER:
          # api_server_ip is IP where contrail-api process is running
          api_server_ip: 10.87.65.154
          api_server_port: 8082
          contrail_extensions: "ipam:neutron_plugin_contrail.plugins.opencontrail.contrail_plugin_ipam.NeutronPluginContrailIpam,policy:neutron_plugin_contrail.plugins.opencontrail.contrail_plugin_policy.NeutronPluginContrailPolicy,route-table:neutron_plugin_contrail.plugins.opencontrail.contrail_plugin_vpc.NeutronPluginContrailVpc,contrail:None,service-interface:None,vf-binding:None"
          multi_tenancy: True
        COLLECTOR:
          # analytics_api_ip is IP of analytics-api
          analytics_api_ip: 10.87.65.154
          analytics_api_port: 8081
        KEYSTONE:
          admin_user: admin
          admin_password: password
          admin_tenant_name: admin
          auth_user: admin
  ```

  ```yaml
  # In neutron/values.yaml
  # Disabling the neutron manifests not needed by opencontrail SDN
  manifests:
    daemonset_dhcp_agent: false
    daemonset_l3_agent: false
    daemonset_lb_agent: false
    daemonset_ovs_agent: false
  ```

#### nova charts

We need to add opencontrail vrouter agent as the dependency for nova-compute

  ```yaml
  # In nova/values.yaml
  images:
    tags:
      compute: docker.io/madhukar32/ubuntu-source-nova-compute:3.0.4
  ```

  ```yaml
    # In nova/values.yaml
    dependencies:
      compute:
        daemonset:
        - contrail-vrouter-agent
  ```
