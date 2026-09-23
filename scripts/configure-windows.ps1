param(
  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$VpsPublicKey,

  [switch]$InstallTailscale
)

$ErrorActionPreference = "Stop"

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  throw "Run this script from an elevated PowerShell session."
}

$capability = Get-WindowsCapability -Online -Name "OpenSSH.Server*"
if ($capability.State -ne "Installed") {
  Add-WindowsCapability -Online -Name $capability.Name
}

Set-Service sshd -StartupType Automatic
Start-Service sshd

if (-not (Get-NetFirewallRule -Name "OpenSSH-Server-In-Tailscale" -ErrorAction SilentlyContinue)) {
  New-NetFirewallRule -Name "OpenSSH-Server-In-Tailscale" `
    -DisplayName "OpenSSH Server (Tailscale)" `
    -Enabled True -Direction Inbound -Protocol TCP -LocalPort 22 `
    -Action Allow -Profile Any | Out-Null
}

$authorizedKeys = "C:\ProgramData\ssh\administrators_authorized_keys"
$normalizedKey = $VpsPublicKey.Trim()
$existing = if (Test-Path $authorizedKeys) { Get-Content $authorizedKeys -Raw } else { "" }
if ($existing -notmatch [regex]::Escape($normalizedKey)) {
  Add-Content -Path $authorizedKeys -Value $normalizedKey
}

icacls $authorizedKeys /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F" | Out-Null

$sshDefaults = "C:\ProgramData\ssh\sshd_config"
$defaultShellValue = "C:\Program Files\PowerShell\7\pwsh.exe"
$defaultShell = if (Test-Path $defaultShellValue) { $defaultShellValue } else { "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" }
if (-not (Get-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -ErrorAction SilentlyContinue)) {
  New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell `
    -Value $defaultShell -PropertyType String | Out-Null
}

Restart-Service sshd

if ($InstallTailscale) {
  if (-not (Get-Command tailscale -ErrorAction SilentlyContinue)) {
    winget install --id tailscale.tailscale --source winget --accept-package-agreements --accept-source-agreements
  }
  & tailscale up
}

Write-Host "Windows OpenSSH Server is configured."
Write-Host "Tailscale IPv4: $(if (Get-Command tailscale -ErrorAction SilentlyContinue) { tailscale ip -4 } else { 'not installed' })"
Write-Host "Authorize the VPS key in: $authorizedKeys"
