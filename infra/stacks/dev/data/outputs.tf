# 1. 輸出 GCS Bucket 名稱 (給 Python Ingest API & DuckDB 用)
output "gcs_bucket_name" {
  description = "The name of the GCS bucket created for raw data"
  # 注意：這裡的 iot_platform 必須跟您在 main.tf 裡定義的 module 名稱一致
  value = module.iot_platform.gcs_bucket_name
}

# 2. 輸出 BigQuery Dataset ID (給 DuckDB ETL 用)
output "bq_dataset_id" {
  description = "The ID of the BigQuery dataset"
  value       = module.iot_platform.bq_dataset_id
}

# 3. (選用) 輸出 Service Account Email
# 這是為了方便您檢查 IAM 權限，或者設定 Kubernetes Workload Identity 時使用
output "service_account_email" {
  description = "The email of the Service Account used for ETL operations"
  value       = module.iot_platform.sa_email
}
