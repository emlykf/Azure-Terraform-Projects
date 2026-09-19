  # --- Creates a public IP address for the load balancer ---
  # the Load Balancer doesn't own or contain the public IP — it just references its ID. They're independently created Azure resources that happen to be linked together
  resource "azurerm_public_ip" "lb_publicIP" {
    name                = "pip-lb-${var.resource_naming}"
    location            = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    allocation_method   = "Static"
    sku                 = "Standard"          # standard SKU requires allocation_method = "Static"
  }

  resource "azurerm_lb" "loadbalancer" {
    name                = "lb-${var.resource_naming}"
    location            = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    sku                 = "Standard"

    frontend_ip_configuration {
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
    loadbalancer_id = azurerm_lb.loadbalancer.id
    name            = "health-probe"    # referencing the load balancer's ID here as well, since the probe is also associated with the load balancer
    protocol        = "Http"            # it's a required argument (Tcp, Http, or Https). The protocol is used to determine how the health probe checks the health of the backend instances
    port            = 80
    request_path    = "/health"         # required when using Http/Https protocol
  }

  # --- The lb_rules allow inbound traffic from internet to the load balancer, and then the load balancer forwards that traffic to the backend pool ---
  resource "azurerm_lb_rule" "lb_rule" {
    # since azurerm_lb_rule is a standalone resource (not nested inside azurerm_lb), you'd use for_each rather than a dynamic block to generate multiple rule resources
    for_each = local.lb_rules

    loadbalancer_id                = azurerm_lb.loadbalancer.id
    name                           = each.key                     # the map's key itself ("http")
    protocol                       = each.value.protocol
    frontend_port                  = each.value.frontend_port
    backend_port                   = each.value.backend_port
    frontend_ip_configuration_name = "PublicIPAddress"
    backend_address_pool_ids       = [azurerm_lb_backend_address_pool.lb_backend_pool.id]
    probe_id                       = azurerm_lb_probe.lb_probe.id
  }