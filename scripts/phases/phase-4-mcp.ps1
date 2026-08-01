$ErrorActionPreference = 'Stop'

$userConfigPath = "$PSScriptRoot\..\..\state\user-config.json"
if (-not (Test-Path $userConfigPath)) {
    $userConfig = @{ mcps = @{ github=$true; postgresql=$true; docker=$true; figma=$true; playwright=$true; sentry=$true; chrome=$true } }
} else {
    $userConfig = Get-Content $userConfigPath | ConvertFrom-Json
}

$mcpsToInstall = @()
if ($userConfig.mcps.github) { $mcpsToInstall += "github" }
if ($userConfig.mcps.postgresql) { $mcpsToInstall += "postgres" }
if ($userConfig.mcps.docker) { $mcpsToInstall += "docker" }
if ($userConfig.mcps.figma) { $mcpsToInstall += "figma" }
if ($userConfig.mcps.playwright) { $mcpsToInstall += "playwright" }
if ($userConfig.mcps.sentry) { $mcpsToInstall += "sentry" }
if ($userConfig.mcps.chrome) { $mcpsToInstall += "puppeteer" }

$mcpsToInstall += @("filesystem", "memory", "fetch", "git")

Write-Host "Installing MCPs: $($mcpsToInstall -join ', ')" -ForegroundColor Cyan

$mcpsToInstall | ForEach-Object {
  if ($_ -eq 'docker') {
    # docker mcp might be @modelcontextprotocol/docker or similar, using known ones
    & npm install -g "@modelcontextprotocol/server-docker" --loglevel=error -f
  } else {
    & npm install -g "@modelcontextprotocol/server-$_" --loglevel=error -f
  }
}

$mcpConfig = @{ mcpServers = @{} }
$mcpsToInstall | ForEach-Object {
  $pkgName = $_
  if ($_ -eq 'docker') { $pkgName = 'server-docker' }
  else { $pkgName = "server-$_" }
  $mcpConfig.mcpServers[$_] = @{
    command = "node"
    args = @("$env:USERPROFILE\AppData\Roaming\npm\node_modules\@modelcontextprotocol\$pkgName\dist\index.js")
  }
}

$configPath = "$env:USERPROFILE\.config\magnus"
if (-not (Test-Path $configPath)) { New-Item -ItemType Directory -Path $configPath -Force | Out-Null }
$mcpConfig | ConvertTo-Json -Depth 10 | Out-File "$configPath\mcp-config.json"

$cliPaths = @(
  "$env:USERPROFILE\.config\cline",
  "$env:USERPROFILE\.config\gemini-cli",
  "$env:USERPROFILE\.config\codex"
)
foreach ($p in $cliPaths) {
  if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
  $target = "$p\mcp-config.json"
  if (Test-Path $target) { Remove-Item $target -Force }
  # Use hardlink or copy instead of mklink to avoid requiring admin rights if developer mode is off
  Copy-Item "$configPath\mcp-config.json" -Destination $target -Force
}

Write-Host "✓ Phase 4 (MCP Setup) completed" -ForegroundColor Green
