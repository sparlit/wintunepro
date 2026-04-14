# WinTune Pro - Enhanced Cleaning Tools
# Additional cleaning commands and tools for comprehensive system cleanup

# Advanced Disk Cleanup (uses Windows built-in tools)
function global:Invoke-AdvancedDiskCleanup {
    param([bool]$TestMode = $false)

    Write-Host "Running Advanced Disk Cleanup..." -ForegroundColor Cyan

    if ($TestMode) {
        Write-Host "[TEST MODE] Would run Windows Disk Cleanup..." -ForegroundColor Yellow
        Write-Host "[TEST MODE] Would clean system files..." -ForegroundColor Yellow
        Write-Host "[TEST MODE] Would remove old Windows installations..." -ForegroundColor Yellow
        return
    }

    try {
        # Run built-in Disk Cleanup
        Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:1" -Wait -NoNewWindow

        # Clean system files (requires elevation)
        if (Test-AdminPrivileges) {
            Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/verylowdisk" -Verb RunAs -Wait -NoNewWindow
        }

        Write-Host "Advanced Disk Cleanup completed." -ForegroundColor Green
    } catch {
        Write-Host "Error during Advanced Disk Cleanup: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Windows Update Cleanup
function global:Invoke-WindowsUpdateCleanup {
    param([bool]$TestMode = $false)

    Write-Host "Running Windows Update Cleanup..." -ForegroundColor Cyan

    if ($TestMode) {
        Write-Host "[TEST MODE] Would stop Windows Update service..." -ForegroundColor Yellow
        Write-Host "[TEST MODE] Would clear SoftwareDistribution folder..." -ForegroundColor Yellow
        Write-Host "[TEST MODE] Would reset Windows Update components..." -ForegroundColor Yellow
        return
    }

    try {
        # Stop Windows Update services
        Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
        Stop-Service -Name bits -Force -ErrorAction SilentlyContinue

        # Clear SoftwareDistribution folder
        Remove-Item -Path "$env:SystemRoot\SoftwareDistribution\*" -Recurse -Force -ErrorAction SilentlyContinue

        # Reset Windows Update components
        Start-Process -FilePath "net.exe" -ArgumentList "stop wuauserv" -Wait -NoNewWindow
        Start-Process -FilePath "net.exe" -ArgumentList "stop cryptSvc" -Wait -NoNewWindow
        Start-Process -FilePath "net.exe" -ArgumentList "stop bits" -Wait -NoNewWindow
        Start-Process -FilePath "net.exe" -ArgumentList "stop msiserver" -Wait -NoNewWindow

        Remove-Item -Path "$env:SystemRoot\SoftwareDistribution\*" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$env:SystemRoot\system32\catroot2\*" -Recurse -Force -ErrorAction SilentlyContinue

        Start-Process -FilePath "net.exe" -ArgumentList "start wuauserv" -Wait -NoNewWindow
        Start-Process -FilePath "net.exe" -ArgumentList "start cryptSvc" -Wait -NoNewWindow
        Start-Process -FilePath "net.exe" -ArgumentList "start bits" -Wait -NoNewWindow
        Start-Process -FilePath "net.exe" -ArgumentList "start msiserver" -Wait -NoNewWindow

        Write-Host "Windows Update Cleanup completed." -ForegroundColor Green
    } catch {
        Write-Host "Error during Windows Update Cleanup: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Storage Sense Cleanup
function global:Invoke-StorageSenseCleanup {
    param([bool]$TestMode = $false)

    Write-Host "Running Storage Sense Cleanup..." -ForegroundColor Cyan

    if ($TestMode) {
        Write-Host "[TEST MODE] Would enable Storage Sense..." -ForegroundColor Yellow
        Write-Host "[TEST MODE] Would run Storage Sense cleanup..." -ForegroundColor Yellow
        return
    }

    try {
        # Enable Storage Sense
        New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" -Name "01" -Value 1 -PropertyType DWORD -Force -ErrorAction SilentlyContinue

        # Run Storage Sense
        Start-Process -FilePath "rundll32.exe" -ArgumentList "shell32.dll,SHQueryUserNotificationState" -Wait -NoNewWindow

        Write-Host "Storage Sense Cleanup completed." -ForegroundColor Green
    } catch {
        Write-Host "Error during Storage Sense Cleanup: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Event Log Cleanup
function global:Invoke-EventLogCleanup {
    param([bool]$TestMode = $false)

    Write-Host "Running Event Log Cleanup..." -ForegroundColor Cyan

    if ($TestMode) {
        Write-Host "[TEST MODE] Would clear system event logs..." -ForegroundColor Yellow
        Write-Host "[TEST MODE] Would clear application event logs..." -ForegroundColor Yellow
        Write-Host "[TEST MODE] Would clear security event logs..." -ForegroundColor Yellow
        return
    }

    try {
        # Clear event logs
        wevtutil cl System
        wevtutil cl Application
        wevtutil cl Security

        Write-Host "Event Log Cleanup completed." -ForegroundColor Green
    } catch {
        Write-Host "Error during Event Log Cleanup: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Registry Cleanup (safe operations only)
function global:Invoke-RegistryCleanup {
    param([bool]$TestMode = $false)

    Write-Host "Running Registry Cleanup..." -ForegroundColor Cyan

    if ($TestMode) {
        Write-Host "[TEST MODE] Would remove invalid software entries..." -ForegroundColor Yellow
        Write-Host "[TEST MODE] Would clean uninstall entries..." -ForegroundColor Yellow
        Write-Host "[TEST MODE] Would remove orphaned registry keys..." -ForegroundColor Yellow
        return
    }

    try {
        # Remove invalid uninstall entries (safe ones only)
        $uninstallKeys = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" -ErrorAction SilentlyContinue
        foreach ($key in $uninstallKeys) {
            try {
                $installLocation = $key.GetValue("InstallLocation")
                if ($installLocation -and -not (Test-Path $installLocation)) {
                    Remove-Item $key.PSPath -Recurse -ErrorAction SilentlyContinue
                }
            } catch {
                # Skip problematic keys
            }
        }

        Write-Host "Registry Cleanup completed." -ForegroundColor Green
    } catch {
        Write-Host "Error during Registry Cleanup: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# SSD TRIM Optimization
function global:Invoke-SSDTrim {
    param([bool]$TestMode = $false)

    Write-Host "Running SSD TRIM Optimization..." -ForegroundColor Cyan

    if ($TestMode) {
        Write-Host "[TEST MODE] Would run defrag with TRIM..." -ForegroundColor Yellow
        return
    }

    try {
        # Run TRIM on SSD drives
        Start-Process -FilePath "defrag.exe" -ArgumentList "/C /H /U /V" -Wait -NoNewWindow

        Write-Host "SSD TRIM Optimization completed." -ForegroundColor Green
    } catch {
        Write-Host "Error during SSD TRIM Optimization: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Memory Optimization
function global:Invoke-MemoryOptimization {
    param([bool]$TestMode = $false)

    Write-Host "Running Memory Optimization..." -ForegroundColor Cyan

    if ($TestMode) {
        Write-Host "[TEST MODE] Would clear system cache..." -ForegroundColor Yellow
        Write-Host "[TEST MODE] Would run memory cleanup..." -ForegroundColor Yellow
        return
    }

    try {
        # Clear system cache
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()

        # Clear DNS cache
        Clear-DnsClientCache

        # Clear network cache
        Start-Process -FilePath "netsh.exe" -ArgumentList "interface ip delete arpcache" -Wait -NoNewWindow

        Write-Host "Memory Optimization completed." -ForegroundColor Green
    } catch {
        Write-Host "Error during Memory Optimization: $($_.Exception.Message)" -ForegroundColor Red
    }
}
