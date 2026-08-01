locals {
  create_custom_role = var.create_custom_role
}

################################################################################
# Custom role
#
# `permissions` is a nested attribute list in the provider schema, and each
# entry's `resources` is a nested attribute in turn — neither is a block, so both
# are assigned straight from the typed variable. `timeouts` is the only true
# block, hence the dynamic block below.
################################################################################

resource "temporalcloud_custom_role" "this" {
  count = local.create_custom_role ? 1 : 0

  name        = var.name
  description = var.description
  permissions = var.permissions

  dynamic "timeouts" {
    for_each = length([for v in var.timeouts : v if v != null]) > 0 ? [var.timeouts] : []

    content {
      create = timeouts.value.create
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }
}
