module "k8s_addons" {
  source = "../../../../modules/k8s-addons"

  project_id                = var.project_id
  env_name                  = "dev"
  gcp_service_account_email = data.terraform_remote_state.compute.outputs.etl_cleaning_gsa_email
  gcs_bucket_name           = data.terraform_remote_state.data.outputs.gcs_bucket_name
}
