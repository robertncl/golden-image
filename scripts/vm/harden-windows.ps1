# Host CIS hardening for Windows Server VM images (run by Packer on a real VM).
# Applies CIS Microsoft Windows Server Benchmark controls via local security
# policy, account policy, firewall and audit configuration.
$ErrorActionPreference = 'Stop'

Write-Host '[vm-harden-windows] Account & password policy  [CIS 1.1 / 1.2]'
net accounts /minpwlen:14 /maxpwage:365 /minpwage:1 /uniquepw:24
net accounts /lockoutthreshold:5 /lockoutduration:15 /lockoutwindow:15

Write-Host '[vm-harden-windows] Enforce password complexity'
secedit /export /cfg C:\secpol.cfg | Out-Null
(Get-Content C:\secpol.cfg) `
  -replace 'PasswordComplexity\s*=\s*0', 'PasswordComplexity = 1' `
  -replace 'MinimumPasswordLength\s*=\s*\d+', 'MinimumPasswordLength = 14' |
  Set-Content C:\secpol.cfg
secedit /configure /db C:\Windows\security\local.sdb /cfg C:\secpol.cfg /areas SECURITYPOLICY | Out-Null
Remove-Item C:\secpol.cfg -Force

Write-Host '[vm-harden-windows] Disable built-in Guest account  [CIS 2.3.1]'
net user Guest /active:no

Write-Host '[vm-harden-windows] Enable Windows Firewall on all profiles  [CIS 9.x]'
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True -DefaultInboundAction Block -DefaultOutboundAction Allow

Write-Host '[vm-harden-windows] Configure audit policy  [CIS 17.x]'
auditpol /set /category:'Logon/Logoff' /success:enable /failure:enable
auditpol /set /category:'Account Logon' /success:enable /failure:enable
auditpol /set /category:'Account Management' /success:enable /failure:enable
auditpol /set /category:'Policy Change' /success:enable /failure:enable
auditpol /set /category:'System' /success:enable /failure:enable

Write-Host '[vm-harden-windows] Disable SMBv1  [CIS 18.x]'
Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force

Write-Host '[vm-harden-windows] Windows CIS hardening complete.'
