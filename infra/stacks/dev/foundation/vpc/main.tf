terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

module "vpc" {
  source     = "../../../../modules/vpc"
  project_id = var.project_id
  region     = var.region
}
