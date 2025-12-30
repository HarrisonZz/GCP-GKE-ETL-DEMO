variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "network_name" {
  description = "Name of the VPC network"
  type        = string
  default     = "gke-vpc"
}

variable "subnet_name" {
  description = "Name of the subnet"
  type        = string
  default     = "gke-subnet"
}

variable "subnet_cidr" {
  description = "CIDR range for the subnet (Nodes)"
  type        = string
  default     = "10.0.0.0/20" # 足夠容納 4096 個 Nodes
}

variable "pods_range_name" {
  description = "Name of the secondary range for Pods"
  type        = string
  default     = "ip-range-pods"
}

variable "pods_cidr" {
  description = "CIDR range for Pods"
  type        = string
  default     = "10.4.0.0/14" # 依需求調整，GKE Pods 消耗 IP 很快
}

variable "services_range_name" {
  description = "Name of the secondary range for Services"
  type        = string
  default     = "ip-range-services"
}

variable "services_cidr" {
  description = "CIDR range for Services"
  type        = string
  default     = "10.8.0.0/20"
}
