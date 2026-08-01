#!/usr/bin/env bash
#
# Fails if the test suite left its namespace fixture behind.
#
# `terraform test` destroys what it created, including after a failed assertion,
# but a cancelled or crashed run can orphan the namespace and nothing else would
# notice. Run this after the apply tests.
#
# Custom roles are NOT covered. The provider exposes no data source that
# enumerates them, so a leftover role cannot be detected from Terraform and has
# to be found in the Temporal Cloud UI. Test roles carry the same prefix as the
# namespace fixture, so the reminder below prints on every run rather than only
# on failure.
#
# Requires TEMPORAL_CLOUD_API_KEY. Creates nothing — tests/orphan-check contains a
# data source and outputs only.

set -euo pipefail

cd "$(git rev-parse --show-toplevel)/tests/orphan-check"

terraform init -backend=false -no-color >/dev/null
terraform apply -auto-approve -no-color >/dev/null

count="$(terraform output -raw orphan_count)"

role_note() {
  echo >&2
  echo "Custom roles cannot be checked automatically: the provider exposes no data" >&2
  echo "source that lists them. If a run was cancelled mid-apply, check Settings >" >&2
  echo "Custom Roles in the Temporal Cloud UI for anything named 'yulei-tftest-role-*'." >&2
}

if [ "$count" -eq 0 ]; then
  echo "No leftover test namespaces."
  role_note
  exit 0
fi

echo "ERROR: $count test namespace(s) still present after the suite finished:" >&2
terraform output -json orphans | sed 's/[][",]/ /g' | tr -s ' ' '\n' | sed '/^$/d;s/^/  - /' >&2
echo >&2
echo "These were not destroyed. Delete them in the Temporal Cloud UI, or import and" >&2
echo "destroy them. If any has delete protection enabled, turn that off first." >&2
role_note
exit 1
