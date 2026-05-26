output "cluster_public_ip" {
  value       = local.kubectl_external_server
  description = "Public EIP address of the cluster API server. (will be an empty string if cluster_public_access is false or cluster_ignore_certificate_clusters_data is true)"
}

output "cluster_private_ip" {
  value       = local.kubectl_internal_server
  description = "Private IP address of the cluster API server. (will be an empty string if cluster_ignore_certificate_clusters_data is true)"
}

output "cluster_credentials" {
  sensitive = true
  value = {
    kubectl_config                     = local.kubectl_config_yaml
    client_key_data                    = local.client_key_data
    client_certificate_data            = local.client_certificate_data
    kubectl_external_server            = local.kubectl_external_server
    kubectl_internal_server            = local.kubectl_internal_server
    cluster_certificate_authority_data = local.cluster_certificate_authority_data
  }
  description = "Collection of access credentials for the API server. (Some or all values will be an empty string if cluster_ignore_certificate_clusters_data or cluster_ignore_certificate_users_data is true)"
}

output "cluster_id" {
  value       = opentelekomcloud_cce_cluster_v3.cluster.id
  description = "UUID of the created CCE cluster."
}

output "cluster_name" {
  value       = opentelekomcloud_cce_cluster_v3.cluster.name
  description = "Name of the created CCE cluster."
}

output "kubeconfig_yaml" {
  sensitive   = true
  value       = local.kubectl_config_yaml
  description = "Cluster credentials for the created CCE cluster in kubeconfig YAML format. (Some or all values will be an empty string if cluster_ignore_certificate_clusters_data or cluster_ignore_certificate_users_data is true)"
}

output "kubeconfig_json" {
  sensitive   = true
  value       = local.kubectl_config_json
  description = "Cluster credentials for the created CCE cluster in kubeconfig JSON format. (Some or all values will be an empty string if cluster_ignore_certificate_clusters_data or cluster_ignore_certificate_users_data is true)"
}

output "node_sg_id" {
  value       = opentelekomcloud_cce_cluster_v3.cluster.security_group_node
  description = "UUID of the security group for worker nodes."
}

output "cluster" {
  sensitive   = true
  value       = opentelekomcloud_cce_cluster_v3.cluster
  description = "Complete configuration of the created CCE cluster."
}
