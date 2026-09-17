# Introduction

## Content List

## Features

## Architecture Diagram

## Demo / Lab

## Challenges & How I Resolved Them

### 1. Implementing the region validation rule

While implementing the region validation rule, I ran into two mistakes that caused the validation to not work as expected:

- **Selecting a region by list index instead of an explicit variable:**

  I was picking a region by its position in a list instead of just choosing it directly. It technically worked, but it meant the deployed region was silently tied to whatever order the list happened to be in — if I ever reordered the list, my deployment region would quietly change without any warning.

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

  While fixing this I also caught two smaller mistakes hiding in the same code: `list()` isn't actually a valid type on its own — Terraform needs to know what's *inside* the list, so it has to be `list(string)`. And `"WestEU"` isn't a real Azure region name. Azure expects `"westeurope"` (lowercase, no spaces). 

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

  This validated `allowed_regions` against a hardcoded copy of itself, so it could never actually fail — it wasn't validating a *selected* region at all, just confirming the list contained its own values.

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

  Two problems here: the `condition` checked `allowed_regions` against a copy of itself, so it could never actually fail — it wasn't validating a *selected* region at all. And the `error_message` tried to drop `var.allowed_regions` (a `list(string)`) straight into a string, which Terraform can't do — string interpolation only accepts a single string value.

  The fix was separating "the list of allowed regions" from "the region actually chosen" with a new `location` variable, and wrapping the list in `join()` to turn it into a proper string for the error message:

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

  I tried to reference my app subnet by index, but `subnet` inside `azurerm_virtual_network` is a set, not a list — sets have no order, so there's no "first" item.

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

  To fix this, I was switching from inline `subnet { }` blocks to standalone `azurerm_subnet` resources, so each subnet can be referenced directly by name instead of by position:

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

  I tried to grab a specific field from `source_image_reference` using `[0]`, but it's a single nested block, not a list — so it can't be indexed.

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

  Now for this one, I tried to grab the VNet's address space with `[0]`, but `address_space` is a set, not a list — sets have no order, so indexing isn't allowed.

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

  The fix was converting the set to a list first with `tolist()`, then indexing it:

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