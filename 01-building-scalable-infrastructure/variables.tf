variable "resource_naming" {
  type = string
  default = "test01-westeu"
}

variable "allowed_regions" {
  type = list(string)
  default = ["eastus", "westeurope", "southeastasia"]
}

variable "location" {
  type = string
  default = "westeurope"

  # Rule that restricts other regions
  validation {    
    /* Variable validation blocks can only reference the variable itself! -> var.location */
    condition     = contains(var.allowed_regions, var.location)
    error_message = "The location must be one of the allowed regions: ${join(", ", var.allowed_regions)}"
    /* var.allowed_regions is a list(string) (e.g. ["eastus", "westeurope", "southeastasia"]), so trying to interpolate it directly into a string doesn't work */
  }
}

variable "environment" {
  type = string
  default = "test"

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "The environment must be one of the following: dev, test, prod"
  }
}

variable "instance_count" {
  description = "Number of VMSS instances"
  type        = number
  default     = 2
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}