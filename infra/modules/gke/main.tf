resource "google_project_service" "container" {
  project = var.project_id
  service = "container.googleapis.com"

  # 建議設為 false：當你 destroy 這個 module 時，不要順便把 API 關掉
  disable_on_destroy = false
}

# 1. GKE Cluster (Control Plane)
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region # 使用 region (如 asia-east1) 而非 zone，代表這是 Regional HA Cluster

  # 我們會使用自定義的 Node Pool，所以這裡移除預設的
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = var.network_self_link
  subnetwork = var.subnetwork_self_link

  # VPC-native 設定 (關鍵：對應 VPC 模組的次要 IP 範圍)
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # 私有叢集設定 (Nodes 沒有 Public IP，更安全)
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false           # false 代表你還是可以透過 Internet 存取 kubectl (但需要認證)
    master_ipv4_cidr_block  = "172.16.0.0/28" # Master 節點專用的內部網段，不要跟 VPC 重疊
  }

  # Workload Identity (讓 Pod 可以安全使用 GCP IAM，類似 AWS IRSA)
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # 維護視窗 (建議設定，以免 Google 在你不想要的時間升級)
  release_channel {
    channel = "REGULAR"
  }

  # 確保刪除時不會因為還有資源而被卡住
  deletion_protection = false

  depends_on = [
    google_project_service.container
  ]

  lifecycle {
    ignore_changes = [initial_node_count]
  }
}

# 2. 專用的 Service Account (給 Node 使用，最小權限原則)
resource "google_service_account" "gke_nodes" {
  account_id   = "${var.cluster_name}-node-sa"
  display_name = "GKE Nodes Service Account"
}

resource "google_project_iam_member" "node_permissions" {
  for_each = toset([
    "roles/logging.logWriter",       # 寫入 Log
    "roles/monitoring.metricWriter", # 寫入監控數據
    "roles/monitoring.viewer",       # 讀取監控
    "roles/artifactregistry.reader"  # 拉取 Image (如果用 Artifact Registry)
  ])
  role    = each.key
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
  project = var.project_id
}

# 3. Node Pool (實際跑 Pod 的機器)
resource "google_container_node_pool" "primary_nodes" {
  name     = "${var.cluster_name}-node-pool"
  location = var.region
  cluster  = google_container_cluster.primary.name

  # Autoscaling 設定
  autoscaling {
    min_node_count = var.min_nodes
    max_node_count = var.max_nodes
  }

  node_config {
    preemptible  = var.spot_instance # 是否使用 Spot 機器 (省錢但會被搶走)
    machine_type = var.machine_type

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    service_account = google_service_account.gke_nodes.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # 標籤與 Metadata
    labels = {
      env = var.env_name
    }

    # 硬碟設定
    disk_size_gb = 50
    disk_type    = "pd-standard"
  }

}
