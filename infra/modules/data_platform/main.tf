# 1. GCS Bucket (Raw Data)
resource "google_storage_bucket" "raw_lake" {
  name          = "${var.project_id}-${var.env}-raw-data" # 命名規則：專案-環境-用途
  location      = var.region
  force_destroy = var.env == "dev" ? true : false # Dev 環境允許暴力刪除，Prod 不行 (安全機制)

  uniform_bucket_level_access = true
}

# 2. BigQuery Dataset (Data Warehouse)
resource "google_bigquery_dataset" "warehouse" {
  dataset_id    = "${var.env}_iot_warehouse"
  friendly_name = "IoT Data Warehouse (${var.env})"
  location      = var.region
}

# 3. Service Account (給 ETL 程式用的身分)
resource "google_service_account" "etl_runner" {
  account_id   = "${var.env}-etl-runner"
  display_name = "ETL Service Account for ${var.env}"
}

# 4. 綁定權限：讓上面那個帳號可以讀寫 Bucket 和 BQ
# (這是 IAM 最佳實踐：最小權限原則)
resource "google_storage_bucket_iam_member" "etl_gcs_admin" {
  bucket = google_storage_bucket.raw_lake.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.etl_runner.email}"
}

resource "google_bigquery_dataset_iam_member" "etl_bq_editor" {
  dataset_id = google_bigquery_dataset.warehouse.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.etl_runner.email}"
}
