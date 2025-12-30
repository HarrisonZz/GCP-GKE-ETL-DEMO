variable "cluster_name" { type = string }
variable "cluster_version" { type = string, default = "1.29" }

variable "vpc_id" { type = string }
variable "subnet_ids" {
  type        = list(string)
  description = "EKS control-plane + nodegroup subnets (通常 private subnets)"
}

variable "endpoint_public_access" { type = bool, default = true }
variable "endpoint_private_access" { type = bool, default = true }
variable "public_access_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "node_group_name" { type = string, default = "default-ng" }
variable "instance_types" { type = list(string), default = ["t3.medium"] }

variable "desired_size" { type = number, default = 2 }
variable "min_size" { type = number, default = 1 }
variable "max_size" { type = number, default = 3 }

variable "tags" {
  type    = map(string)
  default = {}
}
