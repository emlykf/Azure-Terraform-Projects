terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0.0"
    }
    tls = {                           # TLS provider is used to generate a self-signed certificate for the load balancer
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
  required_version = ">= 1.9.0"
}

provider "azurerm" {
  features {}
}