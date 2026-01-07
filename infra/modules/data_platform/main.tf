############################################
# 1) GCS Bucket: Raw Data Lake
############################################
# Dev bucket (allow destroy)
resource "google_storage_bucket" "raw_lake_dev" {
  count         = var.env == "prod" ? 0 : 1
  name          = "${var.project_id}-${var.env}-raw-data"
  location      = var.region
  force_destroy = true

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
}

# Prod bucket (prevent destroy)
resource "google_storage_bucket" "raw_lake_prod" {
  count         = var.env == "prod" ? 1 : 0
  name          = "${var.project_id}-${var.env}-raw-data"
  location      = var.region
  force_destroy = false

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  lifecycle {
    prevent_destroy = true
  }
}

############################################
# 2) BigQuery Dataset
############################################
resource "google_bigquery_dataset" "warehouse" {
  project       = var.project_id
  dataset_id    = "${var.env}_iot_warehouse"
  friendly_name = "IoT Data Warehouse (${var.env})"
  location      = var.region
}

############################################
# 3) Service Account (ETL runner identity)
############################################
resource "google_service_account" "etl_runner" {
  project      = var.project_id
  account_id   = "${var.env}-etl-runner"
  display_name = "ETL Service Account for ${var.env}"
}

############################################
# 4) IAM: 權限
############################################

locals {
  raw_bucket_name = var.env == "prod" ? google_storage_bucket.raw_lake_prod[0].name : google_storage_bucket.raw_lake_dev[0].name
}

# ETL 只需要讀 raw objects（外部表讀 GCS 需要 list/get）
resource "google_storage_bucket_iam_member" "etl_gcs_reader" {
  bucket = local.raw_bucket_name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.etl_runner.email}"
}

# ETL 寫入 BQ dataset 內的 table
resource "google_bigquery_dataset_iam_member" "etl_bq_editor" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.warehouse.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.etl_runner.email}"
}

# 跑 BigQuery Query Job（MERGE/SELECT）需要 jobUser（通常是 project 層）
resource "google_project_iam_member" "etl_bq_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.etl_runner.email}"
}

############################################
# 5) BigQuery External Table: raw_external
#    直接綁定 gs://bucket/raw/*/*.jsonl
############################################
resource "google_storage_bucket_object" "raw_dummy" {
  bucket  = local.raw_bucket_name
  name    = "raw/dt=1970-01-01/dummy.jsonl"
  content = "{\"device_id\":\"dummy\",\"value\":0.0}\n"
}

resource "google_bigquery_table" "raw_external" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.warehouse.dataset_id
  table_id   = "raw_external"

  deletion_protection = var.env == "prod" ? true : false

  external_data_configuration {
    autodetect    = true
    source_format = "NEWLINE_DELIMITED_JSON"
    source_uris   = ["gs://${local.raw_bucket_name}/raw/*"]

    # 讓 dt 從路徑 raw/YYYY-MM-DD/ 自動解析
    hive_partitioning_options {
      mode                     = "AUTO"
      source_uri_prefix        = "gs://${local.raw_bucket_name}/raw"
      require_partition_filter = true
    }
  }

  depends_on = [
    google_storage_bucket_iam_member.etl_gcs_reader,
    google_storage_bucket_object.raw_dummy
  ]
}

############################################
# 6) BigQuery Target Table: device_metrics_agg
############################################
resource "google_bigquery_table" "device_metrics_agg" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.warehouse.dataset_id
  table_id   = "device_metrics_agg"

  schema = jsonencode([
    { name = "device_id", type = "STRING", mode = "REQUIRED" },
    { name = "dt", type = "DATE", mode = "REQUIRED" },
    { name = "count", type = "INT64", mode = "REQUIRED" },
    { name = "avg_val", type = "FLOAT64", mode = "NULLABLE" },
    { name = "min_val", type = "FLOAT64", mode = "NULLABLE" },
    { name = "max_val", type = "FLOAT64", mode = "NULLABLE" },
    { name = "processed_at", type = "TIMESTAMP", mode = "REQUIRED" }
  ])

  time_partitioning {
    type  = "DAY"
    field = "dt"
  }

  clustering = ["device_id"]

  deletion_protection = var.env == "prod" ? true : false
}
