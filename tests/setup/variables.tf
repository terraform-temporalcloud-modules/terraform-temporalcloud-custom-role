variable "create_namespace_fixture" {
  description = "Creates a real namespace whose ID can be used in a permission's `resource_ids`. Off by default so only the run block that needs a scoped permission pays the cost of creating one"
  type        = bool
  default     = false
}
