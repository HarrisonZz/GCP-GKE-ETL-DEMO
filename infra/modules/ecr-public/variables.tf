variable "repository_name" {
  type = string
}

variable "description" {
  type    = string
  default = ""
}

variable "architectures" {
  type    = list(string)
  default = ["x86-64", "ARM64"]
}
