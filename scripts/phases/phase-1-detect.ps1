$ErrorActionPreference = 'Stop'

$state = @{
  detected = @{}
  missing = @()
  started_at = Get-Date
}

$manifestPath = "$PSScriptRoot\..\..\config\tools-manifest.json"
$manifest = Get-Content $manifestPath | ConvertFrom-Json

foreach ($tool in $manifest.tools) {
  $installed = & { Get-Command $tool.command -ErrorAction SilentlyContinue }
  if ($installed) {
    $state.detected[$tool.name] = $installed.Version.ToString()
  } else {
    $state.missing += $tool.name
  }
}

$stateDir = "$PSScriptRoot\..\..\state"
if (-not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }
$state | ConvertTo-Json | Out-File "$stateDir\installation-state.json"

Write-Host "OK Phase 1 (Detection) completed" -ForegroundColor Green
