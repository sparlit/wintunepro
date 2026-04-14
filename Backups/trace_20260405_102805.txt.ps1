$lines = Get-Content 'E:\WinTunePro\WinTunePro.ps1'
$depth = 0
$maxDepth = 0
for ($i = 0; $i -lt $lines.Count; $i++) {
    $opens = ($lines[$i].ToCharArray() | Where-Object { $_ -eq '{' }).Count
    $closes = ($lines[$i].ToCharArray() | Where-Object { $_ -eq '}' }).Count
    $oldDepth = $depth
    $depth += $opens - $closes
    if ($depth -gt $maxDepth) { $maxDepth = $depth }
    if ($depth -lt 0) {
        Write-Host "Depth went negative at line $($i+1)" -ForegroundColor Red
        break
    }
}
Write-Host "Final depth: $depth"
Write-Host "Max depth: $maxDepth"
Write-Host "File lines: $($lines.Count)"
