variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "env" {
  description = "環境名稱 (e.g., dev, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.env)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "region" {
  description = "GCP Region"
  type        = string
}
