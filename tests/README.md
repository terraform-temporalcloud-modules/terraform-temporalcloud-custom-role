# Tests

Not usage examples — see [examples/](../examples) for those.

## Known gap: the apply tests have never passed

Every run of `*.tftest.hcl` against the current test account has failed the same way:

```text
Error: Failed to create custom role
rpc error: code = PermissionDenied desc = request unauthorized
```

The `setup` run block creates a namespace successfully with the same API key, so the key does have
account-level write access — custom roles specifically are refused. That points at the key's role or
an account entitlement, not at this module.

**The Apply Tests badge is therefore red, deliberately.** Nothing below has been confirmed against a
live account, including the six `resource_type` values, which were verified from provider source
only.

**Do not "fix" this by converting the suite to plan-only, deleting a run block, or folding the
coverage into `tests/local/`.** The tests are correct and are kept as written on purpose: the day an
API key that can manage custom roles is available, running them unchanged is the entire point. A red
badge naming a real, understood gap is worth more than a green one that proves nothing. Everything
below describes coverage the suite *will* provide once it can run.

### The access the suite needs, and does not have

`TEMPORAL_CLOUD_API_KEY` is the only credential — nothing here needs a cloud provider account, a
SCIM integration or any other external access. What is missing is the **permission attached to that
key**:

| Requirement | Status on the current key |
| --- | --- |
| `cloud.customrole.create`, `.update` and `.delete` — the three calls the suite makes. Custom role administration [defaults to the Account Owner](https://docs.temporal.io/cloud/manage-access/custom-roles#delegating-custom-roles) and can be delegated, but Developer and Read-only never carry it | **Missing.** `PermissionDenied` at `CreateCustomRole` |
| Create and delete a namespace in one region, for the `setup` fixture | Present — the fixture applies and is torn down cleanly, so the orphan check stays green even on a failed run |

Custom roles are also still a **prerelease** feature, so an account may need them enabled at all
before any key can manage them. The failure alone does not distinguish "key lacks the permission"
from "account lacks the feature"; both are resolved by pointing the suite at an Account Owner key on
an account with custom roles enabled.

Until such a key exists, nothing about the API's own behaviour is verified: the six `resource_type`
values, `allow_all` versus `resource_ids`, the round trip of `actions`, whether an update replaces
the permission set rather than merging into it, the reported `state`, and whether a role is actually
deleted on teardown. All of those are asserted by the suite and none has ever executed.

| Path | Runs on | Credentials |
| --- | --- | --- |
| `local/` | every pull request | no |
| `*.tftest.hcl` | on demand, weekly | **yes** |
| `setup/` | helper for `*.tftest.hcl` | no |

`local/` passes every module input and references every output, so `terraform
validate` fails there as soon as the variable surface changes.

`*.tftest.hcl` applies against a real Temporal Cloud account, which is the only
way to catch the API rejecting a configuration that type-checks. Between them they
cover the whole module input surface:

| File | Covers |
| --- | --- |
| `custom_role.tftest.hcl` | Create a role with `allow_all` permissions on two resource types; update it in place to change the description and add a permission scoped by `resource_ids`; then shrink the permission set to prove an update replaces it rather than merging |
| `wrappers.tftest.hcl` | The `wrappers` submodule: two roles from one call, with per-item overrides |
| `disabled.tftest.hcl` | `create_custom_role = false` creates nothing and every output falls back |

Fixtures: `setup/` generates a unique role name and, when
`create_namespace_fixture` is true, creates a namespace whose ID the scoped
permission can point at. `orphan-check/` reports leftovers and creates nothing.

## Why the namespace fixture exists

Temporal Cloud rejects a `resource_ids` entry that does not name a resource
already in the account, so the scoped form of a permission cannot be applied
against a placeholder. No data source enumerates namespaces that are guaranteed
to be present on an arbitrary account, so the suite creates one rather than
borrowing one.

It is off by default and switched on only by the run block that needs it, so the
whole suite creates one namespace rather than one per file.

## What is not apply-tested

`timeouts` is passed on every run block but never exercised at its limits — a
5-minute create timeout is not reached in practice, so nothing proves the
duration is honoured. Only that the provider accepts the block.

The 20-permission cap and the 256-character description limit are enforced by
this module's variable validation, which runs before the provider is configured.
They are checked at plan rather than on apply, so no run block spends money
proving the API agrees.

## Cleanup has a gap

`terraform test` destroys what it created, including after a failed assertion,
but a cancelled or crashed run can orphan resources. The CI workflow runs
`scripts/check-orphans.sh` afterwards — always, including when the tests fail,
since that is when something is most likely to be left behind.

**It can only see the namespace fixture.** The provider exposes no data source
that enumerates custom roles, so a leftover role is invisible to Terraform. If a
run is cancelled mid-apply, check Settings > Custom Roles in the Temporal Cloud
UI by hand.

```bash
scripts/check-orphans.sh
```

Test resources are prefixed so they are identifiable:

| Prefix | Created by |
| --- | --- |
| `yulei-tftest-role-<random>` | `*.tftest.hcl` — both the roles and the namespace fixture |
| `yulei-tflocal-*` | `local/`, only if applied by hand — CI never applies it |

Anything matching those prefixes that no live configuration owns can be deleted.

Role names are not unique within an account, so a leftover role and a fresh one
can share a name. Delete by role ID where the UI offers it.

The `examples/` directories are not covered by this prefix; they create
`ex-complete` and `ex-read-only`. Example code is published to the Terraform
Registry, so it carries no test-specific naming. Check for those two separately if
you have applied an example by hand.

## Running the apply tests

```bash
export TEMPORAL_CLOUD_API_KEY="<key for a scratch account>"
terraform init
terraform test -verbose
```

Point them at a scratch account: they create and destroy **real, billable**
resources.

Without a key, every run block is skipped — a cheap way to confirm the test files
parse:

```text
Failure! 0 passed, 0 failed, 7 skipped.
```

[CONTRIBUTING.md](../CONTRIBUTING.md) explains why the layers are split this way
and which API behaviours they guard against.
