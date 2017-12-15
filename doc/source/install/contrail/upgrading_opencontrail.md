## Upgrading opencontrail

#### Pre-requisite

  * There is an already existing opencontrail cluster, lets call it v1
    throughout this document
  * You have parallel set of node, where you can deploy your contrail v2 pods

#### Limitations

  * You have an all in one contrail v1 cluster (This is what we have tested for now,
    In future releases, we will take care of multi node HA clusters)
  * Upgrade to minor releases only
  * For now, its required for ISSU components to run on k8s master node


#### Steps to upgrade contrail

  * Label one of your k8s node as `opencontrail.org/controllerv2`
  ```bash
  kubectl label node <node-name> opencontrail.org/controllerv2
  ```

  * Edit opencontrail-controller/values.yaml file and make changes as mentioned
    in the [upgrade config section](#upgrade-config)
    Also refer sample [v2_values.yaml](../../../../tools/opencontrail-upgrade/v2-values.yaml)
  * Install contrail v2 charts
  ```bash
  helm install --name opencontrail-controllerv2 ./opencontrail-controller --namespace=openstack
  ```
  * Verify the upgrade, by checking previous objects and creating VM/ports/network
  * Now delete contrail-controller v1 chart
  ```bash
  helm delete --purge <contrail-controllerv1-release>
  ```



#### Upgrade config

  * Edit images in opencontrail/values.yaml and point the images to new v2 image
  * Add node-selector key and value labels to contrail components
  * Add node-selector key as node-role.kubernetes.io/master for issu components
  * Below dependencies needs to be defined
  ```yaml
  dependencies:
    issu_gen:
      daemonset:
      - contrail-controllerv2
    issu_config_migrate:
      daemonset:
      - contrail-controllerv2
      jobs:
      - job-issu-gen-confv2
    issu_finalize_config:
      daemonset:
      - contrail-controllerv2
      jobs:
      - job-issu-update-vrouterv2
    issu_update_vrouter:
      daemonset:
      - contrail-controllerv2
      jobs:
      - job-issu-config-migratev2
  ```
  * Add the pod mounts needed by the issu pods
  ```yaml
  pod:
    mounts:
      issu_gen:
        init_container: null
        issu_gen:
      issu_config_migrate:
        init_container: null
        issu_config_migrate:
      issu_finalize_config:
        init_container: null
        issu_finalize_config:
      issu_update_vrouter:
        init_container: null
        issu_update_vrouter:
  ```
  * In config, we need to mention what is the suffix name we will give to the
  contrail resources
  * Username and password of controller_node needs to be provided
  ```yaml
  conf:
    suffix_obj_name: v2
    # Controller node username and password details (Needed by ISSU)
    controller_node:
      username: root
      password: c0ntrail123
  ```
  * Give controller_nodes, analyticsdb_nodes, analytics_node information
  of v2 cluster
