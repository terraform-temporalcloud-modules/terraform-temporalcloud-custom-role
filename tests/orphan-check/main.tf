# Reports namespace fixtures the test suite left behind.
#
# Creates nothing: a data source and outputs only. `terraform test` destroys what
# it creates, but a cancelled or crashed run can leave the namespace fixture
# behind, and nothing else would notice.
#
# Custom roles themselves cannot be checked. The provider exposes no data source
# that enumerates them — see the full data source list in the provider docs — so
# a leftover role is invisible to Terraform and has to be found in the Temporal
# Cloud UI under Settings > Custom Roles. Roles created by this suite carry the
# same `yulei-tftest-role-` prefix as the namespace fixture, so anything reported here
# is a hint that a role of the same name may also be orphaned.
#
# Run after the apply tests. Anything reported here is a leftover.

data "temporalcloud_namespaces" "all" {}

locals {
  orphans = [
    for n in data.temporalcloud_namespaces.all.namespaces : n.name
    if startswith(n.name, var.test_namespace_prefix)
  ]
}
