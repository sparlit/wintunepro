# DriverStore.ps1 - PS5.1 compatible driver store cleaning

function Get-DriverStoreSize {
    [CmdletBinding()]
    param()

    $storePath = 'C:\Windows\System32\DriverStore\FileRepository'

    if (-not (Test-Path $storePath)) {
        Write-Log -Level "WARNING" -Category "Cleaning" -Message "DriverStore\FileRepository not found"
        return @{ TotalSizeMB = 0; DriverCount = 0 }
    }

    try {
        $items = Get-ChildItem -Path $storePath -Directory -ErrorAction Stop
        $totalSize = 0
        foreach ($item in $items) {
            $size = (Get-ChildItem -Path $item.FullName -Recurse -Force -ErrorAction SilentlyContinue |
                Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
            if ($size) { $totalSize += $size }
        }

        $result = @{
            TotalSizeMB = [math]::Round($totalSize / 1MB, 2)
            DriverCount = $items.Count
        }
        Write-Log -Level "INFO" -Category "Cleaning" -Message "DriverStore size: $($result.TotalSizeMB) MB across $($result.DriverCount) packages"
        return $result
    } catch {
        Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message
        return @{ TotalSizeMB = 0; DriverCount = 0 }
    }
}

function Clear-OrphanedDrivers {
    [CmdletBinding()]
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{ Success = $false; BytesRecovered = 0; Message = ''; ItemsCleaned = 0 }
    $storePath = 'C:\Windows\System32\DriverStore\FileRepository'

    if (-not (Test-Path $storePath)) {
        $result.Message = 'DriverStore\FileRepository not found'
        Write-Log -Level "WARNING" -Category "Cleaning" -Message $result.Message
        return $result
    }

    try {
        $installedDrivers = @()
        try {
            $pnpOutput = & pnputil /enum-drivers 2>$null
            $currentInf = ''
            foreach ($line in $pnpOutput) {
                if ($line -match 'Published Name:\s*(.+)' -and $currentInf) {
                    $installedDrivers += $currentInf.Trim()
                    $currentInf = ''
                }
                if ($line -match 'Original Name:\s*(.+)') {
                    $currentInf = $Matches[1]
                }
            }
            if ($currentInf) { $installedDrivers += $currentInf.Trim() }
        } catch {
            Write-Log -Level "WARNING" -Category "Cleaning" -Message "pnputil query failed: $($_.Exception.Message)"
        }

        $packages = Get-ChildItem -Path $storePath -Directory -ErrorAction Stop
        $orphaned = @()

        foreach ($pkg in $packages) {
            $infFiles = Get-ChildItem -Path $pkg.FullName -Filter '*.inf' -ErrorAction SilentlyContinue
            $isInstalled = $false
            foreach ($inf in $infFiles) {
                if ($installedDrivers -contains $inf.Name) {
                    $isInstalled = $true
                    break
                }
            }
            if (-not $isInstalled) { $orphaned += $pkg }
        }

        Write-Log -Level "INFO" -Category "Cleaning" -Message "Found $($orphaned.Count) orphaned driver packages"

        foreach ($pkg in $orphaned) {
            try {
                $size = (Get-ChildItem -Path $pkg.FullName -Recurse -Force -ErrorAction SilentlyContinue |
                    Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                if (-not $size) { $size = 0 }

                if ($Preview) {
                    Write-Log -Level "INFO" -Category "Cleaning" -Message "Orphaned driver $($pkg.Name) - $([math]::Round($size / 1MB, 2)) MB (Preview)"
                } elseif ($TestMode) {
                    Write-Log -Level "INFO" -Category "Cleaning" -Message "Orphaned driver $($pkg.Name) - Test mode, skipped"
                } else {
                    Remove-Item -Path $pkg.FullName -Recurse -Force -ErrorAction Stop
                    $result.BytesRecovered += $size
                    $result.ItemsCleaned++
                    Write-Log -Level "SUCCESS" -Category "Cleaning" -Message "Removed orphaned driver $($pkg.Name) - $([math]::Round($size / 1MB, 2)) MB"
                }
            } catch {
                Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message
            }
        }

        $result.Success = $true
        $result.Message = "Orphaned drivers cleaned - $([math]::Round($result.BytesRecovered / 1MB, 2)) MB recovered, $($result.ItemsCleaned) packages"
    } catch {
        Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message
        $result.Message = $_.Exception.Message
    }

    return $result
}

function Clear-DriverStoreBackups {
    [CmdletBinding()]
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{ Success = $false; BytesRecovered = 0; Message = ''; ItemsCleaned = 0 }

    try {
        $backupPaths = @(
            'C:\Windows\System32\DriverStore\FileRepository',
            "$env:WINDIR\inf"
        )

        foreach ($backupPath in $backupPaths) {
            if (-not (Test-Path $backupPath)) { continue }

            $bakFiles = Get-ChildItem -Path $backupPath -Recurse -Include '*.bak', '*.old' -Force -ErrorAction SilentlyContinue

            foreach ($file in $bakFiles) {
                try {
                    $size = $file.Length
                    if ($Preview) {
                        Write-Log -Level "INFO" -Category "Cleaning" -Message "Backup file $($file.Name) - $([math]::Round($size / 1KB, 2)) KB (Preview)"
                    } elseif ($TestMode) {
                        Write-Log -Level "INFO" -Category "Cleaning" -Message "Backup file $($file.Name) - Test mode, skipped"
                    } else {
                        Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                        $result.BytesRecovered += $size
                        $result.ItemsCleaned++
                        Write-Log -Level "SUCCESS" -Category "Cleaning" -Message "Removed backup $($file.Name)"
                    }
                } catch {
                    Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message
                }
            }
        }

        $result.Success = $true
        $result.Message = "Driver store backups cleaned - $([math]::Round($result.BytesRecovered / 1KB, 2)) KB recovered, $($result.ItemsCleaned) files"
    } catch {
        Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message
        $result.Message = $_.Exception.Message
    }

    return $result
}
