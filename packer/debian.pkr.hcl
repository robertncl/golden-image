variable "client_id" {}
variable "client_secret" {}
variable "tenant_id" {}
variable "subscription_id" {}

source "azure-arm" "debian" {
  client_id                  = var.client_id
  client_secret              = var.client_secret
  tenant_id                  = var.tenant_id
  subscription_id            = var.subscription_id
  managed_image_resource_group_name = "myResourceGroup"
  managed_image_name         = "debian-hardened"
  os_type                    = "Linux"
  image_publisher            = "Debian"
  image_offer                = "debian-11"
  image_sku                  = "11"
  location                   = "East US"
  vm_size                    = "Standard_D2s_v3"
}

build {
  sources = ["source.azure-arm.debian"]
  provisioner "shell" {
    script = "../scripts/harden-debian.sh"
  }
  provisioner "shell" {
    inline = [
      "apt-get update && apt-get install -y openscap-scanner scap-security-guide",
      "oscap xccdf eval --profile xccdf_org.ssgproject.content_profile_standard --results /tmp/openscap-results.xml /usr/share/xml/scap/ssg/content/ssg-debian11-ds.xml || true",
      "cat /tmp/openscap-results.xml"
    ]
  }
} 