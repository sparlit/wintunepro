# BrowserDeep.ps1 - PS5.1 compatible deep browser cache cleaning
# Deep cleaning: Code Cache, GPUCache, DawnCache, Service Worker, local storage, etc.

function Clear-ChromeCacheBrowserDeep {
    [CmdletBinding()]
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{ Success = $false; BytesRecovered = 0; Message = ''; ItemsCleaned = 0 }
    $basePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default"
    $deepTargets = @('Code Cache', 'GPUCache', 'DawnCache', 'Service Worker', 'Local Storage',
        'Session Storage', 'IndexedDB', 'blob_storage', 'File System', 'WebrtcEventLog',
        'shared_proto_db', 'optimization_guide_model_store')

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

        foreach ($target in $deepTargets) {
            $targetPath = Join-Path $basePath $target
            if (-not (Test-Path $targetPath)) { continue }

            try {
                $size = (Get-ChildItem -Path $targetPath -Recurse -Force -ErrorAction SilentlyContinue |
                    Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                if (-not $size) { $size = 0 }

                if ($Preview) {
                    Write-Log -Level "INFO" -Category "Cleaning" -Message "Chrome Deep $target - $([math]::Round($size / 1MB, 2)) MB (Preview)"
                } elseif ($TestMode) {
                    Write-Log -Level "INFO" -Category "Cleaning" -Message "Chrome Deep $target - Test mode, skipped"
                } else {
                    Remove-Item -Path $targetPath -Recurse -Force -ErrorAction Stop
                    $result.BytesRecovered += $size
                    $result.ItemsCleaned++
                    Write-Log -Level "SUCCESS" -Category "Cleaning" -Message "Chrome Deep $target cleaned - $([math]::Round($size / 1MB, 2)) MB"
                }
            } catch {
                Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message
            }
        }

        $extraTargets = @('Extension State', 'databases', 'blob_storage', 'Crashpad')
        foreach ($target in $extraTargets) {
            $targetPath = Join-Path $basePath $target
            if (-not (Test-Path $targetPath)) { continue }
            try {
                $size = (Get-ChildItem -Path $targetPath -Recurse -Force -ErrorAction SilentlyContinue |
                    Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                if (-not $size) { $size = 0 }
                if ($Preview) {
                    Write-Log -Level "INFO" -Category "Cleaning" -Message "Chrome Deep $target - $([math]::Round($size / 1MB, 2)) MB (Preview)"
                } elseif (-not $TestMode) {
                    Remove-Item -Path $targetPath -Recurse -Force -ErrorAction Stop
                    $result.BytesRecovered += $size
                    $result.ItemsCleaned++
                    Write-Log -Level "SUCCESS" -Category "Cleaning" -Message "Chrome Deep $target cleaned"
                }
            } catch {
                Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message
            }
        }

        $result.Success = $true
        $result.Message = "Chrome deep clean completed - $([math]::Round($result.BytesRecovered / 1MB, 2)) MB recovered"
    } catch {
        Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message
        $result.Message = $_.Exception.Message
    }

    return $result
}

function Clear-FirefoxCacheBrowserDeep {
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
            $deepTargets = @('cache2', 'shader-cache', 'storage', 'storage/default',
                'startupCache', 'thumbnails', 'webappsstore.sqlite',
                'OfflineCache', 'jumpListCache', 'shader-cache')

            foreach ($target in $deepTargets) {
                $targetPath = Join-Path $profile.FullName $target
                if (-not (Test-Path $targetPath)) { continue }

                try {
                    $size = (Get-ChildItem -Path $targetPath -Recurse -Force -ErrorAction SilentlyContinue |
                        Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                    if (-not $size) { $size = 0 }

                    if ($Preview) {
                        Write-Log -Level "INFO" -Category "Cleaning" -Message "Firefox Deep $($profile.Name)\$target - $([math]::Round($size / 1MB, 2)) MB (Preview)"
                    } elseif ($TestMode) {
                        Write-Log -Level "INFO" -Category "Cleaning" -Message "Firefox Deep $($profile.Name)\$target - Test mode, skipped"
                    } else {
                        Remove-Item -Path $targetPath -Recurse -Force -ErrorAction Stop
                        $result.BytesRecovered += $size
                        $result.ItemsCleaned++
                        Write-Log -Level "SUCCESS" -Category "Cleaning" -Message "Firefox Deep $($profile.Name)\$target cleaned - $([math]::Round($size / 1MB, 2)) MB"
                    }
                } catch {
                    Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message
                }
            }
        }

        $result.Success = $true
        $result.Message = "Firefox deep clean completed - $([math]::Round($result.BytesRecovered / 1MB, 2)) MB recovered"
    } catch {
        Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message
        $result.Message = $_.Exception.Message
    }

    return $result
}

function Clear-VivaldiCacheDeep {
    [CmdletBinding()]
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{ Success = $false; BytesRecovered = 0; Message = ''; ItemsCleaned = 0 }
    $basePath = "$env:LOCALAPPDATA\Vivaldi\User Data\Default"
    $deepTargets = @('Code Cache', 'GPUCache', 'DawnCache', 'Service Worker', 'Local Storage',
        'Session Storage', 'IndexedDB', 'blob_storage')

    if (-not (Test-Path $basePath)) {
        $result.Message = 'Vivaldi not installed or profile not found'
        Write-Log -Level "INFO" -Category "Cleaning" -Message $result.Message
        return $result
    }

    try {
        $proc = Get-Process -Name 'vivaldi' -ErrorAction SilentlyContinue
        if ($proc -and -not $Preview) {
            Stop-Process -Name 'vivaldi' -Force -ErrorAction Stop
            Start-Sleep -Seconds 2
        }

        foreach ($target in $deepTargets) {
            $targetPath = Join-Path $basePath $target
            if (-not (Test-Path $targetPath)) { continue }

            try {
                $size = (Get-ChildItem -Path $targetPath -Recurse -Force -ErrorAction SilentlyContinue |
                    Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                if (-not $size) { $size = 0 }

                if ($Preview) {
                    Write-Log -Level "INFO" -Category "Cleaning" -Message "Vivaldi Deep $target - $([math]::Round($size / 1MB, 2)) MB (Preview)"
                } elseif (-not $TestMode) {
                    Remove-Item -Path $targetPath -Recurse -Force -ErrorAction Stop
                    $result.BytesRecovered += $size
                    $result.ItemsCleaned++
                    Write-Log -Level "SUCCESS" -Category "Cleaning" -Message "Vivaldi Deep $target cleaned - $([math]::Round($size / 1MB, 2)) MB"
                }
            } catch {
                Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message
            }
        }

        $result.Success = $true
        $result.Message = "Vivaldi deep clean completed - $([math]::Round($result.BytesRecovered / 1MB, 2)) MB recovered"
    } catch {
        Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message
        $result.Message = $_.Exception.Message
    }

    return $result
}

function Clear-BraveCacheDeep {
    [CmdletBinding()]
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{ Success = $false; BytesRecovered = 0; Message = ''; ItemsCleaned = 0 }
    $basePath = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default"
    $deepTargets = @('Code Cache', 'GPUCache', 'DawnCache', 'Service Worker', 'Local Storage',
        'Session Storage', 'IndexedDB', 'blob_storage', 'File System')

    if (-not (Test-Path $basePath)) {
        $result.Message = 'Brave not installed or profile not found'
        Write-Log -Level "INFO" -Category "Cleaning" -Message $result.Message
        return $result
    }

    try {
        $proc = Get-Process -Name 'brave' -ErrorAction SilentlyContinue
        if ($proc -and -not $Preview) {
            Stop-Process -Name 'brave' -Force -ErrorAction Stop
            Start-Sleep -Seconds 2
        }

        foreach ($target in $deepTargets) {
            $targetPath = Join-Path $basePath $target
            if (-not (Test-Path $targetPath)) { continue }

            try {
                $size = (Get-ChildItem -Path $targetPath -Recurse -Force -ErrorAction SilentlyContinue |
                    Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                if (-not $size) { $size = 0 }

                if ($Preview) {
                    Write-Log -Level "INFO" -Category "Cleaning" -Message "Brave Deep $target - $([math]::Round($size / 1MB, 2)) MB (Preview)"
                } elseif (-not $TestMode) {
                    Remove-Item -Path $targetPath -Recurse -Force -ErrorAction Stop
                    $result.BytesRecovered += $size
                    $result.ItemsCleaned++
                    Write-Log -Level "SUCCESS" -Category "Cleaning" -Message "Brave Deep $target cleaned - $([math]::Round($size / 1MB, 2)) MB"
                }
            } catch {
                Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message
            }
        }

        $result.Success = $true
        $result.Message = "Brave deep clean completed - $([math]::Round($result.BytesRecovered / 1MB, 2)) MB recovered"
    } catch {
        Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message
        $result.Message = $_.Exception.Message
    }

    return $result
}

function Clear-OperaCacheDeep {
    [CmdletBinding()]
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{ Success = $false; BytesRecovered = 0; Message = ''; ItemsCleaned = 0 }
    $basePath = "$env:APPDATA\Opera Software\Opera Stable"
    $deepTargets = @('Code Cache', 'GPUCache', 'DawnCache', 'Service Worker', 'Local Storage',
        'Session Storage', 'IndexedDB', 'blob_storage')

    if (-not (Test-Path $basePath)) {
        $result.Message = 'Opera not installed or profile not found'
        Write-Log -Level "INFO" -Category "Cleaning" -Message $result.Message
        return $result
    }

    try {
        $proc = Get-Process -Name 'opera' -ErrorAction SilentlyContinue
        if ($proc -and -not $Preview) {
            Stop-Process -Name 'opera' -Force -ErrorAction Stop
            Start-Sleep -Seconds 2
        }

        foreach ($target in $deepTargets) {
            $targetPath = Join-Path $basePath $target
            if (-not (Test-Path $targetPath)) { continue }

            try {
                $size = (Get-ChildItem -Path $targetPath -Recurse -Force -ErrorAction SilentlyContinue |
                    Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                if (-not $size) { $size = 0 }

                if ($Preview) {
                    Write-Log -Level "INFO" -Category "Cleaning" -Message "Opera Deep $target - $([math]::Round($size / 1MB, 2)) MB (Preview)"
                } elseif (-not $TestMode) {
                    Remove-Item -Path $targetPath -Recurse -Force -ErrorAction Stop
                    $result.BytesRecovered += $size
                    $result.ItemsCleaned++
                    Write-Log -Level "SUCCESS" -Category "Cleaning" -Message "Opera Deep $target cleaned - $([math]::Round($size / 1MB, 2)) MB"
                }
            } catch {
                Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message
            }
        }

        $result.Success = $true
        $result.Message = "Opera deep clean completed - $([math]::Round($result.BytesRecovered / 1MB, 2)) MB recovered"
    } catch {
        Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message
        $result.Message = $_.Exception.Message
    }

    return $result
}

function Clear-YandexBrowserCacheDeep {
    [CmdletBinding()]
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{ Success = $false; BytesRecovered = 0; Message = ''; ItemsCleaned = 0 }
    $basePath = "$env:LOCALAPPDATA\Yandex\YandexBrowser\User Data\Default"
    $deepTargets = @('Code Cache', 'GPUCache', 'DawnCache', 'Service Worker', 'Local Storage',
        'Session Storage', 'IndexedDB', 'blob_storage')

    if (-not (Test-Path $basePath)) {
        $result.Message = 'Yandex Browser not installed or profile not found'
        Write-Log -Level "INFO" -Category "Cleaning" -Message $result.Message
        return $result
    }

    try {
        $proc = Get-Process -Name 'browser' -ErrorAction SilentlyContinue
        if ($proc -and -not $Preview) {
            Stop-Process -Name 'browser' -Force -ErrorAction Stop
            Start-Sleep -Seconds 2
        }

        foreach ($target in $deepTargets) {
            $targetPath = Join-Path $basePath $target
            if (-not (Test-Path $targetPath)) { continue }

            try {
                $size = (Get-ChildItem -Path $targetPath -Recurse -Force -ErrorAction SilentlyContinue |
                    Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                if (-not $size) { $size = 0 }

                if ($Preview) {
                    Write-Log -Level "INFO" -Category "Cleaning" -Message "Yandex Deep $target - $([math]::Round($size / 1MB, 2)) MB (Preview)"
                } elseif (-not $TestMode) {
                    Remove-Item -Path $targetPath -Recurse -Force -ErrorAction Stop
                    $result.BytesRecovered += $size
                    $result.ItemsCleaned++
                    Write-Log -Level "SUCCESS" -Category "Cleaning" -Message "Yandex Deep $target cleaned - $([math]::Round($size / 1MB, 2)) MB"
                }
            } catch {
                Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message
            }
        }

        $result.Success = $true
        $result.Message = "Yandex deep clean completed - $([math]::Round($result.BytesRecovered / 1MB, 2)) MB recovered"
    } catch {
        Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message
        $result.Message = $_.Exception.Message
    }

    return $result
}

function Clear-InternetExplorerCacheDeep {
    [CmdletBinding()]
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{ Success = $false; BytesRecovered = 0; Message = ''; ItemsCleaned = 0 }
    $iePaths = @(
        "$env:LOCALAPPDATA\Microsoft\Windows\INetCache",
        "$env:LOCALAPPDATA\Microsoft\Windows\Temporary Internet Files",
        "$env:LOCALAPPDATA\Microsoft\Windows\WebCache"
    )

    try {
        foreach ($iePath in $iePaths) {
            if (-not (Test-Path $iePath)) { continue }

            try {
                $size = (Get-ChildItem -Path $iePath -Recurse -Force -ErrorAction SilentlyContinue |
                    Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                if (-not $size) { $size = 0 }

                if ($Preview) {
                    Write-Log -Level "INFO" -Category "Cleaning" -Message "IE Cache $iePath - $([math]::Round($size / 1MB, 2)) MB (Preview)"
                } elseif ($TestMode) {
                    Write-Log -Level "INFO" -Category "Cleaning" -Message "IE Cache $iePath - Test mode, skipped"
                } else {
                    Remove-Item -Path $iePath -Recurse -Force -ErrorAction Stop
                    $result.BytesRecovered += $size
                    $result.ItemsCleaned++
                    Write-Log -Level "SUCCESS" -Category "Cleaning" -Message "IE Cache cleaned - $([math]::Round($size / 1MB, 2)) MB"
                }
            } catch {
                Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message
            }
        }

        $result.Success = $true
        $result.Message = "IE deep clean completed - $([math]::Round($result.BytesRecovered / 1MB, 2)) MB recovered"
    } catch {
        Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message
        $result.Message = $_.Exception.Message
    }

    return $result
}

function Clear-AllBrowserCachesDeep {
    [CmdletBinding()]
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{ Success = $true; BytesRecovered = 0; Message = ''; ItemsCleaned = 0 }

    Write-Log -Level "INFO" -Category "Cleaning" -Message "Starting deep cleanup of all browser caches"

    $browsers = @(
        @{ Name = 'Chrome'; Func = { Clear-ChromeCacheBrowserDeep -Preview:$Preview -TestMode:$TestMode } },
        @{ Name = 'Firefox'; Func = { Clear-FirefoxCacheBrowserDeep -Preview:$Preview -TestMode:$TestMode } },
        @{ Name = 'Vivaldi'; Func = { Clear-VivaldiCacheDeep -Preview:$Preview -TestMode:$TestMode } },
        @{ Name = 'Brave'; Func = { Clear-BraveCacheDeep -Preview:$Preview -TestMode:$TestMode } },
        @{ Name = 'Opera'; Func = { Clear-OperaCacheDeep -Preview:$Preview -TestMode:$TestMode } },
        @{ Name = 'Yandex'; Func = { Clear-YandexBrowserCacheDeep -Preview:$Preview -TestMode:$TestMode } },
        @{ Name = 'IE'; Func = { Clear-InternetExplorerCacheDeep -Preview:$Preview -TestMode:$TestMode } }
    )

    foreach ($browser in $browsers) {
        try {
            $ret = & $browser.Func
            $result.BytesRecovered += $ret.BytesRecovered
            $result.ItemsCleaned += $ret.ItemsCleaned
        } catch {
            Write-Log -Level "WARNING" -Category "Cleaning" -Message "$($browser.Name) deep clean error: $($_.Exception.Message)"
        }
    }

    $result.Message = "All browser deep cleans completed - $([math]::Round($result.BytesRecovered / 1MB, 2)) MB recovered, $($result.ItemsCleaned) items"
    Write-Log -Level "SUCCESS" -Category "Cleaning" -Message $result.Message
    return $result
}
