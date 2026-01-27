terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

data "terraform_remote_state" "vpc" {
  backend = "gcs"

  config = {
    bucket = "etl-demo-gcs-bucket"
    prefix = "dev/vpc"
  }
}

data "terraform_remote_state" "compute" {
  backend = "gcs"

  config = {
    bucket = "etl-demo-gcs-bucket"
    prefix = "dev/compute/gke"
  }
}

data "terraform_remote_state" "data" {
  backend = "gcs"

  config = {
    bucket = "etl-demo-gcs-bucket"
    prefix = "dev/data"
  }
}

data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${data.terraform_remote_state.compute.outputs.cluster_endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.terraform_remote_state.compute.outputs.cluster_ca_certificate)
}

module "k8s_addons" {
  source = "../../../../modules/k8s-addons"

  project_id                      = var.project_id
  env_name                        = "dev"
  gcp_service_account_email       = data.terraform_remote_state.compute.outputs.etl_cleaning_gsa_email
  gcs_bucket_name                 = data.terraform_remote_state.data.outputs.gcs_bucket_name
  monitoring_secrets_gcp_sa_email = module.monitoring_identity.gsa_email
  external_secrets_gcp_sa_email   = module.external_secrets_identity.gsa_email

  depends_on = [
    module.external_secrets_identity,
    module.monitoring_identity
  ]
}

# External Secrets Operator Workload Identity
module "external_secrets_identity" {
  source = "../../../../modules/workload-identity"

  project_id = var.project_id

  gsa_name  = "external-secrets-gsa"
  ksa_name  = "external-secrets-sa"
  namespace = "external-secrets"

  roles = [
    "roles/secretmanager.secretAccessor",
    "roles/secretmanager.viewer"
  ]

  depends_on = [module.k8s_addons]
}

# Monitoring Workload Identity (for Grafana/Prometheus)
module "monitoring_identity" {
  source = "../../../../modules/workload-identity"

  project_id = var.project_id

  gsa_name  = "monitoring-secrets-gsa"
  ksa_name  = "monitoring-secrets-sa"
  namespace = "monitoring"

  roles = [
    "roles/secretmanager.secretAccessor",
    "roles/monitoring.viewer"
  ]

  depends_on = [module.k8s_addons]
}
