$lines = Get-Content 'E:\WinTunePro\WinTunePro.ps1'
$depth = 0
for ($i = 598; $i -lt 615; $i++) {
    $opens = ($lines[$i].ToCharArray() | Where-Object { $_ -eq '{' }).Count
    $closes = ($lines[$i].ToCharArray() | Where-Object { $_ -eq '}' }).Count
    $oldDepth = $depth
    $depth += $opens - $closes
    $marker = ""
    if ($opens -gt 0 -or $closes -gt 0) { $marker = " <-- $opens open, $closes close, depth=$depth" }
    Write-Host "$($i+1): $($lines[$i].Trim())$marker"
}
