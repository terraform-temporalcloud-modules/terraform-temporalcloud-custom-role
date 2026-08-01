// The wrappers submodule: several roles from one call, with per-item overrides
// of the shared defaults.
//
// This is the only test that creates more than one role at a time, which is the
// behaviour it exists to verify. It needs no namespace fixture, so setup is left
// at its default and creates nothing billable.

provider "temporalcloud" {}

run "setup" {
  module {
    source = "./tests/setup"
  }
}

run "create_many" {
  module {
    source = "./wrappers"
  }

  variables {
    defaults = {
      description = "Created by the wrapper apply test."

      timeouts = {
        create = "5m"
        update = "5m"
        delete = "5m"
      }
    }

    items = {
      reader = {
        name = "${run.setup.role_name}-reader"

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
        name = "${run.setup.role_name}-nexus"
        // Overrides the shared default above.
        description = "Manages Nexus endpoints."

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

  assert {
    condition     = length(output.wrapper) == 2
    error_message = "expected 2 roles from the wrapper, got ${length(output.wrapper)}"
  }

  assert {
    condition     = output.wrapper["reader"].custom_role_name == "${run.setup.role_name}-reader"
    error_message = "the reader item did not take its own name"
  }

  // Shared defaults reach every item.
  assert {
    condition     = output.wrapper["reader"].custom_role_description == "Created by the wrapper apply test."
    error_message = "defaults.description did not reach the reader item"
  }

  // Per-item values override the defaults rather than merging with them.
  assert {
    condition     = output.wrapper["nexus_operator"].custom_role_description == "Manages Nexus endpoints."
    error_message = "the nexus_operator item did not override defaults.description"
  }

  assert {
    condition     = length(output.wrapper["reader"].custom_role_permissions) == 2
    error_message = "per-item permissions did not reach the reader item"
  }

  assert {
    condition     = output.wrapper["nexus_operator"].custom_role_id != ""
    error_message = "the nexus_operator item was not created"
  }
}
