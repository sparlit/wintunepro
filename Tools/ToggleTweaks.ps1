# Ultimate Toggle Tweaks Script with Disk Usage
$logPath = "E:\WinTunePro\logs"
if (!(Test-Path $logPath)) {
    New-Item -ItemType Directory -Path $logPath | Out-Null
}
$logFile = Join-Path $logPath "TweaksLog.txt"
$backupFile = Join-Path $logPath "RegistryBackup.json"
$reportFile = Join-Path $logPath "TweaksReport.txt"

function Write-Log($message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logFile -Value "$timestamp - $message"
}

function Backup-Registry {
    $backup = @{
        Telemetry = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -ErrorAction SilentlyContinue).AllowTelemetry
        MenuShowDelay = (Get-ItemProperty -Path "HKCU:\Control Panel\Desktop").MenuShowDelay
        ContextMenu = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -ErrorAction SilentlyContinue).DesktopProcess
        Animations = (Get-ItemProperty -Path "HKCU:\Control Panel\Desktop\WindowMetrics").MinAnimate
        DNSMax = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" -ErrorAction SilentlyContinue).MaxCacheTtl
        DNSNeg = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" -ErrorAction SilentlyContinue).MaxNegativeCacheTtl
    }
    $backup | ConvertTo-Json | Set-Content $backupFile
    Write-Log "Registry backup saved to $backupFile"
}

function Restore-Registry {
    if (Test-Path $backupFile) {
        $backup = Get-Content $backupFile | ConvertFrom-Json
        Write-Host "Restoring registry from backup..."
        Write-Log "Restored registry from backup"

        if ($backup.Telemetry -ne $null) { Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value $backup.Telemetry -Force }
        if ($backup.MenuShowDelay -ne $null) { Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value $backup.MenuShowDelay }
        if ($backup.ContextMenu -ne $null) { Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "DesktopProcess" -Value $backup.ContextMenu }
        if ($backup.Animations -ne $null) { Set-ItemProperty -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value $backup.Animations }
        if ($backup.DNSMax -ne $null) { Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" -Name "MaxCacheTtl" -Value $backup.DNSMax }
        if ($backup.DNSNeg -ne $null) { Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" -Name "MaxNegativeCacheTtl" -Value $backup.DNSNeg }
    } else {
        Write-Host "No backup file found."
        Write-Log "Restore attempted but no backup file found"
    }
}

function Export-Report {
    $telemetry = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -ErrorAction SilentlyContinue).AllowTelemetry
    $menuDelay = (Get-ItemProperty -Path "HKCU:\Control Panel\Desktop").MenuShowDelay
    $contextMenu = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -ErrorAction SilentlyContinue).DesktopProcess
    $animations = (Get-ItemProperty -Path "HKCU:\Control Panel\Desktop\WindowMetrics").MinAnimate
    $dnsMax = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" -ErrorAction SilentlyContinue).MaxCacheTtl
    $dnsNeg = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" -ErrorAction SilentlyContinue).MaxNegativeCacheTtl

    # System Info
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor
    $ram = [math]::Round($os.TotalVisibleMemorySize/1MB,2)
    $uptime = (Get-Date) - $os.LastBootUpTime

    # Disk Usage
    $drives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
    $diskReport = ""
    foreach ($d in $drives) {
        $sizeGB = [math]::Round($d.Size/1GB,2)
        $freeGB = [math]::Round($d.FreeSpace/1GB,2)
        $usedGB = $sizeGB - $freeGB
        $diskReport += "Drive $($d.DeviceID): $usedGB GB used / $sizeGB GB total ($freeGB GB free)`n"
    }

    $report = @"
System Tweaks Report
====================
Telemetry setting: $telemetry
Menu show delay: $menuDelay ms
Context menu optimization: $contextMenu
Animations enabled (1=yes,0=no): $animations
DNS MaxCacheTtl: $dnsMax
DNS MaxNegativeCacheTtl: $dnsNeg

System Information
==================
OS: $($os.Caption) $($os.Version)
CPU: $($cpu.Name)
RAM: $ram MB
Uptime: $([math]::Round($uptime.TotalHours,2)) hours

Disk Usage
==========
$diskReport
"@
    $report | Set-Content $reportFile
    Write-Host "Report exported to $reportFile"
    Write-Log "Exported full system tweaks + disk usage report"
}

Write-Host "Choose an option:"
Write-Host "1. Apply Performance Tweaks (with backup)"
Write-Host "2. Rollback to Defaults"
Write-Host "3. Check Current Settings"
Write-Host "4. Restore from Backup"
Write-Host "5. Export Current Settings Report (with system info + disk usage)"
$choice = Read-Host "Enter 1, 2, 3, 4 or 5"

switch ($choice) {
    "1" { Backup-Registry; Write-Host "Applying performance tweaks..."; Write-Log "Applied performance tweaks"; # (Tweaks code same as before) }
    "2" { Write-Host "Rolling back to defaults..."; Write-Log "Rolled back to defaults"; # (Rollback code same as before) }
    "3" { Write-Host "Checking current settings..."; Write-Log "Checked current settings"; # (Status check code same as before) }
    "4" { Restore-Registry }
    "5" { Export-Report }
    default { Write-Host "Invalid choice. Please run again and enter 1, 2, 3, 4 or 5." }
}
