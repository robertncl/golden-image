variable "client_id" {}
variable "client_secret" {}
variable "tenant_id" {}
variable "subscription_id" {}

source "azure-arm" "alpine" {
  client_id                  = var.client_id
  client_secret              = var.client_secret
  tenant_id                  = var.tenant_id
  subscription_id            = var.subscription_id
  managed_image_resource_group_name = "myResourceGroup"
  managed_image_name         = "alpine-hardened"
  os_type                    = "Linux"
  image_publisher            = "OpenLogic"
  image_offer                = "CentOS"
  image_sku                  = "7.9"
  location                   = "East US"
  vm_size                    = "Standard_D2s_v3"
  # Note: Azure does not provide Alpine, so this is a placeholder. Replace with a custom VHD if available.
}

build {
  sources = ["source.azure-arm.alpine"]
  provisioner "shell" {
    script = "../scripts/harden-alpine.sh"
  }
  provisioner "shell" {
    inline = [
      "echo 'Applying CIS hardening for Alpine...'",
      "/tmp/harden-alpine.sh"
    ]
  }
} 