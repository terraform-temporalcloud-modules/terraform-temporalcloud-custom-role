provider "temporalcloud" {
  # Reads TEMPORAL_CLOUD_API_KEY from the environment.
}

################################################################################
# Local regression coverage
#
# The examples/ directories source the PUBLISHED module so they are copy-pasteable
# for consumers. That means they validate the last release, not the code in this
# repo — a renamed or removed variable would slip through CI unnoticed.
#
# This directory closes that gap: it sources the module by relative path and
# passes EVERY input, so `terraform validate` fails here the moment the variable
# surface changes incompatibly. CI picks it up automatically because it contains a
# versions.tf with required_version.
#
# When you add a variable to the root module, add it here in the same PR. Adding
# it to examples/ has to wait until the next release publishes it.
################################################################################

# Every input the module accepts, and every shape `permissions` supports.
module "all_inputs" {
  source = "../../"

  create_custom_role = true

  name        = "yulei-tflocal-role"
  description = "Local regression coverage for every module input."

  permissions = [
    # allow_all over an account-scoped type.
    {
      actions = ["cloud.account.get", "cloud.user.list"]
      resources = {
        resource_type = "accounts"
        resource_ids  = []
        allow_all     = true
      }
    },
    # allow_all over a namespace-scoped type.
    {
      actions = ["cloud.namespace.get"]
      resources = {
        resource_type = "namespaces"
        resource_ids  = []
        allow_all     = true
      }
    },
    # Scoped by ID, with allow_all omitted entirely.
    {
      actions = ["cloud.namespace.update"]
      resources = {
        resource_type = "namespaces"
        resource_ids  = ["yulei-tflocal.a1b2c"]
      }
    },
    # Scoped by ID, with allow_all explicitly false.
    {
      actions = ["cloud.nexusendpoint.update"]
      resources = {
        allow_all     = false
        resource_type = "nexus-endpoints"
        resource_ids  = ["endpoint-id"]
      }
    },
    # The two remaining resource types, so all six are exercised.
    {
      actions = ["cloud.namespace.create"]
      resources = {
        resource_type = "projects"
        resource_ids  = []
        allow_all     = true
      }
    },
    {
      actions = ["cloud.connectivityrule.get"]
      resources = {
        resource_type = "connectivity-rules"
        resource_ids  = []
        allow_all     = true
      }
    },
    {
      actions = ["cloud.customrole.get", "cloud.customrole.update"]
      resources = {
        resource_type = "custom-roles"
        resource_ids  = []
        allow_all     = true
      }
    },
  ]

  timeouts = {
    create = "10m"
    update = "10m"
    delete = "10m"
  }
}

# The create flag off: proves the module produces no resources and that every
# output still evaluates via its try() fallback.
module "disabled" {
  source = "../../"

  create_custom_role = false
}

# Minimum viable call: only the two inputs a role cannot be created without.
module "minimal" {
  source = "../../"

  name = "yulei-tflocal-minimal"

  permissions = [
    {
      actions = ["cloud.namespace.list"]
      resources = {
        resource_type = "accounts"
        resource_ids  = []
        allow_all     = true
      }
    },
  ]
}

# The wrapper, exercised through the local path as well.
module "wrapper" {
  source = "../../wrappers"

  defaults = {
    description = "Created by the local regression suite."
  }

  items = {
    reader = {
      name = "yulei-tflocal-reader"

      permissions = [
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

    writer = {
      name        = "yulei-tflocal-writer"
      description = "Overrides the shared default above."

      permissions = [
        {
          actions = ["cloud.namespace.update"]
          resources = {
            resource_type = "namespaces"
            resource_ids  = []
            allow_all     = true
          }
        },
      ]
    }
  }
}
