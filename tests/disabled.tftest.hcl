// Verifies create_custom_role = false against a real provider.
//
// Separate file so it gets its own state and cannot interfere with the role
// created in custom_role.tftest.hcl. Creates no resources, so it is cheap — but
// it still configures the provider, which is why it needs TEMPORAL_CLOUD_API_KEY.

provider "temporalcloud" {}

run "creates_nothing" {
  variables {
    create_custom_role = false
  }

  // Every output is count-gated behind try(); these assertions prove the
  // fallbacks evaluate rather than erroring when the module is switched off.
  assert {
    condition     = output.custom_role_id == ""
    error_message = "custom_role_id should fall back to empty when create_custom_role = false"
  }

  assert {
    condition     = output.custom_role_name == ""
    error_message = "custom_role_name should fall back to empty when create_custom_role = false"
  }

  assert {
    condition     = output.custom_role_description == ""
    error_message = "custom_role_description should fall back to empty"
  }

  assert {
    condition     = output.custom_role_state == ""
    error_message = "custom_role_state should fall back to empty"
  }

  assert {
    // length(), not == tolist([]): the output is an empty tuple, which never
    // compares equal to a list.
    condition     = length(output.custom_role_permissions) == 0
    error_message = "custom_role_permissions should fall back to an empty list"
  }
}
