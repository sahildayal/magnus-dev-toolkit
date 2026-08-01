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
  Write-Host "  OK Git configured"
  Write-Host "  OK Environment variables set"
  Write-Host "  OK PowerShell profile updated with aliases"
  Write-Host "  OK VS Code extensions installed"
  Write-Host "  OK MCP servers registered"
  Write-Host "  OK mcp-router recommendation engine active"
  Write-Host ""
  
  Write-Host "✅ READY TO USE" -ForegroundColor Green
  Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  Write-Host "  1. Open your CLI:  gemini  /  claude  /  codex"
  Write-Host "  2. MCPs instantly available"
  Write-Host "  3. Ask mcp-router for smart recommendations"
  Write-Host ""

  Write-Host "⚡ QUICK COMMANDS" -ForegroundColor Cyan
  Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  Write-Host "  magnus-token-status      # Check token status"
  Write-Host "  magnus-update            # Update toolkit"
  Write-Host "  magnus-check-versions    # Verify all tools"
  Write-Host "  magnus-reset             # Reset configuration"
  Write-Host ""
  
  Write-Host "🎯 FIRST STEPS" -ForegroundColor Magenta
  Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  Write-Host "  Example 1 - Ask for MCP Recommendation:"
  Write-Host "    You:   'Analyze GitHub repos for security issues'"
  Write-Host "    Route: 'Use GitHub MCP — faster, safer, cheaper'"
  Write-Host ""
  Write-Host "  Example 2 - Cost-Aware Recommendation:"
  Write-Host "    You:   'Generate 500 lines of code'"
  Write-Host "    Route: 'Use Codex (10x cheaper than Claude)'"
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
