param(
    [switch]$CI,             # Skip core tool installs to keep CI fast; auto-set via $env:GITHUB_ACTIONS
    [switch]$IncludeCoreInCI # Override: install core tools even under CI (used by the E2E validation workflow)
)

if ($env:GITHUB_ACTIONS -eq 'true') { $CI = $true }

$ErrorActionPreference = 'SilentlyContinue'

$userConfigPath = "$PSScriptRoot\..\..\state\user-config.json"
$manifestPath = "$PSScriptRoot\..\..\config\tools-manifest.json"

if (-not (Test-Path $userConfigPath)) {
    Write-Warning "User config not found. Assuming all tools to be installed."
    $userConfig = @{ tools = @{ python=$true; java=$true; nodejs=$true; csharp=$true; go=$true; rust=$true; cpp=$true }; containers = @{ docker=$true; kubernetes=$true }; cloud = @{ aws=$true; gcp=$true; azure=$true } }
} else {
    $userConfig = Get-Content $userConfigPath | ConvertFrom-Json
}

$manifest = Get-Content $manifestPath | ConvertFrom-Json

function Get-ConfigValue {
    param($Config, [string]$Path)
    $value = $Config
    foreach ($part in ($Path -split '\.')) {
        if ($null -eq $value) { return $false }
        $value = $value.$part
    }
    return [bool]$value
}

$skipCore = $CI -and (-not $IncludeCoreInCI)

$toInstall = $manifest.tools | Where-Object {
    if ($_.category -eq 'core') {
        -not $skipCore   # core tools always install for real users; skipped in CI to keep the pipeline fast, unless -IncludeCoreInCI overrides it
    } else {
        Get-ConfigValue -Config $userConfig -Path $_.selectionKey
    }
}

Write-Host ""
Write-Host "┌─────────────────────────────────────────────┐" -ForegroundColor Yellow
Write-Host "│  HARD GATE: About to Install               │" -ForegroundColor Yellow
Write-Host "└─────────────────────────────────────────────┘" -ForegroundColor Yellow
Write-Host ""
Write-Host "The following will be installed:" -ForegroundColor Cyan

if ($toInstall.Count -eq 0) {
    Write-Host "  No tools selected."
} else {
    $toInstall | ForEach-Object { Write-Host "  OK $($_.name)" }
}
if ($skipCore) {
    Write-Host "  (CI mode: core tools skipped)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "Press ENTER to continue, or Ctrl+C to cancel" -ForegroundColor Yellow
Read-Host

$installed = @()
$alreadyPresent = @()
$failed = @()

$toInstall | ForEach-Object {
    $tool = $_

    # Skip tools already on PATH instead of re-running the installer -
    # avoids needless repair-installs, UAC prompts, and false "FAILED" results on re-runs.
    if (Get-Command $tool.command -ErrorAction SilentlyContinue) {
        Write-Host "Already installed: $($tool.name)" -ForegroundColor DarkGray
        $alreadyPresent += $tool.name
        return
    }

    Write-Host "Installing: $($tool.name)" -ForegroundColor Green

    $success = $false
    if ($tool.installer -eq 'winget') {
        & winget install --id $tool.package_id -e -h --force --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
        $success = ($LASTEXITCODE -eq 0)
    } elseif ($tool.installer -eq 'npm') {
        & npm install -g $tool.package_name --loglevel=error 2>&1 | Out-Null
        $success = ($LASTEXITCODE -eq 0)
    }

    if ($success) {
        $installed += $tool.name
    } else {
        Write-Warning "  FAILED to install $($tool.name) (exit $LASTEXITCODE)"
        $failed += $tool.name
    }
}

Write-Host ""
Write-Host "Phase 2 Summary:" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host "  OK Installed: $($installed.Count)" -ForegroundColor Green
Write-Host "  OK Already present: $($alreadyPresent.Count)" -ForegroundColor DarkGray
if ($failed.Count -gt 0) {
    Write-Host "  FAILED: $($failed.Count) -> $($failed -join ', ')" -ForegroundColor Red
    Write-Warning "Some tools failed to install. Check your internet connection and winget/npm output above, then re-run phase 2."
}
Write-Host ""
Write-Host "OK Phase 2 (Installation) completed" -ForegroundColor Green
