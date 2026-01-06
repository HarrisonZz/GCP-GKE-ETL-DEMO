terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# 呼叫 Data Platform 模組
module "iot_platform" {
  source = "../../../modules/data_platform" # 指向藍圖路徑

  project_id = var.project_id
  region     = var.region
  env        = "dev" # 傳入變數：這是 Dev 環境
}

# 將模組產生的 Bucket 名稱 print 出來，方便您填入 Python Code
output "dev_bucket_name" {
  value = module.iot_platform.gcs_bucket_name
}
