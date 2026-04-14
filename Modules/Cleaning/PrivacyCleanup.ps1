#Requires -Version 5.1
<#
.SYNOPSIS
    Privacy Cleanup Module
.DESCRIPTION
    Functions for clearing activity history, diagnostic data, and location
    history. Privacy settings are NOT re-enabled after clearing.
#>

function global:Clear-ActivityHistory {
    <#
    .SYNOPSIS
        Clears Windows Activity History and Timeline data.
        Does NOT re-enable tracking after clearing.
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
            $activityPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy"
            if (Test-Path $activityPath) {
                if (-not $WhatIf) {
                    Set-ItemProperty -Path $activityPath -Name "ActivityHistoryEnabled" -Value 0 -ErrorAction Stop
                    Write-Log -Level "INFO" -Category "System" -Message "Disabled local activity history storage" -Category "Privacy"
                }
            }
        } catch {
            Write-Log -Level "WARNING" -Category "System" -Message "Failed to disable activity history: $($_.Exception.Message)" -Category "Privacy"
        }

        try {
            $connectedAccountsPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy\ConnectedAccounts"
            if (Test-Path $connectedAccountsPath) {
                if (-not $WhatIf) {
                    Remove-Item -Path $connectedAccountsPath -Recurse -Force -ErrorAction Stop
                    $result.ItemsRemoved++
                    Write-Log -Level "SUCCESS" -Category "Privacy" -Message "Cleared connected accounts cache"
                }
            }
        } catch {
            Write-Log -Level "WARNING" -Category "System" -Message "Failed clearing connected accounts: $($_.Exception.Message)" -Category "Privacy"
        }

        try {
            $activitiesCachePaths = @(
                "$env:LOCALAPPDATA\ConnectedDevicesPlatform",
                "$env:LOCALAPPDATA\Packages\Microsoft.Windows.ContentDeliveryManager_cw5n1h2txyewy\LocalState\TargetedContentCache"
            )

            foreach ($path in $activitiesCachePaths) {
                if (Test-Path $path) {
                    try {
                        $size = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                                 Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                        if (-not $WhatIf) {
                            Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction Stop
                            $result.BytesRecovered += if ($size) { $size } else { 0 }
                        }
                        $result.ItemsRemoved++
                        Write-Log -Level "SUCCESS" -Category "Privacy" -Message "Cleared activity cache: $path"
                    } catch {
                        Write-Log -Level "WARNING" -Category "System" -Message "Failed clearing activity cache '$path': $($_.Exception.Message)" -Category "Privacy"
                    }
                }
            }
        } catch {
            Write-Log -Level "WARNING" -Category "System" -Message "Failed clearing activity cache: $($_.Exception.Message)" -Category "Privacy"
        }

        try {
            $activityFeedPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\TaskFlow\ActivityFeed"
            if (Test-Path $activityFeedPath) {
                if (-not $WhatIf) {
                    Remove-Item -Path $activityFeedPath -Recurse -Force -ErrorAction Stop
                    $result.ItemsRemoved++
                    Write-Log -Level "SUCCESS" -Category "Privacy" -Message "Cleared ActivityFeed registry cache"
                }
            }
        } catch {
            Write-Log -Level "WARNING" -Category "System" -Message "Failed clearing ActivityFeed: $($_.Exception.Message)" -Category "Privacy"
        }

        $result.Success = $true
        $result.Message = "Activity history cleared: $($result.ItemsRemoved) items, $([math]::Round(($result.BytesRecovered / 1MB), 2)) MB"
        Write-Log -Level "SUCCESS" -Category "Privacy" -Message $result.Message
    } catch {
        $result.Message = "Error clearing activity history: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "System" -Message $result.Message -Category "Privacy"
    }

    return $result
}

function global:Clear-DiagnosticData {
    <#
    .SYNOPSIS
        Clears Windows diagnostic and telemetry data.
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
        $diagPaths = @(
            "$env:ProgramData\Microsoft\Diagnosis",
            "$env:LOCALAPPDATA\Microsoft\Diagnosis",
            "$env:LOCALAPPDATA\Packages\windows.immersivecontrolpanel_cw5n1h2txyewy\TempState"
        )

        foreach ($p in $Paths) {
            if ($p -match "\*") {
                $resolved = Resolve-Path -Path $p -ErrorAction SilentlyContinue
                if ($resolved) { $diagPaths += $resolved.Path }
            } else {
                $diagPaths += $p
            }
        }

        foreach ($path in $diagPaths) {
            if (Test-Path $path) {
                try {
                    $size = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                             Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                    $count = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                              Measure-Object -ErrorAction SilentlyContinue).Count
                    if ($WhatIf) {
                        Write-Log -Level "INFO" -Category "System" -Message "Would remove $path ($count items)" -Category "Privacy"
                    } else {
                        Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction Stop
                        $result.BytesRecovered += if ($size) { $size } else { 0 }
                        $result.ItemsRemoved += if ($count) { $count } else { 0 }
                        Write-Log -Level "SUCCESS" -Category "Privacy" -Message "Cleared diagnostic data: $path"
                    }
                } catch {
                    Write-Log -Level "WARNING" -Category "System" -Message "Failed to clear diagnostic data '$path': $($_.Exception.Message)" -Category "Privacy"
                }
            }
        }

        try {
            $diagQueue = "$env:LOCALAPPDATA\Microsoft\Diagnosis\ETLLogs"
            if (Test-Path $diagQueue) {
                $etlSize = (Get-ChildItem -Path $diagQueue -Recurse -Force -ErrorAction SilentlyContinue |
                            Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                if (-not $WhatIf) {
                    Remove-Item -Path "$diagQueue\*" -Recurse -Force -ErrorAction Stop
                    $result.BytesRecovered += if ($etlSize) { $etlSize } else { 0 }
                }
            }
        } catch {
            Write-Log -Level "WARNING" -Category "System" -Message "Failed clearing ETL logs: $($_.Exception.Message)" -Category "Privacy"
        }

        $result.Success = $true
        $result.Message = "Diagnostic data cleared: $([math]::Round(($result.BytesRecovered / 1MB), 2)) MB"
        Write-Log -Level "SUCCESS" -Category "Privacy" -Message $result.Message
    } catch {
        $result.Message = "Error clearing diagnostic data: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "System" -Message $result.Message -Category "Privacy"
    }

    return $result
}

function global:Clear-LocationHistory {
    <#
    .SYNOPSIS
        Clears Windows location history and sensor data.
        Dynamically discovers user profiles.
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
            $locationPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"
            if (Test-Path $locationPath) {
                if (-not $WhatIf) {
                    Set-ItemProperty -Path $locationPath -Name "Value" -Value "Deny" -ErrorAction Stop
                    Write-Log -Level "INFO" -Category "System" -Message "Denied location access for apps" -Category "Privacy"
                }
            }
        } catch {
            Write-Log -Level "WARNING" -Category "System" -Message "Failed to update location consent: $($_.Exception.Message)" -Category "Privacy"
        }

        # Dynamically discover all user profile paths
        $locationPaths = @()
        try {
            $userDirs = Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue |
                        Where-Object { $_.Name -notin @("Default", "Default User", "Public", "All Users") }
            foreach ($userDir in $userDirs) {
                $locPath = Join-Path $userDir.FullName "AppData\Local\Microsoft\Windows\Location"
                if (Test-Path $locPath -ErrorAction SilentlyContinue) {
                    $locationPaths += $locPath
                }
            }
        } catch {
            Write-Log -Level "WARNING" -Category "System" -Message "Failed discovering user profiles: $($_.Exception.Message)" -Category "Privacy"
        }

        # Ensure current user path is included
        $currentUserLoc = "$env:LOCALAPPDATA\Microsoft\Windows\Location"
        if ((Test-Path $currentUserLoc) -and ($currentUserLoc -notin $locationPaths)) {
            $locationPaths += $currentUserLoc
        }

        foreach ($p in $Paths) {
            if ($p -match "\*") {
                $resolved = Resolve-Path -Path $p -ErrorAction SilentlyContinue
                if ($resolved) { $locationPaths += $resolved.Path }
            } else {
                $locationPaths += $p
            }
        }

        foreach ($path in $locationPaths) {
            if (Test-Path $path) {
                try {
                    $size = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                             Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                    if ($WhatIf) {
                        Write-Log -Level "INFO" -Category "System" -Message "Would remove $path" -Category "Privacy"
                    } else {
                        Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction Stop
                        $result.BytesRecovered += if ($size) { $size } else { 0 }
                        $result.ItemsRemoved++
                        Write-Log -Level "SUCCESS" -Category "Privacy" -Message "Cleared location history: $path"
                    }
                } catch {
                    Write-Log -Level "WARNING" -Category "System" -Message "Failed clearing location '$path': $($_.Exception.Message)" -Category "Privacy"
                }
            }
        }

        $result.Success = $true
        $result.Message = "Location history cleared: $([math]::Round(($result.BytesRecovered / 1MB), 2)) MB"
        Write-Log -Level "SUCCESS" -Category "Privacy" -Message $result.Message
    } catch {
        $result.Message = "Error clearing location history: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "System" -Message $result.Message -Category "Privacy"
    }

    return $result
}

function global:Clear-AllPrivacyCleanup {
    <#
    .SYNOPSIS
        Runs all privacy cleanup functions. Tracking settings remain disabled after clearing.
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
        @{ Name = "Activity History";  Function = "Clear-ActivityHistory" },
        @{ Name = "Diagnostic Data";   Function = "Clear-DiagnosticData" },
        @{ Name = "Location History";  Function = "Clear-LocationHistory" }
    )

    Write-Log -Level "INFO" -Category "System" -Message "Starting all privacy cleanup" -Category "Privacy"

    foreach ($op in $operations) {
        try {
            Write-Log -Level "INFO" -Category "System" -Message "Cleaning $($op.Name)..." -Category "Privacy"
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
            Write-Log -Level "ERROR" -Category "System" -Message "Error in $($op.Name): $($_.Exception.Message)" -Category "Privacy"
            $results.Operations += @{
                Name           = $op.Name
                Success        = $false
                BytesRecovered = 0
                Message        = "Error: $($_.Exception.Message)"
            }
        }
    }

    $results.Success = $true
    $results.Message = "All privacy data cleared: $([math]::Round(($results.TotalBytesRecovered / 1MB), 2)) MB recovered. Tracking remains disabled."
    Write-Log -Level "SUCCESS" -Category "Privacy" -Message $results.Message

    return $results
}
