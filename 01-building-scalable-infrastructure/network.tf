resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.resource_naming}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
  #dns_servers         = ["10.0.0.4", "10.0.0.5"]

  tags = {
    environment = local.tags.environment
  }
}

# Application subnet for the VMSS instances
resource "azurerm_subnet" "app" {
  name                 = "snet-app-${var.resource_naming}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Management subnet for the future use
resource "azurerm_subnet" "mgmt" {
  name                 = "snet-mgmt-${var.resource_naming}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}
