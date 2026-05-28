## OTC Cloud Container Engine Cluster Terraform module

A module designed to support the full capabilities of OTC CCE clusters while simplifying the configuration for ease of use.

This module is part of a set of three CCE modules that are meant to be used together:

| Module | Purpose |
| ------ | ------- |
| `cce-cluster` (this module) | Provisions the CCE control plane and optionally bundles the Autoscaler and Metrics Server addons. |
| [`cce-node-pool`](https://github.com/iits-consulting/terraform-opentelekomcloud-cce-node-pool) | Provisions worker node pools and attaches them to an existing CCE cluster. |
| [`cce-addon`](https://github.com/iits-consulting/terraform-opentelekomcloud-cce-addon) | Installs a single CCE addon into an existing cluster (for anything not bundled here). |

A bare `cce-cluster` has no worker nodes - pair it with one or more `cce-node-pool` modules before scheduling workloads.

> **WARNING:** Creating a CCE Cluster requires an agency to grant tenant administration privileges to the OTC CCE service.
> See [provider documentation](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/resources/cce_cluster_v3#creating-agency) for more details.
>
> - Agency Name = `cce_admin_trust`
> - Agency Type = `Account`
> - Delegated Account = `op_svc_cce`
> - Permissions = `Tenant Administrator` within the project

### Usage

#### Minimal private cluster

```hcl
module "cce_cluster" {
  source = "iits-consulting/cce-cluster/opentelekomcloud"

  cluster_name      = "my-cluster"
  cluster_vpc_id    = module.vpc.vpc.id
  cluster_subnet_id = module.vpc.subnets["kubernetes-subnet"].id
}
```

#### Cluster with a node pool

Attach an autoscaling node pool across two availability zones. The Autoscaler addon is installed by default, so `node_pool_enable_scaling` functions without explicit autoscaler addon configuration.

```hcl
module "cce_cluster" {
  source = "iits-consulting/cce-cluster/opentelekomcloud"

  cluster_name          = "my-cluster"
  cluster_vpc_id        = module.vpc.vpc.id
  cluster_subnet_id     = module.vpc.subnets["kubernetes-subnet"].id
  cluster_public_access = true
}

module "cce_node_pool" {
  source   = "iits-consulting/cce-node-pool/opentelekomcloud"
  for_each = toset(["eu-de-02", "eu-de-03"])

  cluster_id                  = module.cce_cluster.cluster_id
  node_pool_availability_zone = each.key
  node_pool_node_count        = 2
  node_pool_flavor            = "s9.xlarge.4"
  node_pool_enable_scaling    = true
  node_pool_node_count_min    = 2
  node_pool_node_count_max    = 4
}
```

#### CCE Turbo (ENI) cluster

Set `cluster_container_network_type` to `eni` to create a CCE Turbo cluster. If `cluster_eni_subnet_id` is not provided, the module reuses `cluster_subnet_id` for ENI networking.

```hcl
module "cce_cluster" {
  source = "iits-consulting/cce-cluster/opentelekomcloud"

  cluster_name                   = "my-turbo-cluster"
  cluster_vpc_id                 = module.vpc.vpc.id
  cluster_subnet_id              = module.vpc.subnets["kubernetes-subnet"].id
  cluster_container_network_type = "eni"
}
```

#### Installing additional addons

For anything outside of Autoscaler and Metrics Server, use the [`cce-addon`](https://github.com/iits-consulting/terraform-opentelekomcloud-cce-addon) module - for example, the NVIDIA GPU addon:

```hcl
module "cce_gpu_addon" {
  source = "iits-consulting/cce-addon/opentelekomcloud"

  addon_name = "gpu-beta"
  cluster_id = module.cce_cluster.cluster_id
  addon_values_custom = {
    is_driver_from_nvidia      = true
    enable_dcgm_exporter       = true
    nvidia_driver_download_url = "https://us.download.nvidia.com/tesla/595.58.03/NVIDIA-Linux-x86_64-595.58.03.run"
  }
}
```

### Cluster sizing

`cluster_size` and `cluster_high_availability` pick the underlying CCE flavor, and `cluster_type` selects between `VirtualMachine` (default) and `BareMetal`:

| `cluster_type`   | HA      | `small`        | `medium`        | `large`        |
| ---------------- | ------- | -------------- | --------------- | -------------- |
| `VirtualMachine` | `false` | `cce.s1.small` | `cce.s1.medium` | `cce.s1.large` |
| `VirtualMachine` | `true`  | `cce.s2.small` | `cce.s2.medium` | `cce.s2.large` |
| `BareMetal`      | `false` | `cce.t1.small` | `cce.t1.medium` | `cce.t1.large` |
| `BareMetal`      | `true`  | `cce.t2.small` | `cce.t2.medium` | `cce.t2.large` |

### Bundled addons

To keep most clusters self-contained, this module installs two addons directly - both can be disabled for clusters that manage addons externally:

- **Autoscaler** (`addon_autoscaler_enabled`, default `true`) - required for `cce-node-pool` autoscaling to take effect.
- **Metrics Server** (`addon_metrics_server_enabled`, default `true`) - required for `kubectl top` and Horizontal Pod Autoscaling.

### Migrating from the older modules

See [`MIGRATION.md`](MIGRATION.md) for the step-by-step path from the predecessor `iits-consulting/cce/opentelekomcloud` and `iits-consulting/cce-gpu-node-pool/opentelekomcloud` modules to this family, including `moved` block templates, variable rename tables, and the keypair/KMS continuity playbook.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.7 |
| <a name="requirement_errorcheck"></a> [errorcheck](#requirement\_errorcheck) | 3.0.3 |
| <a name="requirement_opentelekomcloud"></a> [opentelekomcloud](#requirement\_opentelekomcloud) | >= 1.36.52, < 2.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_errorcheck"></a> [errorcheck](#provider\_errorcheck) | 3.0.3 |
| <a name="provider_opentelekomcloud"></a> [opentelekomcloud](#provider\_opentelekomcloud) | >= 1.36.52, < 2.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_cce_addon_autoscaler"></a> [cce\_addon\_autoscaler](#module\_cce\_addon\_autoscaler) | iits-consulting/cce-addon/opentelekomcloud | ~> 1.0 |
| <a name="module_cce_addon_metrics_server"></a> [cce\_addon\_metrics\_server](#module\_cce\_addon\_metrics\_server) | iits-consulting/cce-addon/opentelekomcloud | < 2.0.0 |

## Resources

| Name | Type |
|------|------|
| [errorcheck_is_valid.cluster_container_network_type](https://registry.terraform.io/providers/iits-consulting/errorcheck/3.0.3/docs/resources/is_valid) | resource |
| [opentelekomcloud_cce_cluster_v3.cluster](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/resources/cce_cluster_v3) | resource |
| [opentelekomcloud_vpc_eip_v1.cce_eip](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/resources/vpc_eip_v1) | resource |
| [opentelekomcloud_vpc_subnet_v1.eni_subnet](https://registry.terraform.io/providers/opentelekomcloud/opentelekomcloud/latest/docs/data-sources/vpc_subnet_v1) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the CCE cluster. | `string` | n/a | yes |
| <a name="input_cluster_subnet_id"></a> [cluster\_subnet\_id](#input\_cluster\_subnet\_id) | The UUID of the subnet for the cluster nodes. | `string` | n/a | yes |
| <a name="input_cluster_vpc_id"></a> [cluster\_vpc\_id](#input\_cluster\_vpc\_id) | The ID of the VPC for the cluster nodes. | `string` | n/a | yes |
| <a name="input_addon_autoscaler_enabled"></a> [addon\_autoscaler\_enabled](#input\_addon\_autoscaler\_enabled) | Enable and install the CCE Autoscaler Addon. | `bool` | `true` | no |
| <a name="input_addon_autoscaler_version"></a> [addon\_autoscaler\_version](#input\_addon\_autoscaler\_version) | Version of the Autoscaler Addon Template | `string` | `"latest"` | no |
| <a name="input_addon_metrics_server_enabled"></a> [addon\_metrics\_server\_enabled](#input\_addon\_metrics\_server\_enabled) | Enable and install the CCE Metrics Server Addon. | `bool` | `true` | no |
| <a name="input_addon_metrics_server_version"></a> [addon\_metrics\_server\_version](#input\_addon\_metrics\_server\_version) | Version of the Metrics Server Addon Template | `string` | `"latest"` | no |
| <a name="input_cluster_annotations"></a> [cluster\_annotations](#input\_cluster\_annotations) | CCE cluster annotations, key/value pair format. This field is not stored in the database and is used only to specify the add-ons to be installed in the cluster. | `map(string)` | `{}` | no |
| <a name="input_cluster_api_access_trustlist"></a> [cluster\_api\_access\_trustlist](#input\_cluster\_api\_access\_trustlist) | Specifies the trustlist of network CIDRs that are allowed to access cluster APIs. | `list(string)` | `null` | no |
| <a name="input_cluster_authenticating_proxy_ca"></a> [cluster\_authenticating\_proxy\_ca](#input\_cluster\_authenticating\_proxy\_ca) | X509 CA certificate configured in authenticating\_proxy mode. The maximum size of the certificate is 1 MB. | `string` | `null` | no |
| <a name="input_cluster_authenticating_proxy_cert"></a> [cluster\_authenticating\_proxy\_cert](#input\_cluster\_authenticating\_proxy\_cert) | Client certificate issued by the X509 CA certificate configured in authenticating\_proxy mode. | `string` | `null` | no |
| <a name="input_cluster_authenticating_proxy_private_key"></a> [cluster\_authenticating\_proxy\_private\_key](#input\_cluster\_authenticating\_proxy\_private\_key) | Private key of the client certificate issued by the X509 CA certificate configured in authenticating\_proxy mode. | `string` | `null` | no |
| <a name="input_cluster_authentication_mode"></a> [cluster\_authentication\_mode](#input\_cluster\_authentication\_mode) | Authentication mode of the Cluster. Either rbac or authenticating\_proxy | `string` | `"rbac"` | no |
| <a name="input_cluster_component_configurations"></a> [cluster\_component\_configurations](#input\_cluster\_component\_configurations) | Specifies the kubernetes component configurations. For details, see https://docs.otc.t-systems.com/cloud-container-engine/umn/clusters/managing_clusters/modifying_cluster_configurations.html#cce-10-0213 | `map(map(string))` | `{}` | no |
| <a name="input_cluster_container_cidr"></a> [cluster\_container\_cidr](#input\_cluster\_container\_cidr) | Kubernetes pod network CIDR range | `string` | `"172.16.0.0/16"` | no |
| <a name="input_cluster_container_network_type"></a> [cluster\_container\_network\_type](#input\_cluster\_container\_network\_type) | Container network type: vpc-router, overlay\_l2 or eni for VirtualMachine Clusters; underlay\_ipvlan for BareMetal Clusters | `string` | `null` | no |
| <a name="input_cluster_delete_all_network"></a> [cluster\_delete\_all\_network](#input\_cluster\_delete\_all\_network) | Specifies whether to delete all associated network resources when deleting the CCE cluster. | `bool` | `null` | no |
| <a name="input_cluster_delete_all_storage"></a> [cluster\_delete\_all\_storage](#input\_cluster\_delete\_all\_storage) | Specifies whether to delete all associated storage resources when deleting the CCE cluster. | `bool` | `null` | no |
| <a name="input_cluster_delete_efs"></a> [cluster\_delete\_efs](#input\_cluster\_delete\_efs) | Specifies whether to unbind associated SFS Turbo file systems when deleting the CCE cluster. | `bool` | `null` | no |
| <a name="input_cluster_delete_eni"></a> [cluster\_delete\_eni](#input\_cluster\_delete\_eni) | Specifies whether to delete ENI ports when deleting the CCE cluster. | `bool` | `null` | no |
| <a name="input_cluster_delete_evs"></a> [cluster\_delete\_evs](#input\_cluster\_delete\_evs) | Specifies whether to delete associated EVS disks when deleting the CCE cluster. | `bool` | `null` | no |
| <a name="input_cluster_delete_net"></a> [cluster\_delete\_net](#input\_cluster\_delete\_net) | Specifies whether to delete cluster Service/ingress-related resources, such as ELB when deleting the CCE cluster. | `bool` | `null` | no |
| <a name="input_cluster_delete_obs"></a> [cluster\_delete\_obs](#input\_cluster\_delete\_obs) | Specifies whether to delete associated OBS buckets when deleting the CCE cluster. | `bool` | `null` | no |
| <a name="input_cluster_delete_sfs"></a> [cluster\_delete\_sfs](#input\_cluster\_delete\_sfs) | Specifies whether to delete associated SFS file systems when deleting the CCE cluster. | `bool` | `null` | no |
| <a name="input_cluster_enable_volume_encryption"></a> [cluster\_enable\_volume\_encryption](#input\_cluster\_enable\_volume\_encryption) | System and data disks encryption of master nodes. Changing this parameter will create a new cluster resource. | `bool` | `true` | no |
| <a name="input_cluster_eni_subnet_id"></a> [cluster\_eni\_subnet\_id](#input\_cluster\_eni\_subnet\_id) | Specifies the UUID of ENI subnet. Specified only when creating a CCE Turbo cluster (when cluster\_container\_network\_type = "eni"). If unspecified, module will use the same subnet as cluster\_subnet\_id. | `string` | `null` | no |
| <a name="input_cluster_extend_param"></a> [cluster\_extend\_param](#input\_cluster\_extend\_param) | CCE cluster extended parameters, key/value pair format. For details, please see https://docs.otc.t-systems.com/cloud-container-engine/api-ref/apis/cluster_management/creating_a_cluster.html#cce-02-0236-table17575013586. | `map(string)` | `null` | no |
| <a name="input_cluster_high_availability"></a> [cluster\_high\_availability](#input\_cluster\_high\_availability) | Create the cluster in highly available mode | `bool` | `false` | no |
| <a name="input_cluster_highway_subnet_id"></a> [cluster\_highway\_subnet\_id](#input\_cluster\_highway\_subnet\_id) | The ID of the high speed network for bare metal nodes. | `string` | `null` | no |
| <a name="input_cluster_ignore_addons"></a> [cluster\_ignore\_addons](#input\_cluster\_ignore\_addons) | Skip all cluster addons operations. | `bool` | `null` | no |
| <a name="input_cluster_ignore_certificate_clusters_data"></a> [cluster\_ignore\_certificate\_clusters\_data](#input\_cluster\_ignore\_certificate\_clusters\_data) | Skip sensitive cluster data. (will disable some module outputs) | `bool` | `null` | no |
| <a name="input_cluster_ignore_certificate_users_data"></a> [cluster\_ignore\_certificate\_users\_data](#input\_cluster\_ignore\_certificate\_users\_data) | Skip sensitive user data. (will disable some module outputs) | `bool` | `null` | no |
| <a name="input_cluster_install_icagent"></a> [cluster\_install\_icagent](#input\_cluster\_install\_icagent) | Install icagent for logging and metrics via AOM | `bool` | `false` | no |
| <a name="input_cluster_ipv6_enable"></a> [cluster\_ipv6\_enable](#input\_cluster\_ipv6\_enable) | Specifies whether the cluster supports IPv6 addresses. This field is supported in clusters of v1.25 and later versions. | `bool` | `null` | no |
| <a name="input_cluster_kube_proxy_mode"></a> [cluster\_kube\_proxy\_mode](#input\_cluster\_kube\_proxy\_mode) | Service forwarding mode: iptables or ipvs | `string` | `null` | no |
| <a name="input_cluster_no_addons"></a> [cluster\_no\_addons](#input\_cluster\_no\_addons) | Remove addons installed by the default after the cluster creation. | `bool` | `null` | no |
| <a name="input_cluster_public_access"></a> [cluster\_public\_access](#input\_cluster\_public\_access) | Bind a public IP to the Cluster to make it publicly reachable over the internet. | `bool` | `false` | no |
| <a name="input_cluster_public_eip_bandwidth_size"></a> [cluster\_public\_eip\_bandwidth\_size](#input\_cluster\_public\_eip\_bandwidth\_size) | Bandwidth size (Mbit/s) for the public EIP bound to the cluster API when cluster\_public\_access is true. | `number` | `50` | no |
| <a name="input_cluster_security_group_id"></a> [cluster\_security\_group\_id](#input\_cluster\_security\_group\_id) | Default worker node security group ID of the cluster. If specified, the cluster will be bound to the target security group. Otherwise, the system will automatically create a default worker node security group for you. | `string` | `null` | no |
| <a name="input_cluster_service_cidr"></a> [cluster\_service\_cidr](#input\_cluster\_service\_cidr) | Kubernetes service network CIDR range | `string` | `"172.17.0.0/16"` | no |
| <a name="input_cluster_size"></a> [cluster\_size](#input\_cluster\_size) | Size of the cluster: small, medium, large | `string` | `"small"` | no |
| <a name="input_cluster_timezone"></a> [cluster\_timezone](#input\_cluster\_timezone) | CCE cluster timezone in string format. | `string` | `null` | no |
| <a name="input_cluster_type"></a> [cluster\_type](#input\_cluster\_type) | Cluster type: VirtualMachine or BareMetal | `string` | `"VirtualMachine"` | no |
| <a name="input_cluster_version"></a> [cluster\_version](#input\_cluster\_version) | CCE cluster version. | `string` | `"v1.33"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tag set for CCE cluster related resources. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster"></a> [cluster](#output\_cluster) | Complete configuration of the created CCE cluster. |
| <a name="output_cluster_credentials"></a> [cluster\_credentials](#output\_cluster\_credentials) | Collection of access credentials for the API server. (Some or all values will be an empty string if cluster\_ignore\_certificate\_clusters\_data or cluster\_ignore\_certificate\_users\_data is true) |
| <a name="output_cluster_id"></a> [cluster\_id](#output\_cluster\_id) | UUID of the created CCE cluster. |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Name of the created CCE cluster. |
| <a name="output_cluster_private_ip"></a> [cluster\_private\_ip](#output\_cluster\_private\_ip) | Private IP address of the cluster API server. (will be an empty string if cluster\_ignore\_certificate\_clusters\_data is true) |
| <a name="output_cluster_public_ip"></a> [cluster\_public\_ip](#output\_cluster\_public\_ip) | Public EIP address of the cluster API server. (will be an empty string if cluster\_public\_access is false or cluster\_ignore\_certificate\_clusters\_data is true) |
| <a name="output_kubeconfig_json"></a> [kubeconfig\_json](#output\_kubeconfig\_json) | Cluster credentials for the created CCE cluster in kubeconfig JSON format. (Some or all values will be an empty string if cluster\_ignore\_certificate\_clusters\_data or cluster\_ignore\_certificate\_users\_data is true) |
| <a name="output_kubeconfig_yaml"></a> [kubeconfig\_yaml](#output\_kubeconfig\_yaml) | Cluster credentials for the created CCE cluster in kubeconfig YAML format. (Some or all values will be an empty string if cluster\_ignore\_certificate\_clusters\_data or cluster\_ignore\_certificate\_users\_data is true) |
| <a name="output_node_sg_id"></a> [node\_sg\_id](#output\_node\_sg\_id) | UUID of the security group for worker nodes. |
<!-- END_TF_DOCS -->
