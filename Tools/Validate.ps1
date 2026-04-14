#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$SmokeHelp,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

function Write-Section {
    param([string]$Text)
    if (-not $Quiet) {
        Write-Host ""
        Write-Host "== $Text ==" -ForegroundColor Cyan
    }
}

function Get-SourceFiles {
    $excluded = @('.git\', 'Backups\', 'Logs\', 'Reports\')
    Get-ChildItem -Path $projectRoot -Recurse -File |
        Where-Object {
            $fullName = $_.FullName
            $extension = $_.Extension.ToLower()
            ($extension -eq '.ps1' -or $extension -eq '.psm1' -or $extension -eq '.psd1') -and
            -not ($excluded | Where-Object { $fullName -like "*$_*" })
        }
}

Write-Section "Parsing PowerShell source"
$parseErrors = @()
foreach ($file in Get-SourceFiles) {
    $tokens = $null
    $parseIssues = $null
    [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseIssues) | Out-Null
    if ($parseIssues) {
        foreach ($issue in $parseIssues) {
            $parseErrors += [pscustomobject]@{
                File    = $file.FullName
                Line    = $issue.Extent.StartLineNumber
                Message = $issue.Message
            }
        }
    }
}

if ($parseErrors.Count -gt 0) {
    $parseErrors | Format-Table -AutoSize
    throw "Parser validation failed with $($parseErrors.Count) error(s)."
}

if (-not $Quiet) {
    Write-Host "Parser validation passed." -ForegroundColor Green
}

if ($SmokeHelp) {
    Write-Section "Running help smoke checks"
    $helpTargets = @('WinTune.ps1', 'WinTunePro.ps1', 'LaunchWinTune.ps1')
    foreach ($target in $helpTargets) {
        $path = Join-Path $projectRoot $target
        if (-not (Test-Path $path)) {
            throw "Missing expected launcher: $target"
        }

        $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $path -Help 2>&1
        if ($LASTEXITCODE -ne 0) {
            $output | Out-Host
            throw "Help smoke failed for $target"
        }

        if (-not $Quiet) {
            Write-Host "$target help smoke passed." -ForegroundColor Green
        }
    }
}

Write-Section "Validation summary"
Write-Host "Validation passed." -ForegroundColor Green
