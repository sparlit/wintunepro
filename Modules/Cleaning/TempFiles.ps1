# TempFiles.ps1 - PS5.1 compatible temp file cleaning
# Functions: Clear-UserTemp, Clear-SystemTemp, Clear-WindowsUpdateCache, Clear-ThumbnailCache, Clear-PrefetchFiles, Clear-AllTempFiles

function Clear-UserTemp {
    [CmdletBinding()]
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{ Success = $false; BytesRecovered = 0; Message = ''; ItemsCleaned = 0 }
    $tempPath = $env:TEMP

    if (-not (Test-Path $tempPath)) {
        $result.Message = 'User temp path not found'
        Write-Log -Level "WARNING" -Category "Cleaning" -Message $result.Message
        return $result
    }

    try {
        $items = Get-ChildItem -Path $tempPath -Force -ErrorAction SilentlyContinue
        foreach ($item in $items) {
            try {
                $size = (Get-ChildItem -Path $item.FullName -Recurse -Force -ErrorAction SilentlyContinue |
                    Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                if (-not $size) { $size = $item.Length }

                if ($Preview) {
                    Write-Log -Level "INFO" -Category "Cleaning" -Message "User temp $($item.Name) - $([math]::Round($size / 1MB, 2)) MB (Preview)"
                } elseif ($TestMode) {
                    Write-Log -Level "INFO" -Category "Cleaning" -Message "User temp $($item.Name) - Test mode, skipped"
                } else {
                    Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop
                    $result.BytesRecovered += $size
                    $result.ItemsCleaned++
                    Write-Log -Level "SUCCESS" -Category "Cleaning" -Message "Removed user temp $($item.Name)"
                }
            } catch {
                Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message
            }
        }

        $result.Success = $true
        $result.Message = "User temp cleaned - $([math]::Round($result.BytesRecovered / 1MB, 2)) MB recovered"
    } catch {
        Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message
        $result.Message = $_.Exception.Message
    }

    return $result
}

function Clear-SystemTemp {
    [CmdletBinding()]
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{ Success = $false; BytesRecovered = 0; Message = ''; ItemsCleaned = 0 }
    $tempPath = "$env:WINDIR\Temp"

    if (-not (Test-Path $tempPath)) {
        $result.Message = 'System temp path not found'
        Write-Log -Level "WARNING" -Category "Cleaning" -Message $result.Message
        return $result
    }

    try {
        $items = Get-ChildItem -Path $tempPath -Force -ErrorAction SilentlyContinue
        foreach ($item in $items) {
            try {
                $size = (Get-ChildItem -Path $item.FullName -Recurse -Force -ErrorAction SilentlyContinue |
                    Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                if (-not $size) { $size = $item.Length }

                if ($Preview) {
                    Write-Log -Level "INFO" -Category "Cleaning" -Message "System temp $($item.Name) - $([math]::Round($size / 1MB, 2)) MB (Preview)"
                } elseif ($TestMode) {
                    Write-Log -Level "INFO" -Category "Cleaning" -Message "System temp $($item.Name) - Test mode, skipped"
                } else {
                    Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop
                    $result.BytesRecovered += $size
                    $result.ItemsCleaned++
                    Write-Log -Level "SUCCESS" -Category "Cleaning" -Message "Removed system temp $($item.Name)"
                }
            } catch {
                Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message
            }
        }

        $result.Success = $true
        $result.Message = "System temp cleaned - $([math]::Round($result.BytesRecovered / 1MB, 2)) MB recovered"
    } catch {
        Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message
        $result.Message = $_.Exception.Message
    }

    return $result
}

function Clear-WindowsUpdateCache {
    [CmdletBinding()]
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{ Success = $false; BytesRecovered = 0; Message = ''; ItemsCleaned = 0 }
    $wuPath = "$env:WINDIR\SoftwareDistribution\Download"

    if (-not (Test-Path $wuPath)) {
        $result.Message = 'Windows Update cache path not found'
        Write-Log -Level "WARNING" -Category "Cleaning" -Message $result.Message
        return $result
    }

    try {
        if (-not $Preview) {
            try {
                Stop-Service -Name 'wuauserv' -Force -ErrorAction Stop
                Write-Log -Level "INFO" -Category "Cleaning" -Message "Stopped Windows Update service"
            } catch {
                Write-Log -Level "WARNING" -Category "Cleaning" -Message "Could not stop wuauserv: $($_.Exception.Message)"
            }
        }

        $items = Get-ChildItem -Path $wuPath -Force -ErrorAction SilentlyContinue
        foreach ($item in $items) {
            try {
                $size = (Get-ChildItem -Path $item.FullName -Recurse -Force -ErrorAction SilentlyContinue |
                    Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                if (-not $size) { $size = $item.Length }

                if ($Preview) {
                    Write-Log -Level "INFO" -Category "Cleaning" -Message "WU cache $($item.Name) - $([math]::Round($size / 1MB, 2)) MB (Preview)"
                } elseif ($TestMode) {
                    Write-Log -Level "INFO" -Category "Cleaning" -Message "WU cache $($item.Name) - Test mode, skipped"
                } else {
                    Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop
                    $result.BytesRecovered += $size
                    $result.ItemsCleaned++
                    Write-Log -Level "SUCCESS" -Category "Cleaning" -Message "Removed WU cache $($item.Name)"
                }
            } catch {
                Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message
            }
        }

        if (-not $Preview) {
            try {
                Start-Service -Name 'wuauserv' -ErrorAction Stop
                Write-Log -Level "INFO" -Category "Cleaning" -Message "Restarted Windows Update service"
            } catch {
                Write-Log -Level "WARNING" -Category "Cleaning" -Message "Could not restart wuauserv: $($_.Exception.Message)"
            }
        }

        $result.Success = $true
        $result.Message = "Windows Update cache cleaned - $([math]::Round($result.BytesRecovered / 1MB, 2)) MB recovered"
    } catch {
        Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message
        $result.Message = $_.Exception.Message
    }

    return $result
}

function Clear-ThumbnailCache {
    [CmdletBinding()]
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{ Success = $false; BytesRecovered = 0; Message = ''; ItemsCleaned = 0 }
    $thumbPath = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"

    if (-not (Test-Path $thumbPath)) {
        $result.Message = 'Thumbnail cache path not found'
        Write-Log -Level "WARNING" -Category "Cleaning" -Message $result.Message
        return $result
    }

    try {
        $thumbFiles = Get-ChildItem -Path $thumbPath -Filter 'thumbcache_*' -Force -ErrorAction SilentlyContinue
        foreach ($file in $thumbFiles) {
            try {
                $size = $file.Length
                if ($Preview) {
                    Write-Log -Level "INFO" -Category "Cleaning" -Message "Thumbnail $($file.Name) - $([math]::Round($size / 1MB, 2)) MB (Preview)"
                } elseif ($TestMode) {
                    Write-Log -Level "INFO" -Category "Cleaning" -Message "Thumbnail $($file.Name) - Test mode, skipped"
                } else {
                    Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                    $result.BytesRecovered += $size
                    $result.ItemsCleaned++
                    Write-Log -Level "SUCCESS" -Category "Cleaning" -Message "Removed thumbnail $($file.Name)"
                }
            } catch {
                Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message
            }
        }

        $result.Success = $true
        $result.Message = "Thumbnail cache cleaned - $([math]::Round($result.BytesRecovered / 1MB, 2)) MB recovered"
    } catch {
        Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message
        $result.Message = $_.Exception.Message
    }

    return $result
}

function Clear-PrefetchFiles {
    [CmdletBinding()]
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{ Success = $false; BytesRecovered = 0; Message = ''; ItemsCleaned = 0 }
    $prefetchPath = "$env:WINDIR\Prefetch"

    if (-not (Test-Path $prefetchPath)) {
        $result.Message = 'Prefetch path not found'
        Write-Log -Level "WARNING" -Category "Cleaning" -Message $result.Message
        return $result
    }

    try {
        $pfFiles = Get-ChildItem -Path $prefetchPath -Filter '*.pf' -Force -ErrorAction SilentlyContinue
        foreach ($file in $pfFiles) {
            try {
                $size = $file.Length
                if ($Preview) {
                    Write-Log -Level "INFO" -Category "Cleaning" -Message "Prefetch $($file.Name) - $([math]::Round($size / 1KB, 2)) KB (Preview)"
                } elseif ($TestMode) {
                    Write-Log -Level "INFO" -Category "Cleaning" -Message "Prefetch $($file.Name) - Test mode, skipped"
                } else {
                    Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                    $result.BytesRecovered += $size
                    $result.ItemsCleaned++
                    Write-Log -Level "SUCCESS" -Category "Cleaning" -Message "Removed prefetch $($file.Name)"
                }
            } catch {
                Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message
            }
        }

        $result.Success = $true
        $result.Message = "Prefetch cleaned - $([math]::Round($result.BytesRecovered / 1MB, 2)) MB recovered, $($result.ItemsCleaned) files"
    } catch {
        Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message
        $result.Message = $_.Exception.Message
    }

    return $result
}

function Clear-AllTempFiles {
    [CmdletBinding()]
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{ Success = $true; BytesRecovered = 0; Message = ''; ItemsCleaned = 0 }

    Write-Log -Level "INFO" -Category "Cleaning" -Message "Starting cleanup of all temp files"

    $cleaners = @(
        @{ Name = 'User Temp'; Func = { Clear-UserTemp -Preview:$Preview -TestMode:$TestMode } },
        @{ Name = 'System Temp'; Func = { Clear-SystemTemp -Preview:$Preview -TestMode:$TestMode } },
        @{ Name = 'Windows Update Cache'; Func = { Clear-WindowsUpdateCache -Preview:$Preview -TestMode:$TestMode } },
        @{ Name = 'Thumbnail Cache'; Func = { Clear-ThumbnailCache -Preview:$Preview -TestMode:$TestMode } },
        @{ Name = 'Prefetch'; Func = { Clear-PrefetchFiles -Preview:$Preview -TestMode:$TestMode } }
    )

    foreach ($cleaner in $cleaners) {
        try {
            $ret = & $cleaner.Func
            $result.BytesRecovered += $ret.BytesRecovered
            $result.ItemsCleaned += $ret.ItemsCleaned
        } catch {
            Write-Log -Level "WARNING" -Category "Cleaning" -Message "$($cleaner.Name) error: $($_.Exception.Message)"
        }
    }

    $result.Message = "All temp files cleaned - $([math]::Round($result.BytesRecovered / 1MB, 2)) MB recovered, $($result.ItemsCleaned) items"
    Write-Log -Level "SUCCESS" -Category "Cleaning" -Message $result.Message
    return $result
}
