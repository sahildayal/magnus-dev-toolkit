$ErrorActionPreference = 'Stop'

$userConfigPath = "$PSScriptRoot\..\..\state\user-config.json"
if (-not (Test-Path $userConfigPath)) {
    $userConfig = @{
        mcps = @{ github=$true; postgresql=$true; docker=$false; figma=$true; playwright=$true; sentry=$true; chrome=$true }
    }
} else {
    $userConfig = Get-Content $userConfigPath | ConvertFrom-Json
}

# ── Verified npm package registry ──────────────────────────────────────────
# docker MCP does not exist on npm; git/fetch are Python-only (uvx)
$mcpRegistry = @{
    github     = @{ pkg = "@modelcontextprotocol/server-github";     needsToken = $true;  tokenEnv = "GITHUB_PERSONAL_ACCESS_TOKEN";  tokenPrompt = "GitHub Personal Access Token (scopes: repo, read:org)" }
    postgres   = @{ pkg = "@modelcontextprotocol/server-postgres";   needsToken = $false; tokenEnv = "";                              tokenPrompt = "" }
    playwright = @{ pkg = "@playwright/mcp";                          needsToken = $false; tokenEnv = "";                              tokenPrompt = "" }
    figma      = @{ pkg = "figma-mcp";                                needsToken = $true;  tokenEnv = "FIGMA_API_KEY";                 tokenPrompt = "Figma API Key (from figma.com/settings -> Access Tokens)" }
    sentry     = @{ pkg = "@sentry/mcp-server";                       needsToken = $true;  tokenEnv = "SENTRY_AUTH_TOKEN";             tokenPrompt = "Sentry Auth Token (from sentry.io/settings/account/api/auth-tokens)" }
    puppeteer  = @{ pkg = "@modelcontextprotocol/server-puppeteer";   needsToken = $false; tokenEnv = "";                              tokenPrompt = "" }
    filesystem = @{ pkg = "@modelcontextprotocol/server-filesystem";  needsToken = $false; tokenEnv = "";                              tokenPrompt = "" }
    memory     = @{ pkg = "@modelcontextprotocol/server-memory";      needsToken = $false; tokenEnv = "";                              tokenPrompt = "" }
}

# ── Build list of MCPs to install based on user selection ──────────────────
$toInstall = @()
if ($userConfig.mcps.github)     { $toInstall += "github" }
if ($userConfig.mcps.postgresql) { $toInstall += "postgres" }
if ($userConfig.mcps.playwright) { $toInstall += "playwright" }
if ($userConfig.mcps.figma)      { $toInstall += "figma" }
if ($userConfig.mcps.sentry)     { $toInstall += "sentry" }
if ($userConfig.mcps.chrome)     { $toInstall += "puppeteer" }
$toInstall += @("filesystem", "memory")   # always included

Write-Host ""
Write-Host "=== Phase 4: MCP Setup ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Selected MCPs: $($toInstall -join ', ')" -ForegroundColor Yellow
Write-Host ""

# ── Collect tokens for MCPs that need them ─────────────────────────────────
$tokens = @{}
foreach ($id in $toInstall) {
    $entry = $mcpRegistry[$id]
    if ($entry -and $entry.needsToken) {
        Write-Host "Token required for $id" -ForegroundColor Yellow
        Write-Host "  $($entry.tokenPrompt)" -ForegroundColor Gray
        $t = Read-Host "  Enter token (or press ENTER to skip)"
        $tokens[$id] = $t.Trim()
        Write-Host ""
    }
}

# ── Install each MCP globally via npm ─────────────────────────────────────
$npmGlobal = "$env:APPDATA\npm"
$mcpConfig = @{ mcpServers = @{} }
$failedMcps = @()

foreach ($id in $toInstall) {
    $entry = $mcpRegistry[$id]
    if (-not $entry) {
        Write-Warning "No registry entry for '$id', skipping."
        continue
    }

    Write-Host "Installing $($entry.pkg)..." -ForegroundColor Cyan
    $result = & npm install -g $entry.pkg 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "FAILED to install $($entry.pkg): $result"
        $failedMcps += $id
        continue
    }

    # Resolve the actual installed dist/index.js path
    $modFolder = "$npmGlobal\node_modules\$($entry.pkg)"
    $pkgJson   = Get-Content "$modFolder\package.json" -Raw | ConvertFrom-Json
    $mainEntry = $pkgJson.main
    if (-not $mainEntry) { $mainEntry = "dist/index.js" }
    $absPath   = Join-Path $modFolder $mainEntry

    # Build the mcpServers entry
    $serverEntry = @{
        command = "node"
        args    = @($absPath)
    }

    # Attach env vars if token was provided
    if ($entry.needsToken -and $tokens[$id]) {
        $serverEntry.env = @{ $entry.tokenEnv = $tokens[$id] }
    }

    # Special case: filesystem needs a root arg
    if ($id -eq "filesystem") {
        $serverEntry.args = @($absPath, $env:USERPROFILE)
    }

    # Special case: postgres needs a connection string arg  
    if ($id -eq "postgres") {
        Write-Host "  PostgreSQL connection string (e.g. postgresql://localhost/mydb):" -ForegroundColor Gray
        $pgConn = Read-Host "  Enter connection string (or ENTER to skip)"
        if ($pgConn) { $serverEntry.args = @($absPath, $pgConn.Trim()) }
    }

    $mcpConfig.mcpServers[$id] = $serverEntry
    Write-Host "  OK $id installed -> $absPath" -ForegroundColor Green
}

# ── Write central config ───────────────────────────────────────────────────
$configDir = "$env:USERPROFILE\.config\magnus"
if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir -Force | Out-Null }
$mcpConfig | ConvertTo-Json -Depth 10 | Out-File "$configDir\mcp-config.json" -Encoding UTF8

# ── Write CLI-specific configs (each CLI has the same MCP JSON schema) ─────
$cliDirs = @{
    "gemini-cli" = "$env:USERPROFILE\.config\gemini-cli"
    "cline"      = "$env:USERPROFILE\.config\cline"
    "codex"      = "$env:USERPROFILE\.config\codex"
}
foreach ($cli in $cliDirs.Keys) {
    $dir = $cliDirs[$cli]
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $mcpConfig | ConvertTo-Json -Depth 10 | Out-File "$dir\mcp-config.json" -Encoding UTF8
    Write-Host "  Wrote config -> $dir\mcp-config.json" -ForegroundColor DarkGray
}

if ($failedMcps.Count -gt 0) {
    Write-Warning "The following MCPs failed to install: $($failedMcps -join ', ')"
    Write-Warning "Check your internet connection and try re-running phase 4."
} else {
    Write-Host ""
    Write-Host "OK Phase 4 (MCP Setup) completed - $($mcpConfig.mcpServers.Keys.Count) MCPs configured" -ForegroundColor Green
}
