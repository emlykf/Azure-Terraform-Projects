output "rg_name" {
  value = azurerm_resource_group.rg.name
}

output "vnet_name" {
  value = azurerm_virtual_network.vnet.name
}

output "vnet" {
  value = azurerm_virtual_network.vnet.id
}

output "subnets" {
  value = {
    Application_subnet = azurerm_subnet.app.address_prefixes[0]
    Management_subnet  = azurerm_subnet.mgmt.address_prefixes[0]
  }
  /* address_prefixes is a list, even when it only holds one value — Azure lets a subnet have multiple CIDR ranges, so Terraform always treats it as a list type (list(string)), never a plain string.

  [0] just grabs the first item out of that list, converting it from ["10.0.1.0/24"] (a list) to "10.0.1.0/24" (a plain string) — which is why the output renders without brackets. */
}