#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Path = (Join-Path (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)) 'WinTunePro.ps1'),
    [int]$StartLine = 1,
    [int]$EndLine = 0,
    [switch]$SummaryOnly
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $Path)) {
    throw "Target file not found: $Path"
}

$lines = Get-Content -Path $Path
$lineCount = $lines.Count
if ($EndLine -le 0 -or $EndLine -gt $lineCount) {
    $EndLine = $lineCount
}
if ($StartLine -gt $lineCount) {
    $StartLine = [Math]::Max(1, $lineCount - 19)
}
if ($StartLine -lt 1 -or $StartLine -gt $EndLine) {
    throw "Invalid line range: $StartLine..$EndLine"
}

$depth = 0
$maxDepth = 0
$negativeDepthLine = $null

for ($index = 0; $index -lt $lineCount; $index++) {
    $opens = ($lines[$index].ToCharArray() | Where-Object { $_ -eq '{' }).Count
    $closes = ($lines[$index].ToCharArray() | Where-Object { $_ -eq '}' }).Count
    $depth += $opens - $closes
    if ($depth -gt $maxDepth) { $maxDepth = $depth }
    if ($depth -lt 0 -and -not $negativeDepthLine) {
        $negativeDepthLine = $index + 1
    }
}

Write-Host "File: $Path"
Write-Host "Final depth: $depth"
Write-Host "Max depth: $maxDepth"
Write-Host "File lines: $lineCount"
if ($negativeDepthLine) {
    Write-Host "Depth went negative at line $negativeDepthLine" -ForegroundColor Red
}

if ($SummaryOnly) {
    return
}

$depth = 0
for ($index = $StartLine - 1; $index -lt $EndLine; $index++) {
    $opens = ($lines[$index].ToCharArray() | Where-Object { $_ -eq '{' }).Count
    $closes = ($lines[$index].ToCharArray() | Where-Object { $_ -eq '}' }).Count
    $depth += $opens - $closes
    $marker = ''
    if ($opens -gt 0 -or $closes -gt 0) {
        $marker = " <-- $opens open, $closes close, depth=$depth"
    }
    Write-Host ('{0}: {1}{2}' -f ($index + 1), $lines[$index].Trim(), $marker)
}
