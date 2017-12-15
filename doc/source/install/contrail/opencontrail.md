### Basic Configurations (for both opencontrail-controller and
opencontrail-vrouter charts)

  1. Point the correct image for each of the opencontrail components
    under images.tags
  2. Add node-selector key and value labels to contrail components
  3. Provide comma separated list of IP's for controller_nodes, analyticsdb_nodes
  and analytics_nodes
  ```yaml
  conf:
    host_os: ubuntu
    global_config:
    GLOBAL:
      controller_nodes: 10.87.65.154
      controller_ip: 10.87.65.154
      analyticsdb_nodes: 10.87.65.154
      analytics_nodes: 10.87.65.154
      cloud_orchestrator: openstack
  ```
