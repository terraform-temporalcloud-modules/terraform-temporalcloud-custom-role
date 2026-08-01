output "custom_role_id" {
  description = "The unique identifier of the custom role, for assigning it to users, groups and service accounts"
  value       = module.custom_role.custom_role_id
}

output "custom_role_name" {
  description = "The name of the custom role"
  value       = module.custom_role.custom_role_name
}
