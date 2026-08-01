# Complete Temporal Cloud custom role example

Configuration in this directory creates a Temporal Cloud custom role whose permissions span four
resource types — `accounts`, `namespaces`, `nexus-endpoints` and `connectivity-rules` — and shows both
ways of scoping a permission.

As written it applies against any account: every permission uses `allow_all = true`, which needs no
pre-existing resource IDs. Supplying `scoped_namespace_ids` adds a fifth permission limited to those
namespaces. Every ID must already exist in the account — an unknown one is rejected at apply.

## Usage

To run this example you need to execute:

```bash
export TEMPORAL_CLOUD_API_KEY="<your-api-key>"

terraform init
terraform plan
terraform apply
```

To scope the namespace-update permission to specific namespaces:

```bash
terraform apply -var='scoped_namespace_ids=["orders-prod.a1b2c"]'
```

Note that this example creates resources which cost money. Run `terraform destroy` when you no longer
need them.

Creating the role does not grant anyone anything. Assign the `custom_role_id` output through
`account_access_custom_roles` on a user, group or service account for it to take effect.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.7 |
| <a name="requirement_temporalcloud"></a> [temporalcloud](#requirement\_temporalcloud) | >= 1.6.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_custom_role"></a> [custom\_role](#module\_custom\_role) | terraform-temporalcloud-modules/custom-role/temporalcloud | ~> 1.0 |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_scoped_namespace_ids"></a> [scoped\_namespace\_ids](#input\_scoped\_namespace\_ids) | Namespace IDs, in the form `<namespace>.<account_id>`, to grant update permission on. Every ID must already exist in the account — an unknown one is rejected at apply. Left empty, the example creates only account-wide permissions and applies against any account | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_custom_role_id"></a> [custom\_role\_id](#output\_custom\_role\_id) | The unique identifier of the custom role, for assigning it to users, groups and service accounts |
| <a name="output_custom_role_name"></a> [custom\_role\_name](#output\_custom\_role\_name) | The name of the custom role |
| <a name="output_custom_role_permissions"></a> [custom\_role\_permissions](#output\_custom\_role\_permissions) | The permissions the role grants, as returned by Temporal Cloud |
| <a name="output_custom_role_state"></a> [custom\_role\_state](#output\_custom\_role\_state) | The current state of the custom role |
<!-- END_TF_DOCS -->

## License

Apache-2.0 licensed. See [LICENSE](../../LICENSE).
