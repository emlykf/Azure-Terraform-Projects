output "rg_name" {
  value = azurerm_resource_group.rg.name
}

output "vnet" {
  value = {
    name          = azurerm_virtual_network.vnet.name
    address_space = tolist(azurerm_virtual_network.vnet.address_space)[0]
  }
}

output "subnets" {
  value = {
    Application_subnet = azurerm_subnet.app.address_prefixes[0]
    Management_subnet  = azurerm_subnet.mgmt.address_prefixes[0]
  }
  /* address_prefixes is a list, even when it only holds one value — Azure lets a subnet have multiple CIDR ranges, so Terraform always treats it as a list type (list(string)), never a plain string.
  [0] just grabs the first item out of that list, converting it from ["10.0.1.0/24"] (a list) to "10.0.1.0/24" (a plain string) — which is why the output renders without brackets. */
}

output "vmss" {
  value = {
    name  = azurerm_linux_virtual_machine_scale_set.vmss.name
    image = azurerm_linux_virtual_machine_scale_set.vmss.source_image_reference
  }
}

output "autoscale" {
  value = {
    name     = azurerm_monitor_autoscale_setting.autoscale.name
    capacity = azurerm_monitor_autoscale_setting.autoscale.profile[0].capacity  # Block type "profile" is represented by a list of objects, so it must be indexed using a numeric key, like .profile[0]
  }
}

output "loadbalancer" {
  value = {
    name = azurerm_lb.loadbalancer.name
    public_ip_address = azurerm_public_ip.lb_publicIP.ip_address    # you'll know the ip_address later after it's created
  }
}

output "nsg_name" {
  value = azurerm_network_security_group.nsg.name
}

output "nat_gateway" {
  value = {
    name = azurerm_nat_gateway.nat_gateway.name
    public_ip_address = azurerm_public_ip.nat_gateway_ip.ip_address   # you'll know the ip_address later after it's created
  }
}

output "environment" {
  value = var.environment
}

output "instance_count" {
  value = var.instance_count
}