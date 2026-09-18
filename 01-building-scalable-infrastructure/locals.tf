locals {
  tags = {
    environment = var.environment
  }

  # --- Define the VM sizes for each environment ---
  vm_sizes = {
      dev   = "Standard_B1s"
      test  = "Standard_D2s_v4"
      prod  = "Standard_D8s_v4"
    }
  
  # --- Define the rules as a map ---
  # we created lb_rule so NSG can reference it. The NSG needs to know which ports to allow traffic on, and the load balancer rule defines those ports (frontend_port and backend_port)
  lb_rules = {
    http = {
      frontend_port          = 80
      backend_port           = 80
      protocol               = "Tcp"
      priority               = 110
    }
    https = {
      frontend_port          = 443
      backend_port           = 443
      protocol               = "Tcp"
      priority               = 100
    }
  }

}