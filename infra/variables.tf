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