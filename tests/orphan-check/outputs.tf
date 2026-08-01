output "orphans" {
  description = "Names of test namespaces still present in the account"
  value       = local.orphans
}

output "orphan_count" {
  description = "Number of test namespaces still present"
  value       = length(local.orphans)
}
