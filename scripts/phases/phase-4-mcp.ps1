param(
    [switch]$CI   # Skip all interactive prompts (auto-set in GitHub Actions via $env:GITHUB_ACTIONS)
)

# Auto-detect CI environment
if ($env:GITHUB_ACTIONS -eq 'true') { $CI = $true }

# NOTE: Use SilentlyContinue here, NOT Stop.
# npm writes deprecation warnings to stderr which PowerShell's Stop would
# treat as terminating errors. We check $LASTEXITCODE manually instead.
$ErrorActionPreference = 'SilentlyContinue'

# Refresh PATH from the registry - a PowerShell process's in-memory PATH doesn't
# auto-update when an earlier phase's installer (e.g. uv in Phase 2) writes to the
# registry mid-session, so freshly-installed commands (uvx) would otherwise be invisible here.
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

# Every MCP in this phase needs npm/npx, but Node.js is an opt-in "language" in the
# wizard, not guaranteed installed. Fail fast with a clear message rather than a
# confusing "npm not found" error deep inside the install loop.
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Warning "npm not found - Node.js is required for MCP setup even if you didn't select it as a language."
    Write-Warning "Install Node.js (winget install OpenJS.NodeJS) and re-run this phase."
    exit 1
}

$userConfigPath = "$PSScriptRoot\..\..\state\user-config.json"
if (-not (Test-Path $userConfigPath)) {
    $userConfig = @{
        mcps = @{ github=$true; postgresql=$true; docker=$false; figma=$true; playwright=$true; sentry=$true; chrome=$true }
    }
} else {
    $userConfig = Get-Content $userConfigPath | ConvertFrom-Json
}

# -- Verified MCP package registry ---------------------------------------------
# docker MCP does not exist on npm - uses Docker Desktop MCP Gateway instead
# git/fetch are installed via uvx (Python/PyPI), not npm
$mcpRegistry = @{
    github     = @{ installer = "npm";  pkg = "@modelcontextprotocol/server-github";     needsToken = $true;  tokenEnv = "GITHUB_PERSONAL_ACCESS_TOKEN";  tokenPrompt = "GitHub Personal Access Token (scopes: repo, read:org)" }
    postgres   = @{ installer = "npm";  pkg = "@modelcontextprotocol/server-postgres";   needsToken = $false; tokenEnv = "";                              tokenPrompt = "" }
    playwright = @{ installer = "npm";  pkg = "@playwright/mcp";                          needsToken = $false; tokenEnv = "";                              tokenPrompt = "" }
    figma      = @{ installer = "npm";  pkg = "figma-mcp";                                needsToken = $true;  tokenEnv = "FIGMA_API_KEY";                 tokenPrompt = "Figma API Key (from figma.com/settings -> Access Tokens)" }
    sentry     = @{ installer = "npm";  pkg = "@sentry/mcp-server";                       needsToken = $true;  tokenEnv = "SENTRY_AUTH_TOKEN";             tokenPrompt = "Sentry Auth Token (from sentry.io/settings/account/api/auth-tokens)" }
    # chrome-devtools: official Google MCP (https://github.com/ChromeDevTools/chrome-devtools-mcp).
    # Run via npx (not npm install -g) per upstream's own recommendation, so it always
    # runs the latest published version. Requires a real installed Google Chrome.
    chrome     = @{ installer = "npx";  pkg = "chrome-devtools-mcp";                      needsToken = $false; tokenEnv = "";                              tokenPrompt = "" }
    filesystem = @{ installer = "npm";  pkg = "@modelcontextprotocol/server-filesystem";  needsToken = $false; tokenEnv = "";                              tokenPrompt = "" }
    memory     = @{ installer = "npm";  pkg = "@modelcontextprotocol/server-memory";      needsToken = $false; tokenEnv = "";                              tokenPrompt = "" }
    git        = @{ installer = "uvx";  pkg = "mcp-server-git";                           needsToken = $false; tokenEnv = "";                              tokenPrompt = "" }
    # fetch: NOT auto-installed. As of 2026-08-01, mcp-server-fetch on PyPI is broken -
    # its `mcp` SDK dependency resolves to a version that renamed McpError to MCPError,
    # so `uvx mcp-server-fetch` fails with ImportError before it even starts. This is an
    # upstream bug (a version-constraint mismatch in mcp-server-fetch's own metadata),
    # not something fixable here. Kept in the registry so it can be re-enabled once
    # upstream publishes a fix - just add "fetch" to the always-included list below.
    fetch      = @{ installer = "uvx";  pkg = "mcp-server-fetch";                         needsToken = $false; tokenEnv = "";                              tokenPrompt = "" }
}

# -- Build list of MCPs to install based on user selection --------------------
$toInstall = @()
if ($userConfig.mcps.github)     { $toInstall += "github" }
if ($userConfig.mcps.postgresql) { $toInstall += "postgres" }
if ($userConfig.mcps.playwright) { $toInstall += "playwright" }
if ($userConfig.mcps.figma)      { $toInstall += "figma" }
if ($userConfig.mcps.sentry)     { $toInstall += "sentry" }
if ($userConfig.mcps.chrome)     { $toInstall += "chrome" }
$toInstall += @("filesystem", "memory", "git")   # always included - see note above re: fetch

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

# -- Pre-flight: confirm each package actually exists on its registry ---------
# before attempting to install it, so a bad/renamed package ID fails fast with
# a clear reason instead of a confusing install error.
Write-Host "Verifying MCP packages against their registries..." -ForegroundColor Cyan
$unreachable = @()
$uvxAvailable = [bool](Get-Command uvx -ErrorAction SilentlyContinue)
foreach ($id in $toInstall) {
    $entry = $mcpRegistry[$id]
    if (-not $entry) { continue }

    if ($entry.installer -eq 'uvx') {
        if (-not $uvxAvailable) {
            Write-Warning "  uvx not found on PATH (needed for $($entry.pkg)) - will skip install."
            $unreachable += $id
            continue
        }
        $status = (Invoke-WebRequest -Uri "https://pypi.org/pypi/$($entry.pkg)/json" -UseBasicParsing -ErrorAction SilentlyContinue).StatusCode
        if ($status -ne 200) {
            Write-Warning "  $($entry.pkg) not found on PyPI (or registry unreachable) - will skip install."
            $unreachable += $id
        }
    } else {
        & npm view $entry.pkg version 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "  $($entry.pkg) not found on npm registry (or registry unreachable) - will skip install."
            $unreachable += $id
        }
    }
}
if ($unreachable.Count -eq 0) {
    Write-Host "  OK all $($toInstall.Count) MCP packages verified" -ForegroundColor Green
}
Write-Host ""

# -- Install each MCP globally via npm ----------------------------------------
# Never assume npm's global root is %APPDATA%\npm - actions/setup-node (and other
# environments) can relocate it. Ask npm directly instead.
$npmGlobalRoot = (& npm root -g 2>&1 | Select-Object -Last 1).Trim()
$mcpServers = @{}
$failedMcps = @()
$failedMcps += $unreachable

foreach ($id in $toInstall) {
    if ($unreachable -contains $id) { continue }
    $entry = $mcpRegistry[$id]
    if (-not $entry) {
        Write-Warning "No registry entry for '$id', skipping."
        continue
    }

    if ($entry.installer -eq 'uvx') {
        # uvx installs into an isolated env on first run - prefetch now so Phase 4b's
        # validation handshake isn't the first (slow) invocation.
        Write-Host "Prefetching $($entry.pkg) via uvx..." -ForegroundColor Cyan
        & uvx $entry.pkg --help 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "FAILED to prefetch $($entry.pkg) via uvx (exit $LASTEXITCODE)"
            $failedMcps += $id
            continue
        }

        $mcpServers[$id] = @{ command = "uvx"; args = @($entry.pkg) }
        Write-Host "  OK $id ready -> uvx $($entry.pkg)" -ForegroundColor Green
        continue
    }

    if ($entry.installer -eq 'npx') {
        # npx pulls (and caches) the package fresh from npm on each launch rather than
        # a separate global install - prefetch now so Phase 4b's validation handshake
        # isn't the first (slow) invocation.
        Write-Host "Prefetching $($entry.pkg) via npx..." -ForegroundColor Cyan
        & npx -y "$($entry.pkg)@latest" --help 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "FAILED to prefetch $($entry.pkg) via npx (exit $LASTEXITCODE)"
            $failedMcps += $id
            continue
        }

        # headless: works without a display (CI, servers). isolated: throwaway profile,
        # avoids leftover-state issues on repeat runs. no-usage-statistics: opt out of
        # Google's telemetry by default, matching this project's no-hidden-tracking stance.
        $mcpServers[$id] = @{ command = "npx"; args = @("-y", "$($entry.pkg)@latest", "--headless", "--isolated", "--no-usage-statistics") }
        Write-Host "  OK $id ready -> npx $($entry.pkg)@latest" -ForegroundColor Green
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
    $modFolder = "$npmGlobalRoot\$($entry.pkg)"
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
        $pgConn = $pgConn.Trim()
        if ($pgConn -and $pgConn -notmatch '^postgres(ql)?://') {
            Write-Warning "  That doesn't look like a PostgreSQL connection string (expected postgresql://...). Using it anyway, but the MCP will likely fail validation."
        }
        if ($pgConn) { $serverEntry.args = @($absPath, $pgConn) }
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

# mcp-router is NOT pre-registered here - it isn't installed until Phase 5, which adds
# its own correct entry (with the actual installed path) after really installing it.
# Pre-registering a not-yet-real path here made Phase 4b validate a file that couldn't
# exist yet, guaranteeing a false failure on every run.

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

if (-not $CI) {
    Write-Host ""
    Write-Host "MANUAL CHECK RECOMMENDED:" -ForegroundColor Yellow
    Write-Host "  The config files above are written based on each CLI's documented format," -ForegroundColor Gray
    Write-Host "  but that hasn't been confirmed against a real running CLI. Verify now:" -ForegroundColor Gray
    Write-Host "    1. Open Gemini CLI (or Cline / Codex) and run: /mcp" -ForegroundColor Gray
    Write-Host "    2. Confirm you see: $($mcpServers.Keys -join ', ')" -ForegroundColor Gray
    Write-Host "    3. If any are missing, the config format/path may be wrong for that CLI version." -ForegroundColor Gray
}
