# BrowserCache.ps1 - PS5.1 compatible browser cache cleaning
# Functions: Clear-ChromeCache, Clear-FirefoxCache, Clear-EdgeCache, Clear-AllBrowserCaches

function Clear-ChromeCache {
    [CmdletBinding()]
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{ Success = $false; BytesRecovered = 0; Message = ''; ItemsCleaned = 0 }
    $basePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default"
    $cacheTargets = @('Cache', 'Cache2', 'Cookies', 'Session Storage', 'Code Cache', 'GPUCache', 'Media Cache')

    if (-not (Test-Path $basePath)) {
        $result.Message = 'Chrome not installed or profile not found'
        Write-Log -Level "INFO" -Category "Cleaning" -Message $result.Message
        return $result
    }

    try {
        $chromeProc = Get-Process -Name 'chrome' -ErrorAction SilentlyContinue
        if ($chromeProc -and -not $Preview) {
            Stop-Process -Name 'chrome' -Force -ErrorAction Stop
            Start-Sleep -Seconds 2
            Write-Log -Level "INFO" -Category "Cleaning" -Message "Stopped Chrome processes"
        }

        foreach ($target in $cacheTargets) {
            $targetPath = Join-Path $basePath $target
            if (-not (Test-Path $targetPath)) { continue }

            try {
                $size = (Get-ChildItem -Path $targetPath -Recurse -Force -ErrorAction SilentlyContinue |
                    Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                if (-not $size) { $size = 0 }

                if ($Preview) {
                    Write-Log -Level "INFO" -Category "Cleaning" -Message "Chrome $target - $([math]::Round($size / 1MB, 2)) MB (Preview)"
                } elseif ($TestMode) {
                    Write-Log -Level "INFO" -Category "Cleaning" -Message "Chrome $target - Test mode, skipped"
                } else {
                    Remove-Item -Path $targetPath -Recurse -Force -ErrorAction Stop
                    $result.BytesRecovered += $size
                    $result.ItemsCleaned++
                    Write-Log -Level "SUCCESS" -Category "Cleaning" -Message "Chrome $target cleaned - $([math]::Round($size / 1MB, 2)) MB"
                }
            } catch {
                Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message
            }
        }

        $result.Success = $true
        $result.Message = "Chrome cache cleaned - $([math]::Round($result.BytesRecovered / 1MB, 2)) MB recovered"
    } catch {
        Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message
        $result.Message = $_.Exception.Message
    }

    return $result
}

function Clear-FirefoxCache {
    [CmdletBinding()]
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{ Success = $false; BytesRecovered = 0; Message = ''; ItemsCleaned = 0 }
    $profileBase = "$env:APPDATA\Mozilla\Firefox\Profiles"

    if (-not (Test-Path $profileBase)) {
        $result.Message = 'Firefox not installed or profiles not found'
        Write-Log -Level "INFO" -Category "Cleaning" -Message $result.Message
        return $result
    }

    try {
        $ffProc = Get-Process -Name 'firefox' -ErrorAction SilentlyContinue
        if ($ffProc -and -not $Preview) {
            Stop-Process -Name 'firefox' -Force -ErrorAction Stop
            Start-Sleep -Seconds 2
            Write-Log -Level "INFO" -Category "Cleaning" -Message "Stopped Firefox processes"
        }

        $profiles = Get-ChildItem -Path $profileBase -Directory -ErrorAction SilentlyContinue
        foreach ($profile in $profiles) {
            $cacheTargets = @('cache2', 'thumbnails', 'cookies.sqlite', 'sessionCheckpoints.json',
                'webappsstore.sqlite', 'startupCache')

            foreach ($target in $cacheTargets) {
                $targetPath = Join-Path $profile.FullName $target
                if (-not (Test-Path $targetPath)) { continue }

                try {
                    $size = (Get-ChildItem -Path $targetPath -Recurse -Force -ErrorAction SilentlyContinue |
                        Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                    if (-not $size) { $size = 0 }

                    if ($Preview) {
                        Write-Log -Level "INFO" -Category "Cleaning" -Message "Firefox $($profile.Name)\$target - $([math]::Round($size / 1MB, 2)) MB (Preview)"
                    } elseif ($TestMode) {
                        Write-Log -Level "INFO" -Category "Cleaning" -Message "Firefox $($profile.Name)\$target - Test mode, skipped"
                    } else {
                        Remove-Item -Path $targetPath -Recurse -Force -ErrorAction Stop
                        $result.BytesRecovered += $size
                        $result.ItemsCleaned++
                        Write-Log -Level "SUCCESS" -Category "Cleaning" -Message "Firefox $($profile.Name)\$target cleaned - $([math]::Round($size / 1MB, 2)) MB"
                    }
                } catch {
                    Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message
                }
            }
        }

        $result.Success = $true
        $result.Message = "Firefox cache cleaned - $([math]::Round($result.BytesRecovered / 1MB, 2)) MB recovered"
    } catch {
        Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message
        $result.Message = $_.Exception.Message
    }

    return $result
}

function Clear-EdgeCache {
    [CmdletBinding()]
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{ Success = $false; BytesRecovered = 0; Message = ''; ItemsCleaned = 0 }
    $basePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"
    $cacheTargets = @('Cache', 'Cache2', 'Cookies', 'Session Storage', 'Code Cache', 'GPUCache', 'Media Cache')

    if (-not (Test-Path $basePath)) {
        $result.Message = 'Edge not installed or profile not found'
        Write-Log -Level "INFO" -Category "Cleaning" -Message $result.Message
        return $result
    }

    try {
        $edgeProc = Get-Process -Name 'msedge' -ErrorAction SilentlyContinue
        if ($edgeProc -and -not $Preview) {
            Stop-Process -Name 'msedge' -Force -ErrorAction Stop
            Start-Sleep -Seconds 2
            Write-Log -Level "INFO" -Category "Cleaning" -Message "Stopped Edge processes"
        }

        foreach ($target in $cacheTargets) {
            $targetPath = Join-Path $basePath $target
            if (-not (Test-Path $targetPath)) { continue }

            try {
                $size = (Get-ChildItem -Path $targetPath -Recurse -Force -ErrorAction SilentlyContinue |
                    Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                if (-not $size) { $size = 0 }

                if ($Preview) {
                    Write-Log -Level "INFO" -Category "Cleaning" -Message "Edge $target - $([math]::Round($size / 1MB, 2)) MB (Preview)"
                } elseif ($TestMode) {
                    Write-Log -Level "INFO" -Category "Cleaning" -Message "Edge $target - Test mode, skipped"
                } else {
                    Remove-Item -Path $targetPath -Recurse -Force -ErrorAction Stop
                    $result.BytesRecovered += $size
                    $result.ItemsCleaned++
                    Write-Log -Level "SUCCESS" -Category "Cleaning" -Message "Edge $target cleaned - $([math]::Round($size / 1MB, 2)) MB"
                }
            } catch {
                Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message
            }
        }

        $result.Success = $true
        $result.Message = "Edge cache cleaned - $([math]::Round($result.BytesRecovered / 1MB, 2)) MB recovered"
    } catch {
        Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message
        $result.Message = $_.Exception.Message
    }

    return $result
}

function Clear-AllBrowserCaches {
    [CmdletBinding()]
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{ Success = $true; BytesRecovered = 0; Message = ''; ItemsCleaned = 0 }

    Write-Log -Level "INFO" -Category "Cleaning" -Message "Starting cleanup of all browser caches"

    $chrome = Clear-ChromeCache -Preview:$Preview -TestMode:$TestMode
    $result.BytesRecovered += $chrome.BytesRecovered
    $result.ItemsCleaned += $chrome.ItemsCleaned

    $firefox = Clear-FirefoxCache -Preview:$Preview -TestMode:$TestMode
    $result.BytesRecovered += $firefox.BytesRecovered
    $result.ItemsCleaned += $firefox.ItemsCleaned

    $edge = Clear-EdgeCache -Preview:$Preview -TestMode:$TestMode
    $result.BytesRecovered += $edge.BytesRecovered
    $result.ItemsCleaned += $edge.ItemsCleaned

    $result.Message = "All browser caches cleaned - $([math]::Round($result.BytesRecovered / 1MB, 2)) MB recovered, $($result.ItemsCleaned) items"
    Write-Log -Level "SUCCESS" -Category "Cleaning" -Message $result.Message
    return $result
}
