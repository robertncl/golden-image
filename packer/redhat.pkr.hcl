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
    script = "../scripts/harden-redhat.sh"
  }
  provisioner "shell" {
    inline = [
      "yum install -y openscap-scanner scap-security-guide",
      "oscap xccdf eval --profile xccdf_org.ssgproject.content_profile_standard --results /tmp/openscap-results.xml /usr/share/xml/scap/ssg/content/ssg-rhel8-ds.xml || true",
      "cat /tmp/openscap-results.xml"
    ]
  }
} 