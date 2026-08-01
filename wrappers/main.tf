module "wrapper" {
  source = "../"

  for_each = var.items

  create_custom_role = try(each.value.create_custom_role, var.defaults.create_custom_role, true)
  description        = try(each.value.description, var.defaults.description, null)
  name               = try(each.value.name, var.defaults.name, "")
  permissions        = try(each.value.permissions, var.defaults.permissions, [])
  timeouts           = try(each.value.timeouts, var.defaults.timeouts, {})
}
