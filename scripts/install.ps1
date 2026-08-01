param(
    [switch]$SkipInteractive,
    # Resolve the phase scripts, report, and exit without installing anything.
    # Exists so CI can guard this entry point: the advertised `irm | iex` one-liner
    # was silently broken for a long time precisely because nothing ever tested it.
    [switch]$ResolveOnly,
    [string]$Ref = "main"
)

$ErrorActionPreference = 'Stop'

$RepoSlug = "sahildayal/magnus-dev-toolkit"

# Resolve where the phase scripts live.
#
# $PSScriptRoot is populated only when this file is executed FROM DISK. The advertised
# entry point is `irm .../install.ps1 | iex`, where no file exists at all - previously
# this used $MyInvocation.MyCommand.Definition, which in that mode returns the script
# TEXT rather than a path, so every phase lookup silently pointed at nonsense and the
# one-liner install could never work. When there is no script on disk, fetch the repo
# first and run the phases from there.
$ScriptDir = $PSScriptRoot

if (-not $ScriptDir) {
    Write-Host "Bootstrapping Magnus Dev Toolkit from $RepoSlug ($Ref)..." -ForegroundColor Cyan

    $installRoot = Join-Path $env:USERPROFILE ".magnus-dev-toolkit"
    $extractDir  = Join-Path $installRoot "src"
    $zipPath     = Join-Path $installRoot "toolkit.zip"

    if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }
    New-Item -ItemType Directory -Path $extractDir -Force | Out-Null

    # Download the archive rather than shelling out to git: git is one of the tools
    # this script installs, so it cannot be assumed present on a fresh machine.
    $zipUrl = "https://github.com/$RepoSlug/archive/refs/heads/$Ref.zip"
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
    } catch {
        throw "Could not download $zipUrl - $_"
    }

    Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force
    Remove-Item $zipPath -Force

    # GitHub archives extract to a single <repo>-<ref> folder.
    $repoDir = Get-ChildItem $extractDir -Directory | Select-Object -First 1
    if (-not $repoDir) { throw "Downloaded archive did not contain the expected repository folder." }

    $ScriptDir = Join-Path $repoDir.FullName "scripts"
    Write-Host "  Toolkit unpacked to $($repoDir.FullName)" -ForegroundColor DarkGray
}

$phaseDir = Join-Path $ScriptDir "phases"
if (-not (Test-Path $phaseDir)) {
    throw "Could not locate the phases directory at $phaseDir - the toolkit files are incomplete."
}

$requiredPhases = @(
    "phase-0-interactive.ps1", "phase-1-detect.ps1", "phase-2-install.ps1",
    "phase-3-config.ps1", "phase-4-mcp.ps1", "phase-4b-validate.ps1",
    "phase-5-mcp-router.ps1", "phase-6-report.ps1"
)
$missingPhases = $requiredPhases | Where-Object { -not (Test-Path (Join-Path $phaseDir $_)) }
if ($missingPhases.Count -gt 0) {
    throw "Missing phase script(s) in ${phaseDir}: $($missingPhases -join ', ')"
}

if ($ResolveOnly) {
    Write-Host "OK entry point resolved - all $($requiredPhases.Count) phase scripts found in $phaseDir" -ForegroundColor Green
    exit 0
}

Write-Host "Starting Magnus Dev Toolkit Setup..." -ForegroundColor Cyan

if (-not $SkipInteractive) {
    & (Join-Path $phaseDir "phase-0-interactive.ps1")
} else {
    Write-Host "Skipping interactive phase (using default or previous configuration)..." -ForegroundColor Yellow
}

& (Join-Path $phaseDir "phase-1-detect.ps1")
& (Join-Path $phaseDir "phase-2-install.ps1")
& (Join-Path $phaseDir "phase-3-config.ps1")
& (Join-Path $phaseDir "phase-4-mcp.ps1")
& (Join-Path $phaseDir "phase-4b-validate.ps1")
& (Join-Path $phaseDir "phase-5-mcp-router.ps1")
& (Join-Path $phaseDir "phase-6-report.ps1")
