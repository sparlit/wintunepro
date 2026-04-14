# Rollback Advanced Tweaks to Windows Defaults

Write-Host "Restoring telemetry settings..."
Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -ErrorAction SilentlyContinue

Write-Host "Restoring menu show delay..."
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value 400

Write-Host "Restoring context menu behavior..."
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "DesktopProcess" -ErrorAction SilentlyContinue

Write-Host "Restoring window animations..."
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value 1

Write-Host "Restoring DNS cache defaults..."
Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" -Name "MaxCacheTtl" -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" -Name "MaxNegativeCacheTtl" -ErrorAction SilentlyContinue

Write-Host "Rollback complete. Restart your PC to apply changes."
