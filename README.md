# Temporal Cloud Custom Role Terraform module

[![CI](https://github.com/terraform-temporalcloud-modules/terraform-temporalcloud-custom-role/actions/workflows/pre-commit.yml/badge.svg?branch=main)](https://github.com/terraform-temporalcloud-modules/terraform-temporalcloud-custom-role/actions/workflows/pre-commit.yml?query=branch%3Amain)
[![Apply Tests](https://github.com/terraform-temporalcloud-modules/terraform-temporalcloud-custom-role/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/terraform-temporalcloud-modules/terraform-temporalcloud-custom-role/actions/workflows/test.yml?query=branch%3Amain)

Terraform module which creates a [Temporal Cloud](https://temporal.io/cloud) custom role — a named set
of permissions that can be assigned to users, groups and service accounts in place of one of the
built-in account roles.

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

Worth knowing if you start from the provider's own page: the `temporalcloud_custom_role` example
published with provider v1.6.0 uses `resource_type = "account"`, which does not work. Upstream
[corrected it after v1.6.0](https://github.com/temporalio/terraform-provider-temporalcloud/commit/03c4287c)
— "the provider example used `account` but the Cloud Ops API expects plural kebab-case values like
`accounts`" — and added the same six-value check to the provider itself.

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

Getting it wrong fails at plan, before anything is sent to Temporal Cloud:

```text
Each permission must set either allow_all = true with resource_ids = [], or a non-empty
resource_ids with allow_all unset. Setting both, or neither, is rejected.
```

The provider enforces the same rule independently, so the constraint holds whether or not a
configuration goes through this module.

Every ID in `resource_ids` must already exist in the account; an unknown one is rejected at apply.

### Actions are scoped to a resource type

Action strings look like `cloud.namespace.get`. An action is valid only against the resource types the
[Custom Role permissions reference](https://docs.temporal.io/cloud/manage-access/permissions-reference#custom-role-permissions-reference)
lists for it, and the pairing is not always the obvious one — `cloud.namespace.list` returns the
account's namespaces and so is listed against `accounts` and `projects`, while `cloud.namespace.get`
reads a single namespace and is listed against `namespaces`. Most actions map to one resource type;
a few, all of them `list` actions, map to two.

Neither this module nor the provider checks the pairing, so look each action up in that reference
rather than inferring its resource type from its name.

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

## Which inputs are required

The generated table below reports `Required: no` for every input. That is a property of the
`create_custom_role` gate rather than of the API: every input carries a default so that
`create_custom_role = false` switches the module off without values being supplied for attributes the
provider marks required. With the gate left on, the requirements are these.

### Always required

| Input | If you leave it out |
| --- | --- |
| `name` | Nothing local stops you: this module's name check accepts the empty default and the provider has no validator on `name`, so the create request carries an empty one. A name is required, and capped at 64 characters, by the [custom role documentation](https://docs.temporal.io/cloud/manage-access/custom-roles) |
| `permissions` | At least one entry is required, in the provider schema and in the documentation. The provider reports `Attribute permissions list must contain at least 1 elements, got: 0` |

### Conditionally required — the keys inside `permissions`

The generated table shows the *type* of `permissions` but not which keys within it may be left out.
Only `allow_all` may:

| Key | Required | Notes |
| --- | --- | --- |
| `actions` | yes | At least one. An empty set is refused by this module — `Every permission must grant at least one action.` — and by the provider |
| `resources` | yes | The object carrying the three keys below |
| `resources.resource_type` | yes | One of the six plural, hyphenated values above |
| `resources.resource_ids` | yes | **Written out even for an allow-all permission**, as `resource_ids = []`. It has no default, so omitting it fails at validate with `attribute "resources": attribute "resource_ids" is required.` |
| `resources.allow_all` | conditionally | `true` exactly when `resource_ids` is empty; omitted otherwise |

The last two are one rule, not two — see
[Exactly one of `allow_all` and `resource_ids`](#exactly-one-of-allow_all-and-resource_ids) for the two
shapes and the errors each mistake produces.

### Optional

- **Wording** — `description`. Left out, the role is created with an empty description.
- **Timing** — `timeouts`. Left out, the provider's own create, update and delete timeouts apply.
- **The gate** — `create_custom_role`. Left at `true`, the role is created.

### Two caps this module applies itself

At most 20 permissions and a description of at most 256 characters. Neither is a provider check: both
are variable validations here, taken from the
[Custom Role limits](https://docs.temporal.io/cloud/limits#custom-role-limits) and the
[custom role documentation](https://docs.temporal.io/cloud/manage-access/custom-roles) respectively.
That page's Cloud CLI tab gives 25 permissions per role instead, as an account default that may vary;
this module holds to the 20 the limits page documents.

### `terraform validate` will not tell you a required input is missing

Values passed into a module are not resolved during the validate walk, so the provider's validators
never see them there: a call to this module with neither `name` nor `permissions` validates clean.
This module's own variable validations *do* run at validate — including the four `permissions` rules —
while the provider's checks wait for plan, which needs an API key.

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
| <a name="input_description"></a> [description](#input\_description) | Optional. Description of the custom role, up to 256 characters. Left out, the role is created with an empty description | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Required when `create_custom_role` is `true`. The name of the custom role. Up to 64 characters of letters, numbers, hyphens and underscores. Names are not unique within an account, so two roles may share one. Nothing rejects the empty default, so an omitted name reaches the API as an empty one | `string` | `""` | no |
| <a name="input_permissions"></a> [permissions](#input\_permissions) | Required when `create_custom_role` is `true`. Permissions granted by the role, as a list of<br/>`{ actions, resources }` entries. At least one is required and a role may hold at most 20.<br/>Updating this variable replaces the role's whole permission set, so every permission to keep must<br/>be listed.<br/><br/>Within an entry, only `resources.allow_all` may be left out: `actions`, `resources`,<br/>`resources.resource_type` and `resources.resource_ids` are all required.<br/><br/>`actions` is a set of Temporal Cloud action strings such as `cloud.namespace.get`; see the<br/>[Custom Role permissions reference](https://docs.temporal.io/cloud/manage-access/permissions-reference#custom-role-permissions-reference).<br/>An action is only valid against the resource types that reference lists for it — for example<br/>`cloud.namespace.list` is listed against `accounts` and `projects`, while `cloud.namespace.get` is<br/>listed against `namespaces`. The pairing is not validated here or by the provider.<br/><br/>`resources.resource_type` is one of `accounts`, `projects`, `namespaces`, `nexus-endpoints`,<br/>`connectivity-rules` or `custom-roles`. These are plural and hyphenated; the singular forms<br/>`account` and `namespace` are rejected.<br/><br/>`resources.resource_ids` and `resources.allow_all` are mutually exclusive and exactly one must be<br/>supplied. To grant a permission over every resource of the type, set `allow_all = true` and pass<br/>`resource_ids = []` — `resource_ids` has no default, so the empty list must be written out. To<br/>scope the permission, list the IDs and leave `allow_all` unset. Each ID must already exist in the<br/>account. | <pre>list(object({<br/>    actions = set(string)<br/>    resources = object({<br/>      allow_all     = optional(bool)<br/>      resource_ids  = set(string)<br/>      resource_type = string<br/>    })<br/>  }))</pre> | `[]` | no |
| <a name="input_timeouts"></a> [timeouts](#input\_timeouts) | Optional. Create, update and delete timeouts, as duration strings such as `30s` or `2h45m`. Left out, the provider's own defaults apply | <pre>object({<br/>    create = optional(string)<br/>    update = optional(string)<br/>    delete = optional(string)<br/>  })</pre> | `{}` | no |

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
