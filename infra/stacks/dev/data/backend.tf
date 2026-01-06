terraform {
  backend "gcs" {
    bucket = "etl-demo-gcs-bucket" # 您手動開的那個 bucket
    prefix = "dev/data"            # 狀態檔的路徑
  }
}
