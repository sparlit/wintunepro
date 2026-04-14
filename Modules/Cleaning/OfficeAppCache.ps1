#Requires -Version 5.1
<#
.SYNOPSIS
    Office App Cache Cleaning Module
.DESCRIPTION
    Functions for cleaning communication/collaboration app caches including
    Microsoft Teams, Zoom, and Slack.
#>

function global:Clear-TeamsCacheOffice {
    <#
    .SYNOPSIS
        Clears Microsoft Teams cache including blob storage, cache, and databases.
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
        try {
            $teamsProcs = Get-Process -Name "Teams","ms-teams" -ErrorAction SilentlyContinue
            if ($teamsProcs) {
                if (-not $WhatIf) {
                    $teamsProcs | Stop-Process -Force -ErrorAction Stop
                    Start-Sleep -Seconds 3
                }
                Write-Log -Level "INFO" -Category "System" -Message "Stopped Microsoft Teams processes" -Category "OfficeApp"
            }
        } catch {
            Write-Log -Level "WARNING" -Category "System" -Message "Could not stop Teams: $($_.Exception.Message)" -Category "OfficeApp"
        }

        $teamsPaths = @(
            "$env:APPDATA\Microsoft\Teams\blob_storage",
            "$env:APPDATA\Microsoft\Teams\Cache",
            "$env:APPDATA\Microsoft\Teams\databases",
            "$env:APPDATA\Microsoft\Teams\GPUCache",
            "$env:APPDATA\Microsoft\Teams\Code Cache",
            "$env:APPDATA\Microsoft\Teams\IndexedDB",
            "$env:APPDATA\Microsoft\Teams\Local Storage",
            "$env:APPDATA\Microsoft\Teams\tmp",
            "$env:LOCALAPPDATA\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams",
            "$env:LOCALAPPDATA\Packages\MSTeams_8wekyb3d8bbwe\LocalState"
        )

        foreach ($p in $Paths) {
            if ($p -match "\*") {
                $resolved = Resolve-Path -Path $p -ErrorAction SilentlyContinue
                if ($resolved) { $teamsPaths += $resolved.Path }
            } else {
                $teamsPaths += $p
            }
        }

        foreach ($path in $teamsPaths) {
            if (Test-Path $path) {
                try {
                    $size = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                             Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                    $count = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                              Measure-Object -ErrorAction SilentlyContinue).Count
                    if ($WhatIf) {
                        Write-Log -Level "INFO" -Category "System" -Message "Would remove $path ($count items)" -Category "OfficeApp"
                    } else {
                        Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction Stop
                        $result.BytesRecovered += if ($size) { $size } else { 0 }
                        $result.ItemsRemoved += if ($count) { $count } else { 0 }
                        Write-Log -Level "SUCCESS" -Category "OfficeApp" -Message "Cleared Teams cache: $path"
                    }
                } catch {
                    Write-Log -Level "WARNING" -Category "System" -Message "Failed to clear Teams cache '$path': $($_.Exception.Message)" -Category "OfficeApp"
                }
            }
        }

        $result.Success = $true
        $result.Message = "Teams cache cleared: $($result.ItemsRemoved) items, $([math]::Round(($result.BytesRecovered / 1MB), 2)) MB"
    } catch {
        $result.Message = "Error clearing Teams cache: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "System" -Message $result.Message -Category "OfficeApp"
    }

    return $result
}

function global:Clear-ZoomCacheOffice {
    <#
    .SYNOPSIS
        Clears Zoom cache, logs, and old update packages.
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
        try {
            $zoomProcs = Get-Process -Name "Zoom","ZoomPhone","CptHost" -ErrorAction SilentlyContinue
            if ($zoomProcs) {
                if (-not $WhatIf) {
                    $zoomProcs | Stop-Process -Force -ErrorAction Stop
                    Start-Sleep -Seconds 2
                }
                Write-Log -Level "INFO" -Category "System" -Message "Stopped Zoom processes" -Category "OfficeApp"
            }
        } catch {
            Write-Log -Level "WARNING" -Category "System" -Message "Could not stop Zoom: $($_.Exception.Message)" -Category "OfficeApp"
        }

        $zoomPaths = @(
            "$env:APPDATA\Zoom\bin",
            "$env:APPDATA\Zoom\data",
            "$env:APPDATA\Zoom\logs",
            "$env:APPDATA\Zoom\Depot",
            "$env:APPDATA\Zoom\Temp"
        )

        foreach ($p in $Paths) {
            if ($p -match "\*") {
                $resolved = Resolve-Path -Path $p -ErrorAction SilentlyContinue
                if ($resolved) { $zoomPaths += $resolved.Path }
            } else {
                $zoomPaths += $p
            }
        }

        foreach ($path in $zoomPaths) {
            if (Test-Path $path) {
                try {
                    $size = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                             Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                    if ($WhatIf) {
                        Write-Log -Level "INFO" -Category "System" -Message "Would remove $path" -Category "OfficeApp"
                    } else {
                        Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction Stop
                        $result.BytesRecovered += if ($size) { $size } else { 0 }
                        Write-Log -Level "SUCCESS" -Category "OfficeApp" -Message "Cleared Zoom cache: $path"
                    }
                } catch {
                    Write-Log -Level "WARNING" -Category "System" -Message "Failed to clear Zoom cache '$path': $($_.Exception.Message)" -Category "OfficeApp"
                }
            }
        }

        $result.Success = $true
        $result.Message = "Zoom cache cleared: $([math]::Round(($result.BytesRecovered / 1MB), 2)) MB"
    } catch {
        $result.Message = "Error clearing Zoom cache: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "System" -Message $result.Message -Category "OfficeApp"
    }

    return $result
}

function global:Clear-SlackCacheOffice {
    <#
    .SYNOPSIS
        Clears Slack cache, storage, and logs.
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
        try {
            $slackProcs = Get-Process -Name "Slack" -ErrorAction SilentlyContinue
            if ($slackProcs) {
                if (-not $WhatIf) {
                    $slackProcs | Stop-Process -Force -ErrorAction Stop
                    Start-Sleep -Seconds 3
                }
                Write-Log -Level "INFO" -Category "System" -Message "Stopped Slack processes" -Category "OfficeApp"
            }
        } catch {
            Write-Log -Level "WARNING" -Category "System" -Message "Could not stop Slack: $($_.Exception.Message)" -Category "OfficeApp"
        }

        $slackPaths = @(
            "$env:APPDATA\Slack\Cache",
            "$env:APPDATA\Slack\Code Cache",
            "$env:APPDATA\Slack\GPUCache",
            "$env:APPDATA\Slack\Session Storage",
            "$env:APPDATA\Slack\Local Storage",
            "$env:APPDATA\Slack\IndexedDB",
            "$env:APPDATA\Slack\logs",
            "$env:APPDATA\Slack\tmp"
        )

        foreach ($p in $Paths) {
            if ($p -match "\*") {
                $resolved = Resolve-Path -Path $p -ErrorAction SilentlyContinue
                if ($resolved) { $slackPaths += $resolved.Path }
            } else {
                $slackPaths += $p
            }
        }

        foreach ($path in $slackPaths) {
            if (Test-Path $path) {
                try {
                    $size = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                             Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                    if ($WhatIf) {
                        Write-Log -Level "INFO" -Category "System" -Message "Would remove $path" -Category "OfficeApp"
                    } else {
                        Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction Stop
                        $result.BytesRecovered += if ($size) { $size } else { 0 }
                        Write-Log -Level "SUCCESS" -Category "OfficeApp" -Message "Cleared Slack cache: $path"
                    }
                } catch {
                    Write-Log -Level "WARNING" -Category "System" -Message "Failed to clear Slack cache '$path': $($_.Exception.Message)" -Category "OfficeApp"
                }
            }
        }

        $result.Success = $true
        $result.Message = "Slack cache cleared: $([math]::Round(($result.BytesRecovered / 1MB), 2)) MB"
    } catch {
        $result.Message = "Error clearing Slack cache: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "System" -Message $result.Message -Category "OfficeApp"
    }

    return $result
}

function global:Clear-AllOfficeAppCaches {
    <#
    .SYNOPSIS
        Runs all office app cache cleaning functions.
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
        @{ Name = "Teams Cache"; Function = "Clear-TeamsCacheOffice" },
        @{ Name = "Zoom Cache";  Function = "Clear-ZoomCacheOffice" },
        @{ Name = "Slack Cache"; Function = "Clear-SlackCacheOffice" }
    )

    Write-Log -Level "INFO" -Category "System" -Message "Starting all office app cache cleanup" -Category "OfficeApp"

    foreach ($op in $operations) {
        try {
            Write-Log -Level "INFO" -Category "System" -Message "Cleaning $($op.Name)..." -Category "OfficeApp"
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
            Write-Log -Level "ERROR" -Category "System" -Message "Error in $($op.Name): $($_.Exception.Message)" -Category "OfficeApp"
            $results.Operations += @{
                Name           = $op.Name
                Success        = $false
                BytesRecovered = 0
                Message        = "Error: $($_.Exception.Message)"
            }
        }
    }

    $results.Success = $true
    $results.Message = "All office app caches cleared: $([math]::Round(($results.TotalBytesRecovered / 1MB), 2)) MB recovered"
    Write-Log -Level "SUCCESS" -Category "OfficeApp" -Message $results.Message

    return $results
}
