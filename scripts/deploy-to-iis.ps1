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

Write-Host "==== PARAMETERS RECEIVED ===="
Write-Host "ZipFilePath: $ZipFilePath"
Write-Host "UnzipPath: $UnzipPath"
Write-Host "DeployPath: $DeployPath"
Write-Host "AppPoolName: $AppPoolName"
Write-Host "SiteName: $SiteName"
Write-Host "PortHttp: $PortHttp"
Write-Host "PortHttps: $PortHttps"
Write-Host "============================="

try {
  if (-not (Test-Path $ZipFilePath)) {
    throw "ZIP file not found at path: $ZipFilePath"
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

  if (-not (Get-WebAppPoolState -Name $AppPoolName -ErrorAction SilentlyContinue)) {
    Write-Host "Creating App Pool: $AppPoolName"
    New-WebAppPool -Name $AppPoolName
  }

  $site = Get-Website | Where-Object { $_.Name -eq $SiteName }
  if (-not $site) {
    Write-Host "Creating new IIS site: $SiteName"
    New-Website -Name $SiteName -PhysicalPath $DeployPath -Port $PortHttp -ApplicationPool $AppPoolName
    Set-ItemProperty "IIS:\Sites\$SiteName" -Name bindings -Value @(
      @{protocol="http"; bindingInformation="*:$PortHttp:"},
      @{protocol="https"; bindingInformation="*:$PortHttps:"}
    )
  } else {
    Write-Host "Updating existing site: $SiteName"
    Set-ItemProperty "IIS:\Sites\$SiteName" -Name physicalPath -Value $DeployPath
    Restart-WebAppPool -Name $AppPoolName
    Restart-WebSite -Name $SiteName
  }

  Write-Host "✅ Deployment complete."
}
catch {
  Write-Error "❌ Deployment failed: $($_.Exception.Message)"
  exit 1
}
