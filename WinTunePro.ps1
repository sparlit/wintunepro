#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$TestMode,
    [switch]$Help,
    [Parameter(ValueFromRemainingArguments = $true)]
    [object[]]$PassthroughArgs
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$targetScript = Join-Path $scriptRoot 'WinTune.ps1'

if (-not (Test-Path $targetScript)) {
    throw "Canonical entrypoint not found: $targetScript"
}

Write-Host 'WinTunePro.ps1 is now a compatibility wrapper for WinTune.ps1.' -ForegroundColor Yellow
& $targetScript -TestMode:$TestMode -Help:$Help @PassthroughArgs
exit $LASTEXITCODE
