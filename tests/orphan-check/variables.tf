variable "test_namespace_prefix" {
  description = "Prefix identifying namespaces created by the test suite. Anything matching it after a test run has finished is a leftover"
  type        = string
  default     = "yulei-tftest-role-"
}
