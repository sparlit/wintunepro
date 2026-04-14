#Requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$smokeTests = Join-Path $scriptRoot 'Tests\Smoke.ps1'

if (-not (Test-Path $smokeTests)) {
    throw "Smoke test script not found: $smokeTests"
}

Write-Host 'test1.ps1 is now a compatibility wrapper for Tests\Smoke.ps1.' -ForegroundColor Yellow
& $smokeTests
exit $LASTEXITCODE
