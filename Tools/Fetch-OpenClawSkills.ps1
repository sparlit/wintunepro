#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Readme','Csv','Both')]
    [string]$Mode = 'Both',

    [string]$ReadmeUrl = 'https://raw.githubusercontent.com/VoltAgent/awesome-openclaw-skills/main/README.md',

    [string]$OutputReadmePath,
    [string]$OutputCsvPath,

    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if (-not $OutputReadmePath) { $OutputReadmePath = Join-Path $projectRoot 'docs\OpenClawSkills.md' }
if (-not $OutputCsvPath) { $OutputCsvPath = Join-Path $projectRoot 'docs\OpenClawSkills.csv' }

function Write-Section {
    param([string]$Text)
    if (-not $Quiet) {
        Write-Host "`n== $Text ==" -ForegroundColor Cyan
    }
}

function Download-Text {
    param([string]$Url)

    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -ErrorAction Stop
        return $response.Content
    }
    catch {
        throw "Unable to download OpenClaw skills source from '$Url'. $_"
    }
}

function Parse-SkillLine {
    param([string]$Line)

    $skillPattern = '^[ \t]*•[ \t]*\[([^\]]+)\]\((https?://[^\)]+)\)[ \t]*[-–—][ \t]*(.+?)\s*$'
    if ($Line -match $skillPattern) {
        return [pscustomobject]@{
            Name        = $Matches[1].Trim()
            Url         = $Matches[2].Trim()
            Description = $Matches[3].Trim()
        }
    }

    return $null
}

Write-Section "OpenClaw skills helper"
$markdown = Download-Text -Url $ReadmeUrl

if ($Mode -ne 'Csv') {
    $readmeDirectory = Split-Path -Parent $OutputReadmePath
    if (-not (Test-Path $readmeDirectory)) {
        New-Item -ItemType Directory -Path $readmeDirectory -Force | Out-Null
    }

    Set-Content -Path $OutputReadmePath -Value $markdown -Encoding UTF8
    if (-not $Quiet) {
        Write-Host "Saved OpenClaw skills markdown to $OutputReadmePath" -ForegroundColor Green
    }
}

if ($Mode -ne 'Readme') {
    $lines = $markdown -split "`n"
    $currentCategory = ''
    $skillEntries = [System.Collections.Generic.List[object]]::new()

    foreach ($line in $lines) {
        if ($line -match '^[ \t]*###[ \t]*(.+?)\s*$') {
            $currentCategory = $Matches[1].Trim()
            continue
        }

        $entry = Parse-SkillLine -Line $line
        if ($entry) {
            $entry | Add-Member -MemberType NoteProperty -Name Category -Value $currentCategory -Force
            $skillEntries.Add($entry)
        }
    }

    if ($skillEntries.Count -eq 0) {
        Write-Host "Warning: no skill entries were parsed from the downloaded README." -ForegroundColor Yellow
    }
    else {
        $csvDirectory = Split-Path -Parent $OutputCsvPath
        if (-not (Test-Path $csvDirectory)) {
            New-Item -ItemType Directory -Path $csvDirectory -Force | Out-Null
        }

        $skillEntries | Select-Object Category, Name, Url, Description | Export-Csv -Path $OutputCsvPath -NoTypeInformation -Encoding UTF8
        if (-not $Quiet) {
            Write-Host "Exported $($skillEntries.Count) OpenClaw skills to $OutputCsvPath" -ForegroundColor Green
        }
    }
}
