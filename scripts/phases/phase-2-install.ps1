param(
    [switch]$CI,             # Skip core tool installs to keep CI fast; auto-set via $env:GITHUB_ACTIONS
    [switch]$IncludeCoreInCI # Override: install core tools even under CI (used by the E2E validation workflow)
)

if ($env:GITHUB_ACTIONS -eq 'true') { $CI = $true }

$ErrorActionPreference = 'SilentlyContinue'

# Every core/opt-in tool in the manifest installs via winget. It ships with Windows 11
# and current Windows 10 builds via the App Installer Store package, but older or
# offline-imaged Windows 10 machines can be missing it entirely - in which case every
# single install below would silently fail one at a time with no clear cause. Fail
# fast with the actual fix instead.
if (-not ($CI) -and -not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warning "winget not found. It ships with Windows 11 and most current Windows 10 installs,"
    Write-Warning "but yours doesn't have it (or App Installer needs updating)."
    Write-Warning "Install/update it from the Microsoft Store: https://apps.microsoft.com/detail/9nblggh4nns1"
    Write-Warning "Then re-run this phase."
    exit 1
}

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

# npm-installed tools (Claude Code, and Yarn/pnpm when Node.js was selected) need
# Node.js. Claude Code is core, so it installs even for users who never selected
# Node.js as a language - without this, it would just fail with a confusing "npm not
# recognized" instead of pulling in its own real dependency. Reuses the manifest's own
# Node.js entry (rather than a separate ad-hoc winget call) so it shows in the
# confirmation gate below and installs through the same verified code path.
$needsNpm = $toInstall | Where-Object { $_.installer -eq 'npm' }
if ($needsNpm -and -not (Get-Command npm -ErrorAction SilentlyContinue) -and -not ($toInstall | Where-Object { $_.command -eq 'node' })) {
    $nodeEntry = $manifest.tools | Where-Object { $_.command -eq 'node' } | Select-Object -First 1
    if ($nodeEntry) {
        $toInstall = @($nodeEntry) + @($toInstall)
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
    # Only CommandType 'Application' counts: Windows PowerShell 5.1 ships built-in
    # curl/wget aliases (-> Invoke-WebRequest) that would otherwise cause a false
    # "already installed" and skip the real executable.
    $existing = Get-Command $tool.command -ErrorAction SilentlyContinue | Where-Object { $_.CommandType -eq 'Application' }
    if ($existing) {
        Write-Host "Already installed: $($tool.name)" -ForegroundColor DarkGray
        $alreadyPresent += $tool.name
        return
    }

    Write-Host "Installing: $($tool.name)" -ForegroundColor Green

    $success = $false
    if ($tool.installer -eq 'winget') {
        & winget install --id $tool.package_id -e -h --force --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
        $success = ($LASTEXITCODE -eq 0)
        if ($success) {
            # Refresh PATH immediately (not just at the top of the phase) - Node.js can
            # land mid-loop via the npm-dependency bootstrap above, and the very next
            # tool in this same loop (e.g. Claude Code) needs npm to already be visible.
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        }
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
