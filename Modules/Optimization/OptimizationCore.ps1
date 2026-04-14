# WinTune Pro - Optimization Module
# PowerShell 5.1+ Compatible

function global:Invoke-OptimizationAnalysis {
    $results = @{
        StartupItems = @()
        Services = @()
        MemoryOptimizations = @()
        PowerPlan = ""
        Recommendations = @()
    }
    
    # Analyze startup items
    if (Get-Command "Get-StartupItems" -ErrorAction SilentlyContinue) {
        $results.StartupItems = Get-StartupItems
    }
    
    # Analyze services
    if (Get-Command "Get-OptimizableServices" -ErrorAction SilentlyContinue) {
        $results.Services = Get-OptimizableServices
    }
    
    # Get current power plan
    $results.PowerPlan = Get-CurrentPowerPlan
    
    # Generate recommendations
    $results.Recommendations = Get-OptimizationRecommendations -StartupItems $results.StartupItems -Services $results.Services
    
    return $results
}


function global:Get-CurrentPowerPlan {
    try {
        $plan = powercfg /getactivescheme
        if ($plan -match "([a-f0-9-]{36})") {
            $guid = $matches[1]
            $name = ($plan -split "\s+", 4)[3]
            return @{
                GUID = $guid
                Name = $name
            }
        }
    } catch { Write-Log -Level "WARNING" -Category "System" -Message $_.Exception.Message }
    
    return @{ GUID = "Unknown"; Name = "Unknown" }
}


function global:Get-OptimizationRecommendations {
    param($StartupItems, $Services)
    
    $recommendations = @()
    
    # Check for many startup items
    if ($StartupItems.Count -gt 15) {
        $recommendations += "High number of startup items ($($StartupItems.Count)). Consider disabling unnecessary ones."
    }
    
    # Check services
    $disabledServices = @($Services | Where-Object { $_.Recommendation -eq "Disable" -and $_.Status -eq "Running" })
    if ($disabledServices.Count -gt 0) {
        $recommendations += "$($disabledServices.Count) services can be safely disabled to improve performance."
    }
    
    # Check power plan
    $powerPlan = Get-CurrentPowerPlan
    if ($powerPlan.Name -notlike "*High Performance*" -and $powerPlan.Name -notlike "*Ultimate*") {
        $recommendations += "Consider switching to High Performance or Ultimate Performance power plan."
    }
    
    # Check memory
    $os = Get-CachedCimInstance "Win32_OperatingSystem"
    if ($os) {
        $memPercent = [math]::Round(($os.FreePhysicalMemory / $os.TotalVisibleMemorySize) * 100, 1)
        if ($memPercent -lt 20) {
            $recommendations += "Low available memory ($memPercent%). Consider closing unused applications or upgrading RAM."
        }
    }
    
    if ($recommendations.Count -eq 0) {
        $recommendations += "System is well optimized. No major issues found."
    }
    
    return $recommendations
}


function global:Invoke-Optimization {
    param(
        [bool]$DisableTelemetry = $true,
        [bool]$OptimizeStartup = $true,
        [bool]$OptimizeMemory = $true,
        [bool]$SetHighPerformance = $true,
        [bool]$TestMode = $false
    )
    
    $results = @{
        Actions = @()
        Success = $true
    }
    
    # Disable telemetry
    if ($DisableTelemetry) {
        if ($TestMode) {
            $results.Actions += "Test Mode: Would disable telemetry"
            Log-Info "Test Mode: Would disable telemetry" -Category "Optimization"
        } else {
            try {
                $tpath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
                if (-not (Test-Path $tpath)) { New-Item -Path $tpath -Force | Out-Null }
                Set-ItemProperty -Path $tpath -Name "AllowTelemetry" -Value 0 -Force -ErrorAction SilentlyContinue
                
                # Also disable diagnostic data
                Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "MaxTelemetryAllowed" -Value 0 -Force -ErrorAction SilentlyContinue
                
                $results.Actions += "Disabled telemetry and diagnostic data"
                Log-Success "Disabled telemetry" -Category "Optimization"
            } catch {
                $results.Actions += "Failed to disable telemetry: $($_.Exception.Message)"
                Log-Error "Failed to disable telemetry" -Category "Optimization"
            }
        }
    }
    
    # Set High Performance power plan
    if ($SetHighPerformance) {
        if ($TestMode) {
            $results.Actions += "Test Mode: Would set High Performance power plan"
        } else {
            try {
                powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8486b7 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    $results.Actions += "Set High Performance power plan"
                    Log-Success "Set High Performance power plan" -Category "Optimization"
                } else {
                    powercfg /setactive SCHEME_MIN 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        $results.Actions += "Set High Performance power plan"
                        Log-Success "Set High Performance power plan" -Category "Optimization"
                    }
                }
            } catch {
                $results.Actions += "Failed to set power plan: $($_.Exception.Message)"
            }
        }
    }
    
    # Optimize memory
    if ($OptimizeMemory) {
        if ($TestMode) {
            $results.Actions += "Test Mode: Would optimize memory"
        } else {
            try {
                [System.GC]::Collect()
                [System.GC]::WaitForPendingFinalizers()
                [System.GC]::Collect()
                $results.Actions += "Optimized memory (garbage collection)"
                Log-Success "Optimized memory" -Category "Optimization"
            } catch {
                $results.Actions += "Failed to optimize memory"
            }
        }
    }
    
    # Disable unnecessary visual effects
    if (-not $TestMode) {
        try {
            $desktopPath = "HKCU:\Control Panel\Desktop"
            Set-ItemProperty -Path $desktopPath -Name "DragFullWindows" -Value "0" -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path "$desktopPath\WindowMetrics" -Name "MinAnimate" -Value "0" -Force -ErrorAction SilentlyContinue
            
            $advPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
            Set-ItemProperty -Path $advPath -Name "TaskbarAnimations" -Value 0 -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $advPath -Name "ListviewAlphaSelect" -Value 0 -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $advPath -Name "ListviewShadow" -Value 0 -Force -ErrorAction SilentlyContinue
            
            $results.Actions += "Disabled visual effects"
        } catch { }
    }
    
    # Additional optimizations (non-test mode)
    if (-not $TestMode) {
        # Disable Cortana
        try {
            $cortanaPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
            if (-not (Test-Path $cortanaPath)) { New-Item -Path $cortanaPath -Force | Out-Null }
            Set-ItemProperty -Path $cortanaPath -Name "AllowCortana" -Value 0 -Force -ErrorAction SilentlyContinue
            $results.Actions += "Disabled Cortana"
        } catch { }
        
        # Disable Windows Tips
        try {
            $tipsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
            Set-ItemProperty -Path $tipsPath -Name "SoftLandingEnabled" -Value 0 -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $tipsPath -Name "SubscribedContentEnabled" -Value 0 -Force -ErrorAction SilentlyContinue
            $results.Actions += "Disabled Windows tips and suggestions"
        } catch { }
        
        # Disable Background Apps
        try {
            $bgPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
            Set-ItemProperty -Path $bgPath -Name "GlobalUserDisabled" -Value 1 -Force -ErrorAction SilentlyContinue
            $results.Actions += "Disabled background apps"
        } catch { }
        
        # Disable Fast Startup (can cause issues)
        try {
            $fsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
            Set-ItemProperty -Path $fsPath -Name "HiberbootEnabled" -Value 0 -Force -ErrorAction SilentlyContinue
            $results.Actions += "Disabled Fast Startup"
        } catch { }
        
        # Optimize NTFS settings
        try {
            $fsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
            Set-ItemProperty -Path $fsPath -Name "NtfsDisableLastAccessUpdate" -Value 80000001 -Type DWord -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $fsPath -Name "NtfsDisable8dot3NameCreation" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            $results.Actions += "Optimized NTFS settings"
        } catch { }
        
        # Disable Windows Ink
        try {
            $inkPath = "HKLM:\SOFTWARE\Policies\Microsoft\WindowsInkWorkspace"
            if (-not (Test-Path $inkPath)) { New-Item -Path $inkPath -Force | Out-Null }
            Set-ItemProperty -Path $inkPath -Name "AllowWindowsInkWorkspace" -Value 0 -Force -ErrorAction SilentlyContinue
            $results.Actions += "Disabled Windows Ink"
        } catch { }
        
        # Disable Windows Spotlight
        try {
            $spotPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
            Set-ItemProperty -Path $spotPath -name "RotatingLockScreenEnabled" -Value 0 -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $spotPath -Name "RotatingLockScreenOverlayEnabled" -Value 0 -Force -ErrorAction SilentlyContinue
            $results.Actions += "Disabled Windows Spotlight"
        } catch { }
        
        # Disable Web Search in Start Menu
        try {
            $searchPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
            Set-ItemProperty -Path $searchPath -Name "BingSearchEnabled" -Value 0 -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $searchPath -Name "CortanaConsent" -Value 0 -Force -ErrorAction SilentlyContinue
            $results.Actions += "Disabled web search in Start Menu"
        } catch { }
        
        # Disable Activity History
        try {
            $activityPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
            if (-not (Test-Path $activityPath)) { New-Item -Path $activityPath -Force | Out-Null }
            Set-ItemProperty -Path $activityPath -Name "EnableActivityFeed" -Value 0 -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $activityPath -Name "PublishUserActivities" -Value 0 -Force -ErrorAction SilentlyContinue
            $results.Actions += "Disabled activity history"
        } catch { }
        
        # Disable Clipboard History
        try {
            $clipPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
            Set-ItemProperty -Path $clipPath -Name "AllowClipboardHistory" -Value 0 -Force -ErrorAction SilentlyContinue
            $results.Actions += "Disabled clipboard history"
        } catch { }
    }
    
    return $results
}


function global:Invoke-QuickOptimize {
    param([bool]$TestMode = $false)
    
    return Invoke-Optimization -DisableTelemetry $true -OptimizeStartup $true -OptimizeMemory $true -SetHighPerformance $true -TestMode $TestMode
}

