output "repository_url" {
  description = "The URL of the repository"
  value       = module.artifact_registry.repository_url
}

output "repository_name" {
  description = "The name of the repository"
  value       = module.artifact_registry.repository_name
}
