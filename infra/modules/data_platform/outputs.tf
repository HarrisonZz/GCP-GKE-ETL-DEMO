# modules/data-platform/outputs.tf

output "gcs_bucket_name" {
  value = local.raw_bucket_name
}

output "bq_dataset_id" {
  value = google_bigquery_dataset.warehouse.dataset_id
}

output "sa_email" {
  value = google_service_account.etl_runner.email
}
