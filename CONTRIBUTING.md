# Contributing

## Prerequisites

```bash
brew install pre-commit terraform-docs
brew install terraform-linters/tap/tflint
pre-commit install
```

Local tool versions must match the pins in
[`.github/workflows/pre-commit.yml`](.github/workflows/pre-commit.yml). terraform-docs changed its
markdown table style after v0.20.0, so a mismatch makes CI reject README tables that were generated
correctly on your machine. When you bump one side, bump the other in the same pull request.

## The gate

```bash
pre-commit run -a
```

This is what CI runs: `terraform fmt`, `terraform-docs`, `tflint`, `terraform validate`, plus two local
checks described below. Expect the first run after a change to *modify* files — terraform-docs rewrites
the README tables. Re-run until clean; it should pass twice in a row.

## Test layers

| Path | Runs on | Credentials | Proves |
| --- | --- | --- | --- |
| `examples/*` | every PR | no | The documented usage still type-checks against this code |
| `tests/local/` | every PR | no | Every input and output is still valid |
| `tests/*.tftest.hcl` | on demand, weekly | **yes** | Temporal Cloud accepts the payloads this module sends |

`terraform validate` is not a test: it never executes anything and never contacts the API. Only the
apply layer can catch the API rejecting a configuration that looks valid.

`terraform plan` is not a usable middle ground, because the provider authenticates when it initialises
and so needs a real key even for a plan that would create nothing.

Variable validation is the exception: it runs *before* the provider is configured, so a validation rule
can be exercised with a scratch config, `create_custom_role = false` and `terraform plan`. The
validation error appears alongside the provider's connection failure. That is how the four
`permissions` rules were checked against all of: both `allow_all` and `resource_ids` set, neither set,
`allow_all` omitted with IDs, and `allow_all = false` with IDs.

### Why examples are validated indirectly

`examples/*` source the **published** module so consumers can copy them verbatim from the Terraform
Registry. Validating them as written would check the last release rather than the working tree, which
would mean a module change and its example update could never land in the same pull request.

[`scripts/validate-examples.sh`](scripts/validate-examples.sh) resolves this: it copies each example to
a temporary directory, rewrites the registry source to a path to the repository root, and validates the
copy. Tracked files are never modified. `terraform_validate` excludes `examples/`, and the
`examples-validate` hook covers them instead.

One consequence: examples are validated only on the maximum supported Terraform version, because the
exclusion also removes them from the minimum-version matrix jobs. The root module and `tests/local/`
are still checked against the minimum, which is what `required_version` asserts.

### Why `wrappers/` is hand-maintained

The upstream `terraform_wrapper_module_for_each` pre-commit hook is not enabled. It hardcodes
`terraform-aws-modules` and `aws` in the source addresses it generates, and it overwrites
`wrappers/README.md` on every run with an Amazon S3 example whose inputs do not exist in this module.
It offers no way to skip that file, so restoring a correct one leaves the gate permanently dirty.

[`scripts/check-wrapper-sync.sh`](scripts/check-wrapper-sync.sh) replaces the one useful thing the hook
did: it fails if a root variable is not passed through `wrappers/main.tf`. When you add a variable to
the root module, add the matching line to the wrapper in the same change.

## Why validations stop where they do

`permissions` is validated for shape, not content:

- **`resource_type` is checked against the six wire values** the Cloud Ops API accepts. That list is
  small and stable, and the plural, hyphenated spelling is the mistake consumers make first.
- **Actions are only checked for the `cloud.` prefix.** The set of action strings grows with the Cloud
  Ops API, so an allowlist here would reject new actions until this module cut a release. The prefix
  check still catches the common error of passing an API operation name such as `GetNamespace`.
- **Action-to-resource-type pairing is not checked at all.** An action granted on the wrong resource
  type is accepted by the API and produces a role that silently grants nothing. Encoding the mapping
  would mean shipping the whole permissions reference in a variable validation and re-releasing
  whenever it changed.

There is no `permissions` non-empty check, because it would have to be conditional on
`create_custom_role` and cross-variable validation needs Terraform 1.9 — above this module's
`required_version` floor of 1.5.7. The API rejects an empty list on apply.

## API behaviours the tests guard against

Each of these passes `terraform validate` and fails only on apply or at plan-time provider validation.
They are the reason the apply layer exists.

1. **`resource_ids` and `allow_all` are mutually exclusive, and exactly one is required.** The provider
   validates this at plan with `resource_ids must be empty when allow_all is true.` and
   `allow_all must be true when resource_ids is empty.` `resource_ids` has no schema default, so an
   allow-all permission must still write out `resource_ids = []`.
2. **Resource IDs must already exist in the account.** An unknown ID is rejected, which is why
   `tests/setup/` creates a namespace instead of using a literal.
3. **An update replaces the entire permission set.** Anything omitted is revoked.
   `custom_role.tftest.hcl` ends by shrinking the set and asserting nothing survives.
4. **Custom roles cannot be enumerated.** There is no data source for them, so the orphan check covers
   only the namespace fixture. See [`tests/README.md`](tests/README.md).

When writing assertions, note that outputs wrapped in `try(x, [])` evaluate to a *tuple*, so
`output.custom_role_permissions == tolist([])` is false even against an empty result. Compare with
`length()` and index elementwise instead. The order of the returned permission list is not guaranteed
either, so match entries by content rather than by index.

## Running the apply tests

They create and destroy **real, billable** resources. Point them at a scratch account.

```bash
export TEMPORAL_CLOUD_API_KEY="<key for a scratch account>"
terraform init
terraform test -verbose
```

Without a key every run block is skipped, which is a cheap way to check that the test files parse:

```text
Failure! 0 passed, 0 failed, 7 skipped.
```

In CI they run from the **Apply Tests** workflow. Its first step is
`scripts/check-api.sh`, a liveness check that confirms the API answers and the key
is accepted, so a credentials problem fails immediately rather than surfacing
minutes later as a resource that would not create.

Apply Tests is chained after Pre-Commit, and Release after Apply Tests, so a merge
to main runs:

```text
push to main -> Pre-Commit -> Apply Tests -> Release
```

A release is therefore only cut from code that passed both the static gate and the
tests that apply against a real account. Any failure in the chain stops it.

Apply Tests never runs on pull requests: forks cannot read secrets and every run
costs money. It also runs weekly, and on demand. Runs are serialized with
`cancel-in-progress: false`, because cancelling mid-apply would abandon resources with no destroy.

Resources created by the tests are prefixed so leftovers from an interrupted run are identifiable; see
[`tests/README.md`](tests/README.md).

## Pull requests

Titles must be [conventional commits](https://www.conventionalcommits.org/) — `feat:`, `fix:`, `docs:`,
`ci:`, `chore:` — with a capitalised subject. Squash-merge makes the title the commit message, and
semantic-release derives the next version from it, so an invalid title silently breaks versioning. A
workflow enforces this.

`CHANGELOG.md` and tags are generated on merge. Never bump versions by hand.

If CI reports fewer checks than usual, check whether the pull request has merge conflicts: GitHub skips
`pull_request` workflows when it cannot compute a merge ref, with no failed check to show for it.
