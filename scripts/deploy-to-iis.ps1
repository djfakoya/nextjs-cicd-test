param (
  [string]$BuildArtifactPath,
  [string]$DeployPath,
  [string]$AppPoolName,
  [string]$SiteName,
  [int]$PortHttp,
  [int]$PortHttps
)

$ErrorActionPreference = "Stop"

Write-Host "Creating deployment folder if it doesn't exist..."
if (!(Test-Path $DeployPath)) {
  New-Item -ItemType Directory -Force -Path $DeployPath
}

Write-Host "Copying build artifacts to deployment folder..."
Copy-Item -Path "$BuildArtifactPath\*" -Destination $DeployPath -Recurse -Force

Import-Module WebAdministration

Write-Host "Creating application pool if not exists..."
if (-not (Get-WebAppPoolState -Name $AppPoolName -ErrorAction SilentlyContinue)) {
  New-WebAppPool -Name $AppPoolName
}

Write-Host "Creating or updating IIS site..."
$site = Get-Website | Where-Object { $_.Name -eq $SiteName }

if (-not $site) {
  New-Website -Name $SiteName -PhysicalPath $DeployPath -Port $PortHttp -ApplicationPool $AppPoolName
  Set-ItemProperty "IIS:\Sites\$SiteName" -Name bindings -Value @(
    @{protocol="http"; bindingInformation="*:$PortHttp:"},
    @{protocol="https"; bindingInformation="*:$PortHttps:"}
  )
} else {
  Set-ItemProperty "IIS:\Sites\$SiteName" -Name physicalPath -Value $DeployPath
  Restart-WebAppPool -Name $AppPoolName
  Restart-WebSite -Name $SiteName
}

Write-Host "✅ Deployment complete."
