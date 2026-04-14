#Requires -Version 5.1
<#
.SYNOPSIS
    System Junk Cleaner Module
.DESCRIPTION
    Functions for removing orphaned registry entries, obsolete drivers,
    temporary junk, and Windows error reports.
#>

function global:Clear-OrphanedRegistry {
    <#
    .SYNOPSIS
        Removes orphaned registry entries from uninstalled applications.
    #>
    param(
        [string[]]$Paths = @(),
        [switch]$WhatIf
    )

    $result = @{
        Success       = $false
        Message       = ""
        BytesRecovered = 0
        ItemsRemoved  = 0
    }

    try {
        $uninstallPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
        )

        foreach ($regPath in $uninstallPaths) {
            if (-not (Test-Path $regPath)) { continue }
            try {
                $subkeys = Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue
                foreach ($subkey in $subkeys) {
                    try {
                        $installLocation = (Get-ItemProperty -Path $subkey.PSPath -Name "InstallLocation" -ErrorAction SilentlyContinue).InstallLocation
                        if ($installLocation -and -not (Test-Path $installLocation -ErrorAction SilentlyContinue)) {
                            if ($WhatIf) {
                                Write-Log -Level "INFO" -Category "System" -Message "Would remove orphaned uninstall key: $($subkey.PSChildName)" -Category "SystemJunk"
                            } else {
                                Remove-Item -Path $subkey.PSPath -Recurse -Force -ErrorAction Stop
                                $result.ItemsRemoved++
                                Write-Log -Level "SUCCESS" -Category "SystemJunk" -Message "Removed orphaned uninstall key: $($subkey.PSChildName)"
                            }
                        }
                    } catch {
                        Write-Log -Level "WARNING" -Category "System" -Message "Failed checking uninstall key '$($subkey.PSChildName)': $($_.Exception.Message)" -Category "SystemJunk"
                    }
                }
            } catch {
                Write-Log -Level "WARNING" -Category "System" -Message "Failed processing '$regPath': $($_.Exception.Message)" -Category "SystemJunk"
            }
        }

        try {
            $muiPath = "HKCU:\SOFTWARE\Classes\Local Settings\MuiCache"
            if (Test-Path $muiPath) {
                if (-not $WhatIf) {
                    Remove-Item -Path $muiPath -Recurse -Force -ErrorAction Stop
                    $result.ItemsRemoved++
                    Write-Log -Level "SUCCESS" -Category "SystemJunk" -Message "Cleared MUI cache"
                }
            }
        } catch {
            Write-Log -Level "WARNING" -Category "System" -Message "Failed to clear MUI cache: $($_.Exception.Message)" -Category "SystemJunk"
        }

        $result.Success = $true
        $result.Message = "Orphaned registry cleanup: $($result.ItemsRemoved) entries removed"
    } catch {
        $result.Message = "Error clearing orphaned registry: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "System" -Message $result.Message -Category "SystemJunk"
    }

    return $result
}

function global:Clear-ObsoleteDrivers {
    <#
    .SYNOPSIS
        Removes obsolete driver packages from the DriverStore.
    #>
    param(
        [string[]]$Paths = @(),
        [switch]$WhatIf
    )

    $result = @{
        Success       = $false
        Message       = ""
        BytesRecovered = 0
        ItemsRemoved  = 0
    }

    try {
        $driverStorePath = "$env:SystemRoot\System32\DriverStore\FileRepository"

        if (Test-Path $driverStorePath) {
            try {
                $pnputilAvailable = Get-Command "pnputil" -ErrorAction SilentlyContinue
                if ($pnputilAvailable) {
                    $driversOutput = pnputil /enum-drivers 2>&1
                    $driverMatches = [regex]::Matches($driversOutput, "Published Name:\s+(oem\d+\.inf)")
                    foreach ($match in $driverMatches) {
                        $driverName = $match.Groups[1].Value
                        try {
                            if ($WhatIf) {
                                Write-Log -Level "INFO" -Category "System" -Message "Would remove driver: $driverName" -Category "SystemJunk"
                            } else {
                                $deleteResult = pnputil /delete-driver $driverName /force 2>&1
                                if ($LASTEXITCODE -eq 0) {
                                    $result.ItemsRemoved++
                                    Write-Log -Level "SUCCESS" -Category "SystemJunk" -Message "Removed obsolete driver: $driverName"
                                }
                            }
                        } catch {
                            Write-Log -Level "WARNING" -Category "System" -Message "Failed to remove driver '$driverName': $($_.Exception.Message)" -Category "SystemJunk"
                        }
                    }
                }
            } catch {
                Write-Log -Level "WARNING" -Category "System" -Message "Failed driver enumeration: $($_.Exception.Message)" -Category "SystemJunk"
            }

            # Check for old driver folders in FileRepository
            try {
                $driverDirs = Get-ChildItem -Path $driverStorePath -Directory -ErrorAction SilentlyContinue
                foreach ($dir in $driverDirs) {
                    try {
                        $dirAge = (Get-Date) - $dir.CreationTime
                        if ($dirAge.Days -gt 180) {
                            $size = (Get-ChildItem -Path $dir.FullName -Recurse -Force -ErrorAction SilentlyContinue |
                                     Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                            if ($WhatIf) {
                                Write-Log -Level "INFO" -Category "System" -Message "Would remove old driver: $($dir.Name) ($([math]::Round(($size / 1MB), 2)) MB)" -Category "SystemJunk"
                            } else {
                                Remove-Item -Path $dir.FullName -Recurse -Force -ErrorAction Stop
                                $result.BytesRecovered += if ($size) { $size } else { 0 }
                                $result.ItemsRemoved++
                                Write-Log -Level "SUCCESS" -Category "SystemJunk" -Message "Removed old driver directory: $($dir.Name)"
                            }
                        }
                    } catch {
                        Write-Log -Level "WARNING" -Category "System" -Message "Failed processing driver dir '$($dir.Name)': $($_.Exception.Message)" -Category "SystemJunk"
                    }
                }
            } catch {
                Write-Log -Level "WARNING" -Category "System" -Message "Failed to enumerate driver store: $($_.Exception.Message)" -Category "SystemJunk"
            }
        }

        $result.Success = $true
        $result.Message = "Obsolete drivers cleanup: $($result.ItemsRemoved) items removed, $([math]::Round(($result.BytesRecovered / 1MB), 2)) MB"
    } catch {
        $result.Message = "Error clearing obsolete drivers: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "System" -Message $result.Message -Category "SystemJunk"
    }

    return $result
}

function global:Clear-TempJunk {
    <#
    .SYNOPSIS
        Clears temporary junk files from various system temp locations.
    #>
    param(
        [string[]]$Paths = @(),
        [switch]$WhatIf
    )

    $result = @{
        Success       = $false
        Message       = ""
        BytesRecovered = 0
        ItemsRemoved  = 0
    }

    try {
        $tempPaths = @(
            $env:TEMP,
            "$env:SystemRoot\Temp",
            "$env:LOCALAPPDATA\Temp",
            "$env:SystemDrive\Temp"
        )

        foreach ($p in $Paths) {
            if ($p -match "\*") {
                $resolved = Resolve-Path -Path $p -ErrorAction SilentlyContinue
                if ($resolved) { $tempPaths += $resolved.Path }
            } else {
                $tempPaths += $p
            }
        }

        foreach ($path in $tempPaths) {
            if (-not (Test-Path $path)) { continue }
            try {
                $items = Get-ChildItem -Path $path -Force -ErrorAction SilentlyContinue
                foreach ($item in $items) {
                    try {
                        if ($item.PSIsContainer) {
                            $size = (Get-ChildItem -Path $item.FullName -Recurse -Force -ErrorAction SilentlyContinue |
                                     Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                            if (-not $WhatIf) {
                                Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop
                                $result.BytesRecovered += if ($size) { $size } else { 0 }
                            }
                        } else {
                            $size = $item.Length
                            if (-not $WhatIf) {
                                Remove-Item -Path $item.FullName -Force -ErrorAction Stop
                                $result.BytesRecovered += $size
                            }
                        }
                        $result.ItemsRemoved++
                    } catch {
                        # File may be locked, skip
                    }
                }
                if ($WhatIf) {
                    Write-Log -Level "INFO" -Category "System" -Message "Would clean $path" -Category "SystemJunk"
                } else {
                    Write-Log -Level "SUCCESS" -Category "SystemJunk" -Message "Cleaned temp: $path"
                }
            } catch {
                Write-Log -Level "WARNING" -Category "System" -Message "Failed to clean temp '$path': $($_.Exception.Message)" -Category "SystemJunk"
            }
        }

        $result.Success = $true
        $result.Message = "Temp junk cleared: $($result.ItemsRemoved) items, $([math]::Round(($result.BytesRecovered / 1MB), 2)) MB"
    } catch {
        $result.Message = "Error clearing temp junk: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "System" -Message $result.Message -Category "SystemJunk"
    }

    return $result
}

function global:Clear-WindowsErrorReportsJunk {
    <#
    .SYNOPSIS
        Clears Windows Error Reporting (WER) archives and queue files.
    #>
    param(
        [string[]]$Paths = @(),
        [switch]$WhatIf
    )

    $result = @{
        Success       = $false
        Message       = ""
        BytesRecovered = 0
        ItemsRemoved  = 0
    }

    try {
        $werPaths = @(
            "$env:ProgramData\Microsoft\Windows\WER",
            "$env:LOCALAPPDATA\Microsoft\Windows\WER",
            "$env:LOCALAPPDATA\CrashDumps"
        )

        foreach ($p in $Paths) {
            if ($p -match "\*") {
                $resolved = Resolve-Path -Path $p -ErrorAction SilentlyContinue
                if ($resolved) { $werPaths += $resolved.Path }
            } else {
                $werPaths += $p
            }
        }

        foreach ($path in $werPaths) {
            if (Test-Path $path) {
                try {
                    $size = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                             Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                    $count = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                              Measure-Object -ErrorAction SilentlyContinue).Count
                    if ($WhatIf) {
                        Write-Log -Level "INFO" -Category "System" -Message "Would remove $path ($count items, $([math]::Round(($size / 1MB), 2)) MB)" -Category "SystemJunk"
                    } else {
                        Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction Stop
                        $result.BytesRecovered += if ($size) { $size } else { 0 }
                        $result.ItemsRemoved += if ($count) { $count } else { 0 }
                        Write-Log -Level "SUCCESS" -Category "SystemJunk" -Message "Cleared WER data: $path"
                    }
                } catch {
                    Write-Log -Level "WARNING" -Category "System" -Message "Failed to clear WER '$path': $($_.Exception.Message)" -Category "SystemJunk"
                }
            }
        }

        $result.Success = $true
        $result.Message = "Windows Error Reports cleared: $([math]::Round(($result.BytesRecovered / 1MB), 2)) MB"
    } catch {
        $result.Message = "Error clearing WER: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "System" -Message $result.Message -Category "SystemJunk"
    }

    return $result
}

function global:Clear-AllSystemJunk {
    <#
    .SYNOPSIS
        Runs all system junk cleaning functions.
    #>
    param(
        [switch]$WhatIf
    )

    $results = @{
        Success       = $false
        Message       = ""
        TotalBytesRecovered = 0
        TotalItemsRemoved = 0
        Operations    = @()
    }

    $operations = @(
        @{ Name = "Orphaned Registry";     Function = "Clear-OrphanedRegistry" },
        @{ Name = "Obsolete Drivers";      Function = "Clear-ObsoleteDrivers" },
        @{ Name = "Temp Junk";             Function = "Clear-TempJunk" },
        @{ Name = "Windows Error Reports"; Function = "Clear-WindowsErrorReportsJunk" }
    )

    Write-Log -Level "INFO" -Category "System" -Message "Starting all system junk cleanup" -Category "SystemJunk"

    foreach ($op in $operations) {
        try {
            Write-Log -Level "INFO" -Category "System" -Message "Cleaning $($op.Name)..." -Category "SystemJunk"
            if ($WhatIf) {
                $result = & $op.Function -WhatIf
            } else {
                $result = & $op.Function
            }
            $results.Operations += @{
                Name           = $op.Name
                Success        = $result.Success
                BytesRecovered = $result.BytesRecovered
                Message        = $result.Message
            }
            $results.TotalBytesRecovered += $result.BytesRecovered
            $results.TotalItemsRemoved += $result.ItemsRemoved
        } catch {
            Write-Log -Level "ERROR" -Category "System" -Message "Error in $($op.Name): $($_.Exception.Message)" -Category "SystemJunk"
            $results.Operations += @{
                Name           = $op.Name
                Success        = $false
                BytesRecovered = 0
                Message        = "Error: $($_.Exception.Message)"
            }
        }
    }

    $results.Success = $true
    $results.Message = "All system junk cleared: $([math]::Round(($results.TotalBytesRecovered / 1MB), 2)) MB recovered"
    Write-Log -Level "SUCCESS" -Category "SystemJunk" -Message $results.Message

    return $results
}
