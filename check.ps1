#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Quiet)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$validator = Join-Path $scriptRoot 'Tools\Validate.ps1'

if (-not (Test-Path $validator)) {
    throw "Validation script not found: $validator"
}

if (-not $Quiet) {
    Write-Host 'check.ps1 is now a compatibility wrapper for Tools\Validate.ps1.' -ForegroundColor Yellow
}

& $validator -Quiet:$Quiet
exit $LASTEXITCODE
