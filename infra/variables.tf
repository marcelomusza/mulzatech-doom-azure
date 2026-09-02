variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "East US"
}

variable "project_name" {
  description = "Short name used as a prefix for resource names"
  type        = string
  default     = "mulzatech-doom"
}

variable "container_image" {
  description = "Full Docker image reference to deploy"
  type        = string
  default     = "docker.io/marcelomusza/mulzatech-doom:latest"
}

variable "admin_object_id" {
  description = "Azure AD object ID of the Key Vault administrator"
  type        = string
  default     = "2a7fb68c-a32f-4396-a19e-bfa3ca4cd32e"
}