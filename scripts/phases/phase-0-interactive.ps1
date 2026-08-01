$ErrorActionPreference = 'Stop'

Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     Magnus Dev Toolkit - Interactive Setup Wizard              ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$userConfig = @{
  tools = @{
    java = $false
    python = $false
    nodejs = $false
    csharp = $false
    go = $false
    rust = $false
    cpp = $false
  }
  containers = @{
    docker = $false
    kubernetes = $false
  }
  cloud = @{
    aws = $false
    gcp = $false
    azure = $false
  }
  mcps = @{
    github = $false
    postgresql = $false
    docker = $false
    figma = $false
    playwright = $false
    sentry = $false
    chrome = $false
  }
}

function Show-Menu {
    param([string[]]$Options)
    $selected = @()
    foreach ($opt in $Options) {
        $ans = Read-Host "Install $opt? (y/n)"
        if ($ans -eq "y") { $selected += $opt }
    }
    return $selected
}

Write-Host "📚 Which programming languages do you need?" -ForegroundColor Yellow
$languages = @("Java", "Python", "Node.js", "C#/.NET", "Go", "Rust", "C/C++")
$selected = Show-Menu $languages

$selected | ForEach-Object {
  if ($_ -eq "Java") { $userConfig.tools.java = $true }
  elseif ($_ -eq "Python") { $userConfig.tools.python = $true }
  elseif ($_ -eq "Node.js") { $userConfig.tools.nodejs = $true }
  elseif ($_ -eq "C#/.NET") { $userConfig.tools.csharp = $true }
  elseif ($_ -eq "Go") { $userConfig.tools.go = $true }
  elseif ($_ -eq "Rust") { $userConfig.tools.rust = $true }
  elseif ($_ -eq "C/C++") { $userConfig.tools.cpp = $true }
}

Write-Host ""
Write-Host "🐳 Do you need containerization? (Docker/Kubernetes)" -ForegroundColor Yellow
if ((Read-Host "Install Docker Desktop? (y/n)") -eq "y") { $userConfig.containers.docker = $true }
if ((Read-Host "Install Kubernetes tools? (y/n)") -eq "y") { $userConfig.containers.kubernetes = $true }

Write-Host ""
Write-Host "☁️  Which cloud providers do you use?" -ForegroundColor Yellow
if ((Read-Host "AWS CLI? (y/n)") -eq "y") { $userConfig.cloud.aws = $true }
if ((Read-Host "Google Cloud SDK? (y/n)") -eq "y") { $userConfig.cloud.gcp = $true }
if ((Read-Host "Azure CLI? (y/n)") -eq "y") { $userConfig.cloud.azure = $true }

Write-Host ""
Write-Host "🔌 Which MCPs do you want configured?" -ForegroundColor Yellow
$mcpOptions = @("GitHub", "PostgreSQL", "Docker", "Figma", "Playwright", "Sentry", "Chrome")
$selectedMcps = Show-Menu $mcpOptions

$selectedMcps | ForEach-Object {
  if ($_ -eq "GitHub") { $userConfig.mcps.github = $true }
  elseif ($_ -eq "PostgreSQL") { $userConfig.mcps.postgresql = $true }
  elseif ($_ -eq "Docker") { $userConfig.mcps.docker = $true }
  elseif ($_ -eq "Figma") { $userConfig.mcps.figma = $true }
  elseif ($_ -eq "Playwright") { $userConfig.mcps.playwright = $true }
  elseif ($_ -eq "Sentry") { $userConfig.mcps.sentry = $true }
  elseif ($_ -eq "Chrome") { $userConfig.mcps.chrome = $true }
}

# Save user config for later phases
$stateDir = "$PSScriptRoot\..\..\state"
if (-not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }
$userConfig | ConvertTo-Json | Out-File "$stateDir\user-config.json"

Write-Host ""
Write-Host "OK Configuration saved" -ForegroundColor Green
