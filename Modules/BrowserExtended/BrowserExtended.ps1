#Requires -Version 5.1
<#
.SYNOPSIS
    WinTune Pro BrowserExtended Module - Extended browser cleaning
.DESCRIPTION
    Extended browser cache cleaning for Opera, Brave, Vivaldi, Opera GX, and Safari
#>

function global:Clear-OperaBrowserCache {
    <#
    .SYNOPSIS
        Clears Opera browser cache, cookies, and session data.
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

    $operaPaths = @(
        "$env:APPDATA\Opera Software\Opera Stable"
        "$env:LOCALAPPDATA\Opera Software\Opera Stable"
    )

    $cleanDirs = @("Cache", "Cookies", "Session Storage", "GPUCache", "Code Cache", "Service Worker")
    $cleanFiles = @("Cookies", "Cookies-journal", "Visited Links", "Top Sites", "Favicons")

    $found = $false
    foreach ($basePath in $operaPaths) {
        if (-not (Test-Path $basePath)) { continue }
        $found = $true

        Write-Log -Level "INFO" -Category "BrowserExtended" -Message "Cleaning Opera at: $basePath"

        foreach ($dir in $cleanDirs) {
            $fullPath = Join-Path $basePath $dir
            if (Test-Path $fullPath) {
                try {
                    $size = (Get-ChildItem -Path $fullPath -Recurse -Force -ErrorAction SilentlyContinue |
                        Measure-Object -Property Length -Sum).Sum
                    if (-not $size) { $size = 0 }

                    if ($Preview) {
                        Write-Log -Level "INFO" -Category "BrowserExtended" -Message "[Preview] Would clean Opera $dir - $(Format-FileSize $size)"
                    } elseif ($TestMode) {
                        Write-Log -Level "INFO" -Category "BrowserExtended" -Message "[TestMode] Opera $dir flagged for cleaning"
                    } else {
                        Remove-Item -Path $fullPath -Recurse -Force -ErrorAction SilentlyContinue
                        Write-Log -Level "SUCCESS" -Category "BrowserExtended" -Message "Cleaned Opera $dir"
                    }
                    $result.SpaceRecovered += $size
                    $result.ItemsCleaned++
                } catch {
                    Write-Log -Level "WARNING" -Category "BrowserExtended" -Message "Error cleaning Opera $dir : $($_.Exception.Message)"
                }
            }
        }

        foreach ($file in $cleanFiles) {
            $fullPath = Join-Path $basePath $file
            if (Test-Path $fullPath) {
                try {
                    $size = (Get-Item -Path $fullPath -Force -ErrorAction SilentlyContinue).Length
                    if (-not $size) { $size = 0 }

                    if ($Preview) {
                        Write-Log -Level "INFO" -Category "BrowserExtended" -Message "[Preview] Would remove Opera file: $file"
                    } elseif ($TestMode) {
                        Write-Log -Level "INFO" -Category "BrowserExtended" -Message "[TestMode] Opera file $file flagged"
                    } else {
                        Remove-Item -Path $fullPath -Force -ErrorAction SilentlyContinue
                        Write-Log -Level "SUCCESS" -Category "BrowserExtended" -Message "Removed Opera file: $file"
                    }
                    $result.SpaceRecovered += $size
                    $result.ItemsCleaned++
                } catch {
                    Write-Log -Level "WARNING" -Category "BrowserExtended" -Message "Error removing Opera file $file : $($_.Exception.Message)"
                }
            }
        }
    }

    if (-not $found) {
        Write-Log -Level "INFO" -Category "BrowserExtended" -Message "Opera not found - skipping"
        return $result
    }

    Write-Log -Level "SUCCESS" -Category "BrowserExtended" -Message "Opera cleanup complete: $(Format-FileSize $result.SpaceRecovered) recovered, $($result.ItemsCleaned) items cleaned"
    return $result
}

function global:Clear-BraveBrowserCache {
    <#
    .SYNOPSIS
        Clears Brave browser cache, cookies, and session data.
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

    $bravePath = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data"

    if (-not (Test-Path $bravePath)) {
        Write-Log -Level "INFO" -Category "BrowserExtended" -Message "Brave not found - skipping"
        return $result
    }

    Write-Log -Level "INFO" -Category "BrowserExtended" -Message "Cleaning Brave at: $bravePath"

    $profiles = Get-ChildItem -Path $bravePath -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq "Default" -or $_.Name -like "Profile *" }

    foreach ($profile in $profiles) {
        $cleanDirs = @("Cache", "Cookies", "Session Storage", "GPUCache", "Code Cache", "Service Worker", "Session Storage")
        $cleanFiles = @("Cookies", "Cookies-journal", "Visited Links", "Top Sites", "Favicons", "History", "History-journal")

        foreach ($dir in $cleanDirs) {
            $fullPath = Join-Path $profile.FullName $dir
            if (Test-Path $fullPath) {
                try {
                    $size = (Get-ChildItem -Path $fullPath -Recurse -Force -ErrorAction SilentlyContinue |
                        Measure-Object -Property Length -Sum).Sum
                    if (-not $size) { $size = 0 }

                    if ($Preview) {
                        Write-Log -Level "INFO" -Category "BrowserExtended" -Message "[Preview] Would clean Brave $($profile.Name)\$dir - $(Format-FileSize $size)"
                    } elseif ($TestMode) {
                        Write-Log -Level "INFO" -Category "BrowserExtended" -Message "[TestMode] Brave $($profile.Name)\$dir flagged"
                    } else {
                        Remove-Item -Path $fullPath -Recurse -Force -ErrorAction SilentlyContinue
                        Write-Log -Level "SUCCESS" -Category "BrowserExtended" -Message "Cleaned Brave $($profile.Name)\$dir"
                    }
                    $result.SpaceRecovered += $size
                    $result.ItemsCleaned++
                } catch {
                    Write-Log -Level "WARNING" -Category "BrowserExtended" -Message "Error cleaning Brave $dir : $($_.Exception.Message)"
                }
            }
        }

        foreach ($file in $cleanFiles) {
            $fullPath = Join-Path $profile.FullName $file
            if (Test-Path $fullPath) {
                try {
                    $size = (Get-Item -Path $fullPath -Force -ErrorAction SilentlyContinue).Length
                    if (-not $size) { $size = 0 }

                    if ($Preview) {
                        Write-Log -Level "INFO" -Category "BrowserExtended" -Message "[Preview] Would remove Brave file: $($profile.Name)\$file"
                    } elseif ($TestMode) {
                        Write-Log -Level "INFO" -Category "BrowserExtended" -Message "[TestMode] Brave file $($profile.Name)\$file flagged"
                    } else {
                        Remove-Item -Path $fullPath -Force -ErrorAction SilentlyContinue
                        Write-Log -Level "SUCCESS" -Category "BrowserExtended" -Message "Removed Brave file: $($profile.Name)\$file"
                    }
                    $result.SpaceRecovered += $size
                    $result.ItemsCleaned++
                } catch {
                    Write-Log -Level "WARNING" -Category "BrowserExtended" -Message "Error removing Brave file $file : $($_.Exception.Message)"
                }
            }
        }
    }

    Write-Log -Level "SUCCESS" -Category "BrowserExtended" -Message "Brave cleanup complete: $(Format-FileSize $result.SpaceRecovered) recovered, $($result.ItemsCleaned) items cleaned"
    return $result
}

function global:Clear-VivaldiBrowserCache {
    <#
    .SYNOPSIS
        Clears Vivaldi browser cache, cookies, and session data.
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

    $vivaldiPath = "$env:LOCALAPPDATA\Vivaldi\User Data"

    if (-not (Test-Path $vivaldiPath)) {
        Write-Log -Level "INFO" -Category "BrowserExtended" -Message "Vivaldi not found - skipping"
        return $result
    }

    Write-Log -Level "INFO" -Category "BrowserExtended" -Message "Cleaning Vivaldi at: $vivaldiPath"

    $profiles = Get-ChildItem -Path $vivaldiPath -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq "Default" -or $_.Name -like "Profile *" }

    foreach ($profile in $profiles) {
        $cleanDirs = @("Cache", "Cookies", "Session Storage", "GPUCache", "Code Cache", "Service Worker")
        $cleanFiles = @("Cookies", "Cookies-journal", "Visited Links", "Top Sites", "Favicons")

        foreach ($dir in $cleanDirs) {
            $fullPath = Join-Path $profile.FullName $dir
            if (Test-Path $fullPath) {
                try {
                    $size = (Get-ChildItem -Path $fullPath -Recurse -Force -ErrorAction SilentlyContinue |
                        Measure-Object -Property Length -Sum).Sum
                    if (-not $size) { $size = 0 }

                    if ($Preview) {
                        Write-Log -Level "INFO" -Category "BrowserExtended" -Message "[Preview] Would clean Vivaldi $($profile.Name)\$dir - $(Format-FileSize $size)"
                    } elseif ($TestMode) {
                        Write-Log -Level "INFO" -Category "BrowserExtended" -Message "[TestMode] Vivaldi $($profile.Name)\$dir flagged"
                    } else {
                        Remove-Item -Path $fullPath -Recurse -Force -ErrorAction SilentlyContinue
                        Write-Log -Level "SUCCESS" -Category "BrowserExtended" -Message "Cleaned Vivaldi $($profile.Name)\$dir"
                    }
                    $result.SpaceRecovered += $size
                    $result.ItemsCleaned++
                } catch {
                    Write-Log -Level "WARNING" -Category "BrowserExtended" -Message "Error cleaning Vivaldi $dir : $($_.Exception.Message)"
                }
            }
        }

        foreach ($file in $cleanFiles) {
            $fullPath = Join-Path $profile.FullName $file
            if (Test-Path $fullPath) {
                try {
                    $size = (Get-Item -Path $fullPath -Force -ErrorAction SilentlyContinue).Length
                    if (-not $size) { $size = 0 }

                    if ($Preview) {
                        Write-Log -Level "INFO" -Category "BrowserExtended" -Message "[Preview] Would remove Vivaldi file: $($profile.Name)\$file"
                    } elseif ($TestMode) {
                        Write-Log -Level "INFO" -Category "BrowserExtended" -Message "[TestMode] Vivaldi file $($profile.Name)\$file flagged"
                    } else {
                        Remove-Item -Path $fullPath -Force -ErrorAction SilentlyContinue
                        Write-Log -Level "SUCCESS" -Category "BrowserExtended" -Message "Removed Vivaldi file: $($profile.Name)\$file"
                    }
                    $result.SpaceRecovered += $size
                    $result.ItemsCleaned++
                } catch {
                    Write-Log -Level "WARNING" -Category "BrowserExtended" -Message "Error removing Vivaldi file $file : $($_.Exception.Message)"
                }
            }
        }
    }

    Write-Log -Level "SUCCESS" -Category "BrowserExtended" -Message "Vivaldi cleanup complete: $(Format-FileSize $result.SpaceRecovered) recovered, $($result.ItemsCleaned) items cleaned"
    return $result
}

function global:Clear-SafariBrowserCache {
    <#
    .SYNOPSIS
        Clears Safari browser cache (Windows version).
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

    $safariPath = "$env:APPDATA\Apple Computer\Safari"
    $safariLocalPath = "$env:LOCALAPPDATA\Apple Computer\Safari"

    $found = $false

    foreach ($basePath in @($safariPath, $safariLocalPath)) {
        if (-not (Test-Path $basePath)) { continue }
        $found = $true

        Write-Log -Level "INFO" -Category "BrowserExtended" -Message "Cleaning Safari at: $basePath"

        $cleanDirs = @("Cache", "WebKitCache", "Caches")
        $cleanFiles = @("History.plist", "History.db", "WebpageIcons.db", "Bookmarks.plist")

        foreach ($dir in $cleanDirs) {
            $fullPath = Join-Path $basePath $dir
            if (Test-Path $fullPath) {
                try {
                    $size = (Get-ChildItem -Path $fullPath -Recurse -Force -ErrorAction SilentlyContinue |
                        Measure-Object -Property Length -Sum).Sum
                    if (-not $size) { $size = 0 }

                    if ($Preview) {
                        Write-Log -Level "INFO" -Category "BrowserExtended" -Message "[Preview] Would clean Safari $dir - $(Format-FileSize $size)"
                    } elseif ($TestMode) {
                        Write-Log -Level "INFO" -Category "BrowserExtended" -Message "[TestMode] Safari $dir flagged"
                    } else {
                        Remove-Item -Path $fullPath -Recurse -Force -ErrorAction SilentlyContinue
                        Write-Log -Level "SUCCESS" -Category "BrowserExtended" -Message "Cleaned Safari $dir"
                    }
                    $result.SpaceRecovered += $size
                    $result.ItemsCleaned++
                } catch {
                    Write-Log -Level "WARNING" -Category "BrowserExtended" -Message "Error cleaning Safari $dir : $($_.Exception.Message)"
                }
            }
        }
    }

    if (-not $found) {
        Write-Log -Level "INFO" -Category "BrowserExtended" -Message "Safari not found - skipping"
        return $result
    }

    Write-Log -Level "SUCCESS" -Category "BrowserExtended" -Message "Safari cleanup complete: $(Format-FileSize $result.SpaceRecovered) recovered, $($result.ItemsCleaned) items cleaned"
    return $result
}

function global:Clear-OperaGXCache {
    <#
    .SYNOPSIS
        Clears Opera GX gaming browser cache, cookies, and session data.
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

    $operaGXPaths = @(
        "$env:APPDATA\Opera Software\Opera GX Stable"
        "$env:LOCALAPPDATA\Opera Software\Opera GX Stable"
    )

    $cleanDirs = @("Cache", "Cookies", "Session Storage", "GPUCache", "Code Cache", "Service Worker")
    $cleanFiles = @("Cookies", "Cookies-journal", "Visited Links", "Top Sites", "Favicons")

    $found = $false
    foreach ($basePath in $operaGXPaths) {
        if (-not (Test-Path $basePath)) { continue }
        $found = $true

        Write-Log -Level "INFO" -Category "BrowserExtended" -Message "Cleaning Opera GX at: $basePath"

        foreach ($dir in $cleanDirs) {
            $fullPath = Join-Path $basePath $dir
            if (Test-Path $fullPath) {
                try {
                    $size = (Get-ChildItem -Path $fullPath -Recurse -Force -ErrorAction SilentlyContinue |
                        Measure-Object -Property Length -Sum).Sum
                    if (-not $size) { $size = 0 }

                    if ($Preview) {
                        Write-Log -Level "INFO" -Category "BrowserExtended" -Message "[Preview] Would clean Opera GX $dir - $(Format-FileSize $size)"
                    } elseif ($TestMode) {
                        Write-Log -Level "INFO" -Category "BrowserExtended" -Message "[TestMode] Opera GX $dir flagged"
                    } else {
                        Remove-Item -Path $fullPath -Recurse -Force -ErrorAction SilentlyContinue
                        Write-Log -Level "SUCCESS" -Category "BrowserExtended" -Message "Cleaned Opera GX $dir"
                    }
                    $result.SpaceRecovered += $size
                    $result.ItemsCleaned++
                } catch {
                    Write-Log -Level "WARNING" -Category "BrowserExtended" -Message "Error cleaning Opera GX $dir : $($_.Exception.Message)"
                }
            }
        }

        foreach ($file in $cleanFiles) {
            $fullPath = Join-Path $basePath $file
            if (Test-Path $fullPath) {
                try {
                    $size = (Get-Item -Path $fullPath -Force -ErrorAction SilentlyContinue).Length
                    if (-not $size) { $size = 0 }

                    if ($Preview) {
                        Write-Log -Level "INFO" -Category "BrowserExtended" -Message "[Preview] Would remove Opera GX file: $file"
                    } elseif ($TestMode) {
                        Write-Log -Level "INFO" -Category "BrowserExtended" -Message "[TestMode] Opera GX file $file flagged"
                    } else {
                        Remove-Item -Path $fullPath -Force -ErrorAction SilentlyContinue
                        Write-Log -Level "SUCCESS" -Category "BrowserExtended" -Message "Removed Opera GX file: $file"
                    }
                    $result.SpaceRecovered += $size
                    $result.ItemsCleaned++
                } catch {
                    Write-Log -Level "WARNING" -Category "BrowserExtended" -Message "Error removing Opera GX file $file : $($_.Exception.Message)"
                }
            }
        }
    }

    if (-not $found) {
        Write-Log -Level "INFO" -Category "BrowserExtended" -Message "Opera GX not found - skipping"
        return $result
    }

    Write-Log -Level "SUCCESS" -Category "BrowserExtended" -Message "Opera GX cleanup complete: $(Format-FileSize $result.SpaceRecovered) recovered, $($result.ItemsCleaned) items cleaned"
    return $result
}

function global:Clear-AllExtendedBrowsers {
    <#
    .SYNOPSIS
        Orchestrator that cleans all extended browsers.
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
        Browsers      = @{}
    }

    Write-Log -Level "INFO" -Category "BrowserExtended" -Message "Starting extended browser cleanup..."

    $result.Browsers.Opera = Clear-OperaBrowserCache -Preview:$Preview -TestMode:$TestMode
    $result.SpaceRecovered += $result.Browsers.Opera.SpaceRecovered
    $result.ItemsCleaned += $result.Browsers.Opera.ItemsCleaned

    $result.Browsers.Brave = Clear-BraveBrowserCache -Preview:$Preview -TestMode:$TestMode
    $result.SpaceRecovered += $result.Browsers.Brave.SpaceRecovered
    $result.ItemsCleaned += $result.Browsers.Brave.ItemsCleaned

    $result.Browsers.Vivaldi = Clear-VivaldiBrowserCache -Preview:$Preview -TestMode:$TestMode
    $result.SpaceRecovered += $result.Browsers.Vivaldi.SpaceRecovered
    $result.ItemsCleaned += $result.Browsers.Vivaldi.ItemsCleaned

    $result.Browsers.Safari = Clear-SafariBrowserCache -Preview:$Preview -TestMode:$TestMode
    $result.SpaceRecovered += $result.Browsers.Safari.SpaceRecovered
    $result.ItemsCleaned += $result.Browsers.Safari.ItemsCleaned

    $result.Browsers.OperaGX = Clear-OperaGXCache -Preview:$Preview -TestMode:$TestMode
    $result.SpaceRecovered += $result.Browsers.OperaGX.SpaceRecovered
    $result.ItemsCleaned += $result.Browsers.OperaGX.ItemsCleaned

    Write-Log -Level "SUCCESS" -Category "BrowserExtended" -Message "Extended browser cleanup complete: $(Format-FileSize $result.SpaceRecovered) recovered, $($result.ItemsCleaned) items cleaned"
    return $result
}

function global:Get-ExtendedBrowserFolderSize {
    <#
    .SYNOPSIS
        Calculates the total size of extended browser cache folders.
    #>
    param(
        [switch]$IncludeOpera,
        [switch]$IncludeBrave,
        [switch]$IncludeVivaldi,
        [switch]$IncludeSafari,
        [switch]$IncludeOperaGX
    )

    $result = @{
        TotalSize   = 0
        Opera       = 0
        Brave       = 0
        Vivaldi     = 0
        Safari      = 0
        OperaGX     = 0
        Breakdown   = @{}
    }

    $allSelected = (-not $IncludeOpera -and -not $IncludeBrave -and -not $IncludeVivaldi -and -not $IncludeSafari -and -not $IncludeOperaGX)

    if ($IncludeOpera -or $allSelected) {
        $operaPaths = @("$env:APPDATA\Opera Software\Opera Stable", "$env:LOCALAPPDATA\Opera Software\Opera Stable")
        foreach ($p in $operaPaths) {
            if (Test-Path $p) {
                $size = (Get-ChildItem -Path $p -Recurse -Force -ErrorAction SilentlyContinue |
                    Measure-Object -Property Length -Sum).Sum
                if ($size) { $result.Opera += $size }
            }
        }
        $result.Breakdown.Opera = $result.Opera
    }

    if ($IncludeBrave -or $allSelected) {
        $bravePath = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data"
        if (Test-Path $bravePath) {
            $size = (Get-ChildItem -Path $bravePath -Recurse -Force -ErrorAction SilentlyContinue |
                Measure-Object -Property Length -Sum).Sum
            if ($size) { $result.Brave = $size }
        }
        $result.Breakdown.Brave = $result.Brave
    }

    if ($IncludeVivaldi -or $allSelected) {
        $vivaldiPath = "$env:LOCALAPPDATA\Vivaldi\User Data"
        if (Test-Path $vivaldiPath) {
            $size = (Get-ChildItem -Path $vivaldiPath -Recurse -Force -ErrorAction SilentlyContinue |
                Measure-Object -Property Length -Sum).Sum
            if ($size) { $result.Vivaldi = $size }
        }
        $result.Breakdown.Vivaldi = $result.Vivaldi
    }

    if ($IncludeSafari -or $allSelected) {
        $safariPaths = @("$env:APPDATA\Apple Computer\Safari", "$env:LOCALAPPDATA\Apple Computer\Safari")
        foreach ($p in $safariPaths) {
            if (Test-Path $p) {
                $size = (Get-ChildItem -Path $p -Recurse -Force -ErrorAction SilentlyContinue |
                    Measure-Object -Property Length -Sum).Sum
                if ($size) { $result.Safari += $size }
            }
        }
        $result.Breakdown.Safari = $result.Safari
    }

    if ($IncludeOperaGX -or $allSelected) {
        $operaGXPaths = @("$env:APPDATA\Opera Software\Opera GX Stable", "$env:LOCALAPPDATA\Opera Software\Opera GX Stable")
        foreach ($p in $operaGXPaths) {
            if (Test-Path $p) {
                $size = (Get-ChildItem -Path $p -Recurse -Force -ErrorAction SilentlyContinue |
                    Measure-Object -Property Length -Sum).Sum
                if ($size) { $result.OperaGX += $size }
            }
        }
        $result.Breakdown.OperaGX = $result.OperaGX
    }

    $result.TotalSize = $result.Opera + $result.Brave + $result.Vivaldi + $result.Safari + $result.OperaGX
    return $result
}
