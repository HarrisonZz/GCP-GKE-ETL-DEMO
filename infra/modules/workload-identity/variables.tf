variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "gsa_name" {
  description = "Name for the Google Service Account"
  type        = string
}

variable "ksa_name" {
  description = "Name for the Kubernetes Service Account"
  type        = string
}

variable "namespace" {
  description = "Kubernetes Namespace"
  type        = string
  default     = "default"
}

variable "roles" {
  description = "List of GCP IAM roles to assign to the service account"
  type        = list(string)
  default     = []
}
