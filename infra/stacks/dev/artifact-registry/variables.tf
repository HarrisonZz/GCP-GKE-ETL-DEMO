variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "asia-northeast1"
}

variable "repository_id" {
  description = "The ID of the repository (e.g., app-images)"
  type        = string
  default     = "app-images"
}
