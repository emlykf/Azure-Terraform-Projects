locals {
  tags = {
    environment = "test"
  }

  # Define the VM sizes for each environment
  vm_sizes = {
      dev   = "Standard_B1s"
      test  = "Standard_B2s"
      prod  = "Standard_B2ms"
    }
  
  # Define the rules as a map
  lb_rules = {
    http = {
      protocol      = "Tcp"
      frontend_port = 80
      backend_port  = 80
    }
  }
}