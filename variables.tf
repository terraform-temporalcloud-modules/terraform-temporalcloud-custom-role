variable "create_custom_role" {
  description = "Controls if the custom role should be created. Set to `false` to disable the module without removing the call"
  type        = bool
  default     = true
}

################################################################################
# Custom role
################################################################################

variable "name" {
  description = "Required when `create_custom_role` is `true`. The name of the custom role. Up to 64 characters of letters, numbers, hyphens and underscores. Names are not unique within an account, so two roles may share one. Nothing rejects the empty default, so an omitted name reaches the API as an empty one"
  type        = string
  default     = ""

  # Mirrors the API's constraint so a malformed name fails during plan rather
  # than after a round trip to Temporal Cloud.
  validation {
    condition     = var.name == "" || can(regex("^[A-Za-z0-9_-]{1,64}$", var.name))
    error_message = "The custom role name must be 1-64 characters and contain only letters, numbers, hyphens and underscores."
  }
}

variable "description" {
  description = "Optional. Description of the custom role, up to 256 characters. Left out, the role is created with an empty description"
  type        = string
  default     = null

  validation {
    condition     = try(length(var.description) <= 256, true)
    error_message = "The custom role description must be at most 256 characters."
  }
}

variable "permissions" {
  description = <<-EOT
    Required when `create_custom_role` is `true`. Permissions granted by the role, as a list of
    `{ actions, resources }` entries. At least one is required and a role may hold at most 20.
    Updating this variable replaces the role's whole permission set, so every permission to keep must
    be listed.

    Within an entry, only `resources.allow_all` may be left out: `actions`, `resources`,
    `resources.resource_type` and `resources.resource_ids` are all required.

    `actions` is a set of Temporal Cloud action strings such as `cloud.namespace.get`; see the
    [Custom Role permissions reference](https://docs.temporal.io/cloud/manage-access/permissions-reference#custom-role-permissions-reference).
    An action is only valid against the resource types that reference lists for it — for example
    `cloud.namespace.list` is listed against `accounts` and `projects`, while `cloud.namespace.get` is
    listed against `namespaces`. The pairing is not validated here or by the provider.

    `resources.resource_type` is one of `accounts`, `projects`, `namespaces`, `nexus-endpoints`,
    `connectivity-rules` or `custom-roles`. These are plural and hyphenated; the singular forms
    `account` and `namespace` are rejected.

    `resources.resource_ids` and `resources.allow_all` are mutually exclusive and exactly one must be
    supplied. To grant a permission over every resource of the type, set `allow_all = true` and pass
    `resource_ids = []` — `resource_ids` has no default, so the empty list must be written out. To
    scope the permission, list the IDs and leave `allow_all` unset. Each ID must already exist in the
    account.
  EOT

  type = list(object({
    actions = set(string)
    resources = object({
      allow_all     = optional(bool)
      resource_ids  = set(string)
      resource_type = string
    })
  }))
  default = []

  validation {
    condition     = length(var.permissions) <= 20
    error_message = "A custom role may hold at most 20 permissions."
  }

  validation {
    condition     = alltrue([for p in var.permissions : length(p.actions) > 0])
    error_message = "Every permission must grant at least one action."
  }

  # Shape check only, not an allowlist: the set of actions grows with the Cloud
  # Ops API, so pinning the full list here would block new ones.
  validation {
    condition = alltrue(flatten([
      for p in var.permissions : [for a in p.actions : startswith(a, "cloud.")]
    ]))
    error_message = "Actions must be Temporal Cloud action strings beginning with \"cloud.\", for example \"cloud.namespace.get\"."
  }

  validation {
    condition = alltrue([
      for p in var.permissions : contains(
        ["accounts", "projects", "namespaces", "nexus-endpoints", "connectivity-rules", "custom-roles"],
        p.resources.resource_type
      )
    ])
    error_message = "Permission resource_type must be one of: accounts, projects, namespaces, nexus-endpoints, connectivity-rules, custom-roles. Note the plural, hyphenated form."
  }

  # Exactly one of allow_all and resource_ids: `!=` on two booleans is exclusive
  # or. coalesce() rather than try(), because an omitted allow_all is null, and
  # try() only catches errors.
  validation {
    condition = alltrue([
      for p in var.permissions :
      coalesce(p.resources.allow_all, false) != (length(p.resources.resource_ids) > 0)
    ])
    error_message = "Each permission must set either allow_all = true with resource_ids = [], or a non-empty resource_ids with allow_all unset. Setting both, or neither, is rejected."
  }
}

variable "timeouts" {
  description = "Optional. Create, update and delete timeouts, as duration strings such as `30s` or `2h45m`. Left out, the provider's own defaults apply"
  type = object({
    create = optional(string)
    update = optional(string)
    delete = optional(string)
  })
  default = {}
}
