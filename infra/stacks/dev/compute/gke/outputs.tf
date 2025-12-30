output "cluster_name" {
  description = "GKE Cluster Name"
  value       = module.gke.cluster_name
}

output "cluster_endpoint" {
  description = "GKE Control Plane Endpoint"
  value       = module.gke.cluster_endpoint
  sensitive   = true # 標記敏感，避免在 Console 噴出一大串 IP
}

output "cluster_ca_certificate" {
  description = "Public certificate of the cluster"
  value       = module.gke.cluster_ca_certificate
  sensitive   = true # 憑證內容很長，標記敏感讓畫面乾淨點
}

output "location" {
  description = "GKE Cluster Region/Location"
  value       = module.gke.location
}

output "project_id" {
  value = var.project_id
}

# =======================================================
# Workload Identity 帳號資訊
# (這些是你寫 Deployment/Job YAML 時要填入 serviceAccountName 的值)
# =======================================================

# 1. FastAPI (Ingest) 用的
output "ingest_api_ksa_name" {
  description = "K8s Service Account name for FastAPI (Ingest)"
  value       = module.fastapi_identity.ksa_name
}

output "ingest_api_gsa_email" {
  description = "GCP Service Account email for FastAPI (Ingest)"
  value       = module.fastapi_identity.gsa_email
}

# 2. ETL (Cleaning) 用的
output "etl_cleaning_ksa_name" {
  description = "K8s Service Account name for ETL Cleaning Job"
  value       = module.etl_identity.ksa_name
}
