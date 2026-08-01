// Main lifecycle: create a custom role, then update it in place twice.
//
// Creates ONE role and updates it across run blocks rather than one per case.
// Run blocks share state within a file, so a later block with different
// variables updates the role instead of creating another — which is also how the
// "an update replaces the whole permission set" behaviour gets proved.
//
// terraform test destroys everything it created when the file finishes, including
// after a failed assertion.

provider "temporalcloud" {
  // Reads TEMPORAL_CLOUD_API_KEY from the environment. The module under test
  // declares no provider block, by design for a published module, so the test
  // supplies one.
}

run "setup" {
  module {
    source = "./tests/setup"
  }

  variables {
    // Needed by update_permissions below: Temporal Cloud rejects a resource ID
    // that does not exist in the account, so a permission scoped by
    // resource_ids cannot be applied without a real namespace.
    create_namespace_fixture = true
  }
}

run "create_role" {
  variables {
    name        = run.setup.role_name
    description = "Created by the apply test suite."

    permissions = [
      {
        actions = ["cloud.account.get", "cloud.user.list"]
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

    timeouts = {
      create = "5m"
      update = "5m"
      delete = "5m"
    }
  }

  assert {
    condition     = output.custom_role_id != ""
    error_message = "custom_role_id is empty, so the role was not created"
  }

  assert {
    condition     = output.custom_role_name == run.setup.role_name
    error_message = "custom_role_name output did not echo the requested name"
  }

  assert {
    condition     = output.custom_role_description == "Created by the apply test suite."
    error_message = "custom_role_description did not round-trip through the API"
  }

  assert {
    condition     = output.custom_role_state != ""
    error_message = "custom_role_state is empty; the API reported no state for the role"
  }

  // length(), not ==: the output comes from try(..., []) so it is a tuple,
  // which never compares equal to a list.
  assert {
    condition     = length(output.custom_role_permissions) == 2
    error_message = "expected 2 permissions, got ${length(output.custom_role_permissions)}"
  }

  // Order within the returned list is not guaranteed, so match by content.
  //
  // `actions` is checked as well as `resource_type`: a permission that came back
  // with the right resource type but its actions dropped would satisfy a
  // resource_type-only assertion. setsubtract() rather than an equality check, so
  // the assertion still holds if the API ever returns implied actions in addition
  // to the requested ones.
  assert {
    condition = anytrue([
      for p in output.custom_role_permissions :
      p.resources.resource_type == "accounts" &&
      length(setsubtract(["cloud.account.get", "cloud.user.list"], p.actions)) == 0
    ])
    error_message = "no permission came back with resource_type 'accounts' carrying both requested actions"
  }

  assert {
    condition = anytrue([
      for p in output.custom_role_permissions :
      p.resources.resource_type == "namespaces" &&
      length(setsubtract(["cloud.namespace.get"], p.actions)) == 0
    ])
    error_message = "no permission came back with resource_type 'namespaces' carrying the requested action"
  }
}

// Updates the SAME role: new description, and a third permission scoped to a
// real namespace by resource_ids rather than allow_all.
run "update_permissions" {
  variables {
    name        = run.setup.role_name
    description = "Updated by the apply test suite."

    permissions = [
      {
        actions = ["cloud.account.get", "cloud.user.list"]
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
      // Scoped by ID. allow_all is omitted: the two are mutually exclusive and
      // setting both is rejected.
      {
        actions = ["cloud.namespace.update", "cloud.namespace.updateTags"]
        resources = {
          resource_type = "namespaces"
          resource_ids  = [run.setup.namespace_id]
        }
      },
    ]

    timeouts = {
      create = "5m"
      update = "5m"
      delete = "5m"
    }
  }

  // Updating must not have replaced the role.
  assert {
    condition     = output.custom_role_id == run.create_role.custom_role_id
    error_message = "the role was replaced rather than updated in place"
  }

  assert {
    condition     = output.custom_role_description == "Updated by the apply test suite."
    error_message = "the updated description did not round-trip through the API"
  }

  assert {
    condition     = length(output.custom_role_permissions) == 3
    error_message = "expected 3 permissions after the update, got ${length(output.custom_role_permissions)}"
  }

  // The scoped permission kept both the namespace ID and the actions it was
  // given. Matching on the ID alone would pass for an entry that arrived scoped
  // correctly but empty.
  assert {
    condition = anytrue([
      for p in output.custom_role_permissions :
      try(contains(p.resources.resource_ids, run.setup.namespace_id), false) &&
      length(setsubtract(["cloud.namespace.update", "cloud.namespace.updateTags"], p.actions)) == 0
    ])
    error_message = "no permission came back scoped to the namespace fixture's ID with both requested actions"
  }
}

// An update replaces the whole permission set rather than merging into it.
// Shrinking to one permission must leave exactly one behind.
run "shrink_permissions" {
  variables {
    name        = run.setup.role_name
    description = "Updated by the apply test suite."

    permissions = [
      {
        actions = ["cloud.account.get"]
        resources = {
          resource_type = "accounts"
          resource_ids  = []
          allow_all     = true
        }
      },
    ]

    timeouts = {
      create = "5m"
      update = "5m"
      delete = "5m"
    }
  }

  assert {
    condition     = output.custom_role_id == run.create_role.custom_role_id
    error_message = "the role was replaced rather than updated in place"
  }

  assert {
    condition     = length(output.custom_role_permissions) == 1
    error_message = "an update should replace the permission set, but ${length(output.custom_role_permissions)} permissions remain"
  }

  // Not just the count: the survivor must be the permission this block asked
  // for. One stale permission left behind from the previous set would also leave
  // exactly one. alltrue() over a list already asserted to hold one element
  // makes this an exact match.
  assert {
    condition = alltrue([
      for p in output.custom_role_permissions :
      p.resources.resource_type == "accounts" && contains(p.actions, "cloud.account.get")
    ])
    error_message = "the permission left after the update is not the one the update requested"
  }
}
