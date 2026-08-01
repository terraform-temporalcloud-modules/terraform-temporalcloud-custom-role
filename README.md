# Temporal Cloud Custom Role Terraform module

[![CI](https://github.com/terraform-temporalcloud-modules/terraform-temporalcloud-custom-role/actions/workflows/pre-commit.yml/badge.svg?branch=main)](https://github.com/terraform-temporalcloud-modules/terraform-temporalcloud-custom-role/actions/workflows/pre-commit.yml?query=branch%3Amain)
[![Apply Tests](https://github.com/terraform-temporalcloud-modules/terraform-temporalcloud-custom-role/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/terraform-temporalcloud-modules/terraform-temporalcloud-custom-role/actions/workflows/test.yml?query=branch%3Amain)

Terraform module which creates a [Temporal Cloud](https://temporal.io/cloud) custom role — a named set
of permissions that can be assigned to users, groups and service accounts in place of one of the
built-in account roles.

Both badges report the state of `main`. **CI** covers formatting, linting,
documentation and `terraform validate`, and runs on every pull request and again
after merge. **Apply Tests** creates and destroys real custom roles against a live
Temporal Cloud account, weekly and on demand — the only check that proves the API
accepts what this module sends.

## Requirements

The `temporalcloud` provider authenticates with an API key, read from the `TEMPORAL_CLOUD_API_KEY`
environment variable:

```bash
export TEMPORAL_CLOUD_API_KEY="<your-api-key>"
```

The provider authenticates when it initialises, so a key is needed even for a `terraform plan` that
would create nothing. Keep the key out of version control — an untracked `.env` file rather than a
committed `.tfvars`.

Creating a role grants nobody anything. Pass the `custom_role_id` output to `account_access_custom_roles`
on a `temporalcloud_user`, `temporalcloud_group_access` or `temporalcloud_service_account` for it to
take effect.

## Usage

### A read-only role

```hcl
module "namespace_reader" {
  source  = "terraform-temporalcloud-modules/custom-role/temporalcloud"
  version = "~> 1.0"

  name        = "namespace-reader"
  description = "Read any namespace in the account."

  permissions = [
    # Listing the account's namespaces is an `accounts` action...
    {
      actions = ["cloud.namespace.list"]
      resources = {
        resource_type = "accounts"
        resource_ids  = []
        allow_all     = true
      }
    },
    # ...while reading one is a `namespaces` action.
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
```

### Scoped to named namespaces

```hcl
module "orders_operator" {
  source  = "terraform-temporalcloud-modules/custom-role/temporalcloud"
  version = "~> 1.0"

  name        = "orders-operator"
  description = "Manage the orders namespaces and nothing else."

  permissions = [
    {
      actions = ["cloud.namespace.get", "cloud.namespace.update", "cloud.namespace.updateTags"]
      resources = {
        resource_type = "namespaces"
        # allow_all is omitted: it cannot be combined with resource_ids.
        resource_ids = [
          module.orders_prod.namespace_id,
          module.orders_staging.namespace_id,
        ]
      }
    },
  ]
}
```

### Assigning the role

```hcl
resource "temporalcloud_user" "analyst" {
  email          = "analyst@example.com"
  account_access = "read"

  account_access_custom_roles = [module.namespace_reader.custom_role_id]
}
```

## Writing permissions

A permission is one set of `actions` applied to one set of `resources`. Three things decide whether it
does what you meant.

### `resource_type` is plural and hyphenated

The accepted values are exactly:

```text
accounts   projects   namespaces   nexus-endpoints   connectivity-rules   custom-roles
```

The singular forms `account` and `namespace` are **not** accepted. This module rejects an unknown value
at plan; without that check, the API rejects it on apply.

### Exactly one of `allow_all` and `resource_ids`

`resource_ids` is a required attribute with no default, and `allow_all` is optional. They are mutually
exclusive, and one of them must effectively be set — which means an allow-all permission still has to
write the empty list out:

```hcl
# Every resource of the type.
resources = {
  resource_type = "namespaces"
  resource_ids  = []
  allow_all     = true
}

# Named resources only. Leave allow_all unset.
resources = {
  resource_type = "namespaces"
  resource_ids  = ["orders-prod.a1b2c"]
}
```

Getting it wrong fails at plan with one of:

```text
resource_ids must be empty when allow_all is true.
allow_all cannot be true when resource_ids contains values.
allow_all must be true when resource_ids is empty.
```

Every ID in `resource_ids` must already exist in the account; an unknown one is rejected at apply.

### Each action belongs to one resource type

Action strings look like `cloud.namespace.get`, and each is valid against exactly one resource type.
The pairing is not always the obvious one — `cloud.namespace.list` returns the account's namespaces and
is an `accounts` action, while `cloud.namespace.get` reads one and is a `namespaces` action.

Pairing an action with the wrong resource type is **accepted** by the API and produces a role that
grants nothing. There is no error to notice, so check each action against the
[Custom Role permissions reference](https://docs.temporal.io/cloud/manage-access/permissions-reference#custom-role-permissions-reference),
which lists the resource type for every action.

This module validates only that actions begin with `cloud.`, deliberately: the action list grows with
the Cloud Ops API, and an allowlist here would reject new actions until this module cut a release.

## Notes

Behaviours worth knowing before you plan:

- **An update replaces the whole permission set.** Anything omitted from `permissions` is revoked, not
  left alone. Always send the complete list.
- **Role names are not unique within an account.** Two roles may share a name, so a duplicated module
  call creates a second role rather than failing. The `custom_role_id` output is the only stable
  handle.
- **A role can hold at most 20 permissions**, and the description at most 256 characters. Both are
  checked at plan by this module.
- **Deleting a role revokes it from everyone it was assigned to**, immediately and irreversibly.
- **Custom roles cannot be listed from Terraform.** The provider offers no data source for them, so a
  role created outside Terraform can only be found in the Temporal Cloud UI under Settings > Custom
  Roles.

## Examples

- [complete](examples/complete) — permissions spanning four resource types, with both allow-all and
  ID-scoped entries
- [read-only](examples/read-only) — the smallest useful role: read every namespace, change nothing

## Managing several custom roles

The [`wrappers`](wrappers) submodule creates many roles from one call, for use with Terragrunt or
anywhere a `for_each` on the module block is awkward:

```hcl
module "custom_roles" {
  source  = "terraform-temporalcloud-modules/custom-role/temporalcloud//wrappers"
  version = "~> 1.0"

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

    nexus_operator = {
      name = "nexus-operator"
      permissions = [
        {
          actions   = ["cloud.nexusendpoint.get", "cloud.nexusendpoint.update"]
          resources = { resource_type = "nexus-endpoints", resource_ids = [], allow_all = true }
        },
      ]
    }
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.7 |
| <a name="requirement_temporalcloud"></a> [temporalcloud](#requirement\_temporalcloud) | >= 1.6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_temporalcloud"></a> [temporalcloud](#provider\_temporalcloud) | >= 1.6.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [temporalcloud_custom_role.this](https://registry.terraform.io/providers/temporalio/temporalcloud/latest/docs/resources/custom_role) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_create_custom_role"></a> [create\_custom\_role](#input\_create\_custom\_role) | Controls if the custom role should be created. Set to `false` to disable the module without removing the call | `bool` | `true` | no |
| <a name="input_description"></a> [description](#input\_description) | Description of the custom role, up to 256 characters | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | The name of the custom role. Up to 64 characters of letters, numbers, hyphens and underscores. Names are not unique within an account, so two roles may share one. Required unless `create_custom_role` is `false` | `string` | `""` | no |
| <a name="input_permissions"></a> [permissions](#input\_permissions) | Permissions granted by the role, as a list of `{ actions, resources }` entries. At least one is<br/>required and a role may hold at most 20. Updating this variable replaces the role's whole<br/>permission set, so every permission to keep must be listed.<br/><br/>`actions` is a set of Temporal Cloud action strings such as `cloud.namespace.get`; see the<br/>[Custom Role permissions reference](https://docs.temporal.io/cloud/manage-access/permissions-reference#custom-role-permissions-reference).<br/>Each action is only valid against the resource type that reference lists for it — for example<br/>`cloud.namespace.list` is an `accounts` action while `cloud.namespace.get` is a `namespaces` one.<br/><br/>`resources.resource_type` is one of `accounts`, `projects`, `namespaces`, `nexus-endpoints`,<br/>`connectivity-rules` or `custom-roles`. These are plural and hyphenated; the singular forms<br/>`account` and `namespace` are rejected.<br/><br/>`resources.resource_ids` and `resources.allow_all` are mutually exclusive and exactly one must be<br/>supplied. To grant a permission over every resource of the type, set `allow_all = true` and pass<br/>`resource_ids = []` — `resource_ids` has no default, so the empty list must be written out. To<br/>scope the permission, list the IDs and leave `allow_all` unset. Each ID must already exist in the<br/>account.<br/><br/>Required unless `create_custom_role` is `false`. | <pre>list(object({<br/>    actions = set(string)<br/>    resources = object({<br/>      allow_all     = optional(bool)<br/>      resource_ids  = set(string)<br/>      resource_type = string<br/>    })<br/>  }))</pre> | `[]` | no |
| <a name="input_timeouts"></a> [timeouts](#input\_timeouts) | Create, update and delete timeouts, as duration strings such as `30s` or `2h45m` | <pre>object({<br/>    create = optional(string)<br/>    update = optional(string)<br/>    delete = optional(string)<br/>  })</pre> | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_custom_role_description"></a> [custom\_role\_description](#output\_custom\_role\_description) | The description of the custom role |
| <a name="output_custom_role_id"></a> [custom\_role\_id](#output\_custom\_role\_id) | The unique identifier of the custom role. This is the value to pass to `account_access_custom_roles` on a user, group or service account |
| <a name="output_custom_role_name"></a> [custom\_role\_name](#output\_custom\_role\_name) | The name of the custom role |
| <a name="output_custom_role_permissions"></a> [custom\_role\_permissions](#output\_custom\_role\_permissions) | The permissions the role grants, as returned by Temporal Cloud |
| <a name="output_custom_role_state"></a> [custom\_role\_state](#output\_custom\_role\_state) | The current state of the custom role, for example `active` |
<!-- END_TF_DOCS -->

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the development workflow, how the test layers are arranged,
and the Temporal Cloud API behaviours the tests exist to guard against.

## License

Apache-2.0 licensed. See [LICENSE](LICENSE).
