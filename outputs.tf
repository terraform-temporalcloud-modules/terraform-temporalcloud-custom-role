################################################################################
# Custom role
#
# Outputs are wrapped in `try()` so they still evaluate to an empty value when
# `create_custom_role = false` leaves no resource to reference.
################################################################################

output "custom_role_id" {
  description = "The unique identifier of the custom role. This is the value to pass to `account_access_custom_roles` on a user, group or service account"
  value       = try(temporalcloud_custom_role.this[0].id, "")
}

output "custom_role_name" {
  description = "The name of the custom role"
  value       = try(temporalcloud_custom_role.this[0].name, "")
}

output "custom_role_description" {
  description = "The description of the custom role"
  value       = try(temporalcloud_custom_role.this[0].description, "")
}

output "custom_role_state" {
  description = "The current state of the custom role, for example `active`"
  value       = try(temporalcloud_custom_role.this[0].state, "")
}

output "custom_role_permissions" {
  description = "The permissions the role grants, as returned by Temporal Cloud"
  value       = try(temporalcloud_custom_role.this[0].permissions, [])
}
