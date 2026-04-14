<#
.SYNOPSIS
    WinTune Pro Boot Optimization Module
.DESCRIPTION
    Comprehensive boot optimization operations including startup optimization,
    boot time analysis, and performance tuning for faster system startup.
#>

# ============================================================================
# BOOT DIAGNOSTICS
# ============================================================================

function global:Get-BootTime {
    <#
    .SYNOPSIS
        Gets system boot time and duration information.
    #>

    $bootInfo = @{
        LastBootTime = $null
        BootDuration = 0
        BootDurationFormatted = ""
        BiosBootTime = 0
        KernelBootTime = 0
        BootProcesses = @()
        BootSlowProcesses = @()
    }

    try {
        $os = Get-WmiObject -Class Win32_OperatingSystem;$bootInfo.LastBootTime = $os.LastBootUpTime

        $bootEvents = Get-WinEvent -FilterHashtable @{
            LogName = 'Microsoft-Windows-Diagnostics-Performance/Operational'
            Id = 100
        } -MaxEvents 1 -ErrorAction SilentlyContinue

        if ($bootEvents) {
            $eventXml = [xml]$bootEvents[0].ToXml()
            $bootDuration = [int]$eventXml.Event.EventData.Data | Where-Object { $_.Name -eq 'BootTime' }

            if ($bootDuration) {
                $bootInfo.BootDuration = $bootDuration
                $bootInfo.BootDurationFormatted = Format-BootDuration -Seconds $bootDuration
            }
        }

        if ($bootInfo.BootDuration -eq 0) {
            $perfData = Get-WmiObject -Class Win32_PerformanceFormattedData_PerfOS_System -ErrorAction SilentlyContinue
            if ($perfData) {
                $systemUptime = $perfData.SystemUpTime
                $bootInfo.BootDuration = $systemUptime
                $bootInfo.BootDurationFormatted = Format-BootDuration -Seconds $systemUptime
            }
        }

        $bootInfo.BootProcesses = Get-BootProcessList

        $bootInfo.BootSlowProcesses = $bootInfo.BootProcesses |
            Where-Object { $_.EstimatedImpact -gt 1000 } |
            Sort-Object EstimatedImpact -Descending |
            Select-Object -First 10

    } catch {
        Write-Log -Level "ERROR" -Category "BootOptimization" -Message "Error getting boot time: $($_.Exception.Message)"
    }

    return $bootInfo
}

function global:Format-BootDuration {
    <#
    .SYNOPSIS
        Formats boot duration in seconds to human-readable format.
    #>
    param([int]$Seconds)

    if ($Seconds -lt 60) {
        return "$Seconds seconds"
    } elseif ($Seconds -lt 3600) {
        $minutes = [Math]::Floor($Seconds / 60)
        $secs = $Seconds % 60
        return "$minutes min $secs sec"
    } else {
        $hours = [Math]::Floor($Seconds / 3600)
        $minutes = [Math]::Floor(($Seconds % 3600) / 60)
        return "$hours hr $minutes min"
    }
}

function global:Get-BootProcessList {
    <#
    .SYNOPSIS
        Gets a list of processes that run during boot.
    #>

    $processes = @()

    try {
        $startupItems = Get-WmiObject -Class Win32_StartupCommand -ErrorAction SilentlyContinue
        foreach ($item in $startupItems) {
            $processes += [PSCustomObject]@{
                Name = $item.Name
                Command = $item.Command
                Location = $item.Location
                Type = "Startup"
                EstimatedImpact = 500
                CanDisable = $true
            }
        }
    } catch {
        Write-Log -Level "WARNING" -Category "BootOptimization" -Message "Error getting startup items: $($_.Exception.Message)"
    }

    try {
        $drivers = Get-WmiObject Win32_SystemDriver | Where-Object {
            $_.StartMode -eq 'Boot' -and $_.State -eq 'Running'
        }
        foreach ($driver in $drivers) {
            $processes += [PSCustomObject]@{
                Name = $driver.DisplayName
                Command = $driver.PathName
                Location = "Boot Driver"
                Type = "Driver"
                EstimatedImpact = 100
                CanDisable = $false
            }
        }
    } catch {
        Write-Log -Level "WARNING" -Category "BootOptimization" -Message "Error getting boot drivers: $($_.Exception.Message)"
    }

    try {
        $autoServices = Get-Service | Where-Object {
            $_.StartType -eq 'Automatic' -and $_.Status -eq 'Running'
        }
        foreach ($service in $autoServices) {
            $processes += [PSCustomObject]@{
                Name = $service.DisplayName
                Command = ""
                Location = "Services"
                Type = "Service"
                EstimatedImpact = 200
                CanDisable = $true
            }
        }
    } catch {
        Write-Log -Level "WARNING" -Category "BootOptimization" -Message "Error getting auto services: $($_.Exception.Message)"
    }

    return $processes
}

function global:Get-BootPerformanceReport {
    <#
    .SYNOPSIS
        Generates a comprehensive boot performance report.
    #>

    $report = @{
        OverallScore = 100
        Rating = "Excellent"
        BootTime = $null
        StartupItems = 0
        AutoServices = 0
        BootDrivers = 0
        Recommendations = @()
        Issues = @()
    }

    $bootTime = Get-BootTime
    $report.BootTime = $bootTime

    $report.StartupItems = ($bootTime.BootProcesses | Where-Object { $_.Type -eq "Startup" }).Count
    $report.AutoServices = ($bootTime.BootProcesses | Where-Object { $_.Type -eq "Service" }).Count
    $report.BootDrivers = ($bootTime.BootProcesses | Where-Object { $_.Type -eq "Driver" }).Count

    if ($bootTime.BootDuration -gt 180) {
        $report.OverallScore -= 30
        $report.Issues += "Boot time exceeds 3 minutes"
        $report.Rating = "Poor"
    } elseif ($bootTime.BootDuration -gt 120) {
        $report.OverallScore -= 20
        $report.Issues += "Boot time exceeds 2 minutes"
        $report.Rating = "Fair"
    } elseif ($bootTime.BootDuration -gt 60) {
        $report.OverallScore -= 10
        $report.Issues += "Boot time exceeds 1 minute"
        $report.Rating = "Good"
    }

    if ($report.StartupItems -gt 20) {
        $report.OverallScore -= 15
        $report.Issues += "High number of startup items ($($report.StartupItems))"
        $report.Recommendations += "Consider reducing startup programs"
    } elseif ($report.StartupItems -gt 10) {
        $report.OverallScore -= 5
        $report.Recommendations += "Review startup programs for optimization"
    }

    if ($bootTime.BootSlowProcesses.Count -gt 5) {
        $report.OverallScore -= 10
        $report.Issues += "Multiple slow boot processes detected"
        $report.Recommendations += "Review and disable unnecessary slow-starting programs"
    }

    $report.OverallScore = [Math]::Max(0, $report.OverallScore)

    if ($report.OverallScore -ge 80) { $report.Rating = "Excellent" }
    elseif ($report.OverallScore -ge 60) { $report.Rating = "Good" }
    elseif ($report.OverallScore -ge 40) { $report.Rating = "Fair" }
    else { $report.Rating = "Poor" }

    return $report
}

# ============================================================================
# BOOT OPTIMIZATION OPERATIONS
# ============================================================================

function global:Optimize-BootConfiguration {
    <#
    .SYNOPSIS
        Optimizes boot configuration for faster startup.
    #>
    param(
        [switch]$Preview,
        [switch]$Force
    )

    $result = @{
        Success = $true
        Message = ""
        Changes = @()
        Errors = @()
    }

    if ($Preview) {
        $result.Message = "[PREVIEW] Would optimize boot configuration"
        $result.Changes = @(
            "Enable fast startup",
            "Optimize boot timeout",
            "Configure prefetch parameters",
            "Optimize boot verification"
        )
        return $result
    }

    Write-Log -Level "INFO" -Category "BootOptimization" -Message "Starting boot configuration optimization..."

    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Message = "Administrator privileges required"
        $result.Errors += "Not running as administrator"
        return $result
    }

    Register-Operation -Operation "BootConfigurationOptimization" -Data @{
        Timestamp = Get-Date
    }

    try {
        $fastStartupPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
        $fastStartup = Get-ItemProperty -Path $fastStartupPath -Name "HiberbootEnabled" -ErrorAction SilentlyContinue
        if ($null -eq $fastStartup -or $fastStartup.HiberbootEnabled -ne 1) {
            Set-ItemProperty -Path $fastStartupPath -Name "HiberbootEnabled" -Value 1 -Force
            $result.Changes += "Fast Startup enabled"
            Write-Log -Level "SUCCESS" -Category "BootOptimization" -Message "Fast Startup enabled"
        }
    } catch {
        $result.Errors += "Fast Startup: $($_.Exception.Message)"
    }

    try {
        $bcdPath = "HKLM:\SYSTEM\CurrentControlSet\Control"
        $timeout = Get-ItemProperty -Path $bcdPath -Name "SystemStartOptions" -ErrorAction SilentlyContinue
        $osCount = (Get-WmiObject -Class Win32_OperatingSystem).Caption
        bcdedit /set timeout 0 | Out-Null
        $result.Changes += "Boot menu timeout minimized"
    } catch {
        $result.Errors += "Boot timeout: $($_.Exception.Message)"
    }

    try {
        $prefetchPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"
        Set-ItemProperty -Path $prefetchPath -Name "EnablePrefetcher" -Value 3 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $prefetchPath -Name "EnableSuperfetch" -Value 3 -Force -ErrorAction SilentlyContinue
        $result.Changes += "Prefetch parameters optimized"
    } catch {
        $result.Errors += "Prefetch: $($_.Exception.Message)"
    }

    try {
        $bootVerifyPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
        Set-ItemProperty -Path $bootVerifyPath -Name "BootExecute" -Value "autocheck autochk *" -Force -ErrorAction SilentlyContinue
        $result.Changes += "Boot verification optimized"
    } catch {
        $result.Errors += "Boot verification: $($_.Exception.Message)"
    }

    try {
        $prefetchFolder = "$env:SystemRoot\Prefetch"
        if (Test-Path $prefetchFolder) {
            $oldPrefetchCount = (Get-ChildItem $prefetchFolder -ErrorAction SilentlyContinue).Count
            Write-Log -Level "DEBUG" -Category "BootOptimization" -Message "Prefetch folder contains $oldPrefetchCount files (managed by Windows)"
        }
    } catch {
        Write-Log -Level "DEBUG" -Category "BootOptimization" -Message "Error checking prefetch folder: $($_.Exception.Message)"
    }

    $result.Message = "Boot configuration optimized with $($result.Changes.Count) changes"
    if ($result.Errors.Count -gt 0) {
        $result.Message += " (with $($result.Errors.Count) warnings)"
        Write-Log -Level "WARNING" -Category "BootOptimization" -Message $result.Message
    } else {
        Write-Log -Level "SUCCESS" -Category "BootOptimization" -Message $result.Message
    }

    $script:State.OperationsExecuted += "BootConfigurationOptimization"

    return $result
}

function global:Optimize-StartupItems {
    <#
    .SYNOPSIS
        Optimizes startup items for faster boot.
    #>
    param(
        [switch]$Preview,
        [switch]$DisableNonEssential,
        [switch]$RemoveInvalid,
        [string[]]$KeepEnabled = @()
    )

    $result = @{
        Success = $true
        Message = ""
        ItemsDisabled = 0
        ItemsRemoved = 0
        InvalidRemoved = 0
        Details = @()
        Errors = @()
    }

    if ($Preview) {
        $result.Message = "[PREVIEW] Would optimize startup items"
        return $result
    }

    Write-Log -Level "INFO" -Category "BootOptimization" -Message "Analyzing startup items for optimization..."

    $startupItems = Get-StartupItems

    if ($RemoveInvalid) {
        $invalidItems = $startupItems | Where-Object { $_.ValidTarget -eq $false }
        foreach ($item in $invalidItems) {
            $disableResult = Disable-StartupItem -Name $item.Name -Location $item.Location -Force
            if ($disableResult.Success) {
                $result.InvalidRemoved++
                $result.Details += "Removed invalid: $($item.Name)"
            }
        }
    }

    if ($DisableNonEssential) {
        $safeCategories = @("Update", "Other", "Gaming/Media")
        $toDisable = $startupItems | Where-Object {
            $_.Category -in $safeCategories -and
            $_.Risk -eq "Low" -and
            $_.Name -notin $KeepEnabled
        }
        foreach ($item in $toDisable) {
            $disableResult = Disable-StartupItem -Name $item.Name -Location $item.Location
            if ($disableResult.Success) {
                $result.ItemsDisabled++
                $result.Details += "Disabled: $($item.Name)"
            }
        }
    }

    $result.Message = "Startup optimization: $($result.ItemsDisabled) disabled, $($result.InvalidRemoved) invalid removed"
    Write-Log -Level "SUCCESS" -Category "BootOptimization" -Message $result.Message

    return $result
}

function global:Optimize-BootServices {
    <#
    .SYNOPSIS
        Optimizes services that affect boot time.
    #>
    param(
        [switch]$Preview,
        [switch]$Aggressive
    )

    $result = @{
        Success = $true
        Message = ""
        ServicesChanged = 0
        Changes = @()
        Errors = @()
    }

    if ($Preview) {
        $result.Message = "[PREVIEW] Would optimize boot services"
        return $result
    }

    Write-Log -Level "INFO" -Category "BootOptimization" -Message "Optimizing boot services..."

    $bootOptServices = @{
        "Spooler" = "Manual"
        "Fax" = "Manual"
        "WMPNetworkSvc" = "Manual"
        "RemoteRegistry" = "Disabled"
        "WinRM" = "Manual"
        "XblAuthManager" = "Manual"
        "XblGameSave" = "Manual"
        "XboxNetApiSvc" = "Manual"
        "DiagTrack" = "Disabled"
        "dmwappushservice" = "Disabled"
        "TrkWks" = "Manual"
        "WSearch" = "AutomaticDelayedStart"
    }

    if ($Aggressive) {
        $newEntry = @{
            "SysMain" = "Disabled"
            "WerSvc" = "Disabled"
            "wscsvc" = "AutomaticDelayedStart"
        }
        foreach ($key in $newEntry.Keys) { $bootOptServices[$key] = $newEntry[$key] }
    }

    foreach ($service in $bootOptServices.Keys) {
        try {
            $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
            if ($svc) {
                $targetStartType = $bootOptServices[$service]
                $startType = $targetStartType -replace "AutomaticDelayedStart", "Automatic"
                if ($svc.StartType -ne $startType) {
                    if (Get-Command 'Set-ServiceStartupType' -ErrorAction SilentlyContinue) {
                        $svcResult = Set-ServiceStartupType -Name $service -StartupType $startType
                    } else {
                        Set-Service -Name $service -StartupType $startType -Force
                    }
                    if ($targetStartType -eq "AutomaticDelayedStart") {
                        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$service"
                        Set-ItemProperty -Path $regPath -Name "DelayedAutostart" -Value 1 -Force -ErrorAction SilentlyContinue
                    }
                    $result.ServicesChanged++
                    $result.Changes += "$service -> $targetStartType"
                    Write-Log -Level "DEBUG" -Category "BootOptimization" -Message "Service $service set to $targetStartType"
                }
            }
        } catch {
            $result.Errors += "$service : $($_.Exception.Message)"
        }
    }

    $result.Message = "Boot services optimized: $($result.ServicesChanged) services modified"
    Write-Log -Level "SUCCESS" -Category "BootOptimization" -Message $result.Message

    return $result
}

# ============================================================================
# BOOT ADVANCED SETTINGS
# ============================================================================

function global:Set-BootAdvancedOptions {
    <#
    .SYNOPSIS
        Configures advanced boot options for performance.
    #>
    param(
        [switch]$EnableFastBoot,
        [switch]$DisableBootLogo,
        [switch]$DisableBootAnimation,
        [switch]$NoGuiBoot,
        [switch]$Preview
    )

    $result = @{
        Success = $true
        Message = ""
        Changes = @()
        Errors = @()
    }

    if ($Preview) {
        $result.Message = "[PREVIEW] Would configure advanced boot options"
        return $result
    }

    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Message = "Administrator privileges required"
        return $result
    }

    try {
        if ($EnableFastBoot) {
            bcdedit /set bootuxdisabled on | Out-Null
            $result.Changes += "Boot UX disabled for faster boot"
        }
        if ($NoGuiBoot) {
            bcdedit /set noumex on | Out-Null
            $result.Changes += "No GUI boot enabled"
        }
        if ($DisableBootLogo -or $DisableBootAnimation) {
            bcdedit /set quietboot on | Out-Null
            $result.Changes += "Quiet boot enabled (no logo/animation)"
        }
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
    }

    $result.Message = "Advanced boot options configured: $($result.Changes.Count) changes"
    Write-Log -Level "INFO" -Category "BootOptimization" -Message $result.Message

    return $result
}

function global:Invoke-CompleteBootOptimization {
    <#
    .SYNOPSIS
        Performs complete boot optimization with all available options.
    #>
    param(
        [switch]$Preview,
        [switch]$Aggressive,
        [switch]$IncludeServices,
        [switch]$IncludeStartup
    )

    $result = @{
        Success = $true
        Message = ""
        TotalChanges = 0
        BootConfig = $null
        StartupOpt = $null
        ServiceOpt = $null
        Errors = @()
    }

    Write-Log -Level "INFO" -Category "BootOptimization" -Message "Starting complete boot optimization..."

    $result.BootConfig = Optimize-BootConfiguration -Preview:$Preview
    $result.TotalChanges += $result.BootConfig.Changes.Count

    if ($IncludeStartup) {
        $result.StartupOpt = Optimize-StartupItems -Preview:$Preview -DisableNonEssential -RemoveInvalid
        $result.TotalChanges += $result.StartupOpt.ItemsDisabled + $result.StartupOpt.InvalidRemoved
    }

    if ($IncludeServices) {
        $result.ServiceOpt = Optimize-BootServices -Preview:$Preview -Aggressive:$Aggressive
        $result.TotalChanges += $result.ServiceOpt.ServicesChanged
    }

    if ($result.BootConfig.Errors) { $result.Errors += $result.BootConfig.Errors }
    if ($result.StartupOpt -and $result.StartupOpt.Errors) { $result.Errors += $result.StartupOpt.Errors }
    if ($result.ServiceOpt -and $result.ServiceOpt.Errors) { $result.Errors += $result.ServiceOpt.Errors }

    $result.Message = "Complete boot optimization finished: $([Math]::Max(0, $result.TotalChanges)) total changes"
    Write-Log -Level "SUCCESS" -Category "BootOptimization" -Message $result.Message
    $script:State.OperationsExecuted += "CompleteBootOptimization"

    return $result
}

# ============================================================================
# BOOT DEFENDER OPTIMIZATION
# ============================================================================

function global:Optimize-DefenderBootScan {
    <#
    .SYNOPSIS
        Optimizes Windows Defender boot-time scanning behavior.
    #>
    param(
        [switch]$DisableBootScan,
        [switch]$Preview
    )

    $result = @{
        Success = $true
        Message = ""
        Changes = @()
        Errors = @()
    }

    if ($Preview) {
        $result.Message = "[PREVIEW] Would optimize Defender boot scan settings"
        return $result
    }

    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Message = "Administrator privileges required"
        return $result
    }

    try {
        $defenderPrefsPath = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Real-Time Protection"
        if ($DisableBootScan) {
            Set-ItemProperty -Path $defenderPrefsPath -Name "DisableBootScanning" -Value 1 -Force -ErrorAction SilentlyContinue
            $result.Changes += "Boot-time scanning disabled"
            Write-Log -Level "WARNING" -Category "BootOptimization" -Message "WARNING: Boot-time scanning disabled - security impact"
        } else {
            Set-ItemProperty -Path $defenderPrefsPath -Name "DisableBootScanning" -Value 0 -Force -ErrorAction SilentlyContinue
            $result.Changes += "Boot-time scanning enabled"
        }
        $result.Message = "Defender boot scan configuration updated"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        $result.Message = "Failed to configure Defender boot scan"
    }

    return $result
}

