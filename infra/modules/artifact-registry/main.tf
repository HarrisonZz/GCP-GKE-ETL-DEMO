resource "aws_ecrpublic_repository" "this" {
  repository_name = var.repository_name

  catalog_data {
    description       = var.description
    operating_systems = ["Linux"]
    architectures     = var.architectures
  }
}
