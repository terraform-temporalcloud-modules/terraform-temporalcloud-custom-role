output "role_name" {
  description = "Unique custom role name for this test run, prefixed `yulei-tftest-role-` so leftovers from an interrupted run are identifiable in the Temporal Cloud account"
  # `yulei-` identifies the owner, `tftest-` distinguishes test roles from
  # anything created by hand. Satisfies the API's constraint: up to 64
  # characters of letters, numbers, hyphens and underscores.
  value = "yulei-tftest-role-${random_pet.this.id}"
}

output "namespace_id" {
  description = "ID of the namespace fixture, for use in a permission's `resource_ids`. Empty unless `create_namespace_fixture` is true"
  value       = try(temporalcloud_namespace.fixture[0].id, "")
}

output "namespace_name" {
  description = "Name of the namespace fixture. Empty unless `create_namespace_fixture` is true"
  value       = try(temporalcloud_namespace.fixture[0].name, "")
}

output "available_regions" {
  description = "Every region this account may use. Surfaced so a test run documents the account's actual entitlements, which differ from the published region list"
  value       = local.region_ids
}
