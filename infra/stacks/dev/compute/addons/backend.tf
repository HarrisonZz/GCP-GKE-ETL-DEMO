terraform {
  backend "gcs" {
    bucket = "etl-demo-gcs-bucket"
    prefix = "dev/k8s-addons"
  }
}


