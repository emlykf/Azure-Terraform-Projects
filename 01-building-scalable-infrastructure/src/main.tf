resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.resource_naming}"
  location = var.location
}