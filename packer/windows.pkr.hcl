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

  # CIS hardening for Windows (PowerShell inline)
  provisioner "powershell" {
    inline = [
      # 1. Enforce password complexity and minimum length
      "Write-Host 'Enforcing password complexity and minimum length'",
      "net accounts /minpwlen:14 /maxpwage:90 /minpwage:1 /uniquepw:5",
      "secedit /export /cfg C:\\secpol.cfg",
      "(Get-Content C:\\secpol.cfg) -replace 'PasswordComplexity = 0', 'PasswordComplexity = 1' | Set-Content C:\\secpol.cfg",
      "secedit /configure /db secedit.sdb /cfg C:\\secpol.cfg /areas SECURITYPOLICY",
      "Remove-Item C:\\secpol.cfg -Force",

      # 2. Account lockout policy
      "Write-Host 'Configuring account lockout policy'",
      "net accounts /lockoutthreshold:5 /lockoutduration:15 /lockoutwindow:15",

      # 3. Disable guest account
      "Write-Host 'Disabling guest account'",
      "net user Guest /active:no",

      # 4. Enable Windows Firewall
      "Write-Host 'Enabling Windows Firewall'",
      "Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True",

      # 5. Configure audit policy
      "Write-Host 'Configuring audit policy'",
      "auditpol /set /category:'Logon/Logoff' /success:enable /failure:enable",
      "auditpol /set /category:'Account Logon' /success:enable /failure:enable"
    ]
  }
} 