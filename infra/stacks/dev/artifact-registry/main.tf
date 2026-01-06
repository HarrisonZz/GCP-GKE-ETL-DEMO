terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "ecr-public" {
  source   = "../../modules/ecr-public"
  for_each = var.repositories

  repository_name = each.key
  description     = each.value.description
  architectures   = each.value.architectures
}
