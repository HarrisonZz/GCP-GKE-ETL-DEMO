# modules/data-platform/outputs.tf

output "gcs_bucket_name" {
  value = google_storage_bucket.raw_lake.name
}

output "bq_dataset_id" {
  value = google_bigquery_dataset.warehouse.dataset_id
}

output "sa_email" {
  value = google_service_account.etl_runner.email
}
