variable "prefix" {
  description = "The prefix which should be used for all resources in this project"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.prefix))
    error_message = "prefix must be 3-20 characters: lowercase letters, numbers and hyphens only."
  }
}

variable "location" {
  description = "The Azure region in which all resources in this project should be created"
  type        = string

  validation {
    condition     = var.location == "germanywestcentral"
    error_message = "Only westeurope is allowed in this project."
  }
}

variable "vm_size" {
  description = "Size of the Linux VM"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "admin_username" {
  description = "Admin username for SSH login on the Linux VM"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key" {
  description = "SSH public key for the VM admin user (public key only, never the private key)"
  type        = string

  validation {
    condition     = can(regex("^(ssh-ed25519|ssh-rsa) ", var.ssh_public_key))
    error_message = "ssh_public_key must be an OpenSSH public key (ssh-ed25519 or ssh-rsa)."
  }
}