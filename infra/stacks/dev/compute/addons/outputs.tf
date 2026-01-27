# External Secrets Operator Workload Identity Outputs
output "external_secrets_gsa_email" {
  description = "GCP Service Account email for External Secrets Operator"
  value       = module.external_secrets_identity.gsa_email
}

output "external_secrets_ksa_name" {
  description = "Kubernetes Service Account name for External Secrets Operator"
  value       = module.external_secrets_identity.ksa_name
}

# Monitoring Workload Identity Outputs
output "monitoring_secrets_gsa_email" {
  description = "GCP Service Account email for Monitoring secrets"
  value       = module.monitoring_identity.gsa_email
}

output "monitoring_secrets_ksa_name" {
  description = "Kubernetes Service Account name for Monitoring secrets"
  value       = module.monitoring_identity.ksa_name
}
