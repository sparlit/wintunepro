#Requires -Version 5.1
<#
.SYNOPSIS
    Deep System Cleaning Module
.DESCRIPTION
    Deep cleaning operations for Windows Search Index, Clipboard History,
    and Activity History.
#>

function global:Clear-WindowsSearchIndex {
    $result = @{ Success = $false; BytesRecovered = 0; Message = ""; ItemsCleaned = @() }
    try {
        $indexPath = "$env:ProgramData\Microsoft\Search\Data\Applications\Windows"
        if (-not (Test-Path $indexPath)) {
            $result.Message = "Search index directory not found"
            $result.Success = $true
            return $result
        }

        $sz = Get-AppFolderSize $indexPath

        try {
            $svc = Get-Service -Name "WSearch" -EA SilentlyContinue
            if ($svc -and $svc.Status -eq "Running") {
                Write-Log -Level "INFO" -Category "Cleaning" -Message "Stopping Windows Search service..."
                Stop-Service -Name "WSearch" -Force -EA Stop
                Start-Sleep -Seconds 3

                try {
                    Remove-Item "$indexPath\*" -Recurse -Force -EA SilentlyContinue
                    $result.BytesRecovered += $sz
                    $result.ItemsCleaned += $indexPath
                } catch {
                    Write-Log -Level "WARNING" -Category "Cleaning" -Message "Search index delete error : $($_.Exception.Message)"
                }

                Write-Log -Level "INFO" -Category "Cleaning" -Message "Starting Windows Search service..."
                Start-Service -Name "WSearch" -EA SilentlyContinue
            } else {
                try {
                    Remove-Item "$indexPath\*" -Recurse -Force -EA SilentlyContinue
                    $result.BytesRecovered += $sz
                    $result.ItemsCleaned += $indexPath
                } catch {
                    Write-Log -Level "WARNING" -Category "Cleaning" -Message "Search index delete error : $($_.Exception.Message)"
                }
            }
        } catch {
            Write-Log -Level "WARNING" -Category "Cleaning" -Message "Search service control error : $($_.Exception.Message)"
        }

        $edbPath = "$indexPath\Windows.edb"
        if (Test-Path $edbPath) {
            Write-Log -Level "WARNING" -Category "Cleaning" -Message "Search index still in use, will rebuild on reboot"
        }

        $result.Success = $true
        $result.Message = "Windows Search index cleared"
    } catch {
        $result.Message = "Error: $($_.Exception.Message)"
    }
    return $result
}

function global:Clear-ClipboardHistoryDeep {
    $result = @{ Success = $false; BytesRecovered = 0; Message = ""; ItemsCleaned = @() }
    try {
        $clipRegPath = "HKCU:\Software\Microsoft\Clipboard"

        try {
            if (-not (Test-Path $clipRegPath)) {
                New-Item -Path $clipRegPath -Force -EA Stop | Out-Null
            }
            Set-ItemProperty -Path $clipRegPath -Name "EnableClipboardHistory" -Value 0 -Type DWord -EA Stop
            Write-Log -Level "INFO" -Category "Cleaning" -Message "Clipboard history disabled"
        } catch {
            Write-Log -Level "WARNING" -Category "Cleaning" -Message "Registry write error : $($_.Exception.Message)"
        }

        $clipDbPath = "$env:LOCALAPPDATA\Microsoft\Windows\Clipboard"
        if (Test-Path $clipDbPath) {
            $sz = Get-AppFolderSize $clipDbPath
            try {
                Remove-Item "$clipDbPath\*" -Recurse -Force -EA SilentlyContinue
                $result.BytesRecovered += $sz
                $result.ItemsCleaned += $clipDbPath
            } catch {
                Write-Log -Level "WARNING" -Category "Cleaning" -Message "Clipboard DB clean error : $($_.Exception.Message)"
            }
        }

        $clipRoamingPath = "$env:APPDATA\Microsoft\Windows\Clipboard"
        if (Test-Path $clipRoamingPath) {
            $sz = Get-AppFolderSize $clipRoamingPath
            try {
                Remove-Item "$clipRoamingPath\*" -Recurse -Force -EA SilentlyContinue
                $result.BytesRecovered += $sz
                $result.ItemsCleaned += $clipRoamingPath
            } catch {
                Write-Log -Level "WARNING" -Category "Cleaning" -Message "Clipboard roaming clean error : $($_.Exception.Message)"
            }
        }

        try {
            Get-Process "rdpclip" -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue
        } catch {
            Write-Log -Level "WARNING" -Category "Cleaning" -Message "rdpclip process error : $($_.Exception.Message)"
        }

        $result.Success = $true
        $result.Message = "Clipboard history cleared and disabled"
    } catch {
        $result.Message = "Error: $($_.Exception.Message)"
    }
    return $result
}

function global:Clear-ActivityHistoryDeep {
    $result = @{ Success = $false; BytesRecovered = 0; Message = ""; ItemsCleaned = @() }
    try {
        $actRegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy"
        try {
            if (Test-Path $actRegPath) {
                Remove-ItemProperty -Path $actRegPath -Name "ActivityType" -EA SilentlyContinue
            }
        } catch {
            Write-Log -Level "WARNING" -Category "Cleaning" -Message "Activity reg clean error : $($_.Exception.Message)"
        }

        $actDbPath = "$env:LOCALAPPDATA\ConnectedDevicesPlatform"
        if (Test-Path $actDbPath) {
            $sz = Get-AppFolderSize $actDbPath
            try {
                Remove-Item "$actDbPath\*" -Recurse -Force -EA SilentlyContinue
                $result.BytesRecovered += $sz
                $result.ItemsCleaned += $actDbPath
            } catch {
                Write-Log -Level "WARNING" -Category "Cleaning" -Message "Activity DB clean error : $($_.Exception.Message)"
            }
        }

        $actCache = "$env:LOCALAPPDATA\Microsoft\Windows\ActivityFeed"
        if (Test-Path $actCache) {
            $sz = Get-AppFolderSize $actCache
            try {
                Remove-Item "$actCache\*" -Recurse -Force -EA SilentlyContinue
                $result.BytesRecovered += $sz
                $result.ItemsCleaned += $actCache
            } catch {
                Write-Log -Level "WARNING" -Category "Cleaning" -Message "Activity cache clean error : $($_.Exception.Message)"
            }
        }

        $timelinePath = "$env:LOCALAPPDATA\Microsoft\Windows\Timeline"
        if (Test-Path $timelinePath) {
            $sz = Get-AppFolderSize $timelinePath
            try {
                Remove-Item "$timelinePath\*" -Recurse -Force -EA SilentlyContinue
                $result.BytesRecovered += $sz
                $result.ItemsCleaned += $timelinePath
            } catch {
                Write-Log -Level "WARNING" -Category "Cleaning" -Message "Timeline clean error : $($_.Exception.Message)"
            }
        }

        $result.Success = $true
        $result.Message = "Activity history cleared"
    } catch {
        $result.Message = "Error: $($_.Exception.Message)"
    }
    return $result
}

function global:Clear-AllDeepClean {
    $results = @{ TotalBytesRecovered = 0; Operations = @() }
    $ops = @("Clear-WindowsSearchIndex", "Clear-ClipboardHistoryDeep", "Clear-ActivityHistoryDeep")
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
