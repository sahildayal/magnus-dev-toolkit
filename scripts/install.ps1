param(
    [switch]$SkipInteractive
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

Write-Host "Starting Magnus Dev Toolkit Setup..." -ForegroundColor Cyan

if (-not $SkipInteractive) {
    & "$ScriptDir\phases\phase-0-interactive.ps1"
} else {
    Write-Host "Skipping interactive phase (using default or previous configuration)..." -ForegroundColor Yellow
}

& "$ScriptDir\phases\phase-1-detect.ps1"
& "$ScriptDir\phases\phase-2-install.ps1"
& "$ScriptDir\phases\phase-3-config.ps1"
& "$ScriptDir\phases\phase-4-mcp.ps1"
& "$ScriptDir\phases\phase-4b-validate.ps1"
& "$ScriptDir\phases\phase-5-mcp-router.ps1"
& "$ScriptDir\phases\phase-6-report.ps1"
