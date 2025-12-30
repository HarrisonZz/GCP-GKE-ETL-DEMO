output "network_name" {
  value = google_compute_network.main.name
}

output "network_self_link" {
  value = google_compute_network.main.self_link
}

output "subnetwork_name" {
  value = google_compute_subnetwork.private.name
}

output "subnetwork_self_link" {
  value = google_compute_subnetwork.private.self_link
}

output "pods_range_name" {
  value = var.pods_range_name
}

output "services_range_name" {
  value = var.services_range_name
}

output "project_id" {
  value = var.project_id
}
