# Read-only Temporal Cloud custom role example

Configuration in this directory creates the smallest useful custom role: read access to every
namespace in the account, and nothing else.

It takes two permissions rather than one because the two actions are scoped to different resource
types. `cloud.namespace.list` returns the account's namespaces and is granted on `accounts`;
`cloud.namespace.get` reads a single namespace and is granted on `namespaces`. Neither this module nor
the provider checks that an action matches the resource type it is granted on, so look each action up
in the
[Custom Role permissions reference](https://docs.temporal.io/cloud/manage-access/permissions-reference#custom-role-permissions-reference),
which lists the resource types every action is valid against.

## Usage

To run this example you need to execute:

```bash
export TEMPORAL_CLOUD_API_KEY="<your-api-key>"

terraform init
terraform plan
terraform apply
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

No inputs.

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_custom_role_id"></a> [custom\_role\_id](#output\_custom\_role\_id) | The unique identifier of the custom role, for assigning it to users, groups and service accounts |
| <a name="output_custom_role_name"></a> [custom\_role\_name](#output\_custom\_role\_name) | The name of the custom role |
<!-- END_TF_DOCS -->

## License

Apache-2.0 licensed. See [LICENSE](../../LICENSE).
