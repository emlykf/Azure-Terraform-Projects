resource "azurerm_monitor_autoscale_setting" "autoscale" {
  name                = "autoscale_setting"
  enabled             = true
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.vmss.id

  profile {
    name = "autoscale"      # the name configuration section inside the autoscale setting

    capacity {
      default = 2
      minimum = 2
      maximum = 5
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.vmss.id
        time_grain         = "PT1M"             # how often Azure checks CPU — every 1 min 
        statistic          = "Average"        
        time_window        = "PT5M"             # looks at the last 5 min of CPU usage   
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 80
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"           # add one instance to the scale set when the CPU usage exceeds 80% for 5 minutes
        cooldown  = "PT2M"        # wait 2 min before scaling again
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
        cooldown  = "PT2M"
      }
    }
  }

  notification {
    email {
      custom_emails                         = ["keishamanapa5@gmail.com"]
    }
  }
}