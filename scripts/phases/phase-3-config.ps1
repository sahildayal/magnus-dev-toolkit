$ErrorActionPreference = 'SilentlyContinue'

# Refresh PATH from the registry - a PowerShell process's in-memory PATH doesn't
# auto-update when an earlier phase's installer (e.g. VS Code in Phase 2) writes
# to the registry mid-session, so freshly-installed commands would otherwise be invisible here.
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

# -- Git identity --------------------------------------------------------------
# NEVER clobber an existing global git identity. This previously wrote a shipped
# placeholder (bikash@example.com) straight over the user's real identity, so every
# subsequent commit was authored to a fake address and GitHub could not attribute it.
# Rule: only fill in an identity that is genuinely missing, and never with a placeholder.
function Test-PlaceholderValue {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $true }
    return ($Value -match 'example\.(com|org|net)$' -or $Value -match '^(your|changeme|todo)')
}

$existingName  = (& git config --global user.name)  2>$null
$existingEmail = (& git config --global user.email) 2>$null

$gitConfigPath = "$PSScriptRoot\..\..\config\git-config.json"
$desiredName = $null; $desiredEmail = $null
if (Test-Path $gitConfigPath) {
    $gitConfig = Get-Content $gitConfigPath | ConvertFrom-Json
    $desiredName  = $gitConfig.user.name
    $desiredEmail = $gitConfig.user.email
}

if (-not (Test-PlaceholderValue $existingName)) {
    Write-Host "  Git user.name already set ($existingName) - leaving it alone" -ForegroundColor DarkGray
} elseif (-not (Test-PlaceholderValue $desiredName)) {
    & git config --global user.name $desiredName
    Write-Host "  Git user.name set to $desiredName" -ForegroundColor Green
} else {
    Write-Warning "  Git user.name not configured. Set it with: git config --global user.name ""Your Name"""
}

if (-not (Test-PlaceholderValue $existingEmail)) {
    Write-Host "  Git user.email already set ($existingEmail) - leaving it alone" -ForegroundColor DarkGray
} elseif (-not (Test-PlaceholderValue $desiredEmail)) {
    & git config --global user.email $desiredEmail
    Write-Host "  Git user.email set to $desiredEmail" -ForegroundColor Green
} else {
    Write-Warning "  Git user.email not configured. Set it with: git config --global user.email ""you@example.com"""
}

if (Get-Command code -ErrorAction SilentlyContinue) {
    & git config --global core.editor code
}

# -- Language environment variables --------------------------------------------
# Derive these from what is actually installed rather than hardcoding paths. The
# previous hardcoded values pointed at directories that often do not exist (e.g.
# PYTHON_HOME -> ...\Python311 while the manifest installs Python 3.13), leaving the
# user with env vars aimed at nothing.
function Set-HomeFromCommand {
    param([string]$VarName, [string]$Command, [int]$ParentLevels = 2)

    $cmd = Get-Command $Command -ErrorAction SilentlyContinue | Where-Object { $_.CommandType -eq 'Application' } | Select-Object -First 1
    if (-not $cmd) {
        Write-Host "  $VarName skipped ($Command not installed)" -ForegroundColor DarkGray
        return
    }

    $path = $cmd.Source
    for ($i = 0; $i -lt $ParentLevels; $i++) { $path = Split-Path $path -Parent }
    if (-not $path -or -not (Test-Path $path)) {
        Write-Host "  $VarName skipped (could not resolve a home directory for $Command)" -ForegroundColor DarkGray
        return
    }

    [Environment]::SetEnvironmentVariable($VarName, $path, 'User')
    Write-Host "  $VarName = $path" -ForegroundColor Green
}

# java/python live in <home>\bin\java.exe and <home>\python.exe respectively
Set-HomeFromCommand -VarName 'JAVA_HOME'   -Command 'java'  -ParentLevels 2
Set-HomeFromCommand -VarName 'PYTHON_HOME' -Command 'python' -ParentLevels 1

# CARGO_HOME / GOPATH are conventional locations, but only meaningful if the
# toolchain is actually present.
if (Get-Command cargo -ErrorAction SilentlyContinue) {
    [Environment]::SetEnvironmentVariable('CARGO_HOME', "$env:USERPROFILE\.cargo", 'User')
    Write-Host "  CARGO_HOME = $env:USERPROFILE\.cargo" -ForegroundColor Green
}
if (Get-Command go -ErrorAction SilentlyContinue) {
    [Environment]::SetEnvironmentVariable('GOPATH', "$env:USERPROFILE\go", 'User')
    Write-Host "  GOPATH = $env:USERPROFILE\go" -ForegroundColor Green
}

# -- Shell aliases -------------------------------------------------------------
# Wrapped in a marker block so re-running setup replaces the block instead of
# appending a duplicate copy of every alias each time.
$aliasesPath = "$PSScriptRoot\..\..\config\shell-aliases.json"
if (Test-Path $aliasesPath) {
    $aliases = Get-Content $aliasesPath | ConvertFrom-Json
    $beginMarker = '# >>> magnus-dev-toolkit >>>'
    $endMarker   = '# <<< magnus-dev-toolkit <<<'
    $block = @($beginMarker) + $aliases.powerShell + @($endMarker) -join "`n"

    $profilePath = $PROFILE.CurrentUserAllHosts
    $profileDir  = Split-Path $profilePath
    if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }

    if (Test-Path $profilePath) {
        $current = Get-Content $profilePath -Raw
        if ($current -match [regex]::Escape($beginMarker)) {
            # Replace the existing managed block rather than appending another one.
            $pattern = [regex]::Escape($beginMarker) + '.*?' + [regex]::Escape($endMarker)
            $updated = [regex]::Replace($current, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $block }, [System.Text.RegularExpressions.RegexOptions]::Singleline)
            $updated | Out-File $profilePath -Encoding UTF8
            Write-Host "  PowerShell aliases updated (existing block replaced)" -ForegroundColor Green
        } else {
            Add-Content $profilePath "`n$block"
            Write-Host "  PowerShell aliases added" -ForegroundColor Green
        }
    } else {
        $block | Out-File $profilePath -Encoding UTF8
        Write-Host "  PowerShell aliases added" -ForegroundColor Green
    }
}

# -- VS Code extensions --------------------------------------------------------
$extPath = "$PSScriptRoot\..\..\config\vscode-extensions.json"
if (Test-Path $extPath) {
    if (Get-Command code -ErrorAction SilentlyContinue) {
        $extensions = Get-Content $extPath | ConvertFrom-Json
        $extensions.extensions | ForEach-Object {
            & code --install-extension $_ --force 2>&1 | Out-Null
        }
        Write-Host "  VS Code extensions installed" -ForegroundColor Green
    } else {
        Write-Host "  VS Code extensions skipped (code not on PATH)" -ForegroundColor DarkGray
    }
}

Write-Host "OK Phase 3 (Environment Configuration) completed" -ForegroundColor Green
