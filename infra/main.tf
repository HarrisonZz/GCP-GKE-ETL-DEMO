terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "data_bucket" {
  source        = "./modules/data_bucket"
  project_name  = var.project_name
  env           = var.env
  iam_user_name = var.ingest_api_user
}

