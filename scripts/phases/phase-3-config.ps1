$ErrorActionPreference = 'SilentlyContinue'

$gitConfigPath = "$PSScriptRoot\..\..\config\git-config.json"
if (Test-Path $gitConfigPath) {
    $gitConfig = Get-Content $gitConfigPath | ConvertFrom-Json
    git config --global user.name $gitConfig.user.name
    git config --global user.email $gitConfig.user.email
    git config --global core.editor code
}

[Environment]::SetEnvironmentVariable('JAVA_HOME', 'C:\Program Files\Java\jdk-17', 'User')
[Environment]::SetEnvironmentVariable('PYTHON_HOME', "$env:USERPROFILE\AppData\Local\Programs\Python\Python311", 'User')
[Environment]::SetEnvironmentVariable('CARGO_HOME', "$env:USERPROFILE\.cargo", 'User')
[Environment]::SetEnvironmentVariable('GOPATH', "$env:USERPROFILE\go", 'User')

$aliasesPath = "$PSScriptRoot\..\..\config\shell-aliases.json"
if (Test-Path $aliasesPath) {
    $aliases = Get-Content $aliasesPath | ConvertFrom-Json
    $profileContent = $aliases.powerShell -join "`n"
    if (-not (Test-Path -Path (Split-Path $PROFILE.CurrentUserAllHosts))) {
        New-Item -ItemType Directory -Path (Split-Path $PROFILE.CurrentUserAllHosts) -Force | Out-Null
    }
    Add-Content $PROFILE.CurrentUserAllHosts $profileContent
}

$extPath = "$PSScriptRoot\..\..\config\vscode-extensions.json"
if (Test-Path $extPath) {
    $extensions = Get-Content $extPath | ConvertFrom-Json
    $extensions.extensions | ForEach-Object {
        & code --install-extension $_ --force
    }
}

Write-Host "✓ Phase 3 (Environment Configuration) completed" -ForegroundColor Green
