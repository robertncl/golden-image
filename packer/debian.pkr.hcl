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
# Minimum OpenSCAP CIS compliance score required for the build to succeed.
variable "min_cis_score" { default = "70" }

source "azure-arm" "debian" {
  client_id                         = var.client_id
  client_secret                     = var.client_secret
  tenant_id                         = var.tenant_id
  subscription_id                   = var.subscription_id
  managed_image_resource_group_name = var.resource_group
  managed_image_name                = "debian-hardened-{{timestamp}}"
  os_type                           = "Linux"
  image_publisher                   = "Debian"
  image_offer                       = "debian-12"
  image_sku                         = "12"
  location                          = var.location
  vm_size                           = var.vm_size
}

build {
  sources = ["source.azure-arm.debian"]

  # Ship the VM hardening scripts onto the build VM (the step the old config
  # was missing — it referenced /tmp/harden-debian.sh that never existed).
  provisioner "file" {
    source      = "../scripts/vm"
    destination = "/tmp"
  }

  # Supplementary host hardening, then OpenSCAP CIS remediation + scoring gate.
  provisioner "shell" {
    inline = [
      "sudo chmod +x /tmp/vm/*.sh",
      "echo '== Supplementary CIS host hardening (Debian) =='",
      "sudo -E bash /tmp/vm/harden-debian.sh",
      "echo '== OpenSCAP CIS remediation + compliance gate =='",
      "sudo MIN_SCORE=${var.min_cis_score} bash /tmp/vm/openscap-remediate.sh"
    ]
  }

  # Pull the OpenSCAP HTML report out as a build artifact for auditing.
  provisioner "file" {
    direction   = "download"
    source      = "/var/log/openscap/cis-report.html"
    destination = "reports/debian-cis-report.html"
  }
}
