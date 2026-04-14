#Requires -Version 5.1
<#
.SYNOPSIS
    Gaming Platforms Cache Cleaning Module
.DESCRIPTION
    Cache cleaning for Steam, Epic Games, UPlay, and Origin gaming platforms.
#>

function global:Clear-SteamPlatformCache {
    $result = @{ Success = $false; BytesRecovered = 0; Message = ""; ItemsCleaned = @() }
    try {
        $steamInstall = @("${env:ProgramFiles(x86)}\Steam", "$env:ProgramFiles\Steam") |
            Where-Object { Test-Path $_ } | Select-Object -First 1

        if (-not $steamInstall) {
            $result.Message = "Steam not found"
            $result.Success = $true
            return $result
        }

        $paths = @(
            "$steamInstall\appcache",
            "$steamInstall\depotcache",
            "$steamInstall\dumps",
            "$steamInstall\logs",
            "$steamInstall\steamapps\downloading",
            "$steamInstall\steamapps\temp",
            "$steamInstall\steamapps\shadercache",
            "$steamInstall\config\htmlcache",
            "$steamInstall\config\avatarcache"
        )

        foreach ($path in $paths) {
            if (Test-Path $path) {
                $sz = Get-AppFolderSize $path
                try {
                    Remove-Item "$path\*" -Recurse -Force -EA SilentlyContinue
                    $result.BytesRecovered += $sz
                    $result.ItemsCleaned += $path
                } catch {
                    Write-Log -Level "WARNING" -Category "Cleaning" -Message "Steam clean error for $path : $($_.Exception.Message)"
                }
            }
        }

        $steamUser = "$env:ProgramData\Steam"
        if (Test-Path $steamUser) {
            $sz = Get-AppFolderSize $steamUser
            try {
                Remove-Item "$steamUser\*" -Recurse -Force -EA SilentlyContinue
                $result.BytesRecovered += $sz
                $result.ItemsCleaned += $steamUser
            } catch {
                Write-Log -Level "WARNING" -Category "Cleaning" -Message "Steam userdata clean error : $($_.Exception.Message)"
            }
        }

        $result.Success = $true
        $result.Message = "Steam platform cache cleared ($($result.ItemsCleaned.Count) locations)"
    } catch {
        $result.Message = "Error: $($_.Exception.Message)"
    }
    return $result
}

function global:Clear-EpicGamesPlatformCache {
    $result = @{ Success = $false; BytesRecovered = 0; Message = ""; ItemsCleaned = @() }
    try {
        $paths = @(
            "$env:LOCALAPPDATA\EpicGamesLauncher\Saved\webcache",
            "$env:LOCALAPPDATA\EpicGamesLauncher\Saved\Logs",
            "$env:LOCALAPPDATA\EpicGamesLauncher\Saved\Cache",
            "$env:LOCALAPPDATA\EpicGamesLauncher\Saved\Crashes",
            "$env:LOCALAPPDATA\EpicGamesLauncher\Saved\Config\CrashReportClient"
        )

        foreach ($path in $paths) {
            if (Test-Path $path) {
                $sz = Get-AppFolderSize $path
                try {
                    Remove-Item "$path\*" -Recurse -Force -EA SilentlyContinue
                    $result.BytesRecovered += $sz
                    $result.ItemsCleaned += $path
                } catch {
                    Write-Log -Level "WARNING" -Category "Cleaning" -Message "Epic clean error for $path : $($_.Exception.Message)"
                }
            }
        }

        $result.Success = $true
        $result.Message = "Epic Games platform cache cleared ($($result.ItemsCleaned.Count) locations)"
    } catch {
        $result.Message = "Error: $($_.Exception.Message)"
    }
    return $result
}

function global:Clear-UPlayCache {
    $result = @{ Success = $false; BytesRecovered = 0; Message = ""; ItemsCleaned = @() }
    try {
        $paths = @(
            "$env:LOCALAPPDATA\Ubisoft Game Launcher\cache",
            "$env:LOCALAPPDATA\Ubisoft Game Launcher\logs",
            "$env:LOCALAPPDATA\Ubisoft Game Launcher\crashes",
            "$env:LOCALAPPDATA\Ubisoft Game Launcher\thumbnails",
            "$env:LOCALAPPDATA\Ubisoft Game Launcher\spool",
            "$env:PROGRAMFILES\Ubisoft\Ubisoft Game Launcher\cache",
            "${env:ProgramFiles(x86)}\Ubisoft\Ubisoft Game Launcher\cache"
        )

        foreach ($path in $paths) {
            if (Test-Path $path) {
                $sz = Get-AppFolderSize $path
                try {
                    Remove-Item "$path\*" -Recurse -Force -EA SilentlyContinue
                    $result.BytesRecovered += $sz
                    $result.ItemsCleaned += $path
                } catch {
                    Write-Log -Level "WARNING" -Category "Cleaning" -Message "UPlay clean error for $path : $($_.Exception.Message)"
                }
            }
        }

        $result.Success = $true
        $result.Message = "UPlay/Ubisoft cache cleared ($($result.ItemsCleaned.Count) locations)"
    } catch {
        $result.Message = "Error: $($_.Exception.Message)"
    }
    return $result
}

function global:Clear-OriginCache {
    $result = @{ Success = $false; BytesRecovered = 0; Message = ""; ItemsCleaned = @() }
    try {
        $paths = @(
            "$env:LOCALAPPDATA\Origin\Origin\cache",
            "$env:LOCALAPPDATA\Origin\Origin\localContent",
            "$env:LOCALAPPDATA\Origin\Origin\logs",
            "$env:LOCALAPPDATA\Origin\Origin\telemetry",
            "$env:PROGRAMDATA\Origin\Logs",
            "$env:PROGRAMDATA\Origin\DownloadCache",
            "${env:ProgramFiles(x86)}\Origin\cache",
            "$env:PROGRAMFILES\Origin\cache"
        )

        foreach ($path in $paths) {
            if (Test-Path $path) {
                $sz = Get-AppFolderSize $path
                try {
                    Remove-Item "$path\*" -Recurse -Force -EA SilentlyContinue
                    $result.BytesRecovered += $sz
                    $result.ItemsCleaned += $path
                } catch {
                    Write-Log -Level "WARNING" -Category "Cleaning" -Message "Origin clean error for $path : $($_.Exception.Message)"
                }
            }
        }

        $result.Success = $true
        $result.Message = "Origin/EA cache cleared ($($result.ItemsCleaned.Count) locations)"
    } catch {
        $result.Message = "Error: $($_.Exception.Message)"
    }
    return $result
}

function global:Clear-AllGamingPlatforms {
    $results = @{ TotalBytesRecovered = 0; Operations = @() }
    $ops = @("Clear-SteamPlatformCache", "Clear-EpicGamesPlatformCache", "Clear-UPlayCache", "Clear-OriginCache")
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
