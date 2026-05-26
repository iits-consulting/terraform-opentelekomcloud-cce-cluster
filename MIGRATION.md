## Migrating from the older CCE modules

This module is part of a family that replaces two older modules:

- [`iits-consulting/terraform-opentelekomcloud-cce`](https://github.com/iits-consulting/terraform-opentelekomcloud-cce) - a single module that created the cluster, all node pools, the keypair, KMS keys, and the Autoscaler + Metrics Server addons.
- [`iits-consulting/terraform-opentelekomcloud-cce-gpu-node-pool`](https://github.com/iits-consulting/terraform-opentelekomcloud-cce-gpu-node-pool) - a sibling module that attached a GPU node pool plus the `gpu-beta` addon to an existing cluster.

The new family splits responsibilities into three composable modules, each published in its own repo:

| Predecessor responsibility | New home |
| -------------------------- | -------- |
| CCE control plane, kubeconfig, public EIP, bundled Autoscaler + Metrics Server addons | [`iits-consulting/terraform-opentelekomcloud-cce-cluster`](https://github.com/iits-consulting/terraform-opentelekomcloud-cce-cluster) |
| Worker node pool, keypair, KMS encryption key, autoscaling knobs, storage layout | [`iits-consulting/terraform-opentelekomcloud-cce-node-pool`](https://github.com/iits-consulting/terraform-opentelekomcloud-cce-node-pool) |
| Any other CCE addon (`gpu-beta`, NVIDIA driver, etc.) | [`iits-consulting/terraform-opentelekomcloud-cce-addon`](https://github.com/iits-consulting/terraform-opentelekomcloud-cce-addon) |

### What carries over vs. what gets recreated

The migration relies on the new `cce-node-pool` module's `create_before_destroy` lifecycle. Resources that can carry forward without disruption use `moved` blocks (in-state address rename, no API churn). Resources that change ownership model - the per-pool keypair and KMS encryption key - are **recreated** during the migration apply. `create_before_destroy` creates the new pool (with its fresh keypair and KMS key) before the old pool drains, so workloads keep running.

| Resource | Strategy |
| -------- | -------- |
| CCE cluster, public EIP, bundled Autoscaler + Metrics Server addons | `moved` block - in-place address rename, no recreation. |
| Node pool | `moved` block lands the pool under the new address. The per-pool keypair and KMS key changes then trigger a `create_before_destroy` replacement of the pool. Terraform garbage-collects the old shared keypair and KMS key at the end of the same apply. |
| Predecessor's shared keypair, `tls_private_key`, and `random_id` for the keypair suffix | **Destroyed automatically** at the end of the apply once no pool references them. Do not add `moved` blocks for them - they intentionally don't migrate. |
| Predecessor's shared KMS key | **Destroyed automatically**; goes into OTC's 7-day pending-delete queue. |
| GPU pool from `cce-gpu-node-pool` | Same as a regular pool - `moved` block + automatic recreation under the new module. |
| `gpu-beta` addon from `cce-gpu-node-pool` | `moved` block to a new `cce-addon` instance - in-place, no recreation. |

During the apply, the cluster temporarily runs **both the old and the new pools at once** (per-AZ doubling of nodes). The new pools come up first, then the old pools drain. For normal stateless workloads with reasonable `PodDisruptionBudget`s this is zero downtime; stateful workloads with local storage need their usual planned-disruption handling.

### Before / after at a glance

#### Cluster + regular node pools (`cce`)

Predecessor (`module "cce"`):

```hcl
module "cce" {
  source = "iits-consulting/cce/opentelekomcloud"

  name                    = "my-cluster"
  cluster_vpc_id          = module.vpc.vpc.id
  cluster_subnet_id       = module.vpc.subnets["kubernetes-subnet"].id
  node_availability_zones = toset(["eu-de-02", "eu-de-03"])
  node_count              = 2
  node_flavor             = "s9.xlarge.4"
  cluster_enable_scaling  = true
  autoscaler_node_max     = 4
}
```

Successor (split across modules; the caller now drives the per-AZ `for_each`):

```hcl
module "cce_cluster" {
  source = "iits-consulting/cce-cluster/opentelekomcloud"

  cluster_name      = "my-cluster"
  cluster_vpc_id    = module.vpc.vpc.id
  cluster_subnet_id = module.vpc.subnets["kubernetes-subnet"].id
}

module "cce_node_pool" {
  source   = "iits-consulting/cce-node-pool/opentelekomcloud"
  for_each = toset(["eu-de-02", "eu-de-03"])

  cluster_id                  = module.cce_cluster.cluster_id
  node_pool_availability_zone = each.key
  node_pool_node_count        = 2
  node_pool_flavor            = "s9.xlarge.4"
  node_pool_enable_scaling    = true
  node_pool_node_count_max    = 4
}
```

#### GPU node pool + addon (`cce-gpu-node-pool`)

Predecessor (`module "cce_gpu"`):

```hcl
module "cce_gpu" {
  source = "iits-consulting/cce-gpu-node-pool/opentelekomcloud"

  name_prefix             = "my-cluster"
  cce_cluster_id          = module.cce.cluster_id
  node_availability_zones = toset(["eu-de-03"])
  node_count              = 1
  node_flavor             = "pi5e.2xlarge.4"
  gpu_beta_enabled        = true
  gpu_driver_url          = "https://us.download.nvidia.com/tesla/595.58.03/NVIDIA-Linux-x86_64-595.58.03.run"
}
```

Successor (one `cce-node-pool` per GPU AZ plus one `cce-addon` for `gpu-beta`):

```hcl
module "cce_gpu_node_pool" {
  source   = "iits-consulting/cce-node-pool/opentelekomcloud"
  for_each = toset(["eu-de-03"])

  cluster_id                  = module.cce_cluster.cluster_id
  node_pool_name              = "my-cluster-gpu-${each.key}" # match predecessor naming
  node_pool_availability_zone = each.key
  node_pool_flavor            = "pi5e.2xlarge.4"
  node_pool_node_count        = 1
}

module "cce_gpu_addon" {
  source = "iits-consulting/cce-addon/opentelekomcloud"

  addon_name = "gpu-beta"
  cluster_id = module.cce_cluster.cluster_id
  addon_values_custom = {
    is_driver_from_nvidia      = true
    nvidia_driver_download_url = "https://us.download.nvidia.com/tesla/595.58.03/NVIDIA-Linux-x86_64-595.58.03.run"
  }
}
```

### Module-mapping cheat sheet

> **NOTE:** The addresses below - both in this cheat sheet and in the [`moved` blocks](#moved-blocks) section - assume the following module instance names. Substitute whichever names your root module actually uses; every address shown changes to match.
>
> Predecessors:
> - `module.cce` - from `iits-consulting/cce/opentelekomcloud`
> - `module.cce_gpu` - from `iits-consulting/cce-gpu-node-pool/opentelekomcloud`
>
> Successors:
> - `module.cce_cluster` - from `iits-consulting/cce-cluster/opentelekomcloud`
> - `module.cce_node_pool` - from `iits-consulting/cce-node-pool/opentelekomcloud`
> - `module.cce_gpu_node_pool` - from `iits-consulting/cce-node-pool/opentelekomcloud`
> - `module.cce_gpu_addon` - from `iits-consulting/cce-addon/opentelekomcloud`

| Predecessor module | Predecessor resource address | New module instance | New resource address |
| ------------------ | ----------------------------- | ------------------- | -------------------- |
| `cce` | `module.cce.opentelekomcloud_cce_cluster_v3.cluster` | `cce-cluster` | `module.cce_cluster.opentelekomcloud_cce_cluster_v3.cluster` |
| `cce` | `module.cce.opentelekomcloud_vpc_eip_v1.cce_eip[0]` | `cce-cluster` | `module.cce_cluster.opentelekomcloud_vpc_eip_v1.cce_eip[0]` |
| `cce` | `module.cce.opentelekomcloud_cce_addon_v3.autoscaler[0]` | `cce-cluster` | `module.cce_cluster.module.cce_addon_autoscaler[0].opentelekomcloud_cce_addon_v3.addon` |
| `cce` | `module.cce.opentelekomcloud_cce_addon_v3.metrics` | `cce-cluster` | `module.cce_cluster.module.cce_addon_metrics_server[0].opentelekomcloud_cce_addon_v3.addon` |
| `cce` | `module.cce.opentelekomcloud_cce_node_pool_v3.cluster_node_pool["<az>"]` | `cce-node-pool` (one per AZ) | `module.cce_node_pool["<az>"].opentelekomcloud_cce_node_pool_v3.node_pool` |
| `cce-gpu-node-pool` | `module.cce_gpu.opentelekomcloud_cce_node_pool_v3.cluster_node_pool["<az>"]` | `cce-node-pool` (one per GPU AZ) | `module.cce_gpu_node_pool["<az>"].opentelekomcloud_cce_node_pool_v3.node_pool` |
| `cce-gpu-node-pool` | `module.cce_gpu.opentelekomcloud_cce_addon_v3.gpu[0]` | `cce-addon` | `module.cce_gpu_addon.opentelekomcloud_cce_addon_v3.addon` |

### `moved` blocks

Add these to your root module alongside the new module calls. Terraform reconciles state without recreating these resources:

```hcl
moved {
  from = module.cce.opentelekomcloud_cce_cluster_v3.cluster
  to   = module.cce_cluster.opentelekomcloud_cce_cluster_v3.cluster
}

moved {
  from = module.cce.opentelekomcloud_vpc_eip_v1.cce_eip[0]
  to   = module.cce_cluster.opentelekomcloud_vpc_eip_v1.cce_eip[0]
}

moved {
  from = module.cce.opentelekomcloud_cce_addon_v3.autoscaler[0]
  to   = module.cce_cluster.module.cce_addon_autoscaler[0].opentelekomcloud_cce_addon_v3.addon
}

moved {
  from = module.cce.opentelekomcloud_cce_addon_v3.metrics
  to   = module.cce_cluster.module.cce_addon_metrics_server[0].opentelekomcloud_cce_addon_v3.addon
}

# One per AZ the predecessor had a pool in:
moved {
  from = module.cce.opentelekomcloud_cce_node_pool_v3.cluster_node_pool["eu-de-02"]
  to   = module.cce_node_pool["eu-de-02"].opentelekomcloud_cce_node_pool_v3.node_pool
}
```

The pool `moved` blocks land the resources in state under the new address. The first plan after the move then surfaces the per-pool `key_pair`, `kms_id`, and `name` drift on each pool. `create_before_destroy` handles those changes as a non-destructive replacement (new pool first, then old pool drains).

**Do not add `moved` blocks** for the predecessor's `opentelekomcloud_compute_keypair_v2.cluster_keypair`, `tls_private_key.cluster_keypair`, `random_id.cluster_keypair_id`, `opentelekomcloud_kms_key_v1.node_storage_encryption_key`, or `random_id.id` - those intentionally don't migrate, and Terraform will destroy them automatically once the last pool referencing them has been replaced.

### GPU node pool migration

`cce-gpu-node-pool` bundled a node pool plus the `gpu-beta` addon. The successor split into a `cce-node-pool` instance and a `cce-addon` instance is shown in [Before / after at a glance](#gpu-node-pool--addon-cce-gpu-node-pool); add the corresponding `moved` blocks:

```hcl
moved {
  from = module.cce_gpu.opentelekomcloud_cce_node_pool_v3.cluster_node_pool["eu-de-03"]
  to   = module.cce_gpu_node_pool["eu-de-03"].opentelekomcloud_cce_node_pool_v3.node_pool
}

moved {
  from = module.cce_gpu.opentelekomcloud_cce_addon_v3.gpu[0]
  to   = module.cce_gpu_addon.opentelekomcloud_cce_addon_v3.addon
}
```

Setting `node_pool_name` explicitly forces the base name to match the predecessor's `${name_prefix}-gpu-${az}` pattern. Same as the regular pools: after the move, `create_before_destroy` replaces each pool to swap in the per-pool keypair and KMS key. The predecessor's shared keypair, KMS key, and the `gpu-beta` addon's old address are cleaned up by Terraform automatically.

### Variable rename table - `cce` predecessor

Top-level variables that changed name and/or moved to a different module. Tables are split by destination module so each column gets enough horizontal space for the longer identifier names.

#### To `cce-cluster`

| Predecessor variable | New variable | Notes |
| -------------------- | ------------ | ----- |
| `name` | `cluster_name` | |
| `autoscaler_version` | `addon_autoscaler_version` | New `addon_autoscaler_enabled` (default `true`) controls install. |
| `metrics_server_version` | `addon_metrics_server_version` | New `addon_metrics_server_enabled` (default `true`) controls install. |

All other `cluster_*` variables (`cluster_vpc_id`, `cluster_subnet_id`, `cluster_eni_subnet_id`, `cluster_security_group_id`, `cluster_highway_subnet_id`, `cluster_version`, `cluster_size`, `cluster_type`, `cluster_container_network_type`, `cluster_enable_volume_encryption`, `cluster_container_cidr`, `cluster_service_cidr`, `cluster_public_access`, `cluster_api_access_trustlist`, `cluster_high_availability`, `cluster_install_icagent`, `cluster_component_configurations`, `cluster_authentication_mode`, `cluster_authenticating_proxy_*`, `cluster_annotations`, `cluster_timezone`, `cluster_ipv6_enable`, `cluster_extend_param`) carry over to `cce-cluster` unchanged.

#### To `cce-node-pool`

| Predecessor variable | New variable | Notes |
| -------------------- | ------------ | ----- |
| `cluster_enable_scaling` | `node_pool_enable_scaling` | Now per-pool - the predecessor's flag toggled scaling cluster-wide. |
| `autoscaler_node_max` | `node_pool_node_count_max` | |
| `autoscaler_node_min` | `node_pool_node_count_min` | |
| `node_availability_zones` | `node_pool_availability_zone` | Set -> single string; caller now drives `for_each` over AZs. |
| `node_count` | `node_pool_node_count` | |
| `node_flavor` | `node_pool_flavor` | |
| `node_os` | `node_pool_os` | |
| `node_container_runtime` | `node_pool_container_runtime` | |
| `node_storage_type` | `node_pool_storage_type` | |
| `node_storage_size` | `node_pool_storage_size` | |
| `node_storage_encryption_enabled` | `node_pool_storage_encryption_enabled` | |
| `node_storage_encryption_kms_key_name` | `node_pool_storage_encryption_kms_key_name` | |
| `node_storage_runtime_size` | `node_pool_storage_runtime_size` | |
| `node_storage_kubernetes_size` | `node_pool_storage_kubernetes_size` | |
| `node_storage_remainder_path` | `node_pool_storage_remainder_path` | |
| `node_postinstall` | `node_pool_postinstall` | |
| `node_taints` | `node_pool_k8s_taints` | Same shape. |
| `node_k8s_tags` | `node_pool_k8s_labels` | Renamed: these are Kubernetes labels, not OTC tags. |

### Variable rename table - `cce-gpu-node-pool` predecessor

#### To `cce-node-pool`

| Predecessor variable | New variable | Notes |
| -------------------- | ------------ | ----- |
| `name_prefix` | `node_pool_name` | Set explicitly to `"${name_prefix}-gpu-${az}"` to preserve naming. |
| `cce_cluster_id` | `cluster_id` | |
| `node_availability_zones` | `node_pool_availability_zone` | Single string; caller now drives `for_each`. |
| `node_scaling_enabled` | `node_pool_enable_scaling` | |

All `node_*` variables (`node_flavor`, `node_count`, `node_os`, `node_container_runtime`, `node_storage_type`, `node_storage_size`, `node_storage_encryption_enabled`, `node_storage_encryption_kms_key_name`, `node_postinstall`, `node_taints`, `node_k8s_tags`) move to `cce-node-pool` with the `node_pool_` prefix - see the `cce` predecessor table above for the new names.

#### To `cce-addon`

| Predecessor variable | New variable | Notes |
| -------------------- | ------------ | ----- |
| `gpu_beta_enabled` | (none) | Toggle by including/excluding the `module "cce_gpu_addon"` block. |
| `gpu_beta_version` | `addon_version` | |
| `gpu_driver_url` | `addon_values_custom` | `{ is_driver_from_nvidia = true, nvidia_driver_download_url = ... }` |

### Behavior changes worth knowing

- **Per-pool keypair.** The predecessor shared one keypair across all pools; the new `cce-node-pool` generates one per pool unless `node_pool_keypair_name` is set. The migration recreates pools to adopt the new model; the old shared keypair is destroyed at the end of the apply.
- **Per-pool KMS key.** Same pattern as the keypair - one KMS key per pool unless `node_pool_storage_encryption_kms_key_name` references a shared one. The migration recreates pools; the old shared KMS key is destroyed and enters OTC's 7-day pending-delete queue.
- **Per-pool autoscaling toggle.** `node_pool_enable_scaling` is now configured per pool instead of cluster-wide; the predecessor's `cluster_enable_scaling` flipped scaling on every pool at once.
- **Caller-driven AZ fan-out.** Pools are now one module instance per AZ. Callers use `for_each = toset(["eu-de-02", "eu-de-03"])` rather than passing a set into the module.
- **Pool name suffix.** `cce-node-pool` adds an 8-character suffix (`<base>-<hex>`) that rotates whenever any `ForceNew` attribute changes; see [Rolling node pools](#rolling-node-pools) below.
- **New exposed knobs.** `node_pool_scale_down_cooldown_time`, `node_pool_scale_priority`, `node_pool_docker_base_size`, `node_pool_root_volume_size`, `node_pool_root_volume_type`, `node_pool_max_pods`, `node_pool_server_group_reference`, `node_pool_security_group_ids`, `node_pool_subnet_id` - all hardcoded in the predecessor, now configurable.
- **`cluster_public_access` default flipped to `false`.** The predecessor defaulted this to `true` (publicly exposed API server). The new `cce-cluster` defaults to `false` - set it explicitly if you relied on the old default.
- **`cluster_version` default bump.** Predecessor: `v1.31`. New: `v1.33`. Pin explicitly to stay on an older version.
- **`cluster_lb_public_ip` output removed.** It was a back-compat alias for `cluster_public_ip` (same value). Use `cluster_public_ip` directly.
- **`kubeconfig` output removed.** Identical alias for `kubeconfig_yaml`. Use `kubeconfig_yaml`.
- **`node_pools_names` (predecessor `cce`) replaced.** The single-pool `cce-node-pool` module exposes `node_pool_name` (singular). Aggregate across instances with `[for k, m in module.cce_node_pool : m.node_pool_name]`.

### Rolling node pools

`cce-node-pool` appends an 8-character suffix to the pool name (`<base>-<hex>`) driven by `random_id.node_pool_unique_suffix_id`. The suffix rotates whenever any of the pool's `ForceNew` attributes changes (flavor, OS, runtime, root volume, storage layout, encryption settings, keypair, etc.). `create_before_destroy` can then create the replacement pool with a distinct name. OTC rejects duplicate pool names within a cluster with HTTP 409, and this scheme sidesteps that without manual UI intervention.

The keypair and KMS key reference the unsuffixed base name (`local.node_pool_name_base`), so they stay stable across subsequent rollouts and don't get recreated as a side effect of an unrelated attribute change.

If the first post-migration plan shows anything besides the expected pool replacements (new + destroy on each AZ) plus the deletions of the predecessor's shared keypair / KMS resources, double-check the `moved` blocks and the variable values for drift before applying.
