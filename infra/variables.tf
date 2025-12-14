variable "project_name" {
  type    = string
  default = "cloud-native-etl"
}

variable "env" {
  type    = string
  default = "dev"
}

variable "aws_region" {
  type    = string
  default = "ap-northeast-1"
}

variable "ingest_api_user" {
  type    = string
  default = "ingest-user"
}
