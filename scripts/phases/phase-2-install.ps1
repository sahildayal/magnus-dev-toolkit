$ErrorActionPreference = 'Stop'

$userConfigPath = "$PSScriptRoot\..\..\state\user-config.json"
$manifestPath = "$PSScriptRoot\..\..\config\tools-manifest.json"

if (-not (Test-Path $userConfigPath)) {
    Write-Warning "User config not found. Assuming all tools to be installed."
    # Setup dummy userConfig
    $userConfig = @{ tools = @{ python=$true; java=$true; nodejs=$true; csharp=$true; go=$true; rust=$true; cpp=$true }; containers = @{ docker=$true; kubernetes=$true }; cloud = @{ aws=$true; gcp=$true; azure=$true } }
} else {
    $userConfig = Get-Content $userConfigPath | ConvertFrom-Json
}

$manifest = Get-Content $manifestPath | ConvertFrom-Json
$toInstall = @()

if ($userConfig.tools.python) { $toInstall += $manifest.tools | Where-Object { $_.name -like "*Python*" } }
if ($userConfig.tools.java) { $toInstall += $manifest.tools | Where-Object { $_.name -like "*Java*" } }
if ($userConfig.tools.nodejs) { $toInstall += $manifest.tools | Where-Object { $_.name -like "*Node*" } }
if ($userConfig.tools.csharp) { $toInstall += $manifest.tools | Where-Object { $_.name -like "*C#*" } }
if ($userConfig.tools.go) { $toInstall += $manifest.tools | Where-Object { $_.name -like "*Go*" } }
if ($userConfig.tools.rust) { $toInstall += $manifest.tools | Where-Object { $_.name -like "*Rust*" } }
if ($userConfig.tools.cpp) { $toInstall += $manifest.tools | Where-Object { $_.name -like "*C/C++*" } }

if ($userConfig.containers.docker) { $toInstall += $manifest.tools | Where-Object { $_.name -like "*Docker*" } }
if ($userConfig.containers.kubernetes) { $toInstall += $manifest.tools | Where-Object { $_.name -like "*Kubernetes*" } }

if ($userConfig.cloud.aws) { $toInstall += $manifest.tools | Where-Object { $_.name -like "*AWS*" } }
if ($userConfig.cloud.gcp) { $toInstall += $manifest.tools | Where-Object { $_.name -like "*Google Cloud*" } }
if ($userConfig.cloud.azure) { $toInstall += $manifest.tools | Where-Object { $_.name -like "*Azure*" } }

Write-Host ""
Write-Host "┌─────────────────────────────────────────────┐" -ForegroundColor Yellow
Write-Host "│  HARD GATE: About to Install               │" -ForegroundColor Yellow
Write-Host "└─────────────────────────────────────────────┘" -ForegroundColor Yellow
Write-Host ""
Write-Host "The following will be installed:" -ForegroundColor Cyan

if ($toInstall.Count -eq 0) {
    Write-Host "  No tools selected."
} else {
    $toInstall | ForEach-Object { Write-Host "  ✓ $($_.name)" }
}

Write-Host ""
Write-Host "Press ENTER to continue, or Ctrl+C to cancel" -ForegroundColor Yellow
Read-Host

$toInstall | ForEach-Object {
  Write-Host "Installing: $($_.name)" -ForegroundColor Green
  if ($_.installer -eq 'winget') {
    & winget install --id $_.package_id -e -h --force --accept-package-agreements --accept-source-agreements
  } elseif ($_.installer -eq 'npm') {
    & npm install -g $_.package_name --loglevel=error
  }
}

Write-Host "✓ Phase 2 (Installation) completed" -ForegroundColor Green
