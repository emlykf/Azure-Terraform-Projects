locals {
  tags = {
    environment = var.environment
  }

  # --- Define the VM sizes for each environment ---
  vm_sizes = {
      dev   = "Standard_D2s_v4"
      test  = "Standard_D4s_v4"
      prod  = "Standard_D8s_v4"
    }
  
  # --- Define the rules as a map ---
  # we created lb_rule so NSG can reference it. The NSG needs to know which ports to allow traffic on, and the load balancer rule defines those ports (frontend_port and backend_port)
  lb_rules = {
    http = {                            # http is the "key" and the value is a map of the rule (frontend_port, backend_port, protocol, priority)
      frontend_port          = 80     
      backend_port           = 80
      protocol               = "Tcp"
      priority               = 100
    }
    https = {
      frontend_port          = 443      # the port clients hit on the LB's public IP (the port that receives traffic from the internet)
      backend_port           = 443      # the port that traffic gets forwarded to on the backend pool (VMSS)
      protocol               = "Tcp"
      priority               = 110
    }
  }

}