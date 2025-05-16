param (
  [string]$BuildArtifactZipPath,
  [string]$DeployPath,
  [string]$AppPoolName,
  [string]$SiteName,
  [int]$PortHttp,
  [int]$PortHttps
)

$ErrorActionPreference = "Stop"

Write-Host "📦 Zipped artifact: $BuildArtifactZipPath"
Write-Host "🚀 Deploying to: $DeployPath"

# Create deployment directory if it doesn't exist
if (!(Test-Path $DeployPath)) {
    Write-Host "Creating deployment folder at $DeployPath..."
    New-Item -ItemType Directory -Force -Path $DeployPath
}

# Clear previous deployment (optional: comment if you want to keep old files)
Write-Host "Cleaning up existing contents in deploy path..."
Remove-Item "$DeployPath\*" -Recurse -Force -ErrorAction SilentlyContinue

# Unzip the build artifact into the deployment directory
Write-Host "Unzipping artifact to deploy path..."
Expand-Archive -Path $BuildArtifactZipPath -DestinationPath $DeployPath -Force

# Load WebAdministration module to interact with IIS
Import-Module WebAdministration

# Create application pool if it doesn't exist
if (-not (Get-WebAppPoolState -Name $AppPoolName -ErrorAction SilentlyContinue)) {
    Write-Host "Creating application pool: $AppPoolName"
    New-WebAppPool -Name $AppPoolName
}

# Check if IIS site exists
$site = Get-Website | Where-Object { $_.Name -eq $SiteName }

if (-not $site) {
    Write-Host "Creating new IIS website: $SiteName"
    New-Website -Name $SiteName -PhysicalPath $DeployPath -Port $PortHttp -ApplicationPool $AppPoolName

    Write-Host "Adding HTTP and HTTPS bindings..."
    New-WebBinding -Name $SiteName -Protocol "http" -Port $PortHttp -IPAddress "*"
    New-WebBinding -Name $SiteName -Protocol "https" -Port $PortHttps -IPAddress "*"
} else {
    Write-Host "Updating site path and restarting..."
    Set-ItemProperty "IIS:\Sites\$SiteName" -Name physicalPath -Value $DeployPath
    Restart-WebAppPool -Name $AppPoolName
    Restart-WebSite -Name $SiteName
}

Write-Host "✅ Deployment to IIS completed successfully."
