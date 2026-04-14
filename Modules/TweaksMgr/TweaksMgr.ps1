<#
.SYNOPSIS
    WinTunePro TweaksMgr Module - System tweaks and optimizations
.DESCRIPTION
    Manages system tweaks and optimizations across performance, privacy, gaming,
    UI, Explorer, and network categories.
.NOTES
    File: Modules\TweaksMgr\TweaksMgr.ps1
    Version: 1.0.0
    PowerShell: 5.1+
    Compatible: Windows 10, Windows 11
#>

#Requires -Version 5.1

$script:TweakDatabase = @()

function global:Initialize-TweakDatabase {
    $script:TweakDatabase = @(
        # Performance Tweaks
        @{
            Name = "DisableAnimations"
            Category = "Performance"
            Description = "Disable window animations"
            Apply = {
                Set-ItemProperty -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value "0" -ErrorAction Stop
            }
            Revert = {
                Set-ItemProperty -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value "1" -ErrorAction Stop
            }
            CheckState = {
                try { (Get-ItemProperty -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -ErrorAction Stop).MinAnimate -eq "0" } catch { $false }
            }
        },
        @{
            Name = "DisableTransparency"
            Category = "Performance"
            Description = "Disable transparency effects"
            Apply = {
                Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 0 -Type DWord -ErrorAction Stop
            }
            Revert = {
                Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 1 -Type DWord -ErrorAction Stop
            }
            CheckState = {
                try { (Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -ErrorAction Stop).EnableTransparency -eq 0 } catch { $false }
            }
        },
        @{
            Name = "DisableTips"
            Category = "Performance"
            Description = "Disable Windows tips and suggestions"
            Apply = {
                Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SoftLandingEnabled" -Value 0 -Type DWord -ErrorAction Stop
                Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338389Enabled" -Value 0 -Type DWord -ErrorAction Stop
                Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-310093Enabled" -Value 0 -Type DWord -ErrorAction Stop
            }
            Revert = {
                Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SoftLandingEnabled" -Value 1 -Type DWord -ErrorAction Stop
                Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338389Enabled" -Value 1 -Type DWord -ErrorAction Stop
            }
            CheckState = {
                try { (Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -ErrorAction Stop).SoftLandingEnabled -eq 0 } catch { $false }
            }
        },
        @{
            Name = "DisableConsumerFeatures"
            Category = "Performance"
            Description = "Disable Windows consumer features (suggestions)"
            Apply = {
                Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SilentInstalledAppsEnabled" -Value 0 -Type DWord -ErrorAction Stop
                Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -Value 1 -Type DWord -ErrorAction Stop
            }
            Revert = {
                Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SilentInstalledAppsEnabled" -Value 1 -Type DWord -ErrorAction Stop
                Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -ErrorAction SilentlyContinue
            }
            CheckState = {
                try { (Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -ErrorAction Stop).SilentInstalledAppsEnabled -eq 0 } catch { $false }
            }
        },
        # Privacy Tweaks
        @{
            Name = "DisableTelemetry"
            Category = "Privacy"
            Description = "Disable telemetry data collection"
            Apply = {
                Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -Type DWord -ErrorAction Stop
                Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Value 0 -Type DWord -ErrorAction Stop
                Stop-Service -Name "DiagTrack" -Force -ErrorAction SilentlyContinue
                Set-Service -Name "DiagTrack" -StartupType Disabled -ErrorAction SilentlyContinue
            }
            Revert = {
                Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 3 -Type DWord -ErrorAction Stop
                Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -ErrorAction SilentlyContinue
                Set-Service -Name "DiagTrack" -StartupType Automatic -ErrorAction SilentlyContinue
                Start-Service -Name "DiagTrack" -ErrorAction SilentlyContinue
            }
            CheckState = {
                try { (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -ErrorAction Stop).AllowTelemetry -eq 0 } catch { $false }
            }
        },
        @{
            Name = "DisableLocation"
            Category = "Privacy"
            Description = "Disable location tracking"
            Apply = {
                Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -Name "DisableLocation" -Value 1 -Type DWord -ErrorAction Stop
                Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeviceAccess\Global\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" -Name "Value" -Value "Deny" -ErrorAction Stop
            }
            Revert = {
                Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -Name "DisableLocation" -ErrorAction SilentlyContinue
                Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeviceAccess\Global\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" -Name "Value" -Value "Allow" -ErrorAction Stop
            }
            CheckState = {
                try { (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -ErrorAction Stop).DisableLocation -eq 1 } catch { $false }
            }
        },
        @{
            Name = "DisableAdvertisingID"
            Category = "Privacy"
            Description = "Disable advertising ID tracking"
            Apply = {
                Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0 -Type DWord -ErrorAction Stop
            }
            Revert = {
                Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 1 -Type DWord -ErrorAction Stop
            }
            CheckState = {
                try { (Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -ErrorAction Stop).Enabled -eq 0 } catch { $false }
            }
        },
        @{
            Name = "DisableCortana"
            Category = "Privacy"
            Description = "Disable Cortana digital assistant"
            Apply = {
                Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -Value 0 -Type DWord -ErrorAction Stop
            }
            Revert = {
                Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -ErrorAction SilentlyContinue
            }
            CheckState = {
                try { (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -ErrorAction Stop).AllowCortana -eq 0 } catch { $false }
            }
        },
        # Gaming Tweaks
        @{
            Name = "EnableGameMode"
            Category = "Gaming"
            Description = "Enable Game Mode"
            Apply = {
                Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "AllowAutoGameMode" -Value 1 -Type DWord -ErrorAction Stop
                Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Value 1 -Type DWord -ErrorAction Stop
            }
            Revert = {
                Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "AllowAutoGameMode" -Value 0 -Type DWord -ErrorAction Stop
                Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Value 0 -Type DWord -ErrorAction Stop
            }
            CheckState = {
                try { (Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -ErrorAction Stop).AutoGameModeEnabled -eq 1 } catch { $false }
            }
        },
        @{
            Name = "DisableGameBar"
            Category = "Gaming"
            Description = "Disable Game Bar overlay"
            Apply = {
                Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "UseNexusForGameBarEnabled" -Value 0 -Type DWord -ErrorAction Stop
                Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Value 0 -Type DWord -ErrorAction Stop
            }
            Revert = {
                Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "UseNexusForGameBarEnabled" -Value 1 -Type DWord -ErrorAction Stop
                Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -ErrorAction SilentlyContinue
            }
            CheckState = {
                try { (Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -ErrorAction Stop).UseNexusForGameBarEnabled -eq 0 } catch { $false }
            }
        },
        @{
            Name = "DisableFullscreenOptimizations"
            Category = "Gaming"
            Description = "Disable fullscreen optimizations globally"
            Apply = {
                Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehaviorMode" -Value 2 -Type DWord -ErrorAction Stop
                Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 1 -Type DWord -ErrorAction Stop
                Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehavior" -Value 2 -Type DWord -ErrorAction Stop
                Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Value 1 -Type DWord -ErrorAction Stop
            }
            Revert = {
                Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehaviorMode" -Value 0 -Type DWord -ErrorAction Stop
                Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 0 -Type DWord -ErrorAction Stop
            }
            CheckState = {
                try { (Get-ItemProperty -Path "HKCU:\System\GameConfigStore" -ErrorAction Stop).GameDVR_FSEBehaviorMode -eq 2 } catch { $false }
            }
        },
        @{
            Name = "EnableGPUScheduling"
            Category = "Gaming"
            Description = "Enable hardware-accelerated GPU scheduling"
            Apply = {
                Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Value 2 -Type DWord -ErrorAction Stop
            }
            Revert = {
                Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Value 1 -Type DWord -ErrorAction Stop
            }
            CheckState = {
                try { (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -ErrorAction Stop).HwSchMode -eq 2 } catch { $false }
            }
        },
        # UI Tweaks
        @{
            Name = "ShowFileExtensions"
            Category = "UI"
            Description = "Show file extensions in Explorer"
            Apply = {
                Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0 -Type DWord -ErrorAction Stop
            }
            Revert = {
                Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 1 -Type DWord -ErrorAction Stop
            }
            CheckState = {
                try { (Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -ErrorAction Stop).HideFileExt -eq 0 } catch { $false }
            }
        },
        @{
            Name = "ShowHiddenFiles"
            Category = "UI"
            Description = "Show hidden files in Explorer"
            Apply = {
                Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1 -Type DWord -ErrorAction Stop
            }
            Revert = {
                Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 2 -Type DWord -ErrorAction Stop
            }
            CheckState = {
                try { (Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -ErrorAction Stop).Hidden -eq 1 } catch { $false }
            }
        },
        @{
            Name = "DisableRecentFiles"
            Category = "UI"
            Description = "Disable recent files history"
            Apply = {
                Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "ShowRecent" -Value 0 -Type DWord -ErrorAction Stop
            }
            Revert = {
                Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "ShowRecent" -Value 1 -Type DWord -ErrorAction Stop
            }
            CheckState = {
                try { (Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -ErrorAction Stop).ShowRecent -eq 0 } catch { $false }
            }
        },
        # Explorer Tweaks
        @{
            Name = "DisableQuickAccess"
            Category = "Explorer"
            Description = "Open Explorer to This PC instead of Quick Access"
            Apply = {
                Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "LaunchTo" -Value 1 -Type DWord -ErrorAction Stop
            }
            Revert = {
                Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "LaunchTo" -Value 2 -Type DWord -ErrorAction Stop
            }
            CheckState = {
                try { (Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -ErrorAction Stop).LaunchTo -eq 1 } catch { $false }
            }
        },
        @{
            Name = "DisableSearchBar"
            Category = "Explorer"
            Description = "Hide search bar in taskbar"
            Apply = {
                Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 0 -Type DWord -ErrorAction Stop
            }
            Revert = {
                Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 1 -Type DWord -ErrorAction Stop
            }
            CheckState = {
                try { (Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -ErrorAction Stop).SearchboxTaskbarMode -eq 0 } catch { $false }
            }
        },
        @{
            Name = "ClassicContextMenu"
            Category = "Explorer"
            Description = "Restore classic right-click context menu"
            Apply = {
                New-Item -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" -Force -ErrorAction Stop | Out-Null
            }
            Revert = {
                Remove-Item -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" -Recurse -Force -ErrorAction SilentlyContinue
            }
            CheckState = {
                Test-Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
            }
        },
        # Network Tweaks
        @{
            Name = "DisableBandwidthThrottling"
            Category = "Network"
            Description = "Remove Windows bandwidth reservation"
            Apply = {
                Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched" -Name "NonBestEffortLimit" -Value 0 -Type DWord -ErrorAction Stop
            }
            Revert = {
                Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched" -Name "NonBestEffortLimit" -ErrorAction SilentlyContinue
            }
            CheckState = {
                try { (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched" -ErrorAction Stop).NonBestEffortLimit -eq 0 } catch { $false }
            }
        },
        @{
            Name = "OptimizeTCPSettings"
            Category = "Network"
            Description = "Optimize TCP auto-tuning and congestion provider"
            Apply = {
                & netsh int tcp set global autotuninglevel=normal 2>&1 | Out-Null
                & netsh int tcp set global congestionprovider=ctcp 2>&1 | Out-Null
                Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TcpAckFrequency" -Value 1 -Type DWord -ErrorAction Stop
                Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TCPNoDelay" -Value 1 -Type DWord -ErrorAction Stop
            }
            Revert = {
                & netsh int tcp set global autotuninglevel=normal 2>&1 | Out-Null
                Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TcpAckFrequency" -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TCPNoDelay" -ErrorAction SilentlyContinue
            }
            CheckState = {
                try { (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -ErrorAction Stop).TcpAckFrequency -eq 1 } catch { $false }
            }
        }
    )

    Write-Log -Level "INFO" -Category "Tuning" -Message "Tweak database initialized with $($script:TweakDatabase.Count) tweaks"
}

function global:Get-SystemTweaks {
    <#
    .SYNOPSIS
        List all available tweaks with current state.
    #>
    param(
        [Parameter()]
        [ValidateSet("", "Performance", "Privacy", "Gaming", "UI", "Explorer", "Network")]
        [string]$Category = ""
    )

    $result = @{
        Success  = $true
        Details  = @()
        Errors   = @()
    }

    if ($script:TweakDatabase.Count -eq 0) {
        Initialize-TweakDatabase
    }

    Write-Log -Level "INFO" -Category "Tuning" -Message "Gathering system tweaks..."

    try {
        foreach ($tweak in $script:TweakDatabase) {
            if ($Category -and $tweak.Category -ne $Category) { continue }

            $isActive = $false
            try {
                $isActive = [bool](& $tweak.CheckState)
            } catch {
                $result.Errors += "Could not check state for $($tweak.Name): $($_.Exception.Message)"
            }

            $result.Details += @{
                Name        = $tweak.Name
                Category    = $tweak.Category
                Description = $tweak.Description
                IsActive    = $isActive
            }
        }

        Write-Log -Level "INFO" -Category "Tuning" -Message "Found $($result.Details.Count) tweaks"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "Tuning" -Message "Failed to get tweaks: $($_.Exception.Message)"
    }

    return $result
}

function global:Apply-Tweak {
    <#
    .SYNOPSIS
        Apply a specific tweak.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$TweakName,
        
        [switch]$TestMode,
        [switch]$WhatIf
    )
    
    if ($TestMode -or $WhatIf) {
        return @{ Success = $true; Details = @{ TweakName = $TweakName }; Errors = @(); Message = "[Preview] Would apply: $TweakName" }
    }

    $result = @{
        Success  = $true
        Details  = @{
            TweakName   = $TweakName
            WasActive   = $false
            NowActive   = $false
        }
        Errors   = @()
    }

    if ($script:TweakDatabase.Count -eq 0) {
        Initialize-TweakDatabase
    }

    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Errors += "Administrator privileges required"
        return $result
    }

    $tweak = $script:TweakDatabase | Where-Object { $_.Name -eq $TweakName } | Select-Object -First 1
    if (-not $tweak) {
        $result.Success = $false
        $result.Errors += "Tweak not found: $TweakName"
        return $result
    }

    try {
        $result.Details.WasActive = [bool](& $tweak.CheckState)
    } catch {
        $result.Errors += "Could not check current state: $($_.Exception.Message)"
    }

    Write-Log -Level "INFO" -Category "Tuning" -Message "Applying tweak: $TweakName"

    try {
        & $tweak.Apply
        $result.Details.NowActive = $true
        Write-Log -Level "SUCCESS" -Category "Tuning" -Message "Tweak applied: $TweakName"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "Tuning" -Message "Failed to apply $TweakName : $($_.Exception.Message)"
    }

    return $result
}

function global:Revert-Tweak {
    <#
    .SYNOPSIS
        Revert a specific tweak.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$TweakName
    )

    $result = @{
        Success  = $true
        Details  = @{
            TweakName   = $TweakName
            WasActive   = $false
            NowActive   = $false
        }
        Errors   = @()
    }

    if ($script:TweakDatabase.Count -eq 0) {
        Initialize-TweakDatabase
    }

    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Errors += "Administrator privileges required"
        return $result
    }

    $tweak = $script:TweakDatabase | Where-Object { $_.Name -eq $TweakName } | Select-Object -First 1
    if (-not $tweak) {
        $result.Success = $false
        $result.Errors += "Tweak not found: $TweakName"
        return $result
    }

    try {
        $result.Details.WasActive = [bool](& $tweak.CheckState)
    } catch {
        $result.Errors += "Could not check current state: $($_.Exception.Message)"
    }

    Write-Log -Level "INFO" -Category "Tuning" -Message "Reverting tweak: $TweakName"

    try {
        & $tweak.Revert
        $result.Details.NowActive = $false
        Write-Log -Level "SUCCESS" -Category "Tuning" -Message "Tweak reverted: $TweakName"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "Tuning" -Message "Failed to revert $TweakName : $($_.Exception.Message)"
    }

    return $result
}

function global:Apply-TweakProfile {
    <#
    .SYNOPSIS
        Apply a set of tweaks (gaming/performance/privacy/balanced).
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Gaming", "Performance", "Privacy", "Balanced")]
        [string]$Profile,

        [Parameter()]
        [switch]$WhatIf
    )

    $result = @{
        Success  = $true
        Details  = @{
            Profile      = $Profile
            Applied      = @()
            Failed       = @()
            Skipped      = @()
        }
        Errors   = @()
    }

    if ($script:TweakDatabase.Count -eq 0) {
        Initialize-TweakDatabase
    }

    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Errors += "Administrator privileges required"
        return $result
    }

    $profileTweaks = switch ($Profile) {
        "Gaming" {
            @("DisableAnimations", "DisableTransparency", "DisableTips", "DisableConsumerFeatures",
              "DisableTelemetry", "DisableAdvertisingID",
              "EnableGameMode", "DisableFullscreenOptimizations", "EnableGPUScheduling",
              "ShowFileExtensions", "ShowHiddenFiles", "ClassicContextMenu",
              "DisableBandwidthThrottling", "OptimizeTCPSettings")
        }
        "Performance" {
            @("DisableAnimations", "DisableTransparency", "DisableTips", "DisableConsumerFeatures",
              "DisableTelemetry", "DisableAdvertisingID",
              "ShowFileExtensions", "ShowHiddenFiles",
              "DisableBandwidthThrottling")
        }
        "Privacy" {
            @("DisableTelemetry", "DisableLocation", "DisableAdvertisingID", "DisableCortana",
              "DisableTips", "DisableConsumerFeatures", "DisableRecentFiles")
        }
        "Balanced" {
            @("DisableTips", "DisableConsumerFeatures", "DisableAdvertisingID",
              "ShowFileExtensions", "ShowHiddenFiles", "ClassicContextMenu")
        }
    }

    Write-Log -Level "INFO" -Category "Tuning" -Message "Applying tweak profile: $Profile ($($profileTweaks.Count) tweaks)"

    foreach ($tweakName in $profileTweaks) {
        if ($WhatIf) {
            $result.Details.Skipped += $tweakName
            continue
        }

        $applyResult = Apply-Tweak -TweakName $tweakName
        if ($applyResult.Success) {
            $result.Details.Applied += $tweakName
        } else {
            $result.Details.Failed += $tweakName
            $result.Errors += $applyResult.Errors
        }
    }

    Write-Log -Level "SUCCESS" -Category "Tuning" -Message "Profile '$Profile' applied: $($result.Details.Applied.Count) success, $($result.Details.Failed.Count) failed"
    return $result
}

function global:Export-TweakState {
    <#
    .SYNOPSIS
        Export current tweak state.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    $result = @{
        Success  = $true
        Details  = @{
            OutputPath = $OutputPath
            TweakCount = 0
        }
        Errors   = @()
    }

    Write-Log -Level "INFO" -Category "Tuning" -Message "Exporting tweak state to $OutputPath..."

    try {
        $tweaks = Get-SystemTweaks
        if (-not $tweaks.Success) {
            $result.Success = $false
            $result.Errors += $tweaks.Errors
            return $result
        }

        $parentDir = Split-Path $OutputPath -Parent
        if ($parentDir -and -not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }

        $exportData = @{
            ExportDate  = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            ComputerName = $env:COMPUTERNAME
            Tweaks      = $tweaks.Details
        }

        $exportData | ConvertTo-Json -Depth 5 | Out-File -FilePath $OutputPath -Encoding UTF8

        $result.Details.TweakCount = $tweaks.Details.Count
        Write-Log -Level "SUCCESS" -Category "Tuning" -Message "Tweak state exported: $($result.Details.TweakCount) tweaks"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "Tuning" -Message "Failed to export tweak state: $($_.Exception.Message)"
    }

    return $result
}

function global:Import-TweakState {
    <#
    .SYNOPSIS
        Import and apply tweak state.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputPath,

        [Parameter()]
        [switch]$WhatIf
    )

    $result = @{
        Success  = $true
        Details  = @{
            Applied = @()
            Failed  = @()
        }
        Errors   = @()
    }

    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Errors += "Administrator privileges required"
        return $result
    }

    if (-not (Test-Path $InputPath)) {
        $result.Success = $false
        $result.Errors += "Import file not found: $InputPath"
        return $result
    }

    Write-Log -Level "INFO" -Category "Tuning" -Message "Importing tweak state from $InputPath..."

    try {
        $importData = Get-Content $InputPath -Raw | ConvertFrom-Json

        foreach ($tweak in $importData.Tweaks) {
            if ($tweak.IsActive) {
                if ($WhatIf) {
                    Write-Log -Level "INFO" -Category "Tuning" -Message "Preview: Would apply $($tweak.Name)"
                    continue
                }

                $applyResult = Apply-Tweak -TweakName $tweak.Name
                if ($applyResult.Success) {
                    $result.Details.Applied += $tweak.Name
                } else {
                    $result.Details.Failed += $tweak.Name
                    $result.Errors += $applyResult.Errors
                }
            }
        }

        Write-Log -Level "SUCCESS" -Category "Tuning" -Message "Import complete: $($result.Details.Applied.Count) applied, $($result.Details.Failed.Count) failed"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "Tuning" -Message "Failed to import tweak state: $($_.Exception.Message)"
    }

    return $result
}
