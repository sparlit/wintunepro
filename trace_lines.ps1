#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Path,
    [int]$StartLine = 601,
    [int]$EndLine = 680
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$tool = Join-Path $scriptRoot 'Tools\Trace-Braces.ps1'

if (-not $Path) {
    $Path = Join-Path $scriptRoot 'WinTunePro.ps1'
}

if (-not (Test-Path $tool)) {
    throw "Trace tool not found: $tool"
}

& $tool -Path $Path -StartLine $StartLine -EndLine $EndLine
exit $LASTEXITCODE
