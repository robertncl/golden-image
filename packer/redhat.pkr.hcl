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
variable "min_cis_score" { default = "70" }

source "azure-arm" "redhat" {
  client_id                         = var.client_id
  client_secret                     = var.client_secret
  tenant_id                         = var.tenant_id
  subscription_id                   = var.subscription_id
  managed_image_resource_group_name = var.resource_group
  managed_image_name                = "redhat-hardened-{{timestamp}}"
  os_type                           = "Linux"
  image_publisher                   = "RedHat"
  image_offer                       = "RHEL"
  image_sku                         = "9_4"
  location                          = var.location
  vm_size                           = var.vm_size
}

build {
  sources = ["source.azure-arm.redhat"]

  provisioner "file" {
    source      = "../scripts/vm"
    destination = "/tmp"
  }

  provisioner "shell" {
    inline = [
      "sudo chmod +x /tmp/vm/*.sh",
      "echo '== Supplementary CIS host hardening (RHEL) =='",
      "sudo -E bash /tmp/vm/harden-redhat.sh",
      "echo '== OpenSCAP CIS remediation + compliance gate =='",
      "sudo MIN_SCORE=${var.min_cis_score} bash /tmp/vm/openscap-remediate.sh"
    ]
  }

  provisioner "file" {
    direction   = "download"
    source      = "/var/log/openscap/cis-report.html"
    destination = "reports/redhat-cis-report.html"
  }
}
