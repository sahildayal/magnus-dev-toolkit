param(
    [switch]$CI   # Skip all interactive prompts (auto-set in GitHub Actions via $env:GITHUB_ACTIONS)
)

# Auto-detect CI environment
if ($env:GITHUB_ACTIONS -eq 'true') { $CI = $true }

# NOTE: Use SilentlyContinue here, NOT Stop.
# npm writes deprecation warnings to stderr which PowerShell's Stop would
# treat as terminating errors. We check $LASTEXITCODE manually instead.
$ErrorActionPreference = 'SilentlyContinue'

$userConfigPath = "$PSScriptRoot\..\..\state\user-config.json"
if (-not (Test-Path $userConfigPath)) {
    $userConfig = @{
        mcps = @{ github=$true; postgresql=$true; docker=$false; figma=$true; playwright=$true; sentry=$true; chrome=$true }
    }
} else {
    $userConfig = Get-Content $userConfigPath | ConvertFrom-Json
}

# -- Verified npm package registry --------------------------------------------
# docker MCP does not exist on npm - uses Docker Desktop MCP Gateway instead
# git/fetch are Python-only (uvx), excluded from npm installs
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

# -- Build list of MCPs to install based on user selection --------------------
$toInstall = @()
if ($userConfig.mcps.github)     { $toInstall += "github" }
if ($userConfig.mcps.postgresql) { $toInstall += "postgres" }
if ($userConfig.mcps.playwright) { $toInstall += "playwright" }
if ($userConfig.mcps.figma)      { $toInstall += "figma" }
if ($userConfig.mcps.sentry)     { $toInstall += "sentry" }
if ($userConfig.mcps.chrome)     { $toInstall += "puppeteer" }
$toInstall += @("filesystem", "memory")   # always included

# Check Docker MCP Gateway separately (requires Docker Desktop 4.59+)
# Source: https://github.com/docker/mcp-gateway
$dockerGatewayAvailable = $false
if ($userConfig.mcps.docker) {
    $dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
    if ($dockerCmd) {
        $gatewayCheck = & docker mcp --help 2>&1
        if ($LASTEXITCODE -eq 0) {
            $dockerGatewayAvailable = $true
            Write-Host "  Docker MCP Gateway detected via Docker Desktop" -ForegroundColor Green
        } else {
            Write-Warning "Docker MCP Gateway not available (requires Docker Desktop 4.59+ with MCP Toolkit enabled). Skipping Docker MCP."
        }
    } else {
        Write-Warning "Docker not installed. Skipping Docker MCP."
    }
}

Write-Host ""
Write-Host "=== Phase 4: MCP Setup ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Selected MCPs: $($toInstall -join ', ')" -ForegroundColor Yellow
Write-Host ""

# -- Collect tokens for MCPs that need them -----------------------------------
$tokens = @{}
if (-not $CI) {
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
} else {
    Write-Host "  CI mode: skipping token prompts" -ForegroundColor DarkGray
}

# -- Install each MCP globally via npm ----------------------------------------
$npmGlobal = "$env:APPDATA\npm"
$mcpServers = @{}
$failedMcps = @()

foreach ($id in $toInstall) {
    $entry = $mcpRegistry[$id]
    if (-not $entry) {
        Write-Warning "No registry entry for '$id', skipping."
        continue
    }

    Write-Host "Installing $($entry.pkg)..." -ForegroundColor Cyan
    # Redirect stderr to stdout so npm warnings don't cause terminating errors
    # under any ErrorActionPreference. We check $LASTEXITCODE for real failures.
    $result = & npm install -g $entry.pkg 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        Write-Warning "FAILED to install $($entry.pkg) (exit $exitCode)"
        $failedMcps += $id
        continue
    }

    # Resolve the actual installed dist/index.js path from package.json main field
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
    if ($id -eq "postgres" -and -not $CI) {
        Write-Host "  PostgreSQL connection string (e.g. postgresql://localhost/mydb):" -ForegroundColor Gray
        $pgConn = Read-Host "  Enter connection string (or ENTER to skip)"
        if ($pgConn) { $serverEntry.args = @($absPath, $pgConn.Trim()) }
    }

    $mcpServers[$id] = $serverEntry
    Write-Host "  OK $id installed -> $absPath" -ForegroundColor Green
}

# Add Docker MCP Gateway if available
# Source: https://github.com/docker/mcp-gateway (Docker Desktop CLI plugin)
if ($dockerGatewayAvailable) {
    $mcpServers["docker"] = @{
        command = "docker"
        args    = @("mcp", "gateway", "start")
    }
    Write-Host "  OK docker MCP Gateway configured" -ForegroundColor Green
}

# Pre-register mcp-router entry (installed in phase 5)
$mcpRouterPath = "$env:USERPROFILE\.local\lib\mcp-servers\mcp-router\src\index.js"
$mcpServers["mcp-router"] = @{
    command = "node"
    args    = @($mcpRouterPath)
    env     = @{
        MCP_ROUTER_CONFIG = "$env:USERPROFILE\.config\magnus\mcp-manifest.json"
    }
}

# -- Save master config -------------------------------------------------------
$configDir = "$env:USERPROFILE\.config\magnus"
if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir -Force | Out-Null }
$masterConfig = @{ mcpServers = $mcpServers }
$masterConfig | ConvertTo-Json -Depth 10 | Out-File "$configDir\mcp-config.json" -Encoding UTF8

# -- Write CLI-specific configs with evidence-based paths and formats ---------
#
# Gemini CLI : ~/.gemini/settings.json  (JSON, mcpServers + type:stdio)
#   Source: https://github.com/google-gemini/gemini-cli (official docs)
#
# Cline      : ~/.config/cline/cline_mcp_config.json  (JSON, mcpServers)
#   Source: https://github.com/cline/cline (official docs)
#
# Codex CLI  : ~/.codex/config.toml  (TOML format - NOT JSON!)
#   Source: https://github.com/openai/codex (official docs)
#   Note: Uses [mcp_servers.<name>] TOML tables with enabled = true

# --- Gemini CLI: ~/.gemini/settings.json ---
$geminiDir = "$env:USERPROFILE\.gemini"
if (-not (Test-Path $geminiDir)) { New-Item -ItemType Directory -Path $geminiDir -Force | Out-Null }
$geminiServers = @{}
foreach ($k in $mcpServers.Keys) {
    $s = $mcpServers[$k]
    $geminiEntry = @{ command = $s.command; args = $s.args; type = "stdio" }
    if ($s.env) { $geminiEntry.env = $s.env }
    $geminiServers[$k] = $geminiEntry
}
$geminiSettingsPath = "$geminiDir\settings.json"
if (Test-Path $geminiSettingsPath) {
    $existing = Get-Content $geminiSettingsPath -Raw | ConvertFrom-Json
    if (-not $existing.mcpServers) { $existing | Add-Member -MemberType NoteProperty -Name mcpServers -Value @{} }
    foreach ($k in $geminiServers.Keys) {
        $existing.mcpServers | Add-Member -MemberType NoteProperty -Name $k -Value $geminiServers[$k] -Force
    }
    $existing | ConvertTo-Json -Depth 10 | Out-File $geminiSettingsPath -Encoding UTF8
} else {
    @{ mcpServers = $geminiServers } | ConvertTo-Json -Depth 10 | Out-File $geminiSettingsPath -Encoding UTF8
}
Write-Host "  OK Gemini CLI -> $geminiSettingsPath" -ForegroundColor DarkGray

# --- Cline: ~/.config/cline/cline_mcp_config.json ---
$clineDir = "$env:USERPROFILE\.config\cline"
if (-not (Test-Path $clineDir)) { New-Item -ItemType Directory -Path $clineDir -Force | Out-Null }
$masterConfig | ConvertTo-Json -Depth 10 | Out-File "$clineDir\cline_mcp_config.json" -Encoding UTF8
Write-Host "  OK Cline -> $clineDir\cline_mcp_config.json" -ForegroundColor DarkGray

# --- Codex CLI: ~/.codex/config.toml (TOML format, NOT JSON) ---
$codexDir = "$env:USERPROFILE\.codex"
if (-not (Test-Path $codexDir)) { New-Item -ItemType Directory -Path $codexDir -Force | Out-Null }
$tomlLines = @("# Magnus Dev Toolkit MCP Servers (auto-generated)", "")
foreach ($k in $mcpServers.Keys) {
    $s = $mcpServers[$k]
    $tomlLines += "[mcp_servers.$k]"
    $tomlLines += "command = `"$($s.command)`""
    $argsToml = ($s.args | ForEach-Object { "`"$_`"" }) -join ", "
    $tomlLines += "args = [$argsToml]"
    $tomlLines += "enabled = true"
    if ($s.env) {
        $tomlLines += "[mcp_servers.$k.env]"
        foreach ($envKey in ($s.env | Get-Member -MemberType NoteProperty).Name) {
            $tomlLines += "$envKey = `"$($s.env.$envKey)`""
        }
    }
    $tomlLines += ""
}
$tomlContent = $tomlLines -join "`n"
$codexConfigPath = "$codexDir\config.toml"
if (Test-Path $codexConfigPath) {
    Add-Content $codexConfigPath "`n$tomlContent"
} else {
    $tomlContent | Out-File $codexConfigPath -Encoding UTF8
}
Write-Host "  OK Codex CLI -> $codexConfigPath (TOML)" -ForegroundColor DarkGray

if ($failedMcps.Count -gt 0) {
    Write-Warning "The following MCPs failed to install: $($failedMcps -join ', ')"
    Write-Warning "Check your internet connection and try re-running phase 4."
} else {
    Write-Host ""
    Write-Host "OK Phase 4 (MCP Setup) completed - $($mcpServers.Keys.Count) MCPs configured" -ForegroundColor Green
}
