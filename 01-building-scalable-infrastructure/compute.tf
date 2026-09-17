resource "azurerm_linux_virtual_machine_scale_set" "vmss" {
  name                = "vmss-${var.resource_naming}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = lookup(local.vm_sizes, var.environment)   # here we use the lookup function to get the VM size based on the environment variable
  instances           = var.instance_count
  admin_username      = "adminuser"
  custom_data         = filebase64("${path.module}/user-data.sh")

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")  # I generated a new SSH key pair for this project 
  }

  network_interface {
    name    = "nic"
    primary = true

    ip_configuration {
      name      = "ipconfig"
      primary   = true
      subnet_id = azurerm_subnet.app.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.lb_backend_pool.id]  # This is how we connect the VMSS instances with the backend pool of the load balancer
      
      /* It needs [ ] because the field expects a list of IDs, not a single ID — even when you're only giving it one.
      azurerm_lb_backend_address_pool.lb_backend_pool.id on its own is just one string. But load_balancer_backend_address_pool_ids (plural, "ids") is typed as list(string) in the schema —
      so wrapping it in [ ] turns your one ID into a one-item list, matching what the field expects. */
    }
  }

    os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

    source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

    lifecycle {
      ignore_changes = [instances]
    }
}


resource "azurerm_monitor_autoscale_setting" "autoscale" {
  name                = "autoscale_setting"
  enabled             = true
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.vmss.id

  profile {
    name = "autoscale"

    capacity {
      default = 2
      minimum = 2
      maximum = 5
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.vmss.id
        time_grain         = "PT1M"             # How often Azure collects the raw metric data
        statistic          = "Average"        
        time_window        = "PT5M"             # This means that the average CPU usage is calculated over a 5-minute window 
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 80
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"       # This means add one instance to the scale set when the CPU usage exceeds 80% for 5 minutes
        cooldown  = "PT1M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 10
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }

  notification {
    email {
      send_to_subscription_administrator    = true
      custom_emails                         = ["admin@contoso.com"]
    }
  }
}