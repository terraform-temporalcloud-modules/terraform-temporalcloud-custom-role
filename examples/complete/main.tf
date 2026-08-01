provider "temporalcloud" {
  # Reads TEMPORAL_CLOUD_API_KEY from the environment.
}

locals {
  name = "ex-${basename(path.cwd)}"

  # Account-wide permissions. `resource_ids = []` with `allow_all = true` is how
  # a permission covers every resource of its type; the two are mutually
  # exclusive and exactly one must be supplied.
  account_wide_permissions = [
    # Read the account itself, and list what it contains. The `list` actions are
    # account-scoped even though they return namespaces and endpoints.
    {
      actions = [
        "cloud.account.get",
        "cloud.namespace.list",
        "cloud.nexusendpoint.list",
        "cloud.region.list",
        "cloud.user.list",
      ]
      resources = {
        resource_type = "accounts"
        resource_ids  = []
        allow_all     = true
      }
    },

    # Namespace-scoped read. `cloud.namespace.get` is a namespaces action, unlike
    # `cloud.namespace.list` above.
    {
      actions = [
        "cloud.namespace.get",
        "cloud.namespace.getUserNamespaceAssignments",
      ]
      resources = {
        resource_type = "namespaces"
        resource_ids  = []
        allow_all     = true
      }
    },

    # Nexus endpoints, read and update but not delete.
    {
      actions = [
        "cloud.nexusendpoint.get",
        "cloud.nexusendpoint.update",
      ]
      resources = {
        resource_type = "nexus-endpoints"
        resource_ids  = []
        allow_all     = true
      }
    },

    # Connectivity rules, read only.
    {
      actions = ["cloud.connectivityrule.get"]
      resources = {
        resource_type = "connectivity-rules"
        resource_ids  = []
        allow_all     = true
      }
    },
  ]

  # A permission scoped to named namespaces rather than all of them. Every ID
  # must already exist in the account, so this entry is only added when
  # `scoped_namespace_ids` is supplied — see variables.tf.
  scoped_permissions = length(var.scoped_namespace_ids) > 0 ? [
    {
      actions = [
        "cloud.namespace.update",
        "cloud.namespace.updateTags",
      ]
      resources = {
        resource_type = "namespaces"
        resource_ids  = var.scoped_namespace_ids
        # allow_all is deliberately unset: it cannot be combined with resource_ids.
      }
    },
  ] : []
}

################################################################################
# Complete: permissions spanning several resource types
################################################################################

module "custom_role" {
  source  = "terraform-temporalcloud-modules/custom-role/temporalcloud"
  version = "~> 1.0"

  name        = local.name
  description = "Platform operator: reads the account, manages Nexus endpoints, updates named namespaces."

  # Updating this list replaces the role's whole permission set — anything left
  # out is revoked.
  permissions = concat(local.account_wide_permissions, local.scoped_permissions)

  timeouts = {
    create = "5m"
    update = "5m"
    delete = "5m"
  }
}
