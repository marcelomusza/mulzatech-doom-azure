output "app_url" {
  description = "Public URL for the deployed DOOM app"
  value       = "https://${azurerm_container_app.main.ingress[0].fqdn}"
}