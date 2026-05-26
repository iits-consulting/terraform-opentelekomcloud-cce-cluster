variable "cluster_name" {
  type        = string
  description = "Name of the CCE cluster."
}

variable "tags" {
  type        = map(string)
  description = "Common tag set for CCE cluster related resources."
  default     = {}
}

variable "cluster_annotations" {
  type        = map(string)
  description = "CCE cluster annotations, key/value pair format. This field is not stored in the database and is used only to specify the add-ons to be installed in the cluster."
  default     = {}
}

variable "cluster_timezone" {
  type        = string
  description = "CCE cluster timezone in string format."
  default     = null
}

variable "cluster_ipv6_enable" {
  type        = bool
  description = "Specifies whether the cluster supports IPv6 addresses. This field is supported in clusters of v1.25 and later versions."
  default     = null
}

variable "cluster_extend_param" {
  type        = map(string)
  description = "CCE cluster extended parameters, key/value pair format. For details, please see https://docs.otc.t-systems.com/cloud-container-engine/api-ref/apis/cluster_management/creating_a_cluster.html#cce-02-0236-table17575013586."
  default     = null
}

variable "cluster_vpc_id" {
  type        = string
  description = "The ID of the VPC for the cluster nodes."
}

variable "cluster_subnet_id" {
  type        = string
  description = "The UUID of the subnet for the cluster nodes."
}

variable "cluster_eni_subnet_id" {
  type        = string
  description = "Specifies the UUID of ENI subnet. Specified only when creating a CCE Turbo cluster (when cluster_container_network_type = \"eni\"). If unspecified, module will use the same subnet as cluster_subnet_id."
  default     = null
}

resource "errorcheck_is_valid" "cluster_container_network_type" {
  name = "Check if cluster_container_network_type is set up correctly when cluster_eni_subnet_id is specified."
  test = {
    assert        = var.cluster_eni_subnet_id != null ? local.cluster_container_network_type == "eni" : true
    error_message = "If cluster_eni_subnet_id is specified, cluster_container_network_type must be \"eni\" (CCE Turbo Cluster)."
  }
}

variable "cluster_security_group_id" {
  type        = string
  description = "Default worker node security group ID of the cluster. If specified, the cluster will be bound to the target security group. Otherwise, the system will automatically create a default worker node security group for you."
  default     = null
}

variable "cluster_highway_subnet_id" {
  type        = string
  description = "The ID of the high speed network for bare metal nodes."
  default     = null
}

variable "cluster_version" {
  type        = string
  description = "CCE cluster version."
  default     = "v1.33"
}

variable "cluster_size" {
  type        = string
  description = "Size of the cluster: small, medium, large"
  default     = "small"
  validation {
    condition     = contains(["small", "medium", "large"], lower(var.cluster_size))
    error_message = "Allowed values for cluster_size are \"small\", \"medium\" and \"large\"."
  }
}

variable "cluster_type" {
  type        = string
  description = "Cluster type: VirtualMachine or BareMetal"
  default     = "VirtualMachine"
}

locals {
  # CCE flavor IDs. Format: cce.<type_prefix><ha_suffix>.<size>
  #   type_prefix: "s" for VirtualMachine, "t" for BareMetal
  #   ha_suffix:   "1" for single master, "2" for highly available (multi-master)
  cluster_flavor_id_map = {
    VirtualMachine = {
      "false" = { small = "cce.s1.small", medium = "cce.s1.medium", large = "cce.s1.large" }
      "true"  = { small = "cce.s2.small", medium = "cce.s2.medium", large = "cce.s2.large" }
    }
    BareMetal = {
      "false" = { small = "cce.t1.small", medium = "cce.t1.medium", large = "cce.t1.large" }
      "true"  = { small = "cce.t2.small", medium = "cce.t2.medium", large = "cce.t2.large" }
    }
  }
  cluster_flavor_id = local.cluster_flavor_id_map[var.cluster_type][tostring(var.cluster_high_availability)][lower(var.cluster_size)]
}

variable "cluster_container_network_type" {
  type        = string
  description = "Container network type: vpc-router, overlay_l2 or eni for VirtualMachine Clusters; underlay_ipvlan for BareMetal Clusters"
  default     = null
}

locals {
  // When cluster_container_network_type is unset, fall back to the per-cluster_type default:
  //   VirtualMachine → vpc-router      (overlay_l2 and eni are the other valid VM choices)
  //   BareMetal      → underlay_ipvlan (the only valid BareMetal choice)
  cluster_container_network_type = var.cluster_container_network_type != null ? var.cluster_container_network_type : var.cluster_type == "VirtualMachine" ? "vpc-router" : "underlay_ipvlan"
}

variable "cluster_enable_volume_encryption" {
  type        = bool
  description = "System and data disks encryption of master nodes. Changing this parameter will create a new cluster resource."
  default     = true
}

variable "cluster_container_cidr" {
  type        = string
  description = "Kubernetes pod network CIDR range"
  default     = "172.16.0.0/16"
}

variable "cluster_service_cidr" {
  type        = string
  description = "Kubernetes service network CIDR range"
  default     = "172.17.0.0/16"
}

variable "cluster_public_access" {
  type        = bool
  description = "Bind a public IP to the Cluster to make it publicly reachable over the internet."
  default     = false
}

variable "cluster_public_eip_bandwidth_size" {
  type        = number
  description = "Bandwidth size (Mbit/s) for the public EIP bound to the cluster API when cluster_public_access is true."
  default     = 50
}

variable "cluster_api_access_trustlist" {
  type        = list(string)
  description = "Specifies the trustlist of network CIDRs that are allowed to access cluster APIs."
  default     = null
}

variable "cluster_high_availability" {
  type        = bool
  description = "Create the cluster in highly available mode"
  default     = false
}

variable "cluster_install_icagent" {
  type        = bool
  description = "Install icagent for logging and metrics via AOM"
  default     = false
}

variable "cluster_component_configurations" {
  type        = map(map(string))
  description = "Specifies the kubernetes component configurations. For details, see https://docs.otc.t-systems.com/cloud-container-engine/umn/clusters/managing_clusters/modifying_cluster_configurations.html#cce-10-0213"
  default     = {}
}

variable "cluster_authentication_mode" {
  type        = string
  description = "Authentication mode of the Cluster. Either rbac or authenticating_proxy"
  default     = "rbac"
}

variable "cluster_authenticating_proxy_ca" {
  type        = string
  description = "X509 CA certificate configured in authenticating_proxy mode. The maximum size of the certificate is 1 MB."
  default     = null
}

variable "cluster_authenticating_proxy_cert" {
  type        = string
  description = "Client certificate issued by the X509 CA certificate configured in authenticating_proxy mode."
  default     = null
}

variable "cluster_authenticating_proxy_private_key" {
  type        = string
  description = "Private key of the client certificate issued by the X509 CA certificate configured in authenticating_proxy mode."
  default     = null
}

variable "cluster_no_addons" {
  type        = bool
  description = "Remove addons installed by the default after the cluster creation."
  default     = null
}

variable "cluster_ignore_addons" {
  type        = bool
  description = "Skip all cluster addons operations."
  default     = null
}

variable "cluster_ignore_certificate_users_data" {
  type        = bool
  description = "Skip sensitive user data. (will disable some module outputs)"
  default     = null
}

variable "cluster_ignore_certificate_clusters_data" {
  type        = bool
  description = "Skip sensitive cluster data. (will disable some module outputs)"
  default     = null
}

variable "cluster_kube_proxy_mode" {
  type        = string
  description = "Service forwarding mode: iptables or ipvs"
  default     = null
}

variable "cluster_delete_evs" {
  type        = bool
  description = "Specifies whether to delete associated EVS disks when deleting the CCE cluster."
  default     = null
}

variable "cluster_delete_obs" {
  type        = bool
  description = "Specifies whether to delete associated OBS buckets when deleting the CCE cluster."
  default     = null
}

variable "cluster_delete_sfs" {
  type        = bool
  description = "Specifies whether to delete associated SFS file systems when deleting the CCE cluster."
  default     = null
}

variable "cluster_delete_efs" {
  type        = bool
  description = "Specifies whether to unbind associated SFS Turbo file systems when deleting the CCE cluster."
  default     = null
}

variable "cluster_delete_eni" {
  type        = bool
  description = "Specifies whether to delete ENI ports when deleting the CCE cluster."
  default     = null
}

variable "cluster_delete_net" {
  type        = bool
  description = "Specifies whether to delete cluster Service/ingress-related resources, such as ELB when deleting the CCE cluster."
  default     = null
}

variable "cluster_delete_all_storage" {
  type        = bool
  description = "Specifies whether to delete all associated storage resources when deleting the CCE cluster."
  default     = null
}

variable "cluster_delete_all_network" {
  type        = bool
  description = "Specifies whether to delete all associated network resources when deleting the CCE cluster."
  default     = null
}

variable "addon_autoscaler_enabled" {
  type        = bool
  description = "Enable and install the CCE Autoscaler Addon."
  default     = true
}

variable "addon_autoscaler_version" {
  type        = string
  description = "Version of the Autoscaler Addon Template"
  default     = "latest"
}

variable "addon_metrics_server_enabled" {
  type        = bool
  description = "Enable and install the CCE Metrics Server Addon."
  default     = true
}

variable "addon_metrics_server_version" {
  type        = string
  description = "Version of the Metrics Server Addon Template"
  default     = "latest"
}
