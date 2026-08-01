$ErrorActionPreference = 'Stop'

$state = @{
  detected = @{}
  missing = @()
  started_at = Get-Date
}

$manifestPath = "$PSScriptRoot\..\..\config\tools-manifest.json"
$manifest = Get-Content $manifestPath | ConvertFrom-Json

foreach ($tool in $manifest.tools) {
  # Only CommandType 'Application' counts as detected - Windows PowerShell 5.1 ships
  # built-in curl/wget aliases (-> Invoke-WebRequest) that would otherwise report as installed.
  $installed = & { Get-Command $tool.command -ErrorAction SilentlyContinue | Where-Object { $_.CommandType -eq 'Application' } | Select-Object -First 1 }
  if ($installed) {
    $state.detected[$tool.name] = if ($installed.Version) { $installed.Version.ToString() } else { "unknown" }
  } else {
    $state.missing += $tool.name
  }
}

$stateDir = "$PSScriptRoot\..\..\state"
if (-not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }
$state | ConvertTo-Json | Out-File "$stateDir\installation-state.json" -Encoding UTF8

Write-Host "OK Phase 1 (Detection) completed" -ForegroundColor Green
