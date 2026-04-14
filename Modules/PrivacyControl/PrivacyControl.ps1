# WinTune Pro - Privacy Control Module
# PowerShell 5.1+ Compatible

function global:Get-PrivacyScore {
    $score = 100
    $issues = @()

    try {
        $telemetry = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -ErrorAction SilentlyContinue
        if (-not $telemetry -or $telemetry.AllowTelemetry -gt 0) {
            $score -= 15
            $issues += "Telemetry is enabled"
        }
    } catch {
        $score -= 15
        $issues += "Telemetry is enabled"
    }

    try {
        $cortana = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -ErrorAction SilentlyContinue
        if (-not $cortana -or $cortana.AllowCortana -ne 0) {
            $score -= 10
            $issues += "Cortana may be enabled"
        }
    } catch {
        Write-Log -Level "WARNING" -Category "Privacy" -Message "Error checking Cortana: $($_.Exception.Message)"
    }

    try {
        $adId = Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -ErrorAction SilentlyContinue
        if ($adId -and $adId.Enabled -eq 1) {
            $score -= 10
            $issues += "Advertising ID is enabled"
        }
    } catch {
        Write-Log -Level "WARNING" -Category "Privacy" -Message "Error checking Advertising ID: $($_.Exception.Message)"
    }

    try {
        $activity = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed" -ErrorAction SilentlyContinue
        if (-not $activity -or $activity.EnableActivityFeed -ne 0) {
            $score -= 10
            $issues += "Activity history may be enabled"
        }
    } catch {
        Write-Log -Level "WARNING" -Category "Privacy" -Message "Error checking Activity History: $($_.Exception.Message)"
    }

    try {
        $location = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -Name "DisableLocation" -ErrorAction SilentlyContinue
        if (-not $location -or $location.DisableLocation -ne 1) {
            $score -= 10
            $issues += "Location tracking may be enabled"
        }
    } catch {
        Write-Log -Level "WARNING" -Category "Privacy" -Message "Error checking Location: $($_.Exception.Message)"
    }

    if ($score -lt 0) { $score = 0 }

    return @{
        Score = $score
        Issues = $issues
    }
}

function global:Invoke-PrivacyScan {
    $results = @{
        Telemetry = "Unknown"
        Cortana = "Unknown"
        AdvertisingID = "Unknown"
        ActivityHistory = "Unknown"
        Location = "Unknown"
        DiagTrackService = "Unknown"
    }

    try {
        $telemetry = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -ErrorAction SilentlyContinue
        $results.Telemetry = if ($telemetry -and $telemetry.AllowTelemetry -eq 0) { "Disabled" } else { "Enabled" }
    } catch {
        Write-Log -Level "WARNING" -Category "Privacy" -Message "Error scanning telemetry: $($_.Exception.Message)"
    }

    try {
        $cortana = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -ErrorAction SilentlyContinue
        $results.Cortana = if ($cortana -and $cortana.AllowCortana -eq 0) { "Disabled" } else { "Enabled" }
    } catch {
        Write-Log -Level "WARNING" -Category "Privacy" -Message "Error scanning Cortana: $($_.Exception.Message)"
    }

    try {
        $adId = Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -ErrorAction SilentlyContinue
        $results.AdvertisingID = if ($adId -and $adId.Enabled -eq 0) { "Disabled" } else { "Enabled" }
    } catch {
        Write-Log -Level "WARNING" -Category "Privacy" -Message "Error scanning Advertising ID: $($_.Exception.Message)"
    }

    try {
        $service = Get-Service -Name "DiagTrack" -ErrorAction SilentlyContinue
        $results.DiagTrackService = $service.Status.ToString()
    } catch {
        Write-Log -Level "WARNING" -Category "Privacy" -Message "Error scanning DiagTrack: $($_.Exception.Message)"
    }

    return $results
}

function global:Invoke-PrivacyOptimization {
    param(
        [ValidateSet("Basic", "Strict")]
        [string]$Mode = "Basic",
        [bool]$TestMode = $false
    )

    $results = @{
        Actions = @()
        Success = $true
    }

    if ($TestMode) {
        $results.Actions += "Test Mode: Would apply privacy optimization"
        return $results
    }

    try {
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0 -Force -ErrorAction SilentlyContinue
        $results.Actions += "Disabled Advertising ID"
    } catch {
        Write-Log -Level "WARNING" -Category "Privacy" -Message "Error disabling Advertising ID: $($_.Exception.Message)"
    }

    try {
        if (-not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection")) {
            New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Force | Out-Null
        }
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -Force
        $results.Actions += "Disabled Telemetry"
    } catch {
        Write-Log -Level "WARNING" -Category "Privacy" -Message "Error disabling telemetry: $($_.Exception.Message)"
    }

    if ($Mode -eq "Strict") {
        try {
            if (-not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search")) {
                New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Force | Out-Null
            }
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -Value 0 -Force
            $results.Actions += "Disabled Cortana"
        } catch {
            Write-Log -Level "WARNING" -Category "Privacy" -Message "Error disabling Cortana: $($_.Exception.Message)"
        }

        try {
            if (-not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System")) {
                New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Force | Out-Null
            }
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed" -Value 0 -Force
            $results.Actions += "Disabled Activity History"
        } catch {
            Write-Log -Level "WARNING" -Category "Privacy" -Message "Error disabling Activity History: $($_.Exception.Message)"
        }

        try {
            if (-not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors")) {
                New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -Force | Out-Null
            }
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -Name "DisableLocation" -Value 1 -Force
            $results.Actions += "Disabled Location Tracking"
        } catch {
            Write-Log -Level "WARNING" -Category "Privacy" -Message "Error disabling Location: $($_.Exception.Message)"
        }

        try {
            Stop-Service -Name "DiagTrack" -Force -ErrorAction SilentlyContinue
            Set-Service -Name "DiagTrack" -StartupType Disabled -ErrorAction SilentlyContinue
            $results.Actions += "Disabled DiagTrack Service"
        } catch {
            Write-Log -Level "WARNING" -Category "Privacy" -Message "Error disabling DiagTrack: $($_.Exception.Message)"
        }
    }

    Log-Success "Applied $Mode privacy optimization" -Category "Privacy"

    return $results
}

function global:Set-TelemetryLevel {
    param(
        [ValidateSet("Disabled", "Basic", "Enhanced", "Full")]
        [string]$Level = "Basic"
    )

    $value = switch ($Level) {
        "Disabled" { 0 }
        "Basic" { 1 }
        "Enhanced" { 2 }
        "Full" { 3 }
    }

    try {
        if (-not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection")) {
            New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Force | Out-Null
        }
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value $value -Force

        Log-Success "Set telemetry level to $Level" -Category "Privacy"
        return $true
    } catch {
        Log-Error "Failed to set telemetry level: $($_.Exception.Message)" -Category "Privacy"
        return $false
    }
}

# Telemetry scheduled tasks to disable
$script:TelemetryTasks = @(
    '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser',
    '\Microsoft\Windows\Application Experience\ProgramDataUpdater',
    '\Microsoft\Windows\Autochk\Proxy',
    '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
    '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip',
    '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector',
    '\Microsoft\Windows\Feedback\Siuf\DmClient',
    '\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload'
)

# Privacy-related services to disable
$script:PrivacyServices = @(
    @{ Name = "DiagTrack"; Display = "Connected User Experiences and Telemetry" },
    @{ Name = "dmwappushservice"; Display = "WAP Push Message Routing" },
    @{ Name = "WerSvc"; Display = "Windows Error Reporting" },
    @{ Name = "OneSyncSvc"; Display = "Sync Host" }
)

function global:Disable-PrivacyTasks {
    param([bool]$TestMode = $false)
    $results = @{ Actions = @(); Success = $true }

    foreach ($task in $script:TelemetryTasks) {
        if ($TestMode) {
            $results.Actions += "[Preview] Would disable: $task"
        } else {
            try {
                schtasks /Change /TN $task /Disable 2>$null
                $results.Actions += "Disabled: $(Split-Path $task -Leaf)"
            } catch { }
        }
    }
    return $results
}

function global:Disable-PrivacyServices {
    param([bool]$TestMode = $false)
    $results = @{ Actions = @(); Success = $true }

    foreach ($svc in $script:PrivacyServices) {
        if ($TestMode) {
            $results.Actions += "[Preview] Would disable: $($svc.Display)"
        } else {
            try {
                Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
                Set-Service -Name $svc.Name -StartupType Disabled -ErrorAction SilentlyContinue
                $results.Actions += "Disabled: $($svc.Display)"
            } catch { }
        }
    }
    return $results
}

function global:Disable-BingSearch {
    param([bool]$TestMode = $false)
    $results = @{ Actions = @(); Success = $true }

    if ($TestMode) {
        $results.Actions += "[Preview] Would disable Bing search in Start Menu"
        return $results
    }

    try {
        if (-not (Test-Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search")) {
            New-Item -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Force | Out-Null
        }
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Value 0 -Force
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "CortanaConsent" -Value 0 -Force
        $results.Actions += "Disabled Bing search in Start Menu"
    } catch { }
    return $results
}

function global:Disable-FeedbackNotifications {
    param([bool]$TestMode = $false)
    $results = @{ Actions = @(); Success = $true }

    if ($TestMode) {
        $results.Actions += "[Preview] Would disable feedback notifications"
        return $results
    }

    try {
        if (-not (Test-Path "HKCU:\Software\Microsoft\Siuf\Rules")) {
            New-Item -Path "HKCU:\Software\Microsoft\Siuf\Rules" -Force | Out-Null
        }
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Siuf\Rules" -Name "NumberOfSIUFInPeriod" -Value 0 -Force
        $results.Actions += "Disabled feedback notifications"
    } catch { }
    return $results
}

function global:Disable-WiFiSense {
    param([bool]$TestMode = $false)
    $results = @{ Actions = @(); Success = $true }

    if ($TestMode) {
        $results.Actions += "[Preview] Would disable Wi-Fi Sense"
        return $results
    }

    try {
        $paths = @(
            "HKLM:\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\features",
            "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowWiFiHotSpotReporting",
            "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowAutoConnectToWiFiSenseHotspots"
        )
        foreach ($path in $paths) {
            if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        }
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\features" -Name "FeatureStates" -Value 0x00000083 -Type DWord -Force
        $results.Actions += "Disabled Wi-Fi Sense"
    } catch { }
    return $results
}

function global:Disable-WindowsConsumerFeatures {
    param([bool]$TestMode = $false)
    $results = @{ Actions = @(); Success = $true }

    if ($TestMode) {
        $results.Actions += "[Preview] Would disable Windows consumer features (suggestions)"
        return $results
    }

    try {
        if (-not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent")) {
            New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Force | Out-Null
        }
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -Value 1 -Force

        # Also disable content delivery
        $cdmPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
        if (Test-Path $cdmPath) {
            Set-ItemProperty -Path $cdmPath -Name "SilentInstalledAppsEnabled" -Value 0 -Force
            Set-ItemProperty -Path $cdmPath -Name "SoftLandingEnabled" -Value 0 -Force
            Set-ItemProperty -Path $cdmPath -Name "SubscribedContentEnabled" -Value 0 -Force
            Set-ItemProperty -Path $cdmPath -Name "SubscribedContent-338388Enabled" -Value 0 -Force
            Set-ItemProperty -Path $cdmPath -Name "SubscribedContent-338389Enabled" -Value 0 -Force
            Set-ItemProperty -Path $cdmPath -Name "SubscribedContent-310093Enabled" -Value 0 -Force
            Set-ItemProperty -Path $cdmPath -Name "SubscribedContent-338393Enabled" -Value 0 -Force
        }
        $results.Actions += "Disabled Windows consumer features and suggestions"
    } catch { }
    return $results
}

function global:Invoke-FullPrivacyOptimization {
    param([bool]$TestMode = $false)

    $results = @{ Actions = @(); Success = $true }

    $results.Actions += (Invoke-PrivacyOptimization -Mode "Strict" -TestMode:$TestMode).Actions
    $results.Actions += (Disable-PrivacyTasks -TestMode:$TestMode).Actions
    $results.Actions += (Disable-PrivacyServices -TestMode:$TestMode).Actions
    $results.Actions += (Disable-BingSearch -TestMode:$TestMode).Actions
    $results.Actions += (Disable-FeedbackNotifications -TestMode:$TestMode).Actions
    $results.Actions += (Disable-WiFiSense -TestMode:$TestMode).Actions
    $results.Actions += (Disable-WindowsConsumerFeatures -TestMode:$TestMode).Actions

    Log-Success "Full privacy optimization complete" -Category "Privacy"
    return $results
}
