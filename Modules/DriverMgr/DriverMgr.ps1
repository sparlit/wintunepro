<#
.SYNOPSIS
    WinTunePro DriverMgr Module - Driver management
.DESCRIPTION
    Manages device drivers including listing, backing up, restoring, removing
    orphaned drivers, and checking for updates via Windows Update.
.NOTES
    File: Modules\DriverMgr\DriverMgr.ps1
    Version: 1.0.0
    PowerShell: 5.1+
    Compatible: Windows 10, Windows 11
#>

#Requires -Version 5.1

$script:DriverCache = $null
$script:DriverCacheTimestamp = $null

function global:Get-InstalledDrivers {
    <#
    .SYNOPSIS
        List all installed drivers with version, date, provider.
    #>
    param(
        [Parameter()]
        [switch]$ForceRefresh
    )

    $result = @{
        Success  = $true
        Details  = @()
        Errors   = @()
    }

    Write-Log -Level "INFO" -Category "System" -Message "Gathering installed drivers..."

    try {
        $now = Get-Date
        if ($ForceRefresh -or -not $script:DriverCache -or -not $script:DriverCacheTimestamp -or ($now - $script:DriverCacheTimestamp).TotalMinutes -gt 10) {
            $drivers = Get-CimInstance -ClassName Win32_PnPSignedDriver -ErrorAction Stop
            $script:DriverCache = $drivers
            $script:DriverCacheTimestamp = $now
        } else {
            $drivers = $script:DriverCache
        }

        foreach ($driver in $drivers) {
            if (-not $driver.DeviceName) { continue }

            $driverDate = ""
            if ($driver.DriverDate) {
                try {
                    $driverDate = [Management.ManagementDateTimeConverter]::ToDateTime($driver.DriverDate).ToString("yyyy-MM-dd")
                } catch {
                    $driverDate = $driver.DriverDate.ToString()
                }
            }

            $result.Details += @{
                DeviceName    = $driver.DeviceName
                Description  = $driver.Description
                DriverVersion = $driver.DriverVersion
                DriverDate   = $driver.DriverDate
                Manufacturer = $driver.Manufacturer
                DriverName   = $driver.DriverName
                InfName      = $driver.InfName
                DeviceID     = $driver.DeviceID
                IsSigned     = $driver.IsSigned
                DriverProviderName = $driver.DriverProviderName
            }
        }

        Write-Log -Level "INFO" -Category "System" -Message "Found $($result.Details.Count) installed drivers"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "System" -Message "Failed to get drivers: $($_.Exception.Message)"
    }

    return $result
}

function global:Get-OutdatedDrivers {
    <#
    .SYNOPSIS
        Find drivers that may need updates.
    #>
    $result = @{
        Success  = $true
        Details  = @()
        Errors   = @()
    }

    Write-Log -Level "INFO" -Category "System" -Message "Checking for outdated drivers..."

    try {
        $drivers = Get-InstalledDrivers
        if (-not $drivers.Success) {
            $result.Success = $false
            $result.Errors += $drivers.Errors
            return $result
        }

        $criticalCategories = @("Display", "Network", "Audio", "Storage", "USB", "Bluetooth")
        $twoYearsAgo = (Get-Date).AddYears(-2)

        foreach ($driver in $drivers.Details) {
            $isOld = $false
            $reason = ""

            if ($driver.DriverDate) {
                try {
                    $date = [Management.ManagementDateTimeConverter]::ToDateTime($driver.DriverDate)
                    if ($date -lt $twoYearsAgo) {
                        $isOld = $true
                        $reason = "Driver older than 2 years ($($date.ToString('yyyy-MM-dd')))"
                    }
                } catch {
                    if (-not $driver.DriverVersion -or $driver.DriverVersion -eq "") {
                        $isOld = $true
                        $reason = "No version information available"
                    }
                }
            }

            if ($isOld) {
                $result.Details += @{
                    DeviceName     = $driver.DeviceName
                    DriverVersion  = $driver.DriverVersion
                    DriverDate     = $driver.DriverDate
                    Manufacturer   = $driver.Manufacturer
                    Reason         = $reason
                    Priority       = "Medium"
                }
            }
        }

        Write-Log -Level "INFO" -Category "System" -Message "Found $($result.Details.Count) potentially outdated drivers"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "System" -Message "Failed to check outdated drivers: $($_.Exception.Message)"
    }

    return $result
}

function global:Backup-DriverStore {
    <#
    .SYNOPSIS
        Backup current driver store to folder.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$BackupPath
    )

    $result = @{
        Success  = $true
        Details  = @{
            BackupPath = $BackupPath
            DriverCount = 0
            TotalSizeMB = 0
        }
        Errors   = @()
    }

    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Errors += "Administrator privileges required"
        return $result
    }

    Write-Log -Level "INFO" -Category "System" -Message "Backing up driver store to: $BackupPath"

    try {
        if (-not (Test-Path $BackupPath)) {
            New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
        }

        $exportResult = & dism.exe /online /export-driver /destination:"$BackupPath" 2>&1

        if ($LASTEXITCODE -eq 0) {
            $backupFiles = Get-ChildItem $BackupPath -Recurse -File
            $totalSize = ($backupFiles | Measure-Object -Property Length -Sum).Sum
            $result.Details.DriverCount = ($backupFiles | Where-Object { $_.Extension -eq ".inf" }).Count
            $result.Details.TotalSizeMB = [math]::Round($totalSize / 1MB, 2)

            Write-Log -Level "SUCCESS" -Category "System" -Message "Driver store backed up: $($result.Details.DriverCount) drivers ($($result.Details.TotalSizeMB) MB)"
        } else {
            $result.Success = $false
            $result.Errors += "DISM export failed with exit code $LASTEXITCODE : $($exportResult -join "`n")"
            Write-Log -Level "ERROR" -Category "System" -Message "Driver backup failed"
        }
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "System" -Message "Driver backup failed: $($_.Exception.Message)"
    }

    return $result
}

function global:Restore-DriverStore {
    <#
    .SYNOPSIS
        Restore drivers from backup.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$BackupPath
    )

    $result = @{
        Success  = $true
        Details  = @{
            DriversInstalled = 0
            DriversFailed    = 0
        }
        Errors   = @()
    }

    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Errors += "Administrator privileges required"
        return $result
    }

    if (-not (Test-Path $BackupPath)) {
        $result.Success = $false
        $result.Errors += "Backup path does not exist: $BackupPath"
        return $result
    }

    Write-Log -Level "INFO" -Category "System" -Message "Restoring drivers from: $BackupPath"

    try {
        $infFiles = Get-ChildItem $BackupPath -Recurse -Filter "*.inf" -ErrorAction Stop

        foreach ($inf in $infFiles) {
            try {
                $pnputilResult = & pnputil.exe /add-driver "$($inf.FullName)" /install 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $result.Details.DriversInstalled++
                } else {
                    $result.Details.DriversFailed++
                    $result.Errors += "Failed to install $($inf.Name): $($pnputilResult -join ' ')"
                }
            } catch {
                $result.Details.DriversFailed++
                $result.Errors += "Failed to install $($inf.Name): $($_.Exception.Message)"
            }
        }

        Write-Log -Level "SUCCESS" -Category "System" -Message "Driver restore complete: $($result.Details.DriversInstalled) installed, $($result.Details.DriversFailed) failed"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "System" -Message "Driver restore failed: $($_.Exception.Message)"
    }

    return $result
}

function global:Remove-OrphanedDrivers {
    <#
    .SYNOPSIS
        Remove drivers for hardware no longer present.
    #>
    param(
        [Parameter()]
        [switch]$WhatIf
    )

    $result = @{
        Success  = $true
        Details  = @{
            OrphanedDrivers = @()
            RemovedCount    = 0
            PreviewMode     = $WhatIf.IsPresent
        }
        Errors   = @()
    }

    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Errors += "Administrator privileges required"
        return $result
    }

    Write-Log -Level "INFO" -Category "System" -Message "Scanning for orphaned drivers..."

    try {
        $driverStore = "$env:SystemRoot\System32\DriverStore\FileRepository"
        if (-not (Test-Path $driverStore)) {
            $result.Errors += "Driver store path not found"
            return $result
        }

        $oemDrivers = Get-ChildItem $driverStore -Filter "oem*.inf" -ErrorAction Stop
        $activeDevices = Get-CimInstance -ClassName Win32_PnPEntity -ErrorAction Stop
        $activeDriverInfs = @()

        foreach ($device in $activeDevices) {
            try {
                $driver = Get-CimInstance -ClassName Win32_PnPSignedDriver -Filter "DeviceID='$($device.DeviceID.Replace('\','\\'))'" -ErrorAction SilentlyContinue
                if ($driver -and $driver.InfName) {
                    $activeDriverInfs += $driver.InfName.ToLower()
                }
            } catch {
                continue
            }
        }

        foreach ($oemInf in $oemDrivers) {
            if ($activeDriverInfs -notcontains $oemInf.Name.ToLower()) {
                $orphanInfo = @{
                    Name = $oemInf.Name
                    Path = $oemInf.FullName
                    SizeMB = [math]::Round($oemInf.Length / 1MB, 2)
                    LastModified = $oemInf.LastWriteTime.ToString("yyyy-MM-dd")
                }

                $result.Details.OrphanedDrivers += $orphanInfo

                if (-not $WhatIf) {
                    try {
                        $pnputilResult = & pnputil.exe /delete-driver $oemInf.Name /force 2>&1
                        if ($LASTEXITCODE -eq 0) {
                            $result.Details.RemovedCount++
                            Write-Log -Level "INFO" -Category "System" -Message "Removed orphaned driver: $($oemInf.Name)"
                        } else {
                            $result.Errors += "Failed to remove $($oemInf.Name): $($pnputilResult -join ' ')"
                        }
                    } catch {
                        $result.Errors += "Failed to remove $($oemInf.Name): $($_.Exception.Message)"
                    }
                }
            }
        }

        if ($WhatIf) {
            Write-Log -Level "INFO" -Category "System" -Message "Preview: Found $($result.Details.OrphanedDrivers.Count) orphaned drivers"
        } else {
            Write-Log -Level "SUCCESS" -Category "System" -Message "Removed $($result.Details.RemovedCount) orphaned drivers"
        }
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "System" -Message "Failed to scan orphaned drivers: $($_.Exception.Message)"
    }

    return $result
}

function global:Get-DriverStoreSize {
    <#
    .SYNOPSIS
        Calculate driver store size.
    #>
    $result = @{
        Success  = $true
        Details  = @{}
        Errors   = @()
    }

    Write-Log -Level "INFO" -Category "Storage" -Message "Calculating driver store size..."

    try {
        $driverStore = "$env:SystemRoot\System32\DriverStore\FileRepository"
        if (-not (Test-Path $driverStore)) {
            $result.Success = $false
            $result.Errors += "Driver store path not found"
            return $result
        }

        $files = Get-ChildItem $driverStore -Recurse -File -ErrorAction Stop
        $totalSize = ($files | Measure-Object -Property Length -Sum).Sum
        $folderCount = (Get-ChildItem $driverStore -Directory -ErrorAction Stop).Count
        $infCount = ($files | Where-Object { $_.Extension -eq ".inf" }).Count

        $result.Details = @{
            Path         = $driverStore
            TotalSizeMB  = [math]::Round($totalSize / 1MB, 2)
            TotalSizeGB  = [math]::Round($totalSize / 1GB, 2)
            FileCount    = $files.Count
            FolderCount  = $folderCount
            InfCount     = $infCount
        }

        Write-Log -Level "INFO" -Category "Storage" -Message "Driver store size: $($result.Details.TotalSizeGB) GB ($infCount drivers)"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "Storage" -Message "Failed to calculate driver store size: $($_.Exception.Message)"
    }

    return $result
}

function global:Export-DriverList {
    <#
    .SYNOPSIS
        Export driver list to file.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,

        [Parameter()]
        [ValidateSet("TXT", "CSV", "JSON")]
        [string]$Format = "TXT"
    )

    $result = @{
        Success  = $true
        Details  = @{
            OutputPath = $OutputPath
            Format     = $Format
            DriverCount = 0
        }
        Errors   = @()
    }

    Write-Log -Level "INFO" -Category "Report" -Message "Exporting driver list to $OutputPath ($Format)..."

    try {
        $drivers = Get-InstalledDrivers
        if (-not $drivers.Success) {
            $result.Success = $false
            $result.Errors += $drivers.Errors
            return $result
        }

        $parentDir = Split-Path $OutputPath -Parent
        if ($parentDir -and -not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }

        $result.Details.DriverCount = $drivers.Details.Count

        switch ($Format) {
            "CSV" {
                $drivers.Details | Select-Object DeviceName, DriverVersion, DriverDate, Manufacturer, DriverProviderName, InfName, IsSigned |
                    Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
            }
            "JSON" {
                $drivers.Details | ConvertTo-Json -Depth 5 | Out-File -FilePath $OutputPath -Encoding UTF8
            }
            default {
                $sb = New-Object System.Text.StringBuilder
                [void]$sb.AppendLine("=" * 80)
                [void]$sb.AppendLine("WinTunePro Driver List")
                [void]$sb.AppendLine("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
                [void]$sb.AppendLine("Computer: $env:COMPUTERNAME")
                [void]$sb.AppendLine("=" * 80)
                [void]$sb.AppendLine("")

                foreach ($driver in ($drivers.Details | Sort-Object DeviceName)) {
                    [void]$sb.AppendLine("Device: $($driver.DeviceName)")
                    [void]$sb.AppendLine("  Version: $($driver.DriverVersion)")
                    [void]$sb.AppendLine("  Date: $($driver.DriverDate)")
                    [void]$sb.AppendLine("  Manufacturer: $($driver.Manufacturer)")
                    [void]$sb.AppendLine("  Provider: $($driver.DriverProviderName)")
                    [void]$sb.AppendLine("  INF: $($driver.InfName)")
                    [void]$sb.AppendLine("  Signed: $($driver.IsSigned)")
                    [void]$sb.AppendLine("-" * 40)
                }

                $sb.ToString() | Out-File -FilePath $OutputPath -Encoding UTF8
            }
        }

        Write-Log -Level "SUCCESS" -Category "Report" -Message "Driver list exported: $($result.Details.DriverCount) drivers"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "Report" -Message "Failed to export driver list: $($_.Exception.Message)"
    }

    return $result
}

function global:Update-DriverFromWindowsUpdate {
    <#
    .SYNOPSIS
        Check for driver updates via Windows Update.
    #>
    param(
        [Parameter()]
        [switch]$Install
    )

    $result = @{
        Success  = $true
        Details  = @{
            AvailableUpdates = @()
            InstalledCount   = 0
        }
        Errors   = @()
    }

    Write-Log -Level "INFO" -Category "System" -Message "Checking for driver updates via Windows Update..."

    try {
        $session = New-Object -ComObject Microsoft.Update.Session -ErrorAction Stop
        $searcher = $session.CreateUpdateSearcher()
        $searchResult = $searcher.Search("IsInstalled=0 and IsHidden=0 and Type='Driver'")

        foreach ($update in $searchResult.Updates) {
            $result.Details.AvailableUpdates += @{
                Title        = $update.Title
                DriverModel  = $update.DriverModel
                DriverVerDate = $update.DriverVerDate
                DriverVendor = $update.DriverVendor
                SizeMB       = [math]::Round($update.MaxDownloadSize / 1MB, 2)
            }
        }

        Write-Log -Level "INFO" -Category "System" -Message "Found $($result.Details.AvailableUpdates.Count) driver updates available"

        if ($Install -and $result.Details.AvailableUpdates.Count -gt 0) {
            Write-Log -Level "INFO" -Category "System" -Message "Installing driver updates..."

            $updatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
            foreach ($update in $searchResult.Updates) {
                [void]$updatesToInstall.Add($update)
            }

            $downloader = $session.CreateUpdateDownloader()
            $downloader.Updates = $updatesToInstall
            $downloadResult = $downloader.Download()

            if ($downloadResult.ResultCode -eq 2 -or $downloadResult.ResultCode -eq 3) {
                $installer = $session.CreateUpdateInstaller()
                $installer.Updates = $updatesToInstall
                $installResult = $installer.Install()

                for ($i = 0; $i -lt $updatesToInstall.Count; $i++) {
                    $rc = $installResult.GetUpdateResult($i).ResultCode
                    if ($rc -eq 2 -or $rc -eq 3) {
                        $result.Details.InstalledCount++
                    }
                }

                Write-Log -Level "SUCCESS" -Category "System" -Message "Installed $($result.Details.InstalledCount) driver updates"
            } else {
                $result.Errors += "Driver download failed with result code: $($downloadResult.ResultCode)"
            }
        }
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "System" -Message "Failed to check driver updates: $($_.Exception.Message)"
    }

    return $result
}
