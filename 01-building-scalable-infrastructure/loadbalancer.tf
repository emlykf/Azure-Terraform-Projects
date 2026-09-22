# --- Creates a public IP address for the load balancer ---
# the Load Balancer doesn't own or contain the public IP, it just references its ID. That's why we need to create a separate public IP
resource "azurerm_public_ip" "lb_publicIP" {
  name                = "pip-lb-${var.resource_naming}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"          # allocation_method = "Static" requires standard SKU

  /* When a client on the internet hits your LB's public IP, the LB routes traffic to your backend VM, but doesn't hide the client's original IP.
  So when the packet actually arrives at your VMSS instance's NIC, its source IP is still the original client's public IP, not the load balancer's IP. */
}

resource "azurerm_lb" "loadbalancer" {
  name                = "lb-${var.resource_naming}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"

    frontend_ip_configuration {                                   # receives traffic from the internet and forwards it to the backend pool (VMSS), referencing the public IP we just created
      name                 = "PublicIPAddress"
      public_ip_address_id = azurerm_public_ip.lb_publicIP.id
    }
}

resource "azurerm_lb_backend_address_pool" "lb_backend_pool" {
  loadbalancer_id = azurerm_lb.loadbalancer.id    # the backend pool is associated with the load balancer, so we reference the load balancer's ID here
  name            = "lb-backend-pool"
}

# --- checks if VMs are actually healthy before sending them traffic ---
resource "azurerm_lb_probe" "lb_probe" {  
  loadbalancer_id = azurerm_lb.loadbalancer.id    # referencing the load balancer's ID here as well, since the probe is also associated with the load balancer
  name            = "health-probe"    
  protocol        = "Https"           # it's a required argument (Tcp, Http, or Https)
  port            = 443
  request_path    = "/health"         # required when using Http/Https protocol
}

# --- The lb_rules allow inbound traffic from internet to the load balancer, and then the load balancer forwards that traffic to the backend pool ---
resource "azurerm_lb_rule" "lb_rule" {
# since azurerm_lb_rule is a standalone resource (not nested inside azurerm_lb), you'd use "for_each" rather than a dynamic block to generate multiple rule resources that are similar but not identical
  for_each = local.lb_rules

  loadbalancer_id                = azurerm_lb.loadbalancer.id
  name                           = each.key                       # the map's key itself (http, https)
  protocol                       = each.value.protocol
  frontend_port                  = each.value.frontend_port       # the port clients hit on the LB's public IP (the port that receives traffic from the internet)
  backend_port                   = each.value.backend_port        # the port that traffic gets forwarded to on the backend pool (VMSS instances)
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.lb_backend_pool.id]
  probe_id                       = azurerm_lb_probe.lb_probe.id
}