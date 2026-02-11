variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "env_name" {
  description = "環境名稱 (dev, staging, prod)"
  type        = string
  default     = "dev"
}
