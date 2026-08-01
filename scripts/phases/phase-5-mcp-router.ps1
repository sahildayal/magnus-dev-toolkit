$ErrorActionPreference = 'Stop'

# Refresh PATH from the registry - a PowerShell process's in-memory PATH doesn't
# auto-update when an earlier phase's installer (e.g. Node.js in Phase 2) writes to
# the registry mid-session, so a freshly-installed npm would otherwise be invisible here.
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

Write-Host "Installing mcp-router skill..." -ForegroundColor Cyan

$mcpRouterPath = "$env:USERPROFILE\.local\lib\mcp-servers\mcp-router"
if (-not (Test-Path $mcpRouterPath)) { New-Item -ItemType Directory -Path $mcpRouterPath -Force | Out-Null }

$sourceDir = "$PSScriptRoot\..\..\mcp-router"
Copy-Item "$sourceDir\*" $mcpRouterPath -Recurse -Force

Push-Location $mcpRouterPath
& npm install --loglevel=error
Pop-Location

$mcpConfigPath = "$env:USERPROFILE\.config\magnus\mcp-config.json"
if (Test-Path $mcpConfigPath) {
    $mcpConfig = Get-Content $mcpConfigPath | ConvertFrom-Json
    
    # PowerShell ConvertFrom-Json converts objects to PSCustomObject. 
    # We need to add a new property if it doesn't exist.
    if (-not $mcpConfig.mcpServers) {
        $mcpConfig | Add-Member -MemberType NoteProperty -Name "mcpServers" -Value @{}
    }

    # Add mcp-router to mcpServers
    $mcpConfig.mcpServers | Add-Member -MemberType NoteProperty -Name "mcp-router" -Value @{
        command = "node"
        args = @("$mcpRouterPath\src\index.js")
        env = @{
            MCP_ROUTER_CONFIG = "$env:USERPROFILE\.config\magnus\mcp-manifest.json"
        }
    } -Force

    $mcpConfig | ConvertTo-Json -Depth 10 | Out-File $mcpConfigPath -Encoding UTF8
}

# Ensure configs exist in user profile
$configPath = "$env:USERPROFILE\.config\magnus"
if (-not (Test-Path $configPath)) { New-Item -ItemType Directory -Path $configPath -Force | Out-Null }
Copy-Item "$PSScriptRoot\..\..\config\mcp-manifest.json" -Destination "$configPath\mcp-manifest.json" -Force

Write-Host "OK Phase 5 (mcp-router) installed" -ForegroundColor Green
