#Requires -Version 5.1
<#
.SYNOPSIS
    WinTune Pro DefenderCleanup Module - Windows Defender cleanup
.DESCRIPTION
    Windows Defender log, cache, and quarantine file cleanup
#>

function global:Clear-DefenderScanHistory {
    <#
    .SYNOPSIS
        Clears Windows Defender scan history logs.
    #>
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{
        Success       = $true
        SpaceRecovered = 0
        ItemsCleaned  = 0
        Error         = $null
    }

    $scanHistoryPaths = @(
        "$env:ProgramData\Microsoft\Windows Defender\Scans\History"
        "$env:ProgramData\Microsoft\Windows Defender\Scans\Results"
    )

    Write-Log -Level "INFO" -Category "DefenderCleanup" -Message "Clearing Defender scan history..."

    foreach ($path in $scanHistoryPaths) {
        if (-not (Test-Path $path)) {
            Write-Log -Level "INFO" -Category "DefenderCleanup" -Message "Path not found: $path - skipping"
            continue
        }

        try {
            $items = Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue
            $size = ($items | Measure-Object -Property Length -Sum).Sum
            if (-not $size) { $size = 0 }

            if ($Preview) {
                Write-Log -Level "INFO" -Category "DefenderCleanup" -Message "[Preview] Would clear scan history at $path - $(Format-FileSize $size)"
            } elseif ($TestMode) {
                Write-Log -Level "INFO" -Category "DefenderCleanup" -Message "[TestMode] Scan history at $path flagged"
            } else {
                Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
                Write-Log -Level "SUCCESS" -Category "DefenderCleanup" -Message "Cleared scan history at $path"
            }

            $result.SpaceRecovered += $size
            $result.ItemsCleaned += ($items | Measure-Object).Count
        } catch {
            Write-Log -Level "WARNING" -Category "DefenderCleanup" -Message "Error clearing scan history at $path : $($_.Exception.Message)"
        }
    }

    Write-Log -Level "SUCCESS" -Category "DefenderCleanup" -Message "Scan history cleanup complete: $(Format-FileSize $result.SpaceRecovered) recovered"
    return $result
}

function global:Clear-DefenderQuarantineFiles {
    <#
    .SYNOPSIS
        Clears quarantined files older than N days.
    #>
    param(
        [int]$DaysOld = 30,
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{
        Success       = $true
        SpaceRecovered = 0
        ItemsCleaned  = 0
        Error         = $null
    }

    $quarantinePath = "$env:ProgramData\Microsoft\Windows Defender\Quarantine"

    if (-not (Test-Path $quarantinePath)) {
        Write-Log -Level "INFO" -Category "DefenderCleanup" -Message "Quarantine folder not found - skipping"
        return $result
    }

    Write-Log -Level "INFO" -Category "DefenderCleanup" -Message "Clearing Defender quarantine files older than $DaysOld days..."

    try {
        $cutoffDate = (Get-Date).AddDays(-$DaysOld)
        $items = Get-ChildItem -Path $quarantinePath -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { -not $_.PSIsContainer -and $_.LastWriteTime -lt $cutoffDate }

        $size = ($items | Measure-Object -Property Length -Sum).Sum
        if (-not $size) { $size = 0 }

        if ($Preview) {
            Write-Log -Level "INFO" -Category "DefenderCleanup" -Message "[Preview] Would clear $($items.Count) quarantine files - $(Format-FileSize $size)"
        } elseif ($TestMode) {
            Write-Log -Level "INFO" -Category "DefenderCleanup" -Message "[TestMode] $($items.Count) quarantine files flagged"
        } else {
            $items | Remove-Item -Force -ErrorAction SilentlyContinue
            Write-Log -Level "SUCCESS" -Category "DefenderCleanup" -Message "Cleared $($items.Count) quarantine files"
        }

        $result.SpaceRecovered = $size
        $result.ItemsCleaned = ($items | Measure-Object).Count
    } catch {
        Write-Log -Level "ERROR" -Category "DefenderCleanup" -Message "Error clearing quarantine: $($_.Exception.Message)"
        $result.Success = $false
        $result.Error = $_.Exception.Message
    }

    Write-Log -Level "SUCCESS" -Category "DefenderCleanup" -Message "Quarantine cleanup complete: $(Format-FileSize $result.SpaceRecovered) recovered"
    return $result
}

function global:Clear-DefenderETLLogs {
    <#
    .SYNOPSIS
        Clears Defender ETL trace logs.
    #>
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{
        Success       = $true
        SpaceRecovered = 0
        ItemsCleaned  = 0
        Error         = $null
    }

    $supportPath = "$env:ProgramData\Microsoft\Windows Defender\Support"

    if (-not (Test-Path $supportPath)) {
        Write-Log -Level "INFO" -Category "DefenderCleanup" -Message "Defender Support folder not found - skipping"
        return $result
    }

    Write-Log -Level "INFO" -Category "DefenderCleanup" -Message "Clearing Defender ETL logs..."

    try {
        $items = Get-ChildItem -Path $supportPath -Filter "*.etl" -Force -ErrorAction SilentlyContinue
        $size = ($items | Measure-Object -Property Length -Sum).Sum
        if (-not $size) { $size = 0 }

        if ($Preview) {
            Write-Log -Level "INFO" -Category "DefenderCleanup" -Message "[Preview] Would clear $($items.Count) ETL logs - $(Format-FileSize $size)"
        } elseif ($TestMode) {
            Write-Log -Level "INFO" -Category "DefenderCleanup" -Message "[TestMode] $($items.Count) ETL logs flagged"
        } else {
            $items | Remove-Item -Force -ErrorAction SilentlyContinue
            Write-Log -Level "SUCCESS" -Category "DefenderCleanup" -Message "Cleared $($items.Count) ETL logs"
        }

        $result.SpaceRecovered = $size
        $result.ItemsCleaned = ($items | Measure-Object).Count
    } catch {
        Write-Log -Level "WARNING" -Category "DefenderCleanup" -Message "Error clearing ETL logs: $($_.Exception.Message)"
    }

    Write-Log -Level "SUCCESS" -Category "DefenderCleanup" -Message "ETL log cleanup complete: $(Format-FileSize $result.SpaceRecovered) recovered"
    return $result
}

function global:Clear-DefenderOperationalLogs {
    <#
    .SYNOPSIS
        Clears Defender operational event logs.
    #>
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{
        Success       = $true
        SpaceRecovered = 0
        ItemsCleaned  = 0
        Error         = $null
    }

    Write-Log -Level "INFO" -Category "DefenderCleanup" -Message "Clearing Defender operational logs..."

    $logNames = @("Microsoft-Windows-Windows Defender/Operational", "Microsoft-Windows-Windows Defender/WHC")

    foreach ($logName in $logNames) {
        try {
            if ($Preview) {
                Write-Log -Level "INFO" -Category "DefenderCleanup" -Message "[Preview] Would clear event log: $logName"
            } elseif ($TestMode) {
                Write-Log -Level "INFO" -Category "DefenderCleanup" -Message "[TestMode] Event log $logName flagged"
            } else {
                wevtutil cl "$logName" 2>$null
                Write-Log -Level "SUCCESS" -Category "DefenderCleanup" -Message "Cleared event log: $logName"
            }
            $result.ItemsCleaned++
        } catch {
            Write-Log -Level "WARNING" -Category "DefenderCleanup" -Message "Error clearing log $logName : $($_.Exception.Message)"
        }
    }

    Write-Log -Level "SUCCESS" -Category "DefenderCleanup" -Message "Operational log cleanup complete"
    return $result
}

function global:Clear-DefenderMpCmdRunCache {
    <#
    .SYNOPSIS
        Clears MpCmdRun temp files and cache.
    #>
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{
        Success       = $true
        SpaceRecovered = 0
        ItemsCleaned  = 0
        Error         = $null
    }

    $mpCmdRunPaths = @(
        "$env:ProgramData\Microsoft\Windows Defender\Scans\mpenginedb.db"
        "$env:ProgramData\Microsoft\Windows Defender\Scans\History\Service\DetectionHistory"
    )

    Write-Log -Level "INFO" -Category "DefenderCleanup" -Message "Clearing Defender MpCmdRun cache..."

    foreach ($path in $mpCmdRunPaths) {
        if (-not (Test-Path $path)) { continue }

        try {
            if (Test-Path $path -PathType Container) {
                $items = Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                $size = ($items | Measure-Object -Property Length -Sum).Sum
                if (-not $size) { $size = 0 }

                if ($Preview) {
                    Write-Log -Level "INFO" -Category "DefenderCleanup" -Message "[Preview] Would clear MpCmdRun cache at $path - $(Format-FileSize $size)"
                } elseif ($TestMode) {
                    Write-Log -Level "INFO" -Category "DefenderCleanup" -Message "[TestMode] MpCmdRun cache at $path flagged"
                } else {
                    Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Log -Level "SUCCESS" -Category "DefenderCleanup" -Message "Cleared MpCmdRun cache at $path"
                }

                $result.SpaceRecovered += $size
                $result.ItemsCleaned += ($items | Measure-Object).Count
            } else {
                $size = (Get-Item -Path $path -Force -ErrorAction SilentlyContinue).Length
                if (-not $size) { $size = 0 }

                if ($Preview) {
                    Write-Log -Level "INFO" -Category "DefenderCleanup" -Message "[Preview] Would remove $path - $(Format-FileSize $size)"
                } elseif ($TestMode) {
                    Write-Log -Level "INFO" -Category "DefenderCleanup" -Message "[TestMode] File $path flagged"
                } else {
                    Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
                    Write-Log -Level "SUCCESS" -Category "DefenderCleanup" -Message "Removed $path"
                }

                $result.SpaceRecovered += $size
                $result.ItemsCleaned++
            }
        } catch {
            Write-Log -Level "WARNING" -Category "DefenderCleanup" -Message "Error clearing MpCmdRun cache at $path : $($_.Exception.Message)"
        }
    }

    Write-Log -Level "SUCCESS" -Category "DefenderCleanup" -Message "MpCmdRun cache cleanup complete: $(Format-FileSize $result.SpaceRecovered) recovered"
    return $result
}

function global:Clear-DefenderProtectionHistory {
    <#
    .SYNOPSIS
        Clears Defender protection history.
    #>
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{
        Success       = $true
        SpaceRecovered = 0
        ItemsCleaned  = 0
        Error         = $null
    }

    $historyPaths = @(
        "$env:ProgramData\Microsoft\Windows Defender\Scans\History\Service"
        "$env:ProgramData\Microsoft\Windows Defender\Scans\History\Results"
    )

    Write-Log -Level "INFO" -Category "DefenderCleanup" -Message "Clearing Defender protection history..."

    foreach ($path in $historyPaths) {
        if (-not (Test-Path $path)) { continue }

        try {
            $items = Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue
            $size = ($items | Measure-Object -Property Length -Sum).Sum
            if (-not $size) { $size = 0 }

            if ($Preview) {
                Write-Log -Level "INFO" -Category "DefenderCleanup" -Message "[Preview] Would clear protection history at $path - $(Format-FileSize $size)"
            } elseif ($TestMode) {
                Write-Log -Level "INFO" -Category "DefenderCleanup" -Message "[TestMode] Protection history at $path flagged"
            } else {
                Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
                Write-Log -Level "SUCCESS" -Category "DefenderCleanup" -Message "Cleared protection history at $path"
            }

            $result.SpaceRecovered += $size
            $result.ItemsCleaned += ($items | Measure-Object).Count
        } catch {
            Write-Log -Level "WARNING" -Category "DefenderCleanup" -Message "Error clearing protection history at $path : $($_.Exception.Message)"
        }
    }

    Write-Log -Level "SUCCESS" -Category "DefenderCleanup" -Message "Protection history cleanup complete: $(Format-FileSize $result.SpaceRecovered) recovered"
    return $result
}

function global:Clear-AllDefenderData {
    <#
    .SYNOPSIS
        Orchestrator that performs all Defender cleanup operations.
    #>
    param(
        [int]$QuarantineDays = 30,
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{
        Success       = $true
        SpaceRecovered = 0
        ItemsCleaned  = 0
        Error         = $null
        Operations    = @{}
    }

    if (-not $script:State.IsElevated) {
        Write-Log -Level "ERROR" -Category "DefenderCleanup" -Message "Admin privileges required for Defender cleanup"
        $result.Success = $false
        $result.Error = "Admin privileges required"
        return $result
    }

    Write-Log -Level "INFO" -Category "DefenderCleanup" -Message "Starting full Defender cleanup..."

    $result.Operations.ScanHistory = Clear-DefenderScanHistory -Preview:$Preview -TestMode:$TestMode
    $result.SpaceRecovered += $result.Operations.ScanHistory.SpaceRecovered
    $result.ItemsCleaned += $result.Operations.ScanHistory.ItemsCleaned

    $result.Operations.Quarantine = Clear-DefenderQuarantineFiles -DaysOld $QuarantineDays -Preview:$Preview -TestMode:$TestMode
    $result.SpaceRecovered += $result.Operations.Quarantine.SpaceRecovered
    $result.ItemsCleaned += $result.Operations.Quarantine.ItemsCleaned

    $result.Operations.ETLLogs = Clear-DefenderETLLogs -Preview:$Preview -TestMode:$TestMode
    $result.SpaceRecovered += $result.Operations.ETLLogs.SpaceRecovered
    $result.ItemsCleaned += $result.Operations.ETLLogs.ItemsCleaned

    $result.Operations.OperationalLogs = Clear-DefenderOperationalLogs -Preview:$Preview -TestMode:$TestMode
    $result.ItemsCleaned += $result.Operations.OperationalLogs.ItemsCleaned

    $result.Operations.MpCmdRunCache = Clear-DefenderMpCmdRunCache -Preview:$Preview -TestMode:$TestMode
    $result.SpaceRecovered += $result.Operations.MpCmdRunCache.SpaceRecovered
    $result.ItemsCleaned += $result.Operations.MpCmdRunCache.ItemsCleaned

    $result.Operations.ProtectionHistory = Clear-DefenderProtectionHistory -Preview:$Preview -TestMode:$TestMode
    $result.SpaceRecovered += $result.Operations.ProtectionHistory.SpaceRecovered
    $result.ItemsCleaned += $result.Operations.ProtectionHistory.ItemsCleaned

    Write-Log -Level "SUCCESS" -Category "DefenderCleanup" -Message "Full Defender cleanup complete: $(Format-FileSize $result.SpaceRecovered) recovered, $($result.ItemsCleaned) items"
    return $result
}

function global:Get-DefenderCleanupSize {
    <#
    .SYNOPSIS
        Calculates reclaimable space from Defender cleanup.
    #>

    $result = @{
        TotalReclaimable    = 0
        ScanHistory         = 0
        Quarantine          = 0
        ETLLogs             = 0
        MpCmdRunCache       = 0
        ProtectionHistory   = 0
    }

    $paths = @{
        ScanHistory       = @("$env:ProgramData\Microsoft\Windows Defender\Scans\History", "$env:ProgramData\Microsoft\Windows Defender\Scans\Results")
        Quarantine        = @("$env:ProgramData\Microsoft\Windows Defender\Quarantine")
        ETLLogs           = @("$env:ProgramData\Microsoft\Windows Defender\Support")
        MpCmdRunCache     = @("$env:ProgramData\Microsoft\Windows Defender\Scans\mpenginedb.db")
        ProtectionHistory = @("$env:ProgramData\Microsoft\Windows Defender\Scans\History\Service", "$env:ProgramData\Microsoft\Windows Defender\Scans\History\Results")
    }

    foreach ($category in $paths.Keys) {
        foreach ($path in $paths[$category]) {
            if (Test-Path $path) {
                if (Test-Path $path -PathType Container) {
                    $size = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                        Measure-Object -Property Length -Sum).Sum
                    if ($size) { $result.$category += $size }
                } else {
                    $size = (Get-Item -Path $path -Force -ErrorAction SilentlyContinue).Length
                    if ($size) { $result.$category += $size }
                }
            }
        }
    }

    $result.TotalReclaimable = $result.ScanHistory + $result.Quarantine + $result.ETLLogs + $result.MpCmdRunCache + $result.ProtectionHistory
    return $result
}
