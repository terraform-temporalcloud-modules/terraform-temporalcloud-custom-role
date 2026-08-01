# Local regression coverage

This directory is **not an example** — do not copy it. See [examples/](../../examples) for usage.

## Why it exists

The `examples/` directories source the *published* module from the Terraform Registry so they are
copy-pasteable for consumers. The tradeoff is that they validate the last release rather than the code
in this repository: a renamed or removed variable would pass CI unnoticed.

This directory sources the module by relative path (`../../`) and passes **every** input, so
`terraform validate` fails here the moment the variable surface changes incompatibly. It covers:

| Module call | What it proves |
| --- | --- |
| `all_inputs` | Every input the module accepts is still valid, across all six resource types and both ways of scoping a permission |
| `disabled` | `create_custom_role = false` produces no resources and every output falls back via `try()` |
| `minimal` | The module works with only `name` and one permission |
| `wrapper` | `wrappers/` accepts `defaults` / `items` and passes them through |

`outputs.tf` references every output, so a broken output expression fails here rather than in a
consumer's plan.

The resource IDs in `all_inputs` are placeholders. Nothing here is ever applied — Temporal Cloud
rejects unknown resource IDs, so these values would only work as literals in a directory CI validates
and never plans.

## Maintenance

When you add a variable to the root module, **add it here in the same PR** — the `wrapper-sync` hook
guards `wrappers/main.tf`, but nothing else would catch an untested input. Adding it to `examples/` has
to wait until the next release publishes it.

CI discovers this directory automatically: the workflow globs for any directory containing a `.tf`
file with `required_version`, so no matrix entry needs maintaining.

## Running it

```bash
terraform init
terraform validate
```

`terraform plan` additionally requires `TEMPORAL_CLOUD_API_KEY`, because the provider authenticates at
configure time even when no resources would be created.
