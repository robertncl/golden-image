variable "client_id" {}
variable "client_secret" {}
variable "tenant_id" {}
variable "subscription_id" {}

source "azure-arm" "redhat" {
  client_id                  = var.client_id
  client_secret              = var.client_secret
  tenant_id                  = var.tenant_id
  subscription_id            = var.subscription_id
  managed_image_resource_group_name = "myResourceGroup"
  managed_image_name         = "redhat-hardened"
  os_type                    = "Linux"
  image_publisher            = "RedHat"
  image_offer                = "RHEL"
  image_sku                  = "8_6"
  location                   = "East US"
  vm_size                    = "Standard_D2s_v3"
}

build {
  sources = ["source.azure-arm.redhat"]
  provisioner "shell" {
    inline = [
      "echo 'Applying CIS hardening for RedHat...'",
      "/tmp/harden-redhat.sh"
    ]
  }
} 