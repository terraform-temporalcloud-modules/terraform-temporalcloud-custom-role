# Referencing every output forces Terraform to evaluate each one, so a broken
# output expression fails validation here rather than in a consumer's plan.

output "all_inputs" {
  description = "Every output of the fully configured module instance"
  value = {
    custom_role_id          = module.all_inputs.custom_role_id
    custom_role_name        = module.all_inputs.custom_role_name
    custom_role_description = module.all_inputs.custom_role_description
    custom_role_state       = module.all_inputs.custom_role_state
    custom_role_permissions = module.all_inputs.custom_role_permissions
  }
}

output "disabled" {
  description = "Outputs when create_custom_role is false — every one must fall back rather than error"
  value = {
    custom_role_id          = module.disabled.custom_role_id
    custom_role_name        = module.disabled.custom_role_name
    custom_role_description = module.disabled.custom_role_description
    custom_role_state       = module.disabled.custom_role_state
    custom_role_permissions = module.disabled.custom_role_permissions
  }
}

output "minimal" {
  description = "Outputs from the minimum viable module call"
  value       = module.minimal.custom_role_id
}

output "wrapper" {
  description = "Wrapper outputs, keyed by item name"
  value       = module.wrapper.wrapper
}
