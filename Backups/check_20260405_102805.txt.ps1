$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile('E:\WinTunePro\WinTunePro.ps1', [ref]$null, [ref]$errors) | Out-Null
if ($errors.Count -gt 0) {
    Write-Host "Errors: $($errors.Count)" -ForegroundColor Red
    foreach ($e in $errors) { Write-Host "  $($e.Extent.StartLineNumber): $($e.Message)" -ForegroundColor Red }
} else {
    Write-Host "Syntax OK" -ForegroundColor Green
}
