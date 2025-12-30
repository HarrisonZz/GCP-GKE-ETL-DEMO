variable "project_id" {}
variable "region" {}
variable "env_name" { default = "dev" }

variable "cluster_name" {
  description = "GKE Cluster Name"
  type        = string
}

variable "network_name" {
  description = "VPC Network Name"
  type        = string
}

variable "subnetwork_name" {
  description = "Subnet Name"
  type        = string
}

variable "pods_range_name" {
  description = "Name of the secondary range for pods"
  type        = string
}

variable "services_range_name" {
  description = "Name of the secondary range for services"
  type        = string
}

variable "machine_type" {
  default = "e2-medium" # 適合測試，正式環境建議用 e2-standard-2 或更大
}

variable "min_nodes" {
  default = 1
}

variable "max_nodes" {
  default = 3
}

variable "spot_instance" {
  description = "Use Preemptible/Spot VMs to save cost"
  type        = bool
  default     = false
}
