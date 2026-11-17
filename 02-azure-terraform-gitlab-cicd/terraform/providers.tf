terraform {
  required_version = "~> 1.17.2"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.5"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-test01-gwc"
    storage_account_name = "sttest01gwc"
    container_name       = "tfstate"
    key                  = "azure-terraform-gitlab-cicd.tfstate"
    use_azuread_auth     = true # Entra ID login, no storage account key
  }
}

provider "azurerm" {
  features {}
}