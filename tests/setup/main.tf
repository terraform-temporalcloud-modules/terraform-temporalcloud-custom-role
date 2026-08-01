# Generates a unique name per test run.
#
# Custom role names are NOT unique within an account — two roles may share one —
# so a fixed name would not fail outright, it would quietly accumulate duplicates
# that nothing can tell apart afterwards. A random suffix keeps every run
# identifiable, and keeps the namespace fixture below from colliding, since
# namespace names *are* unique per account.
resource "random_pet" "this" {
  length    = 2
  separator = "-"
}

# Regions this account is entitled to use.
#
# Not hardcoded: the regions an account may use are a subset of the published
# list, so a fixed ID makes the suite account-specific and can fail with
# "is not a valid Temporal Cloud region".
data "temporalcloud_regions" "available" {}

locals {
  # Sorted so repeat runs pick the same region and results stay comparable.
  region_ids = sort([for r in data.temporalcloud_regions.available.regions : r.id])
}

# A real namespace, for the permission scoped by `resource_ids`.
#
# Temporal Cloud rejects a resource ID that does not exist in the account, and no
# data source enumerates namespaces guaranteed to be present, so the scoped
# permission cannot be tested without creating one. Off by default: only the run
# block that needs it pays for it.
resource "temporalcloud_namespace" "fixture" {
  count = var.create_namespace_fixture ? 1 : 0

  name           = "yulei-tftest-${random_pet.this.id}"
  regions        = [local.region_ids[0]]
  retention_days = 1
  api_key_auth   = true
}
