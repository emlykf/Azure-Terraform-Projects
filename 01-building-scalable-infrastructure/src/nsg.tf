resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-${var.resource_naming}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # --- Allows inbound internet traffic to reach the VMSS instances via the load balancer ---
  # security_rule is a nested block inside azurerm_network_security_group (not a standalone resource), so you use a dynamic block to generate multiple security_rule blocks 
  # dynamic block => dynamic "rule_name"
  dynamic "security_rule" {
    for_each = local.lb_rules
    
    content {
      name                       = "Allow-${security_rule.key}"
      priority                   = security_rule.value.priority         # evaluation order; lower number = checked first
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = security_rule.value.protocol
      source_port_range          = "*"                                  # sender's port; "*" = any (LB uses ephemeral ports)                                         
      destination_port_range     = security_rule.value.backend_port     # which port on VMSS this opens (e.g. 80, 443)
      source_address_prefix      = "Internet"                           # allow traffic from the Internet. From NSG's pov, inbound traffic looks like it's coming directly from the internet client, not from the load balancer itself
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

# --- Associates the NSG with the app subnet ---
# azurerm_network_security_group just defines a set of rules, it's not attached to anything by default
# so the azurerm_subnet_network_security_group_association resource is used to attach the NSG to a specific subnet
resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}