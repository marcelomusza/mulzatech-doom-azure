resource "azurerm_resource_group" "main" {
  name     = "${var.project_name}-rg"
  location = var.location
}

resource "azurerm_container_app_environment" "main" {
  name                = "${var.project_name}-env"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_container_app" "main" {
  name                         = var.project_name
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name           = azurerm_resource_group.main.name
  revision_mode                  = "Single"

  template {
    container {
      name   = "doom"
      image  = var.container_image
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }

  ingress {
    external_enabled = true
    target_port       = 80
    transport          = "http"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}