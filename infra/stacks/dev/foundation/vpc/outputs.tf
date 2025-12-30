output "network_name" {
  description = "The name of the VPC being created"
  value       = module.vpc.network_name
}

output "subnetwork_name" {
  description = "The name of the subnet being created"
  value       = module.vpc.subnetwork_name
}

output "pods_range_name" {
  description = "The secondary IP range used for pods"
  value       = module.vpc.pods_range_name
}

output "services_range_name" {
  description = "The secondary IP range used for services"
  value       = module.vpc.services_range_name
}

output "project_id" {
  value = var.project_id
}

output "region" {
  value = var.region
}
