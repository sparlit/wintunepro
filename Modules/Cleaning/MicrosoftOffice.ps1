#Requires -Version 5.1
<#
.SYNOPSIS
    Microsoft Office Cache Cleaning Module
.DESCRIPTION
    Functions for cleaning Microsoft Office application caches including
    Word, Excel, PowerPoint, Outlook, and OneNote.
#>

function global:Clear-OfficeCacheComplete {
    <#
    .SYNOPSIS
        Clears Microsoft Office common caches (MRU, temp, converter cache).
    #>
    param(
        [string[]]$Paths = @(),
        [switch]$WhatIf
    )

    $result = @{
        Success       = $false
        Message       = ""
        BytesRecovered = 0
        ItemsRemoved  = 0
    }

    try {
        $officePaths = @(
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\Wef",
            "$env:LOCALAPPDATA\Microsoft\Office\15.0\Wef",
            "$env:APPDATA\Microsoft\Office\Recent",
            "$env:LOCALAPPDATA\Microsoft\Office\OTele"
        )

        foreach ($p in $Paths) {
            if ($p -match "\*") {
                $resolved = Resolve-Path -Path $p -ErrorAction SilentlyContinue
                if ($resolved) { $officePaths += $resolved.Path }
            } else {
                $officePaths += $p
            }
        }

        $officeVersions = @("16.0", "15.0")
        foreach ($ver in $officeVersions) {
            $apps = @("Word", "Excel", "PowerPoint", "Access")
            foreach ($app in $apps) {
                try {
                    $mruPath = "HKCU:\SOFTWARE\Microsoft\Office\$ver\$app\File MRU"
                    if (Test-Path $mruPath) {
                        if (-not $WhatIf) {
                            Remove-ItemProperty -Path $mruPath -Name "*" -ErrorAction Stop
                            Write-Log -Level "SUCCESS" -Category "Office" -Message "Cleared $app MRU entries"
                        }
                    }
                } catch {
                    Write-Log -Level "WARNING" -Category "System" -Message "Failed to clear $app MRU: $($_.Exception.Message)" -Category "Office"
                }
            }
        }

        foreach ($path in $officePaths) {
            if (Test-Path $path) {
                try {
                    $size = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                             Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                    $count = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                              Measure-Object -ErrorAction SilentlyContinue).Count
                    if ($WhatIf) {
                        Write-Log -Level "INFO" -Category "System" -Message "Would remove $path ($count items)" -Category "Office"
                    } else {
                        Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction Stop
                        $result.BytesRecovered += if ($size) { $size } else { 0 }
                        $result.ItemsRemoved += if ($count) { $count } else { 0 }
                        Write-Log -Level "SUCCESS" -Category "Office" -Message "Cleared Office cache: $path"
                    }
                } catch {
                    Write-Log -Level "WARNING" -Category "System" -Message "Failed to clear Office cache '$path': $($_.Exception.Message)" -Category "Office"
                }
            }
        }

        $result.Success = $true
        $result.Message = "Office cache cleared: $([math]::Round(($result.BytesRecovered / 1MB), 2)) MB"
    } catch {
        $result.Message = "Error clearing Office cache: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "System" -Message $result.Message -Category "Office"
    }

    return $result
}

function global:Clear-WordCacheComplete {
    <#
    .SYNOPSIS
        Clears Microsoft Word-specific caches and temp files.
    #>
    param(
        [string[]]$Paths = @(),
        [switch]$WhatIf
    )

    $result = @{
        Success       = $false
        Message       = ""
        BytesRecovered = 0
        ItemsRemoved  = 0
    }

    try {
        $wordPaths = @(
            "$env:APPDATA\Microsoft\Word",
            "$env:LOCALAPPDATA\Microsoft\Word"
        )

        foreach ($p in $Paths) {
            if ($p -match "\*") {
                $resolved = Resolve-Path -Path $p -ErrorAction SilentlyContinue
                if ($resolved) { $wordPaths += $resolved.Path }
            } else {
                $wordPaths += $p
            }
        }

        foreach ($basePath in $wordPaths) {
            if (-not (Test-Path $basePath)) { continue }
            try {
                $tempFiles = Get-ChildItem -Path $basePath -File -Force -ErrorAction SilentlyContinue |
                             Where-Object { $_.Name -match "^~\$|\.tmp$" }
                foreach ($file in $tempFiles) {
                    try {
                        if (-not $WhatIf) {
                            $result.BytesRecovered += $file.Length
                            Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                            $result.ItemsRemoved++
                        }
                    } catch {
                        Write-Log -Level "WARNING" -Category "System" -Message "Failed to remove Word temp '$($file.FullName)': $($_.Exception.Message)" -Category "Office"
                    }
                }
            } catch {
                Write-Log -Level "WARNING" -Category "System" -Message "Failed processing Word path '$basePath': $($_.Exception.Message)" -Category "Office"
            }
        }

        Write-Log -Level "SUCCESS" -Category "Office" -Message "Cleared Word cache"
        $result.Success = $true
        $result.Message = "Word cache cleared: $([math]::Round(($result.BytesRecovered / 1MB), 2)) MB"
    } catch {
        $result.Message = "Error clearing Word cache: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "System" -Message $result.Message -Category "Office"
    }

    return $result
}

function global:Clear-ExcelCacheComplete {
    <#
    .SYNOPSIS
        Clears Microsoft Excel-specific caches and temp files.
    #>
    param(
        [string[]]$Paths = @(),
        [switch]$WhatIf
    )

    $result = @{
        Success       = $false
        Message       = ""
        BytesRecovered = 0
        ItemsRemoved  = 0
    }

    try {
        $excelPaths = @(
            "$env:APPDATA\Microsoft\Excel",
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\Excel"
        )

        foreach ($p in $Paths) {
            if ($p -match "\*") {
                $resolved = Resolve-Path -Path $p -ErrorAction SilentlyContinue
                if ($resolved) { $excelPaths += $resolved.Path }
            } else {
                $excelPaths += $p
            }
        }

        foreach ($path in $excelPaths) {
            if (Test-Path $path) {
                try {
                    $tempFiles = Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                                 Where-Object { -not $_.PSIsContainer -and $_.Name -match "^~\$|\.tmp$" }
                    foreach ($file in $tempFiles) {
                        try {
                            if (-not $WhatIf) {
                                $result.BytesRecovered += $file.Length
                                Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                                $result.ItemsRemoved++
                            }
                        } catch {
                            Write-Log -Level "WARNING" -Category "System" -Message "Failed to remove Excel temp '$($file.FullName)': $($_.Exception.Message)" -Category "Office"
                        }
                    }
                } catch {
                    Write-Log -Level "WARNING" -Category "System" -Message "Failed to clear Excel cache '$path': $($_.Exception.Message)" -Category "Office"
                }
            }
        }

        Write-Log -Level "SUCCESS" -Category "Office" -Message "Cleared Excel cache"
        $result.Success = $true
        $result.Message = "Excel cache cleared: $([math]::Round(($result.BytesRecovered / 1MB), 2)) MB"
    } catch {
        $result.Message = "Error clearing Excel cache: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "System" -Message $result.Message -Category "Office"
    }

    return $result
}

function global:Clear-PowerPointCacheComplete {
    <#
    .SYNOPSIS
        Clears Microsoft PowerPoint-specific caches and temp files.
    #>
    param(
        [string[]]$Paths = @(),
        [switch]$WhatIf
    )

    $result = @{
        Success       = $false
        Message       = ""
        BytesRecovered = 0
        ItemsRemoved  = 0
    }

    try {
        $pptPaths = @(
            "$env:APPDATA\Microsoft\PowerPoint",
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\PowerPoint"
        )

        foreach ($p in $Paths) {
            if ($p -match "\*") {
                $resolved = Resolve-Path -Path $p -ErrorAction SilentlyContinue
                if ($resolved) { $pptPaths += $resolved.Path }
            } else {
                $pptPaths += $p
            }
        }

        foreach ($path in $pptPaths) {
            if (Test-Path $path) {
                try {
                    $size = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                             Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                    if ($WhatIf) {
                        Write-Log -Level "INFO" -Category "System" -Message "Would remove $path" -Category "Office"
                    } else {
                        Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction Stop
                        $result.BytesRecovered += if ($size) { $size } else { 0 }
                        Write-Log -Level "SUCCESS" -Category "Office" -Message "Cleared PowerPoint cache: $path"
                    }
                } catch {
                    Write-Log -Level "WARNING" -Category "System" -Message "Failed to clear PowerPoint cache '$path': $($_.Exception.Message)" -Category "Office"
                }
            }
        }

        $result.Success = $true
        $result.Message = "PowerPoint cache cleared: $([math]::Round(($result.BytesRecovered / 1MB), 2)) MB"
    } catch {
        $result.Message = "Error clearing PowerPoint cache: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "System" -Message $result.Message -Category "Office"
    }

    return $result
}

function global:Clear-OutlookCacheComplete {
    <#
    .SYNOPSIS
        Clears Microsoft Outlook caches including temp and RoamCache files.
        Preserves OST/PST data files.
    #>
    param(
        [string[]]$Paths = @(),
        [switch]$WhatIf
    )

    $result = @{
        Success       = $false
        Message       = ""
        BytesRecovered = 0
        ItemsRemoved  = 0
    }

    try {
        $outlookPaths = @(
            "$env:LOCALAPPDATA\Microsoft\Outlook",
            "$env:APPDATA\Microsoft\Outlook",
            "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\Content.Outlook"
        )

        foreach ($p in $Paths) {
            if ($p -match "\*") {
                $resolved = Resolve-Path -Path $p -ErrorAction SilentlyContinue
                if ($resolved) { $outlookPaths += $resolved.Path }
            } else {
                $outlookPaths += $p
            }
        }

        foreach ($path in $outlookPaths) {
            if (Test-Path $path) {
                try {
                    $filesToClean = Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                                    Where-Object { -not $_.PSIsContainer -and $_.Extension -notmatch "\.ost$|\.pst$" -and $_.Name -match "\.tmp$|^~\$|RoamCache" }
                    foreach ($file in $filesToClean) {
                        try {
                            if (-not $WhatIf) {
                                $result.BytesRecovered += $file.Length
                                Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                                $result.ItemsRemoved++
                            }
                        } catch {
                            Write-Log -Level "WARNING" -Category "System" -Message "Failed to remove Outlook temp '$($file.FullName)': $($_.Exception.Message)" -Category "Office"
                        }
                    }
                } catch {
                    Write-Log -Level "WARNING" -Category "System" -Message "Failed processing Outlook path '$path': $($_.Exception.Message)" -Category "Office"
                }
            }
        }

        Write-Log -Level "SUCCESS" -Category "Office" -Message "Cleared Outlook cache"
        $result.Success = $true
        $result.Message = "Outlook cache cleared: $($result.ItemsRemoved) items, $([math]::Round(($result.BytesRecovered / 1MB), 2)) MB"
    } catch {
        $result.Message = "Error clearing Outlook cache: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "System" -Message $result.Message -Category "Office"
    }

    return $result
}

function global:Clear-OneNoteCacheComplete {
    <#
    .SYNOPSIS
        Clears Microsoft OneNote caches and temp files.
    #>
    param(
        [string[]]$Paths = @(),
        [switch]$WhatIf
    )

    $result = @{
        Success       = $false
        Message       = ""
        BytesRecovered = 0
        ItemsRemoved  = 0
    }

    try {
        $oneNotePaths = @(
            "$env:LOCALAPPDATA\Microsoft\OneNote\16.0\cache",
            "$env:LOCALAPPDATA\Microsoft\OneNote\15.0\cache",
            "$env:LOCALAPPDATA\Microsoft\OneNote\backup"
        )

        foreach ($p in $Paths) {
            if ($p -match "\*") {
                $resolved = Resolve-Path -Path $p -ErrorAction SilentlyContinue
                if ($resolved) { $oneNotePaths += $resolved.Path }
            } else {
                $oneNotePaths += $p
            }
        }

        foreach ($path in $oneNotePaths) {
            if (Test-Path $path) {
                try {
                    $size = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                             Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                    if ($WhatIf) {
                        Write-Log -Level "INFO" -Category "System" -Message "Would remove $path" -Category "Office"
                    } else {
                        Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction Stop
                        $result.BytesRecovered += if ($size) { $size } else { 0 }
                        Write-Log -Level "SUCCESS" -Category "Office" -Message "Cleared OneNote cache: $path"
                    }
                } catch {
                    Write-Log -Level "WARNING" -Category "System" -Message "Failed to clear OneNote cache '$path': $($_.Exception.Message)" -Category "Office"
                }
            }
        }

        $result.Success = $true
        $result.Message = "OneNote cache cleared: $([math]::Round(($result.BytesRecovered / 1MB), 2)) MB"
    } catch {
        $result.Message = "Error clearing OneNote cache: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "System" -Message $result.Message -Category "Office"
    }

    return $result
}

function global:Clear-AllOfficeCacheComplete {
    <#
    .SYNOPSIS
        Runs all Microsoft Office cache cleaning functions.
    #>
    param(
        [switch]$WhatIf
    )

    $results = @{
        Success       = $false
        Message       = ""
        TotalBytesRecovered = 0
        TotalItemsRemoved = 0
        Operations    = @()
    }

    $operations = @(
        @{ Name = "Office Common Cache"; Function = "Clear-OfficeCacheComplete" },
        @{ Name = "Word Cache";          Function = "Clear-WordCacheComplete" },
        @{ Name = "Excel Cache";         Function = "Clear-ExcelCacheComplete" },
        @{ Name = "PowerPoint Cache";    Function = "Clear-PowerPointCacheComplete" },
        @{ Name = "Outlook Cache";       Function = "Clear-OutlookCacheComplete" },
        @{ Name = "OneNote Cache";       Function = "Clear-OneNoteCacheComplete" }
    )

    Write-Log -Level "INFO" -Category "System" -Message "Starting all Office cache cleanup" -Category "Office"

    foreach ($op in $operations) {
        try {
            Write-Log -Level "INFO" -Category "System" -Message "Cleaning $($op.Name)..." -Category "Office"
            if ($WhatIf) {
                $result = & $op.Function -WhatIf
            } else {
                $result = & $op.Function
            }
            $results.Operations += @{
                Name           = $op.Name
                Success        = $result.Success
                BytesRecovered = $result.BytesRecovered
                Message        = $result.Message
            }
            $results.TotalBytesRecovered += $result.BytesRecovered
            $results.TotalItemsRemoved += $result.ItemsRemoved
        } catch {
            Write-Log -Level "ERROR" -Category "System" -Message "Error in $($op.Name): $($_.Exception.Message)" -Category "Office"
            $results.Operations += @{
                Name           = $op.Name
                Success        = $false
                BytesRecovered = 0
                Message        = "Error: $($_.Exception.Message)"
            }
        }
    }

    $results.Success = $true
    $results.Message = "All Office caches cleared: $([math]::Round(($results.TotalBytesRecovered / 1MB), 2)) MB recovered"
    Write-Log -Level "SUCCESS" -Category "Office" -Message $results.Message

    return $results
}
