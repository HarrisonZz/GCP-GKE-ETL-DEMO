terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.0" # 建議使用 2.0 以上
    }
    # ★★★ 必須補上這段 ★★★
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Kubernetes Provider
provider "kubernetes" {
  host                   = "https://${data.terraform_remote_state.compute.outputs.cluster_endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.terraform_remote_state.compute.outputs.cluster_ca_certificate)
}

# Helm Provider (依賴 Kubernetes 設定)
provider "helm" {
  kubernetes = {
    host                   = "https://${data.terraform_remote_state.compute.outputs.cluster_endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(data.terraform_remote_state.compute.outputs.cluster_ca_certificate)
  }
}
