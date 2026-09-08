locals {
  common_tags = {
    project     = var.project_name
    managed_by  = "terraform"
    environment = "production"
  }
}