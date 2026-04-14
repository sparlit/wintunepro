#Requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$validator = Join-Path $projectRoot 'Tools\Validate.ps1'

if (-not (Test-Path $validator)) {
    throw "Missing validator: $validator"
}

Write-Host 'Running repository smoke tests...' -ForegroundColor Cyan

& $validator -SmokeHelp -Quiet
if ($LASTEXITCODE -ne 0) {
    throw 'Validator smoke check failed.'
}

$requiredPaths = @(
    'README.md',
    '.gitignore',
    'WinTune.ps1',
    'Core\Bootstrap.ps1',
    'Core\ModuleLoader.ps1',
    'Core\GUILauncher.ps1',
    'WinTunePro.ps1',
    'LaunchWinTune.ps1',
    'WinTune.bat',
    'Tools\Validate.ps1',
    'NativeBuild\README.md'
)

foreach ($relativePath in $requiredPaths) {
    $fullPath = Join-Path $projectRoot $relativePath
    if (-not (Test-Path $fullPath)) {
        throw "Required path missing: $relativePath"
    }
}

$unexpectedSecrets = @(
    'MyGod#Is$MySaviour@20%26',
    'Simon@3551'
)

$matches = @()
foreach ($secret in $unexpectedSecrets) {
    $hits = Get-ChildItem -Path $projectRoot -Recurse -File -ErrorAction SilentlyContinue |
        Select-String -Pattern $secret -SimpleMatch -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -ne $PSCommandPath }
    if ($hits) {
        $matches += $hits
    }
}

if ($matches.Count -gt 0) {
    $matches | Select-Object Path, LineNumber, Line | Format-Table -AutoSize
    throw 'Unexpected known secret literal found in repository content.'
}

Write-Host 'Smoke tests passed.' -ForegroundColor Green
