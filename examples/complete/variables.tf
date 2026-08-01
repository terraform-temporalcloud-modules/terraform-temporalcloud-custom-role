variable "scoped_namespace_ids" {
  description = "Namespace IDs, in the form `<namespace>.<account_id>`, to grant update permission on. Every ID must already exist in the account — an unknown one is rejected at apply. Left empty, the example creates only account-wide permissions and applies against any account"
  type        = list(string)
  default     = []
}
