# WinTune Pro - Storage Health Module
# PowerShell 5.1+ Compatible

function global:Get-StorageHealth {
    $health = @{ Score = 100; Disks = @(); Warnings = @() }
    try {
        $disks = Get-PhysicalDisk -ErrorAction SilentlyContinue
        foreach ($disk in $disks) {
            $diskInfo = @{ DeviceId = $disk.DeviceId; FriendlyName = $disk.FriendlyName; MediaType = $disk.MediaType; HealthStatus = $disk.HealthStatus.ToString(); Size = [math]::Round($disk.Size / 1GB, 2); IsSystem = $false }
            try { $systemDrive = Get-Partition | Where-Object { $_.DriveLetter -eq "C" }; if ($systemDrive -and $systemDrive.DiskNumber -eq $disk.DeviceId) { $diskInfo.IsSystem = $true } } catch { Write-Log -Level "WARNING" -Category "System" -Message $_.Exception.Message }
            if ($disk.HealthStatus -ne "Healthy") { $health.Score -= 20; $health.Warnings += "Disk $($disk.DeviceId) ($($disk.FriendlyName)) health: $($disk.HealthStatus)" }
            $health.Disks += $diskInfo
        }
    } catch { Write-Log $_.Exception.Message -Level 'WARNING' -Category 'System' }
    try {
        $volumes = Get-Volume -ErrorAction SilentlyContinue
        foreach ($vol in $volumes) { if ($vol.DriveLetter -and $vol.SizeRemaining -ne $null) { $usedPercent = (($vol.Size - $vol.SizeRemaining) / $vol.Size) * 100; if ($usedPercent -gt 90) { $health.Score -= 10; $health.Warnings += "Drive $($vol.DriveLetter) is nearly full ($([math]::Round($usedPercent, 1))% used)" } } }
    } catch { Write-Log $_.Exception.Message -Level 'WARNING' -Category 'System' }
    if ($health.Score -lt 0) { $health.Score = 0 }
    return $health
}

function global:Get-TRIMStatus {
    $status = @{ Enabled = $false; Supported = $false }
    try {
        $result = fsutil behavior query DisableDeleteNotify 2>$null
        if ($result -match "DisableDeleteNotify = 0") { $status.Enabled = $true }
        $disks = Get-PhysicalDisk -ErrorAction SilentlyContinue
        foreach ($disk in $disks) { if ($disk.MediaType -eq "SSD") { $status.Supported = $true; break } }
    } catch { Write-Log $_.Exception.Message -Level 'WARNING' -Category 'System' }
    return $status
}

function global:Enable-TRIM {
    param([bool]$TestMode = $false)
    if ($TestMode) { Log-Info "Test Mode: Would enable TRIM" -Category "Storage"; return $true }
    try { fsutil behavior set DisableDeleteNotify 0 | Out-Null; Log-Success "Enabled TRIM" -Category "Storage"; return $true } catch { Log-Error "Failed to enable TRIM: $($_.Exception.Message)" -Category "Storage"; return $false }
}

function global:Invoke-TRIMOptimization {
    param([bool]$TestMode = $false)
    if ($TestMode) { Log-Info "Test Mode: Would run TRIM optimization" -Category "Storage"; return @{ Success = $true; Actions = @("Test Mode: Would run TRIM") } }
    $results = @{ Success = $true; Actions = @() }
    try {
        $drives = Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveType -eq "Fixed" }
        foreach ($drive in $drives) { try { $driveLetter = $drive.DriveLetter; defrag "$driveLetter`:" /L /O | Out-Null; $results.Actions += "Optimized drive $driveLetter" } catch { $results.Actions += "Could not optimize drive $($drive.DriveLetter)" } }
        Log-Success "TRIM optimization completed" -Category "Storage"
    } catch { $results.Success = $false; Log-Error "TRIM optimization failed: $($_.Exception.Message)" -Category "Storage" }
    return $results
}

function global:Get-DiskList {
    $disks = @()
    try { Get-PhysicalDisk | ForEach-Object { $disk = @{ DeviceId = $_.DeviceId; FriendlyName = $_.FriendlyName; MediaType = $_.MediaType.ToString(); HealthStatus = $_.HealthStatus.ToString(); SizeGB = [math]::Round($_.Size / 1GB, 2); BusType = $_.BusType.ToString() }; $disks += $disk } } catch { Write-Log $_.Exception.Message -Level 'WARNING' -Category 'System' }
    return $disks
}

function global:Get-VolumeList {
    $volumes = @()
    try { Get-Volume | Where-Object { $_.DriveLetter } | ForEach-Object { $vol = @{ DriveLetter = "$($_.DriveLetter):"; FileSystemLabel = $_.FileSystemLabel; FileSystem = $_.FileSystem; SizeGB = [math]::Round($_.Size / 1GB, 2); FreeGB = [math]::Round($_.SizeRemaining / 1GB, 2); UsedPercent = [math]::Round((($_.Size - $_.SizeRemaining) / $_.Size) * 100, 1); HealthStatus = $_.HealthStatus.ToString() }; $volumes += $vol } } catch { Write-Log $_.Exception.Message -Level 'WARNING' -Category 'System' }
    return $volumes
}

function global:Enable-StorageSense {
    param([bool]$Enable = $true, [bool]$TestMode = $false)
    if ($TestMode) { Log-Info "Test Mode: Would $(if($Enable){'enable'}else{'disable'}) Storage Sense" -Category "Storage"; return $true }
    try { $value = if ($Enable) { 1 } else { 0 }; Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" -Name "01" -Value $value -Force -ErrorAction SilentlyContinue; Log-Success "$(if($Enable){'Enabled'}else{'Disabled'}) Storage Sense" -Category "Storage"; return $true } catch { Log-Error "Failed to set Storage Sense: $($_.Exception.Message)" -Category "Storage"; return $false }
}
