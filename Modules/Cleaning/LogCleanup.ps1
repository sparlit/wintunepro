#Requires -Version 5.1
<#
.SYNOPSIS
    Log Cleanup Module
.DESCRIPTION
    Clearing of Windows Event Logs, System Logs, Application Logs, and Security Logs
    using wevtutil and direct file cleanup.
#>

function global:Clear-WindowsEventLogs {
    $result = @{ Success = $false; BytesRecovered = 0; Message = ""; ItemsCleaned = @() }
    try {
        $logNames = @("Application", "Security", "System", "Setup", "ForwardedEvents")
        foreach ($logName in $logNames) {
            try {
                $output = wevtutil el 2>&1
                if ($output -contains $logName) {
                    $beforeSize = (Get-Item "$env:SystemRoot\System32\winevt\Logs\${logName}.evtx" -EA SilentlyContinue).Length
                    wevtutil cl $logName 2>&1 | Out-Null
                    if ($beforeSize) {
                        $result.BytesRecovered += $beforeSize
                    }
                    $result.ItemsCleaned += $logName
                    Write-Log -Level "INFO" -Category "Cleaning" -Message "Cleared event log: $logName"
                }
            } catch {
                Write-Log -Level "WARNING" -Category "Cleaning" -Message "Failed to clear $logName : $($_.Exception.Message)"
            }
        }

        $winevtPath = "$env:SystemRoot\System32\winevt\Logs"
        if (Test-Path $winevtPath) {
            try {
                $oldLogs = Get-ChildItem "$winevtPath\*.evtx" -EA SilentlyContinue |
                    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) }
                foreach ($log in $oldLogs) {
                    $sz = $log.Length
                    try {
                        Remove-Item $log.FullName -Force -EA SilentlyContinue
                        $result.BytesRecovered += $sz
                    } catch {
                        Write-Log -Level "WARNING" -Category "Cleaning" -Message "Old log delete error : $log : $($_.Exception.Message)"
                    }
                }
            } catch {
                Write-Log -Level "WARNING" -Category "Cleaning" -Message "Old log scan error : $($_.Exception.Message)"
            }
        }

        $result.Success = $true
        $result.Message = "Windows event logs cleared ($($result.ItemsCleaned.Count) logs)"
    } catch {
        $result.Message = "Error: $($_.Exception.Message)"
    }
    return $result
}

function global:Clear-SystemLogs {
    $result = @{ Success = $false; BytesRecovered = 0; Message = ""; ItemsCleaned = @() }
    try {
        try {
            wevtutil cl "System" 2>&1 | Out-Null
            $result.ItemsCleaned += "System"
            Write-Log -Level "INFO" -Category "Cleaning" -Message "Cleared System event log"
        } catch {
            Write-Log -Level "WARNING" -Category "Cleaning" -Message "System log clear error : $($_.Exception.Message)"
        }

        $paths = @(
            "$env:SystemRoot\Logs",
            "$env:SystemRoot\Logs\CBS",
            "$env:SystemRoot\Logs\DISM",
            "$env:SystemRoot\debug",
            "$env:SystemRoot\Panther",
            "$env:PROGRAMDATA\Microsoft\Windows\WER\ReportQueue",
            "$env:PROGRAMDATA\Microsoft\Windows\WER\ReportArchive"
        )

        foreach ($path in $paths) {
            if (Test-Path $path) {
                $sz = Get-AppFolderSize $path
                try {
                    Remove-Item "$path\*" -Recurse -Force -EA SilentlyContinue
                    $result.BytesRecovered += $sz
                    $result.ItemsCleaned += $path
                } catch {
                    Write-Log -Level "WARNING" -Category "Cleaning" -Message "System log clean error for $path : $($_.Exception.Message)"
                }
            }
        }

        $result.Success = $true
        $result.Message = "System logs cleared ($($result.ItemsCleaned.Count) locations)"
    } catch {
        $result.Message = "Error: $($_.Exception.Message)"
    }
    return $result
}

function global:Clear-ApplicationLogs {
    $result = @{ Success = $false; BytesRecovered = 0; Message = ""; ItemsCleaned = @() }
    try {
        try {
            wevtutil cl "Application" 2>&1 | Out-Null
            $result.ItemsCleaned += "Application"
            Write-Log -Level "INFO" -Category "Cleaning" -Message "Cleared Application event log"
        } catch {
            Write-Log -Level "WARNING" -Category "Cleaning" -Message "Application log clear error : $($_.Exception.Message)"
        }

        $paths = @(
            "$env:LOCALAPPDATA\CrashDumps",
            "$env:LOCALAPPDATA\Microsoft\Windows\WER\ReportQueue",
            "$env:LOCALAPPDATA\Microsoft\Windows\WER\ReportArchive",
            "$env:LOCALAPPDATA\Microsoft\Windows\WER\Temp"
        )

        foreach ($path in $paths) {
            if (Test-Path $path) {
                $sz = Get-AppFolderSize $path
                try {
                    Remove-Item "$path\*" -Recurse -Force -EA SilentlyContinue
                    $result.BytesRecovered += $sz
                    $result.ItemsCleaned += $path
                } catch {
                    Write-Log -Level "WARNING" -Category "Cleaning" -Message "App log clean error for $path : $($_.Exception.Message)"
                }
            }
        }

        $result.Success = $true
        $result.Message = "Application logs cleared ($($result.ItemsCleaned.Count) locations)"
    } catch {
        $result.Message = "Error: $($_.Exception.Message)"
    }
    return $result
}

function global:Clear-SecurityLogs {
    $result = @{ Success = $false; BytesRecovered = 0; Message = ""; ItemsCleaned = @() }
    try {
        try {
            wevtutil cl "Security" 2>&1 | Out-Null
            $result.ItemsCleaned += "Security"
            Write-Log -Level "INFO" -Category "Cleaning" -Message "Cleared Security event log"
        } catch {
            Write-Log -Level "WARNING" -Category "Cleaning" -Message "Security log clear error (may require elevation) : $($_.Exception.Message)"
        }

        $auditPath = "$env:SystemRoot\Security\Audit"
        if (Test-Path $auditPath) {
            $sz = Get-AppFolderSize $auditPath
            try {
                Remove-Item "$auditPath\*" -Recurse -Force -EA SilentlyContinue
                $result.BytesRecovered += $sz
                $result.ItemsCleaned += $auditPath
            } catch {
                Write-Log -Level "WARNING" -Category "Cleaning" -Message "Audit log clean error : $($_.Exception.Message)"
            }
        }

        $result.Success = $true
        $result.Message = "Security logs cleared ($($result.ItemsCleaned.Count) locations)"
    } catch {
        $result.Message = "Error: $($_.Exception.Message)"
    }
    return $result
}

function global:Clear-AllLogs {
    $results = @{ TotalBytesRecovered = 0; Operations = @() }
    $ops = @("Clear-WindowsEventLogs", "Clear-SystemLogs", "Clear-ApplicationLogs", "Clear-SecurityLogs")
    foreach ($op in $ops) {
        try {
            $r = & $op
            $results.Operations += @{ Name = $op; Success = $r.Success; BytesRecovered = $r.BytesRecovered; Message = $r.Message }
            $results.TotalBytesRecovered += $r.BytesRecovered
        } catch {
            $results.Operations += @{ Name = $op; Success = $false; BytesRecovered = 0; Message = "Error: $($_.Exception.Message)" }
            Write-Log -Level "ERROR" -Category "Cleaning" -Message "Failed to run $op : $($_.Exception.Message)"
        }
    }
    return $results
}
