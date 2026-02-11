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
    bucket = "etl-demo-gcs-bucket" # 必須跟 VPC 用的 Bucket 一樣
    prefix = "dev/vpc"             # 必須跟 VPC 的 Backend Prefix 一樣
  }
}

# 1. 呼叫 GKE 模組 (建立叢集)
module "gke" {
  source     = "../../../../modules/gke"
  project_id = var.project_id
  region     = var.region
  env_name   = "dev"

  cluster_name = var.cluster_name

  network_self_link    = data.terraform_remote_state.vpc.outputs.network_self_link
  subnetwork_self_link = data.terraform_remote_state.vpc.outputs.subnetwork_self_link

  pods_range_name     = data.terraform_remote_state.vpc.outputs.pods_range_name
  services_range_name = data.terraform_remote_state.vpc.outputs.services_range_name

  min_nodes    = 1
  max_nodes    = 3
  machine_type = "e2-standard-2"

}

data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${module.gke.cluster_endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.cluster_ca_certificate)
}

module "fastapi_identity" {
  # 注意路徑名稱的變更
  source = "../../../../modules/workload-identity"

  project_id = var.project_id

  # 設定帳號名稱
  gsa_name  = "ingest-api-sa"
  ksa_name  = "ingest-api-ksa"
  namespace = "default"

  # 直接列出需要的權限
  roles = [
    "roles/storage.objectCreator", # 讀取 GCS
    "roles/logging.logWriter"      # 寫 Log
  ]

  # 重要：一定要等 GKE 建好，不然無法連進去建 KSA
  depends_on = [module.gke]
}

module "etl_identity" {
  # 注意路徑名稱的變更
  source = "../../../../modules/workload-identity"

  project_id = var.project_id

  # 設定帳號名稱
  gsa_name  = "etl-cleaning-sa"
  ksa_name  = "etl-cleaning-job-ksa" # Pod 的 serviceAccountName 要填這個
  namespace = "default"

  # 直接列出需要的權限
  roles = [
    "roles/storage.objectUser",
    "roles/logging.logWriter"
  ]

  # 重要：一定要等 GKE 建好，不然無法連進去建 KSA
  depends_on = [module.gke]
}
