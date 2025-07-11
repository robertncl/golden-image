variable "client_id" {}
variable "client_secret" {}
variable "tenant_id" {}
variable "subscription_id" {}

source "azure-arm" "windows" {
  client_id            = var.client_id
  client_secret        = var.client_secret
  tenant_id            = var.tenant_id
  subscription_id      = var.subscription_id
  managed_image_resource_group_name = "myResourceGroup"
  managed_image_name               = "windows-hardened"
  managed_image_location           = "East US"
  os_type                          = "Windows"
  image_publisher                  = "MicrosoftWindowsServer"
  image_offer                      = "WindowsServer"
  image_sku                        = "2022-Datacenter"
  location                         = "East US"
  vm_size                          = "Standard_D2s_v3"
}

build {
  sources = ["source.azure-arm.windows"]

  # Set local admin password and enable WinRM
  provisioner "powershell" {
    inline = [
      "net user Administrator 'P@ssw0rd123!'",
      "Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections' -Value 0",
      "Enable-PSRemoting -Force"
    ]
  }

  # TODO: Add Windows CIS hardening steps here
} 