provider "temporalcloud" {
  # Reads TEMPORAL_CLOUD_API_KEY from the environment.
}

locals {
  name = "ex-${basename(path.cwd)}"
}

################################################################################
# Minimal read-only role
#
# The smallest useful custom role: see every namespace in the account, change
# nothing. Two permissions rather than one, because listing namespaces and
# reading a namespace are actions on different resource types.
################################################################################

module "custom_role" {
  source  = "terraform-temporalcloud-modules/custom-role/temporalcloud"
  version = "~> 1.0"

  name        = local.name
  description = "Read-only access to every namespace in the account."

  permissions = [
    # `cloud.namespace.list` returns the account's namespaces, so it is granted
    # on `accounts`.
    {
      actions = ["cloud.namespace.list"]
      resources = {
        resource_type = "accounts"
        resource_ids  = []
        allow_all     = true
      }
    },

    # `cloud.namespace.get` reads one namespace, so it is granted on
    # `namespaces`. `allow_all = true` covers all of them; naming individual
    # namespaces instead means setting `resource_ids` and leaving `allow_all`
    # unset.
    {
      actions = ["cloud.namespace.get"]
      resources = {
        resource_type = "namespaces"
        resource_ids  = []
        allow_all     = true
      }
    },
  ]
}
