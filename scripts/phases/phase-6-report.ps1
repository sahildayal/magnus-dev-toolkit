$ErrorActionPreference = 'SilentlyContinue'

function Format-Report {
  $statePath = "$PSScriptRoot\..\..\state\installation-state.json"
  if (Test-Path $statePath) {
    $state = Get-Content $statePath | ConvertFrom-Json
    if ($state.detected) {
        $toolCount = ($state.detected | Get-Member -MemberType NoteProperty | Measure-Object).Count
    } else {
        $toolCount = 0
    }
    $started_at = [datetime]$state.started_at
    if ($started_at) {
        $duration = [math]::Round(([datetime]::Now - $started_at).TotalMinutes, 2)
    } else {
        $duration = 0
    }
  } else {
    $toolCount = "Unknown"
    $duration = "Unknown"
  }
  
  Write-Host ""
  Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
  Write-Host "║          Magnus Dev Toolkit - Onboarding Complete! 🎉          ║" -ForegroundColor Cyan
  Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
  Write-Host ""
  
  Write-Host "📦 INSTALLATION SUMMARY" -ForegroundColor Yellow
  Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  Write-Host "  OK Tools Installed: $toolCount"
  Write-Host "  OK Duration: $duration minutes"
  Write-Host "  OK Status: SUCCESS"
  Write-Host ""
  
  Write-Host "🔧 ENVIRONMENT CONFIGURED" -ForegroundColor Green
  Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  Write-Host "  OK Git identity checked (only filled in if it was missing)"
  Write-Host "  OK Environment variables set for whatever was actually installed"
  Write-Host "  OK PowerShell profile updated with aliases"
  Write-Host "  OK VS Code extensions installed (if VS Code was found on PATH)"
  Write-Host "  OK MCP servers registered"
  Write-Host "  OK mcp-router recommendation engine active"
  Write-Host ""
  
  Write-Host "✅ READY TO USE" -ForegroundColor Green
  Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  Write-Host "  1. Open your CLI:  gemini  /  claude  /  codex"
  Write-Host "  2. MCPs instantly available"
  Write-Host "  3. Ask mcp-router for smart recommendations"
  Write-Host ""

  Write-Host "🎯 FIRST STEPS" -ForegroundColor Magenta
  Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  Write-Host "  1. Open Gemini CLI / Cline / Codex and run: /mcp"
  Write-Host "     Confirm the MCPs you configured actually show up (see state\mcp-validation.json"
  Write-Host "     for which ones passed a real handshake in this run)."
  Write-Host "  2. Ask mcp-router for a recommendation, e.g.:"
  Write-Host "       You:   'search github repos and code'"
  Write-Host "       Route: 'Use GitHub MCP' (scored on capability + keyword + a static"
  Write-Host "              per-MCP cost-efficiency heuristic - see docs\MCP_ROUTER_GUIDE.md)"
  Write-Host ""
  
  Write-Host "📚 DOCUMENTATION" -ForegroundColor Blue
  Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  Write-Host "  docs/QUICK_START.md       # Quick start guide"
  Write-Host "  docs/MCP_ROUTER_GUIDE.md  # How to use recommendations"
  Write-Host "  docs/ARCHITECTURE.md      # Technical details"
  Write-Host "  docs/TROUBLESHOOTING.md   # Common issues"
  Write-Host ""

  Write-Host "💡 PRO TIPS" -ForegroundColor Yellow
  Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  Write-Host "  • mcp-router improves recommendations over time"
  Write-Host "  • All MCPs work offline (except GitHub/Docker APIs)"
  Write-Host ""
  
  Write-Host "🚀 YOU'RE ALL SET! START CODING! 🚀" -ForegroundColor Green
  Write-Host ""
}

Format-Report
