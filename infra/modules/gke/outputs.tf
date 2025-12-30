output "cluster_name" {
  value = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  value       = google_container_cluster.primary.endpoint
  description = "GKE Control Plane Endpoint"
}

output "cluster_ca_certificate" {
  value       = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  description = "Public certificate of the cluster"
}

output "location" {
  value = google_container_cluster.primary.location
}
