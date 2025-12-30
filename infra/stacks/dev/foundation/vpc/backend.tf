terraform {
  backend "gcs" {
    bucket = "etl-demo-gcs-bucket"
    prefix = "dev/vpc"
  }
}
