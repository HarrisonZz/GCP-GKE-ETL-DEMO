# 1. 啟用 Artifact Registry API
resource "google_project_service" "artifact_registry" {
  project            = var.project_id
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

# 2. 建立 Repository
resource "google_artifact_registry_repository" "repo" {
  location      = var.region
  repository_id = var.repository_id
  description   = "Docker repository for ${var.repository_id}"
  format        = "DOCKER" # 指定格式為 Docker

  # 確保 API 先啟用
  depends_on = [google_project_service.artifact_registry]
}

# 3. (選用) 設定權限 - 讓 GKE 的 Node 或 Workload Identity 可以拉取
# 通常我們在 GKE 那邊設定 SA 權限，這裡可以先略過，或是給予專案級別的讀取權限
