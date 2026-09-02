terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "mulzatech-tfstate-rg"
    storage_account_name = "mulzatechtfstate"
    container_name        = "tfstate"
    key                    = "mulzatech-doom.tfstate"
    use_azuread_auth       = true
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}