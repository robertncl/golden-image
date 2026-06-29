packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = ">= 2.0.0"
    }
  }
}

variable "client_id" { default = "" }
variable "client_secret" {
  default   = ""
  sensitive = true
}
variable "tenant_id" { default = "" }
variable "subscription_id" { default = "" }
variable "resource_group" { default = "myResourceGroup" }
variable "location" { default = "East US" }
variable "vm_size" { default = "Standard_D2s_v3" }

# Local administrator password for the transient build VM. NO DEFAULT — must be
# supplied via PKR_VAR_admin_password (e.g. from a CI secret). This replaces the
# previously hardcoded plaintext password.
variable "admin_password" {
  type      = string
  sensitive = true
}

source "azure-arm" "windows" {
  client_id                         = var.client_id
  client_secret                     = var.client_secret
  tenant_id                         = var.tenant_id
  subscription_id                   = var.subscription_id
  managed_image_resource_group_name = var.resource_group
  managed_image_name                = "windows-hardened-{{timestamp}}"
  managed_image_location            = var.location
  os_type                           = "Windows"
  image_publisher                   = "MicrosoftWindowsServer"
  image_offer                       = "WindowsServer"
  image_sku                         = "2022-datacenter-azure-edition"
  location                          = var.location
  vm_size                           = var.vm_size
  communicator                      = "winrm"
  winrm_use_ssl                     = true
  winrm_insecure                    = true
  winrm_timeout                     = "10m"
  winrm_username                    = "packer"
}

build {
  sources = ["source.azure-arm.windows"]

  # Set the local admin password from the (secret) variable — no plaintext.
  provisioner "powershell" {
    inline = [
      "net user Administrator \"${var.admin_password}\""
    ]
  }

  # Apply the CIS Windows Server hardening script.
  provisioner "file" {
    source      = "../scripts/vm/harden-windows.ps1"
    destination = "C:/Windows/Temp/harden-windows.ps1"
  }
  provisioner "powershell" {
    inline = [
      "powershell -ExecutionPolicy Bypass -File C:/Windows/Temp/harden-windows.ps1"
    ]
  }
}
