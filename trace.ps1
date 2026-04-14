#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Path,
    [switch]$SummaryOnly
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$tool = Join-Path $scriptRoot 'Tools\Trace-Braces.ps1'

if (-not (Test-Path $tool)) {
    throw "Trace tool not found: $tool"
}

if ($Path) {
    & $tool -Path $Path -SummaryOnly:$SummaryOnly
} else {
    & $tool -SummaryOnly:$SummaryOnly
}
exit $LASTEXITCODE
