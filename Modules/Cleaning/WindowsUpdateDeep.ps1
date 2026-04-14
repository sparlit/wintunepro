#Requires -Version 5.1
<#
.SYNOPSIS
    Windows Update Deep Cleaning Module
.DESCRIPTION
    Functions for deep cleaning Windows Update caches, logs, and temp files.
#>

function global:Clear-WindowsUpdateCacheDeep {
    <#
    .SYNOPSIS
        Clears the Windows Update download cache and DataStore.
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
        $wuPaths = @(
            "$env:SystemRoot\SoftwareDistribution\Download",
            "$env:SystemRoot\SoftwareDistribution\DataStore"
        )

        foreach ($p in $Paths) {
            if ($p -match "\*") {
                $resolved = Resolve-Path -Path $p -ErrorAction SilentlyContinue
                if ($resolved) { $wuPaths += $resolved.Path }
            } else {
                $wuPaths += $p
            }
        }

        # Stop Windows Update service first
        try {
            $wuService = Get-Service -Name "wuauserv" -ErrorAction SilentlyContinue
            if ($wuService -and $wuService.Status -eq "Running") {
                if (-not $WhatIf) {
                    Stop-Service -Name "wuauserv" -Force -ErrorAction Stop
                    Start-Sleep -Seconds 2
                    Write-Log -Level "INFO" -Category "System" -Message "Stopped Windows Update service" -Category "WindowsUpdate"
                }
            }
        } catch {
            Write-Log -Level "WARNING" -Category "System" -Message "Could not stop wuauserv: $($_.Exception.Message)" -Category "WindowsUpdate"
        }

        try {
            $bitsService = Get-Service -Name "BITS" -ErrorAction SilentlyContinue
            if ($bitsService -and $bitsService.Status -eq "Running") {
                if (-not $WhatIf) {
                    Stop-Service -Name "BITS" -Force -ErrorAction Stop
                    Start-Sleep -Seconds 2
                    Write-Log -Level "INFO" -Category "System" -Message "Stopped BITS service" -Category "WindowsUpdate"
                }
            }
        } catch {
            Write-Log -Level "WARNING" -Category "System" -Message "Could not stop BITS: $($_.Exception.Message)" -Category "WindowsUpdate"
        }

        foreach ($path in $wuPaths) {
            if (Test-Path $path) {
                try {
                    $size = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                             Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                    $count = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                              Measure-Object -ErrorAction SilentlyContinue).Count
                    if ($WhatIf) {
                        Write-Log -Level "INFO" -Category "System" -Message "Would remove $path ($count items, $([math]::Round(($size / 1MB), 2)) MB)" -Category "WindowsUpdate"
                    } else {
                        Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction Stop
                        $result.BytesRecovered += if ($size) { $size } else { 0 }
                        $result.ItemsRemoved += if ($count) { $count } else { 0 }
                        Write-Log -Level "SUCCESS" -Category "WindowsUpdate" -Message "Cleared WU cache: $path"
                    }
                } catch {
                    Write-Log -Level "WARNING" -Category "System" -Message "Failed to clear WU cache '$path': $($_.Exception.Message)" -Category "WindowsUpdate"
                }
            }
        }

        if (-not $WhatIf) {
            try {
                Start-Service -Name "BITS" -ErrorAction SilentlyContinue
                Start-Service -Name "wuauserv" -ErrorAction SilentlyContinue
                Write-Log -Level "INFO" -Category "System" -Message "Restarted WU and BITS services" -Category "WindowsUpdate"
            } catch {
                Write-Log -Level "WARNING" -Category "System" -Message "Failed to restart WU services: $($_.Exception.Message)" -Category "WindowsUpdate"
            }
        }

        $result.Success = $true
        $result.Message = "Windows Update cache cleared: $($result.ItemsRemoved) items, $([math]::Round(($result.BytesRecovered / 1MB), 2)) MB"
    } catch {
        $result.Message = "Error clearing WU cache: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "System" -Message $result.Message -Category "WindowsUpdate"
    }

    return $result
}

function global:Clear-WindowsUpdateLogsDeep {
    <#
    .SYNOPSIS
        Clears Windows Update log files and ETL traces.
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
        $logPaths = @(
            "$env:SystemRoot\WindowsUpdate.log",
            "$env:SystemRoot\Logs\WindowsUpdate",
            "$env:LOCALAPPDATA\Microsoft\Windows\WindowsUpdate"
        )

        foreach ($p in $Paths) {
            if ($p -match "\*") {
                $resolved = Resolve-Path -Path $p -ErrorAction SilentlyContinue
                if ($resolved) { $logPaths += $resolved.Path }
            } else {
                $logPaths += $p
            }
        }

        foreach ($path in $logPaths) {
            if (Test-Path $path) {
                try {
                    if ((Get-Item -Path $path -Force -ErrorAction SilentlyContinue).PSIsContainer) {
                        $size = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                                 Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                        $count = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                                  Measure-Object -ErrorAction SilentlyContinue).Count
                        if ($WhatIf) {
                            Write-Log -Level "INFO" -Category "System" -Message "Would remove $path ($count items)" -Category "WindowsUpdate"
                        } else {
                            Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction Stop
                            $result.BytesRecovered += if ($size) { $size } else { 0 }
                            $result.ItemsRemoved += if ($count) { $count } else { 0 }
                            Write-Log -Level "SUCCESS" -Category "WindowsUpdate" -Message "Cleared WU logs: $path"
                        }
                    } else {
                        $size = (Get-Item -Path $path -Force -ErrorAction SilentlyContinue).Length
                        if ($WhatIf) {
                            Write-Log -Level "INFO" -Category "System" -Message "Would remove $path ($([math]::Round(($size / 1MB), 2)) MB)" -Category "WindowsUpdate"
                        } else {
                            Remove-Item -Path $path -Force -ErrorAction Stop
                            $result.BytesRecovered += if ($size) { $size } else { 0 }
                            $result.ItemsRemoved++
                            Write-Log -Level "SUCCESS" -Category "WindowsUpdate" -Message "Removed WU log: $path"
                        }
                    }
                } catch {
                    Write-Log -Level "WARNING" -Category "System" -Message "Failed to clear WU logs '$path': $($_.Exception.Message)" -Category "WindowsUpdate"
                }
            }
        }

        $result.Success = $true
        $result.Message = "Windows Update logs cleared: $([math]::Round(($result.BytesRecovered / 1MB), 2)) MB"
    } catch {
        $result.Message = "Error clearing WU logs: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "System" -Message $result.Message -Category "WindowsUpdate"
    }

    return $result
}

function global:Clear-WindowsUpdateTemp {
    <#
    .SYNOPSIS
        Clears Windows Update temporary files and pending operations.
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
            "$env:SystemRoot\SoftwareDistribution\PostRebootEventCache",
            "$env:SystemRoot\SoftwareDistribution\Sls",
            "$env:SystemRoot\System32\catroot2"
        )

        foreach ($p in $Paths) {
            if ($p -match "\*") {
                $resolved = Resolve-Path -Path $p -ErrorAction SilentlyContinue
                if ($resolved) { $tempPaths += $resolved.Path }
            } else {
                $tempPaths += $p
            }
        }

        # Stop crypto service for catroot2
        try {
            $cryptSvc = Get-Service -Name "cryptsvc" -ErrorAction SilentlyContinue
            if ($cryptSvc -and $cryptSvc.Status -eq "Running") {
                if (-not $WhatIf) {
                    Stop-Service -Name "cryptsvc" -Force -ErrorAction Stop
                    Start-Sleep -Seconds 2
                    Write-Log -Level "INFO" -Category "System" -Message "Stopped Cryptographic Services" -Category "WindowsUpdate"
                }
            }
        } catch {
            Write-Log -Level "WARNING" -Category "System" -Message "Could not stop cryptsvc: $($_.Exception.Message)" -Category "WindowsUpdate"
        }

        foreach ($path in $tempPaths) {
            if (Test-Path $path) {
                try {
                    $size = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                             Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                    if ($WhatIf) {
                        Write-Log -Level "INFO" -Category "System" -Message "Would remove $path" -Category "WindowsUpdate"
                    } else {
                        Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction Stop
                        $result.BytesRecovered += if ($size) { $size } else { 0 }
                        $result.ItemsRemoved++
                        Write-Log -Level "SUCCESS" -Category "WindowsUpdate" -Message "Cleared WU temp: $path"
                    }
                } catch {
                    Write-Log -Level "WARNING" -Category "System" -Message "Failed to clear WU temp '$path': $($_.Exception.Message)" -Category "WindowsUpdate"
                }
            }
        }

        if (-not $WhatIf) {
            try {
                Start-Service -Name "cryptsvc" -ErrorAction SilentlyContinue
                Write-Log -Level "INFO" -Category "System" -Message "Restarted Cryptographic Services" -Category "WindowsUpdate"
            } catch {
                Write-Log -Level "WARNING" -Category "System" -Message "Failed to restart cryptsvc: $($_.Exception.Message)" -Category "WindowsUpdate"
            }
        }

        $result.Success = $true
        $result.Message = "Windows Update temp cleared: $([math]::Round(($result.BytesRecovered / 1MB), 2)) MB"
    } catch {
        $result.Message = "Error clearing WU temp: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "System" -Message $result.Message -Category "WindowsUpdate"
    }

    return $result
}

function global:Clear-AllWUCaches {
    <#
    .SYNOPSIS
        Runs all Windows Update cache cleaning functions.
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
        @{ Name = "WU Cache"; Function = "Clear-WindowsUpdateCacheDeep" },
        @{ Name = "WU Logs";  Function = "Clear-WindowsUpdateLogsDeep" },
        @{ Name = "WU Temp";  Function = "Clear-WindowsUpdateTemp" }
    )

    Write-Log -Level "INFO" -Category "System" -Message "Starting all Windows Update cache cleanup" -Category "WindowsUpdate"

    foreach ($op in $operations) {
        try {
            Write-Log -Level "INFO" -Category "System" -Message "Cleaning $($op.Name)..." -Category "WindowsUpdate"
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
            Write-Log -Level "ERROR" -Category "System" -Message "Error in $($op.Name): $($_.Exception.Message)" -Category "WindowsUpdate"
            $results.Operations += @{
                Name           = $op.Name
                Success        = $false
                BytesRecovered = 0
                Message        = "Error: $($_.Exception.Message)"
            }
        }
    }

    $results.Success = $true
    $results.Message = "All WU caches cleared: $([math]::Round(($results.TotalBytesRecovered / 1MB), 2)) MB recovered"
    Write-Log -Level "SUCCESS" -Category "WindowsUpdate" -Message $results.Message

    return $results
}
