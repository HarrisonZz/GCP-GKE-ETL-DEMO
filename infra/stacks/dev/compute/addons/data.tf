# 讀取 Compute 層 (為了拿 GKE 連線資訊)
data "terraform_remote_state" "compute" {
  backend = "gcs"
  config = {
    bucket = "etl-demo-gcs-bucket" # 請修改為實際 Bucket
    prefix = "dev/compute/gke"
  }
}

# 讀取 Data 層 (為了拿 Bucket Name)
data "terraform_remote_state" "data" {
  backend = "gcs"
  config = {
    bucket = "etl-demo-gcs-bucket" # 請修改為實際 Bucket
    prefix = "dev/data"
  }
}

# 取得存取 Token
data "google_client_config" "default" {}
