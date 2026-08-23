$ErrorActionPreference = 'Stop'

$state = @{
  detected = @{}
  missing = @()
  started_at = Get-Date
}

$manifestPath = "$PSScriptRoot\..\..\config\tools-manifest.json"
$manifest = Get-Content $manifestPath | ConvertFrom-Json

# Not every real install lands on PATH. Verified on a real machine: Google Chrome
# installs and runs fine but never adds "chrome" to PATH, so a plain Get-Command
# reports it as missing even though it's there - the same is true of several other
# GUI installers (e.g. 7-Zip). Windows itself tracks these via the "App Paths"
# registry key regardless of PATH, so fall back to it before concluding "missing".
function Test-ToolInstalled {
    param([string]$Command)
    $cmd = Get-Command $Command -ErrorAction SilentlyContinue | Where-Object { $_.CommandType -eq 'Application' } | Select-Object -First 1
    if ($cmd) { return $cmd }

    $exeName = if ($Command -match '\.exe$') { $Command } else { "$Command.exe" }
    foreach ($hive in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths', 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths')) {
        $key = Join-Path $hive $exeName
        if (Test-Path $key) {
            $exePath = (Get-Item $key).GetValue('')
            if ($exePath -and (Test-Path $exePath)) {
                return [PSCustomObject]@{ Source = $exePath; CommandType = 'Application'; Version = $null }
            }
        }
    }
    return $null
}

foreach ($tool in $manifest.tools) {
  $installed = Test-ToolInstalled -Command $tool.command
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
