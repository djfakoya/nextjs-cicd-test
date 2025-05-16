param (
  [string]$BuildArtifactPath,
  [string]$DeployPath,
  [string]$AppPoolName,
  [string]$SiteName,
  [int]$PortHttp,
  [int]$PortHttps
)

$ErrorActionPreference = "Stop"

Write-Host "📁 BuildArtifactPath: $BuildArtifactPath"
Write-Host "📁 DeployPath: $DeployPath"
Write-Host "🌐 AppPoolName: $AppPoolName"
Write-Host "🌐 SiteName: $SiteName"

try {
  if (!(Test-Path $DeployPath)) {
    Write-Host "Creating deployment folder..."
    New-Item -ItemType Directory -Force -Path $DeployPath
  }

  Write-Host "Copying build artifacts..."
  Copy-Item -Path "$BuildArtifactPath\*" -Destination $DeployPath -Recurse -Force

  Import-Module WebAdministration

  Write-Host "Checking for application pool..."
  if (-not (Get-WebAppPoolState -Name $AppPoolName -ErrorAction SilentlyContinue)) {
    New-WebAppPool -Name $AppPoolName
  }

  $site = Get-Website | Where-Object { $_.Name -eq $SiteName }

  if (-not $site) {
    Write-Host "Creating new IIS site..."
    New-Website -Name $SiteName -PhysicalPath $DeployPath -Port $PortHttp -ApplicationPool $AppPoolName

    # Use New-WebBinding instead of Set-ItemProperty
    Write-Host "Adding HTTP and HTTPS bindings..."
    New-WebBinding -Name $SiteName -Protocol "http" -Port $PortHttp -IPAddress "*" -HostHeader ""
    New-WebBinding -Name $SiteName -Protocol "https" -Port $PortHttps -IPAddress "*" -HostHeader ""
  } else {
    Write-Host "Updating site path and restarting app pool..."
    Set-ItemProperty "IIS:\Sites\$SiteName" -Name physicalPath -Value $DeployPath
    Restart-WebAppPool -Name $AppPoolName
    Restart-WebSite -Name $SiteName
  }

  Write-Host "✅ Deployment completed successfully."

} catch {
  Write-Error "❌ Deployment failed: $_"
  exit 1
}
