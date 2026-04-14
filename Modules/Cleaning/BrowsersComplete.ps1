#Requires -Version 5.1
<#
.SYNOPSIS
    Comprehensive Browser Cleaning Module - Opera, Brave, Vivaldi
.DESCRIPTION
    Complete cache and data cleaning for Opera, Brave, and Vivaldi browsers.
    Covers cache, code cache, GPU cache, service worker data, and temp files.
#>

function global:Clear-OperaCacheComplete {
    $result = @{ Success = $false; BytesRecovered = 0; Message = ""; ItemsCleaned = @() }
    try {
        $operaBase = "$env:LOCALAPPDATA\Programs\Opera"
        if (-not (Test-Path $operaBase)) {
            $result.Message = "Opera not found"
            $result.Success = $true
            return $result
        }

        $operaData = "$env:APPDATA\Opera Software\Opera Stable"
        $paths = @(
            "$operaData\Cache",
            "$operaData\Code Cache",
            "$operaData\GPUCache",
            "$operaData\DawnCache",
            "$operaData\Service Worker\CacheStorage",
            "$operaData\Service Worker\ScriptCache",
            "$operaData\Session Storage",
            "$operaData\databases",
            "$operaData\IndexedDB",
            "$operaData\blob_storage",
            "$operaData\Crashpad",
            "$operaData\Media Cache",
            "$operaData\GraphiteDawnCache",
            "$operaData\GrShaderCache",
            "$operaData\ShaderCache"
        )
        foreach ($path in $paths) {
            if (Test-Path $path) {
                $sz = Get-AppFolderSize $path
                try {
                    Remove-Item "$path\*" -Recurse -Force -EA SilentlyContinue
                    $result.BytesRecovered += $sz
                    $result.ItemsCleaned += $path
                } catch {
                    Write-Log -Level "WARNING" -Category "Cleaning" -Message "Opera clean error for $path : $($_.Exception.Message)"
                }
            }
        }

        $operaTemp = "$env:LOCALAPPDATA\Temp\opera_crashreports"
        if (Test-Path $operaTemp) {
            $sz = Get-AppFolderSize $operaTemp
            try {
                Remove-Item "$operaTemp\*" -Recurse -Force -EA SilentlyContinue
                $result.BytesRecovered += $sz
                $result.ItemsCleaned += $operaTemp
            } catch {
                Write-Log -Level "WARNING" -Category "Cleaning" -Message "Opera temp clean error : $($_.Exception.Message)"
            }
        }

        $result.Success = $true
        $result.Message = "Opera cache cleared ($($result.ItemsCleaned.Count) locations)"
    } catch {
        $result.Message = "Error: $($_.Exception.Message)"
    }
    return $result
}

function global:Clear-BraveCacheComplete {
    $result = @{ Success = $false; BytesRecovered = 0; Message = ""; ItemsCleaned = @() }
    try {
        $braveData = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data"
        if (-not (Test-Path $braveData)) {
            $result.Message = "Brave not found"
            $result.Success = $true
            return $result
        }

        $profiles = Get-ChildItem $braveData -Directory -EA SilentlyContinue | Where-Object {
            $_.Name -eq "Default" -or $_.Name -match '^Profile \d+$'
        }

        foreach ($profile in $profiles) {
            $pp = $profile.FullName
            $paths = @(
                "$pp\Cache",
                "$pp\Cache\Cache_Data",
                "$pp\Code Cache",
                "$pp\GPUCache",
                "$pp\DawnCache",
                "$pp\ShaderCache",
                "$pp\GrShaderCache",
                "$pp\GraphiteDawnCache",
                "$pp\Service Worker\CacheStorage",
                "$pp\Service Worker\ScriptCache",
                "$pp\Session Storage",
                "$pp\databases",
                "$pp\IndexedDB",
                "$pp\blob_storage",
                "$pp\Crashpad",
                "$pp\optimization_guide_hint_cache_store",
                "$pp\optimization_guide_model_metadata_store",
                "$pp\BudgetDatabase",
                "$pp\Download Service",
                "$pp\Platform Notifications"
            )
            foreach ($path in $paths) {
                if (Test-Path $path) {
                    $sz = Get-AppFolderSize $path
                    try {
                        Remove-Item "$path\*" -Recurse -Force -EA SilentlyContinue
                        $result.BytesRecovered += $sz
                        $result.ItemsCleaned += $path
                    } catch {
                        Write-Log -Level "WARNING" -Category "Cleaning" -Message "Brave clean error for $path : $($_.Exception.Message)"
                    }
                }
            }
        }

        $result.Success = $true
        $result.Message = "Brave cache cleared ($($result.ItemsCleaned.Count) locations)"
    } catch {
        $result.Message = "Error: $($_.Exception.Message)"
    }
    return $result
}

function global:Clear-VivaldiCacheComplete {
    $result = @{ Success = $false; BytesRecovered = 0; Message = ""; ItemsCleaned = @() }
    try {
        $vivaldiData = "$env:LOCALAPPDATA\Vivaldi\User Data"
        if (-not (Test-Path $vivaldiData)) {
            $result.Message = "Vivaldi not found"
            $result.Success = $true
            return $result
        }

        $profiles = Get-ChildItem $vivaldiData -Directory -EA SilentlyContinue | Where-Object {
            $_.Name -eq "Default" -or $_.Name -match '^Profile \d+$'
        }

        foreach ($profile in $profiles) {
            $pp = $profile.FullName
            $paths = @(
                "$pp\Cache",
                "$pp\Cache\Cache_Data",
                "$pp\Code Cache",
                "$pp\GPUCache",
                "$pp\DawnCache",
                "$pp\ShaderCache",
                "$pp\GrShaderCache",
                "$pp\GraphiteDawnCache",
                "$pp\Service Worker\CacheStorage",
                "$pp\Service Worker\ScriptCache",
                "$pp\Session Storage",
                "$pp\databases",
                "$pp\IndexedDB",
                "$pp\blob_storage",
                "$pp\Crashpad",
                "$pp\Visited Links",
                "$pp\BudgetDatabase"
            )
            foreach ($path in $paths) {
                if (Test-Path $path) {
                    $sz = Get-AppFolderSize $path
                    try {
                        Remove-Item "$path\*" -Recurse -Force -EA SilentlyContinue
                        $result.BytesRecovered += $sz
                        $result.ItemsCleaned += $path
                    } catch {
                        Write-Log -Level "WARNING" -Category "Cleaning" -Message "Vivaldi clean error for $path : $($_.Exception.Message)"
                    }
                }
            }
        }

        $vivaldiUpdate = "$env:LOCALAPPDATA\Vivaldi\Update"
        if (Test-Path $vivaldiUpdate) {
            $sz = Get-AppFolderSize $vivaldiUpdate
            try {
                Remove-Item "$vivaldiUpdate\*" -Recurse -Force -EA SilentlyContinue
                $result.BytesRecovered += $sz
                $result.ItemsCleaned += $vivaldiUpdate
            } catch {
                Write-Log -Level "WARNING" -Category "Cleaning" -Message "Vivaldi update clean error : $($_.Exception.Message)"
            }
        }

        $result.Success = $true
        $result.Message = "Vivaldi cache cleared ($($result.ItemsCleaned.Count) locations)"
    } catch {
        $result.Message = "Error: $($_.Exception.Message)"
    }
    return $result
}

function global:Clear-AllBrowsersComplete {
    $results = @{ TotalBytesRecovered = 0; Operations = @() }
    $ops = @("Clear-OperaCacheComplete", "Clear-BraveCacheComplete", "Clear-VivaldiCacheComplete")
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
