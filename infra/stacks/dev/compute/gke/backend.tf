terraform {
  backend "gcs" {
    bucket = "etl-demo-gcs-bucket"
    prefix = "dev/compute/gke"
  }
}

