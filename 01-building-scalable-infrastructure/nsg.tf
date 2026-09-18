resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-${var.resource_naming}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # --- Allows inbound traffic from the load balancer to the VMSS instances on the backend_port ---
  # dynamic block => dynamic "rule_name"
  dynamic "security_rule" {
    for_each = local.lb_rules
    
    content {
      name                       = "Allow-${security_rule.key}-from-LB"
      priority                   = security_rule.value.priority         # evaluation order; lower number = checked first
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = security_rule.value.protocol
      source_port_range          = "*"                                  # sender's port; "*" = any (LB uses ephemeral ports)                                         
      destination_port_range     = security_rule.value.backend_port     # which port on VMSS this opens (e.g. 80, 443)
      source_address_prefix      = "Internet"                           # the LB is sending traffic from the internet
      destination_address_prefix = "*"                                  # any VM in the subnet 
    }
  }

  # --- Allows SSH only from within the same VNet. SSH isn't traffic from the load balancer. It's direct administrative access to a VM instance ---
  security_rule {
    name                       = "Allow-SSH-Internal"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  tags = {
    environment = local.tags.environment
  }
}

# --- azurerm_network_security_group just defines a set of rules — it's not attached to anything by default ---
# it's what actually applies that NSG to a specific subnet, turning it from "rules sitting unused" into "rules actively filtering traffic
resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}