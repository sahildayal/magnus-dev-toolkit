$ErrorActionPreference = 'SilentlyContinue'

# Refresh PATH from the registry - MCP server commands are resolved via PATH when
# spawning, and a PowerShell process's in-memory PATH doesn't auto-update when an
# earlier phase's installer wrote to the registry mid-session.
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

Write-Host ""
Write-Host "=== Phase 4b: MCP Validation ===" -ForegroundColor Cyan
Write-Host ""

$configPath = "$env:USERPROFILE\.config\magnus\mcp-config.json"
if (-not (Test-Path $configPath)) {
    Write-Warning "mcp-config.json not found. Skipping validation."
    exit 0
}

$repoRoot = "$PSScriptRoot\..\.."
$stateDir = "$repoRoot\state"
if (-not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }

# -- Set up the probe environment ---------------------------------------------
# Validation speaks the real Model Context Protocol via the official client SDK
# rather than a hand-rolled handshake. The probe needs the SDK resolvable, and ESM
# resolves node_modules by walking up from the *script's* own directory - so the
# probe is staged in its own folder with the SDK installed alongside it.
$probeDir = "$stateDir\mcp-probe"
if (-not (Test-Path $probeDir)) { New-Item -ItemType Directory -Path $probeDir -Force | Out-Null }
Copy-Item "$repoRoot\scripts\mcp-probe.mjs" -Destination "$probeDir\mcp-probe.mjs" -Force

if (-not (Test-Path "$probeDir\node_modules\@modelcontextprotocol\sdk")) {
    Write-Host "Installing MCP client SDK for validation..." -ForegroundColor Cyan
    Push-Location $probeDir
    & npm install "@modelcontextprotocol/sdk" --loglevel=error --no-fund --no-audit 2>&1 | Out-Null
    $sdkExit = $LASTEXITCODE
    Pop-Location
    if ($sdkExit -ne 0 -or -not (Test-Path "$probeDir\node_modules\@modelcontextprotocol\sdk")) {
        Write-Warning "Could not install the MCP client SDK - skipping validation."
        Write-Warning "MCP servers were still configured; re-run this phase once npm can reach the registry."
        exit 0
    }
}

$mcpConfig = Get-Content $configPath -Raw | ConvertFrom-Json
$passed  = @()
$failed  = @()
$skipped = @()

foreach ($name in ($mcpConfig.mcpServers | Get-Member -MemberType NoteProperty).Name) {
    $server = $mcpConfig.mcpServers.$name

    if (-not $server.command) {
        $skipped += "$name (no command in config)"
        continue
    }

    # Hand the probe the exact command/args/env the MCP clients will use, so what
    # gets validated is byte-for-byte what actually launches in real use.
    $spec = @{
        command = $server.command
        args    = @($server.args)
    }
    if ($server.env) {
        $envMap = @{}
        foreach ($k in ($server.env | Get-Member -MemberType NoteProperty).Name) {
            $envMap[$k] = $server.env.$k
        }
        $spec.env = $envMap
    }
    # Write the spec to a file rather than passing it inline - Windows PowerShell
    # mangles embedded double quotes when handing strings to native commands.
    $specPath = "$probeDir\spec.json"
    $spec | ConvertTo-Json -Depth 10 | Out-File $specPath -Encoding UTF8

    $raw = & node "$probeDir\mcp-probe.mjs" $specPath 2>$null
    $line = ($raw | Where-Object { $_ -like "__MAGNUS_PROBE__*" } | Select-Object -First 1)

    if (-not $line) {
        $failed += $name
        Write-Host "  FAIL [$name] -> probe produced no result" -ForegroundColor Red
        continue
    }

    $result = $line.Substring("__MAGNUS_PROBE__".Length) | ConvertFrom-Json

    if ($result.ok) {
        $passed += $name
        $toolCount = @($result.tools).Count
        Write-Host "  PASS [$name] -> handshake OK, $toolCount tool(s)" -ForegroundColor Green
    } elseif ($result.timedOut) {
        $skipped += "$name (timeout)"
        Write-Host "  WARN [$name] -> no response before timeout (may need a token or extra args)" -ForegroundColor Yellow
    } else {
        $failed += $name
        Write-Host "  FAIL [$name] -> $($result.error)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Validation Summary:" -ForegroundColor Cyan
Write-Host "  Passed : $($passed.Count)  [$($passed -join ', ')]" -ForegroundColor Green
if ($skipped.Count -gt 0) {
    Write-Host "  Skipped: $($skipped.Count)  [$($skipped -join ', ')]" -ForegroundColor Yellow
}
if ($failed.Count -gt 0) {
    Write-Host "  Failed : $($failed.Count)  [$($failed -join ', ')]" -ForegroundColor Red
    Write-Host ""
    Write-Host "  TIP: Failed MCPs usually mean a missing token in config or a wrong path." -ForegroundColor Gray
    Write-Host "       Edit ~/.config/magnus/mcp-config.json and re-run this phase." -ForegroundColor Gray
}

@{ passed=$passed; failed=$failed; skipped=$skipped; timestamp=(Get-Date -Format "o") } `
    | ConvertTo-Json | Out-File "$stateDir\mcp-validation.json" -Encoding UTF8

Write-Host ""
Write-Host "OK Phase 4b (MCP Validation) completed" -ForegroundColor Green
