module "cce_addon_autoscaler" {
  count         = var.addon_autoscaler_enabled ? 1 : 0
  source        = "iits-consulting/cce-addon/opentelekomcloud"
  version       = "< 2.0.0" // todo: replace with "~> 1.0" for first major release (1.0.0)
  addon_name    = "autoscaler"
  addon_version = var.addon_autoscaler_version
  cluster_id    = opentelekomcloud_cce_cluster_v3.cluster.id
  addon_values_custom = {
    "coresTotal"                    = 16000
    "expander"                      = "priority"
    "logLevel"                      = 4
    "maxEmptyBulkDeleteFlag"        = 11
    "maxNodesTotal"                 = 100
    "memoryTotal"                   = 64000
    "scaleDownDelayAfterAdd"        = 15
    "scaleDownDelayAfterDelete"     = 15
    "scaleDownDelayAfterFailure"    = 3
    "scaleDownEnabled"              = true
    "scaleDownUnneededTime"         = 8
    "scaleUpUnscheduledPodEnabled"  = true
    "scaleUpUtilizationEnabled"     = true
    "unremovableNodeRecheckTimeout" = 8
  }
  addon_values_flavor = jsonencode({
    resources = [
      {
        "requestsCpu" = "100m"
        "limitsCpu"   = "1000m"
        "requestsMem" = "128Mi"
        "limitsMem"   = "1Gi"
        "name"        = "autoscaler"
        "replicas"    = 2
      }
    ]
  })
}

module "cce_addon_metrics_server" {
  count         = var.addon_metrics_server_enabled ? 1 : 0
  source        = "iits-consulting/cce-addon/opentelekomcloud"
  version       = "< 2.0.0" // todo: replace with "~> 1.0" for first major release (1.0.0)
  addon_name    = "metrics-server"
  addon_version = var.addon_metrics_server_version
  cluster_id    = opentelekomcloud_cce_cluster_v3.cluster.id
}
