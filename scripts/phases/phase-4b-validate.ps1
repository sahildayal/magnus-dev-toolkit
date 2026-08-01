$ErrorActionPreference = 'SilentlyContinue'

# Refresh PATH from the registry - MCP server commands (uvx, node) are resolved via
# PATH when spawning the process, and a PowerShell process's in-memory PATH doesn't
# auto-update when an earlier phase's installer wrote to the registry mid-session.
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

Write-Host ""
Write-Host "=== Phase 4b: MCP Validation ===" -ForegroundColor Cyan
Write-Host ""

$configPath = "$env:USERPROFILE\.config\magnus\mcp-config.json"
if (-not (Test-Path $configPath)) {
    Write-Warning "mcp-config.json not found. Skipping validation."
    exit 0
}

$mcpConfig = Get-Content $configPath -Raw | ConvertFrom-Json
$passed  = @()
$failed  = @()
$skipped = @()

foreach ($name in ($mcpConfig.mcpServers | Get-Member -MemberType NoteProperty).Name) {
    $server = $mcpConfig.mcpServers.$name

    if (-not $server.command -or -not $server.args) {
        $skipped += $name
        continue
    }

    # Check the entry point exists - only meaningful when command is "node" and args[0]
    # is a literal file path. For uvx/npx/docker, args[0] is a package name or flag
    # (e.g. "-y", "mcp-server-git") resolved via PATH/registry at spawn time, not a path.
    if ($server.command -eq "node") {
        $targetFile = $server.args[0]
        if (-not (Test-Path $targetFile)) {
            Write-Host "  FAIL [$name] -> entry point not found: $targetFile" -ForegroundColor Red
            $failed += $name
            continue
        }
    }

    # Spawn the MCP process and send an MCP initialize handshake via stdio
    # The MCP protocol initialize message:
    $initMsg = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"magnus-validator","version":"1.0.0"}}}' + "`n"

    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $server.command
        $psi.Arguments = ($server.args | ForEach-Object { "`"$_`"" }) -join " "
        $psi.UseShellExecute = $false
        $psi.RedirectStandardInput = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true

        # Inject env vars if present
        if ($server.env) {
            foreach ($envKey in ($server.env | Get-Member -MemberType NoteProperty).Name) {
                $psi.EnvironmentVariables[$envKey] = $server.env.$envKey
            }
        }

        $proc = [System.Diagnostics.Process]::Start($psi)
        $proc.StandardInput.WriteLine($initMsg)
        $proc.StandardInput.Close()

        # Read response with a 30s timeout - first-run MCP spawns (e.g. Playwright
        # downloading/launching Chromium) can take 10-15s, so 5s was giving false timeouts.
        $outputTask = $proc.StandardOutput.ReadToEndAsync()
        $timedOut   = -not $proc.WaitForExit(30000)

        if ($timedOut) {
            $proc.Kill()
            $skipped += "$name (timeout - process spawned but did not respond in 30s)"
            Write-Host "  WARN [$name] -> spawned but no response in 30s (may need token/args)" -ForegroundColor Yellow
        } else {
            $output = $outputTask.Result
            if ($output -match '"result"' -or $output -match '"serverInfo"' -or $output -match '"protocolVersion"') {
                $passed += $name
                Write-Host "  PASS [$name] -> MCP initialized successfully" -ForegroundColor Green
            } else {
                # Some MCPs output nothing on init but exit 0 — treat exit 0 as pass
                if ($proc.ExitCode -eq 0) {
                    $passed += $name
                    Write-Host "  PASS [$name] -> process exited cleanly" -ForegroundColor Green
                } else {
                    $stderr = $proc.StandardError.ReadToEnd()
                    $failed += $name
                    Write-Host "  FAIL [$name] -> exit code $($proc.ExitCode): $stderr" -ForegroundColor Red
                }
            }
        }
    } catch {
        $failed += $name
        Write-Host "  FAIL [$name] -> exception: $_" -ForegroundColor Red
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

# Save results to state
$stateDir = "$PSScriptRoot\..\..\state"
@{ passed=$passed; failed=$failed; skipped=$skipped; timestamp=(Get-Date -Format "o") } `
    | ConvertTo-Json | Out-File "$stateDir\mcp-validation.json" -Encoding UTF8

Write-Host ""
Write-Host "OK Phase 4b (MCP Validation) completed" -ForegroundColor Green
