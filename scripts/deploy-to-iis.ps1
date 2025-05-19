param (
  [string]$ZipFilePath,
  [string]$UnzipPath,
  [string]$DeployPath,
  [string]$AppPoolName,
  [string]$SiteName,
  [int]$PortHttp,
  [int]$PortHttps
)

$ErrorActionPreference = "Stop"

Write-Host "=== Deploy to IIS Script Starting ==="
Write-Host "ZipFilePath: $ZipFilePath"
Write-Host "UnzipPath: $UnzipPath"
Write-Host "DeployPath: $DeployPath"
Write-Host "AppPoolName: $AppPoolName"
Write-Host "SiteName: $SiteName"
Write-Host "PortHttp: $PortHttp"
Write-Host "PortHttps: $PortHttps"
Write-Host "===================================="

try {
  if (-not (Test-Path $ZipFilePath)) {
    throw "❌ ZIP file not found: $ZipFilePath"
  }

  if (Test-Path $DeployPath) {
    Write-Host "Removing existing deploy path: $DeployPath"
    Remove-Item -Recurse -Force $DeployPath
  }

  Write-Host "Creating deploy path: $DeployPath"
  New-Item -ItemType Directory -Force -Path $DeployPath | Out-Null

  Write-Host "Extracting ZIP file to deploy path..."
  Expand-Archive -Path $ZipFilePath -DestinationPath $DeployPath -Force

  Import-Module WebAdministration

  # Create app pool if it doesn't exist
  if (-not (Test-Path "IIS:\AppPools\$AppPoolName")) {
    Write-Host "Creating App Pool: $AppPoolName"
    New-WebAppPool -Name $AppPoolName
  }

  # Create or update site
  $site = Get-Website | Where-Object { $_.Name -eq $SiteName }
  if (-not $site) {
    Write-Host "Creating new IIS site: $SiteName"
    New-Website -Name $SiteName -PhysicalPath $DeployPath -ApplicationPool $AppPoolName -Port $PortHttp

    # Add HTTPS binding
    New-WebBinding -Name $SiteName -Protocol https -Port $PortHttps -IPAddress "*" -HostHeader ""
  } else {
    Write-Host "Updating existing site: $SiteName"
    Set-ItemProperty "IIS:\Sites\$SiteName" -Name physicalPath -Value $DeployPath
    Restart-WebAppPool -Name $AppPoolName
    Restart-WebSite -Name $SiteName
  }

  Write-Host "✅ Deployment to IIS complete."
}
catch {
  Write-Error "❌ Deployment failed: $($_.Exception.Message)"
  exit 1
}
