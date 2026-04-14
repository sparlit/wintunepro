$lines = Get-Content 'E:\WinTunePro\WinTunePro.ps1'
$newLines = @()
$skip = $false
$depth = 0

for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '# =+.*MAIN ENTRY') {
        # Found the main entry section - stop here
        break
    }
    if (-not $skip) {
        $newLines += $lines[$i]
    }
}

# Add clean main entry
$newLines += ''
$newLines += '# ============================================================================'
$newLines += '# MAIN ENTRY'
$newLines += '# ============================================================================'
$newLines += ''
$newLines += 'try {'
$newLines += '    if ($Help) { Write-Host "WinTune Pro - WinTunePro.ps1 -CLI or -GUI"; exit }'
$newLines += '    Write-Host "Loading..." -ForegroundColor DarkGray'
$newLines += '    Load-All'
$newLines += '    Clear-Host'
$newLines += '    Write-Host ""; Write-Host "  WinTune Pro" -ForegroundColor Cyan; Write-Host ""'
$newLines += '    Write-Host "  [1] CLI Mode" -ForegroundColor Green'
$newLines += '    Write-Host "  [2] GUI Mode" -ForegroundColor Green'
$newLines += '    Write-Host "  [0] Exit" -ForegroundColor Red; Write-Host ""'
$newLines += '    $ch = (Read-Host "  Select").Trim()'
$newLines += '    switch ($ch) {'
$newLines += '        "1" { Start-CLI }'
$newLines += '        "2" { Start-GUI }'
$newLines += '        "0" { Save-Settings; Write-Host "Goodbye!"; exit }'
$newLines += '        default { Write-Host "Starting CLI..."; Start-CLI }'
$newLines += '    }'
$newLines += '} catch {'
$newLines += '    $msg = $_.Exception.Message'
$newLines += '    Write-Host "Error: $msg" -ForegroundColor Red'
$newLines += '    Read-Host "Press Enter"'
$newLines += '}'

[System.IO.File]::WriteAllLines('E:\WinTunePro\WinTunePro.ps1', $newLines)
Write-Host "File rebuilt with clean main entry point" -ForegroundColor Green
