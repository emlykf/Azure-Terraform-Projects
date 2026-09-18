# Introduction

In this project, I will demonstrate a scalable Azure cloud infrastructure using Terraform that provides redundancy and improved performance for applications that are typically distributed across multiple instances. This setup allows customer traffic to be automatically redirected to other available instances when performing maintenance or updates.

## Features

- VMSS: running Ubuntu 22.04, auto-scales based on CPU load
- VM size: picked automatically depending on environment (dev/test/prod)
- Load Balancer: spreads traffic across instances, only sends it to healthy ones
- NSG: only lets the load balancer talk to the VMs — everything else is blocked
- NAT Gateway: gives the VMs internet access without exposing them publicly
- Each VM runs a fun demo app (Terramino) so you can actually see if the load balancer is working

## Architecture Diagram

## Challenges & How I Resolved Them

### 1. Implementing the region validation rule

While implementing the region validation rule, I ran into two mistakes that caused the validation to not work as expected:

- **Selecting a region by list index instead of an explicit variable:**

  I initially picked the deployment region based on its position in a list instead of by name. It worked, but if I ever reordered the list, my deployment region would quietly change without any warning.

  ```hcl
  resource "azurerm_resource_group" "rg" {
    name     = "rg-${var.resource_naming}"
    location = var.allowed_regions[1]
  }

  variable "allowed_regions" {
    type = list()
    default = ["EastUS", "WestEU", "SoutheastAsia"]
  }
  ```

  While fixing this, I also found two smaller mistakes in the same code. I realized that `list()` isn’t a valid type on its own. Terraform needs to know what’s inside the list, so it should be `list(string)`. Azure expects `"westeurope"` (lowercase, no spaces). 

  So the fix was adding a dedicated `location` variable that names the region directly instead of indexing into the list, plus correcting the type and the region name:

  ```hcl
  resource "azurerm_resource_group" "rg" {
    name     = "rg-${var.resource_naming}"
    location = var.location
  }

  variable "allowed_regions" {
    type = list(string)
    default = ["eastus", "westeurope", "southeastasia"]
  }

  variable "location" {
    type = string
    default = "westeurope"
  }
  ```

- **A validation rule that checked the list against itself:**

  ```hcl
  variable "allowed_regions" {
    type = list()
    default = ["EastUS", "WestEU", "SoutheastAsia"]

    # Rule that restrict other regions
    validation {
      condition = alltrue([for region in var.allowed_regions : contains(["EastUS", "WestEU", "SoutheastAsia"], region)])
      error_message = "The region must be one of the allowed regions: ${var.allowed_regions}"
    }
  }
  ```

  There were two problems here. First, the `condition` checked `allowed_regions` against a copy of itself, so it could never actually fail. It wasn’t validating a selected region at all. Second, the `error_message` tried to drop `var.allowed_regions` (a `list(string)`) directly into a string, which Terraform can’t handle because plugging a value into a string (Interpolation) only works with a single string, not a list.

  The fix was to separate "the list of allowed regions" from "the selected region" by introducing a new `location` variable. I also used `join()` to turn the list into a proper string for the error message:

  ```hcl
  variable "allowed_regions" {
    type = list(string)
    default = ["eastus", "westeurope", "southeastasia"]
  }

  variable "location" {
    type    = string
    default = "westeurope"

    validation {
      condition     = contains(var.allowed_regions, var.location)
      error_message = "The location must be one of the allowed regions: ${join(", ", var.allowed_regions)}"
    }
  }
  ```

### 2. Setting up the VMSS 

- **Indexing into an inline `subnet` block:**

  I tried to reference my app subnet by index, but `subnet` inside `azurerm_virtual_network` is a set, not a list. Sets have no order, so there’s no “first” item.

  ```hcl
  resource "azurerm_virtual_network" "vnet" {
  ...

    subnet {
      # Application subnet for the VMSS instances
      name             = "snet-app-${var.resource_naming}"
      address_prefixes = ["10.0.1.0/24"]
    }

    subnet {
      # Management subnet for the future use
      name             = "snet-mgmt-${var.resource_naming}"
      address_prefixes = ["10.0.2.0/24"]
      #security_group   = azurerm_network_security_group.vnet.id
    }
  }
  ```
  ```hcl
  resource "azurerm_linux_virtual_machine_scale_set" "vmss" {
    ...

    subnet_id = azurerm_virtual_network.vnet.subnet[0].id
  }
  ```

  To fix this, I switched from inline `subnet { }` blocks to standalone `azurerm_subnet` resources, This way, each subnet can be referenced directly by name instead of by position:

  ```hcl
  resource "azurerm_subnet" "app" {
    name                 = "snet-app-${var.resource_naming}"
    resource_group_name  = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.vnet.name
    address_prefixes     = ["10.0.1.0/24"]
  }

  resource "azurerm_subnet" "mgmt" {
    ...
  }
  ```
  ```hcl
  resource "azurerm_linux_virtual_machine_scale_set" "vmss" {
  ...

    subnet_id = azurerm_subnet.app.id
  }
  ```

- **Missing SSH key for VMSS admin access:**

  `admin_ssh_key` needs a public key to install on the VM instances, but I didn't have an SSH key pair generated yet. The fix was generating a new SSH key pair, then pointing `file()` at the public key:

  ```bash
  ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
  ```

  Then pointing `file()` at the public key:

  ```hcl
  public_key = file("~/.ssh/id_rsa.pub")
  ```

- **Indexing into a nested block output:**

  I tried to grab a specific field from `source_image_reference` using `[0]`, but it's a single nested block, not a list, so it can't be indexed.

  ```hcl
  output "vmss" {
    value = [
      azurerm_linux_virtual_machine_scale_set.vmss.name,
      azurerm_linux_virtual_machine_scale_set.vmss.source_image_reference[0]
    ]
  }
  ```

  The fix was referencing it directly as an object instead of indexing into it:

  ```hcl
  output "vmss" {
    value = {
      name  = azurerm_linux_virtual_machine_scale_set.vmss.name
      image = azurerm_linux_virtual_machine_scale_set.vmss.source_image_reference
    }
  }
  ```

- **Indexing into a set attribute:**

  Now for this one, I tried to grab the VNet's address space with `[0]`, but `address_space` is a set, not a list. Sets have no order, so indexing isn't allowed.

  ```hcl
  resource "azurerm_virtual_network" "vnet" {
    name                = "vnet-${var.resource_naming}"
    address_space       = ["10.0.0.0/16"]
  }
  ```
  ```hcl
  output "vnet_name" {
    value = {
      name          = azurerm_virtual_network.vnet.name
      address_space = azurerm_virtual_network.vnet.address_space[0]
    }
  }
  ```

  The fix was converting the set to a list first with `tolist()`, and then indexing it:

  ```hcl
  output "vnet_name" {
    value = {
      name          = azurerm_virtual_network.vnet.name
      address_space = tolist(azurerm_virtual_network.vnet.address_space)[0]
    }
  }
  ```
  
  > Note: `address_prefixes` (subnet) and `address_space` (VNet) look like they should behave the same way, but they don't — `address_prefixes` is a `list(string)` (indexable), while `address_space` is a `set(string)` (not indexable).

  ```hcl
  output "subnets" {
    value = {
      Application_subnet = azurerm_subnet.app.address_prefixes[0]
      Management_subnet  = azurerm_subnet.mgmt.address_prefixes[0]
    }
  }
  ```