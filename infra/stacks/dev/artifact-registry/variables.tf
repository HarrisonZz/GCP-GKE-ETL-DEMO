variable "repositories" {
  type = map(object({
    description   = string
    architectures = list(string)
  }))
}

variable "description" {
  type    = string
  default = "ETL related image for demo"
}
