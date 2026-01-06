output "repository_uris" {
  value = { for k, m in module.ecr-public : k => m.repository_uri }
}

output "registry_ids" {
  value = { for k, m in module.ecr-public : k => m.registry_id }
}
