# Wrapper for the Temporal Cloud custom role module

The configuration in `wrappers/` implements the single module wrapper pattern, which allows managing
several copies of this module from one call in places where the native `for_each` on a module block is
not available — most commonly Terragrunt.

This wrapper adds no functionality of its own. Every key under `items` accepts any input the root
module accepts, and `defaults` supplies values shared by all items.

Contributors: see [CONTRIBUTING.md](../CONTRIBUTING.md) for how these files are maintained.

## Usage with Terraform

```hcl
module "custom_roles" {
  source = "terraform-temporalcloud-modules/custom-role/temporalcloud//wrappers"

  # Shared by every item unless the item overrides it.
  defaults = {
    timeouts = {
      create = "5m"
    }
  }

  items = {
    namespace_reader = {
      name        = "namespace-reader"
      description = "Read any namespace in the account"

      permissions = [
        {
          actions = ["cloud.namespace.list"]
          resources = {
            resource_type = "accounts"
            resource_ids  = []
            allow_all     = true
          }
        },
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

    nexus_operator = {
      name        = "nexus-operator"
      description = "Manage Nexus endpoints"

      permissions = [
        {
          actions = ["cloud.nexusendpoint.get", "cloud.nexusendpoint.update"]
          resources = {
            resource_type = "nexus-endpoints"
            resource_ids  = []
            allow_all     = true
          }
        },
      ]
    }
  }
}
```

Outputs are keyed by the same map keys:

```hcl
output "namespace_reader_role_id" {
  value = module.custom_roles.wrapper["namespace_reader"].custom_role_id
}
```

## Usage with Terragrunt

`terragrunt.hcl`:

```hcl
terraform {
  source = "tfr:///terraform-temporalcloud-modules/custom-role/temporalcloud//wrappers?version=1.0.0"
  # Alternative source:
  # source = "git::git@github.com:terraform-temporalcloud-modules/terraform-temporalcloud-custom-role.git//wrappers?ref=v1.0.0"
}

inputs = {
  items = {
    namespace_reader = {
      name = "namespace-reader"
      permissions = [
        {
          actions   = ["cloud.namespace.get"]
          resources = { resource_type = "namespaces", resource_ids = [], allow_all = true }
        },
      ]
    }
  }
}
```

Pin `?version=` / `?ref=` to a released tag rather than a branch, so a wrapper upgrade is a deliberate
change.

## Inputs

| Name | Description | Type | Default |
| ---- | ----------- | ---- | ------- |
| `defaults` | Default values applied to every custom role in `items`, unless that item overrides them | `any` | `{}` |
| `items` | Map of custom roles to create; each key becomes an instance of the module | `any` | `{}` |

## Outputs

| Name | Description |
| ---- | ----------- |
| `wrapper` | Map of module outputs, keyed by the same keys as `items` |
