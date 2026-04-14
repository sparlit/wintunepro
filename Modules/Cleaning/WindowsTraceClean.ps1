#Requires -Version 5.1
<#
.SYNOPSIS
    Windows Trace Data Cleaning Module
.DESCRIPTION
    Clearing of WMI traces, Performance traces, and Diagnostic traces
    by stopping the DiagTrack service and cleaning trace data directories.
#>

function global:Clear-WMITraces {
    $result = @{ Success = $false; BytesRecovered = 0; Message = ""; ItemsCleaned = @() }
    try {
        $paths = @(
            "$env:SystemRoot\System32\LogFiles\WMI",
            "$env:SystemRoot\System32\LogFiles\WMI\RtBackup",
            "$env:PROGRAMDATA\Microsoft\Diagnosis",
            "$env:PROGRAMDATA\Microsoft\Diagnosis\ETLLogs",
            "$env:PROGRAMDATA\Microsoft\Diagnosis\DownloadedScenarios",
            "$env:LOCALAPPDATA\Microsoft\Diagnosis"
        )

        foreach ($path in $paths) {
            if (Test-Path $path) {
                $sz = Get-AppFolderSize $path
                try {
                    Remove-Item "$path\*" -Recurse -Force -EA SilentlyContinue
                    $result.BytesRecovered += $sz
                    $result.ItemsCleaned += $path
                } catch {
                    Write-Log -Level "WARNING" -Category "Cleaning" -Message "WMI trace clean error for $path : $($_.Exception.Message)"
                }
            }
        }

        $traceFiles = Get-ChildItem "$env:SystemRoot\System32\LogFiles\*.etl" -EA SilentlyContinue
        foreach ($file in $traceFiles) {
            try {
                $sz = $file.Length
                Remove-Item $file.FullName -Force -EA SilentlyContinue
                $result.BytesRecovered += $sz
                $result.ItemsCleaned += $file.FullName
            } catch {
                Write-Log -Level "WARNING" -Category "Cleaning" -Message "ETL delete error : $($file.Name) : $($_.Exception.Message)"
            }
        }

        $result.Success = $true
        $result.Message = "WMI traces cleared ($($result.ItemsCleaned.Count) locations)"
    } catch {
        $result.Message = "Error: $($_.Exception.Message)"
    }
    return $result
}

function global:Clear-PerformanceTraces {
    $result = @{ Success = $false; BytesRecovered = 0; Message = ""; ItemsCleaned = @() }
    try {
        try {
            $diagSvc = Get-Service -Name "DiagTrack" -EA SilentlyContinue
            if ($diagSvc -and $diagSvc.Status -eq "Running") {
                Write-Log -Level "INFO" -Category "Cleaning" -Message "Stopping DiagTrack service..."
                Stop-Service -Name "DiagTrack" -Force -EA Stop
                Start-Sleep -Seconds 3
            }
        } catch {
            Write-Log -Level "WARNING" -Category "Cleaning" -Message "DiagTrack service stop error : $($_.Exception.Message)"
        }

        $paths = @(
            "$env:SystemRoot\System32\LogFiles\Performance",
            "$env:LOCALAPPDATA\Microsoft\Windows\Perfmon",
            "$env:PROGRAMDATA\Microsoft\Windows\Perfmon",
            "$env:SystemRoot\Performance\WinSAT",
            "$env:LOCALAPPDATA\Microsoft\Windows\WinSAT"
        )

        foreach ($path in $paths) {
            if (Test-Path $path) {
                $sz = Get-AppFolderSize $path
                try {
                    Remove-Item "$path\*" -Recurse -Force -EA SilentlyContinue
                    $result.BytesRecovered += $sz
                    $result.ItemsCleaned += $path
                } catch {
                    Write-Log -Level "WARNING" -Category "Cleaning" -Message "Perf trace clean error for $path : $($_.Exception.Message)"
                }
            }
        }

        try {
            $diagSvc = Get-Service -Name "DiagTrack" -EA SilentlyContinue
            if ($diagSvc -and $diagSvc.Status -ne "Running") {
                Write-Log -Level "INFO" -Category "Cleaning" -Message "Starting DiagTrack service..."
                Start-Service -Name "DiagTrack" -EA SilentlyContinue
            }
        } catch {
            Write-Log -Level "WARNING" -Category "Cleaning" -Message "DiagTrack service start error : $($_.Exception.Message)"
        }

        $result.Success = $true
        $result.Message = "Performance traces cleared ($($result.ItemsCleaned.Count) locations)"
    } catch {
        $result.Message = "Error: $($_.Exception.Message)"
    }
    return $result
}

function global:Clear-DiagnosticTraces {
    $result = @{ Success = $false; BytesRecovered = 0; Message = ""; ItemsCleaned = @() }
    try {
        $paths = @(
            "$env:PROGRAMDATA\Microsoft\Diagnosis\EventTranscript",
            "$env:PROGRAMDATA\Microsoft\Diagnosis\LocalTraceStore",
            "$env:LOCALAPPDATA\Microsoft\Diagnosis\LocalTraceStore",
            "$env:PROGRAMDATA\Microsoft\Diagnosis\FeedbackHub",
            "$env:LOCALAPPDATA\Microsoft\Diagnosis\FeedbackHub",
            "$env:PROGRAMDATA\Microsoft\Diagnosis\TenantStorage",
            "$env:LOCALAPPDATA\Microsoft\Diagnosis\TenantStorage",
            "$env:PROGRAMDATA\Microsoft\Diagnosis\SoftLandingStage",
            "$env:LOCALAPPDATA\DiagTrack"
        )

        foreach ($path in $paths) {
            if (Test-Path $path) {
                $sz = Get-AppFolderSize $path
                try {
                    Remove-Item "$path\*" -Recurse -Force -EA SilentlyContinue
                    $result.BytesRecovered += $sz
                    $result.ItemsCleaned += $path
                } catch {
                    Write-Log -Level "WARNING" -Category "Cleaning" -Message "Diagnostic trace clean error for $path : $($_.Exception.Message)"
                }
            }
        }

        $result.Success = $true
        $result.Message = "Diagnostic traces cleared ($($result.ItemsCleaned.Count) locations)"
    } catch {
        $result.Message = "Error: $($_.Exception.Message)"
    }
    return $result
}

function global:Clear-AllTraceData {
    $results = @{ TotalBytesRecovered = 0; Operations = @() }
    $ops = @("Clear-WMITraces", "Clear-PerformanceTraces", "Clear-DiagnosticTraces")
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
