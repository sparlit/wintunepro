#Requires -Version 5.1
<#
.SYNOPSIS
    System Files Cleaning Module
.DESCRIPTION
    Functions for removing hibernation files, memory dumps, and other
    large system-generated files.
#>

function global:Clear-HibernationFileDeep {
    <#
    .SYNOPSIS
        Disables hibernation and removes hiberfil.sys to reclaim disk space.
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
        $hiberfilPath = "$env:SystemDrive\hiberfil.sys"

        if (Test-Path $hiberfilPath) {
            try {
                $size = (Get-Item -Path $hiberfilPath -Force -ErrorAction SilentlyContinue).Length
                if ($WhatIf) {
                    Write-Log -Level "INFO" -Category "System" -Message "Would disable hibernation and remove hiberfil.sys ($([math]::Round(($size / 1GB), 2)) GB)" -Category "SystemFiles"
                } else {
                    $process = Start-Process -FilePath "powercfg.exe" -ArgumentList "/hibernate off" -WindowStyle Hidden -Wait -PassThru -ErrorAction Stop
                    if ($process.ExitCode -eq 0) {
                        $result.BytesRecovered += $size
                        $result.ItemsRemoved++
                        Write-Log -Level "SUCCESS" -Category "SystemFiles" -Message "Hibernation disabled, hiberfil.sys removed ($([math]::Round(($size / 1GB), 2)) GB)"
                    } else {
                        Write-Log -Level "WARNING" -Category "System" -Message "powercfg returned exit code $($process.ExitCode)" -Category "SystemFiles"
                    }
                }
            } catch {
                Write-Log -Level "WARNING" -Category "System" -Message "Failed to disable hibernation: $($_.Exception.Message)" -Category "SystemFiles"
            }
        } else {
            Write-Log -Level "INFO" -Category "System" -Message "Hibernation file not found (may already be disabled)" -Category "SystemFiles"
        }

        $result.Success = $true
        if ($result.BytesRecovered -eq 0) {
            $result.Message = "Hibernation file was not present or already disabled"
        } else {
            $result.Message = "Hibernation file cleared: $([math]::Round(($result.BytesRecovered / 1GB), 2)) GB recovered"
        }
    } catch {
        $result.Message = "Error clearing hibernation file: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "System" -Message $result.Message -Category "SystemFiles"
    }

    return $result
}

function global:Clear-MemoryDumpFilesDeep {
    <#
    .SYNOPSIS
        Removes Windows memory dump files (MEMORY.DMP, minidumps).
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
        $dumpPaths = @(
            "$env:SystemRoot\MEMORY.DMP",
            "$env:SystemRoot\Minidump",
            "$env:LOCALAPPDATA\CrashDumps"
        )

        foreach ($p in $Paths) {
            if ($p -match "\*") {
                $resolved = Resolve-Path -Path $p -ErrorAction SilentlyContinue
                if ($resolved) { $dumpPaths += $resolved.Path }
            } else {
                $dumpPaths += $p
            }
        }

        foreach ($path in $dumpPaths) {
            if (Test-Path $path) {
                try {
                    if ((Get-Item -Path $path -Force -ErrorAction SilentlyContinue).PSIsContainer) {
                        $size = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                                 Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                        $count = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                                  Measure-Object -ErrorAction SilentlyContinue).Count
                        if ($WhatIf) {
                            Write-Log -Level "INFO" -Category "System" -Message "Would remove $path ($count files, $([math]::Round(($size / 1MB), 2)) MB)" -Category "SystemFiles"
                        } else {
                            Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction Stop
                            $result.BytesRecovered += if ($size) { $size } else { 0 }
                            $result.ItemsRemoved += if ($count) { $count } else { 0 }
                            Write-Log -Level "SUCCESS" -Category "SystemFiles" -Message "Cleared dump directory: $path"
                        }
                    } else {
                        $size = (Get-Item -Path $path -Force -ErrorAction SilentlyContinue).Length
                        if ($WhatIf) {
                            Write-Log -Level "INFO" -Category "System" -Message "Would remove $path ($([math]::Round(($size / 1MB), 2)) MB)" -Category "SystemFiles"
                        } else {
                            Remove-Item -Path $path -Force -ErrorAction Stop
                            $result.BytesRecovered += if ($size) { $size } else { 0 }
                            $result.ItemsRemoved++
                            Write-Log -Level "SUCCESS" -Category "SystemFiles" -Message "Removed dump file: $path"
                        }
                    }
                } catch {
                    Write-Log -Level "WARNING" -Category "System" -Message "Failed to clear dump '$path': $($_.Exception.Message)" -Category "SystemFiles"
                }
            }
        }

        $result.Success = $true
        $result.Message = "Memory dump files cleared: $([math]::Round(($result.BytesRecovered / 1GB), 2)) GB"
    } catch {
        $result.Message = "Error clearing memory dumps: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "System" -Message $result.Message -Category "SystemFiles"
    }

    return $result
}

function global:Clear-SystemFiles {
    <#
    .SYNOPSIS
        Clears various system-generated files including old Windows installations
        and delivery optimization cache.
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
        $systemPaths = @(
            "$env:SystemDrive\Windows.old",
            "$env:SystemRoot\SoftwareDistribution\DeliveryOptimization",
            "$env:LOCALAPPDATA\Microsoft\Windows\DeliveryOptimization",
            "$env:SystemRoot\Logs",
            "$env:SystemRoot\Temp"
        )

        foreach ($p in $Paths) {
            if ($p -match "\*") {
                $resolved = Resolve-Path -Path $p -ErrorAction SilentlyContinue
                if ($resolved) { $systemPaths += $resolved.Path }
            } else {
                $systemPaths += $p
            }
        }

        foreach ($path in $systemPaths) {
            if (Test-Path $path) {
                try {
                    $size = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                             Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                    $count = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                              Measure-Object -ErrorAction SilentlyContinue).Count
                    if ($WhatIf) {
                        Write-Log -Level "INFO" -Category "System" -Message "Would remove $path ($count items, $([math]::Round(($size / 1MB), 2)) MB)" -Category "SystemFiles"
                    } else {
                        Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction Stop
                        $result.BytesRecovered += if ($size) { $size } else { 0 }
                        $result.ItemsRemoved += if ($count) { $count } else { 0 }
                        Write-Log -Level "SUCCESS" -Category "SystemFiles" -Message "Cleared system files: $path"
                    }
                } catch {
                    Write-Log -Level "WARNING" -Category "System" -Message "Failed to clear system files '$path': $($_.Exception.Message)" -Category "SystemFiles"
                }
            }
        }

        $result.Success = $true
        $result.Message = "System files cleared: $($result.ItemsRemoved) items, $([math]::Round(($result.BytesRecovered / 1GB), 2)) GB"
    } catch {
        $result.Message = "Error clearing system files: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "System" -Message $result.Message -Category "SystemFiles"
    }

    return $result
}

function global:Clear-AllSystemFiles {
    <#
    .SYNOPSIS
        Runs all system file cleaning functions.
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
        @{ Name = "Hibernation File"; Function = "Clear-HibernationFileDeep" },
        @{ Name = "Memory Dumps";     Function = "Clear-MemoryDumpFilesDeep" },
        @{ Name = "System Files";     Function = "Clear-SystemFiles" }
    )

    Write-Log -Level "INFO" -Category "System" -Message "Starting all system file cleanup" -Category "SystemFiles"

    foreach ($op in $operations) {
        try {
            Write-Log -Level "INFO" -Category "System" -Message "Cleaning $($op.Name)..." -Category "SystemFiles"
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
            Write-Log -Level "ERROR" -Category "System" -Message "Error in $($op.Name): $($_.Exception.Message)" -Category "SystemFiles"
            $results.Operations += @{
                Name           = $op.Name
                Success        = $false
                BytesRecovered = 0
                Message        = "Error: $($_.Exception.Message)"
            }
        }
    }

    $results.Success = $true
    $results.Message = "All system files cleared: $([math]::Round(($results.TotalBytesRecovered / 1GB), 2)) GB recovered"
    Write-Log -Level "SUCCESS" -Category "SystemFiles" -Message $results.Message

    return $results
}
