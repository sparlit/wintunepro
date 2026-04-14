#Requires -Version 5.1

$script:ActiveProfile = $null
$script:CustomProfiles = @()
$script:ProfilesPath = ""

$script:BuiltinProfiles = @(
    @{
        Name        = "Gaming"
        Description = "Maximum performance, minimal background services, high-performance power plan, disable telemetry, optimize network for low latency"
        Category    = "Performance"
        Services    = @{
            Disable = @("DiagTrack", "dmwappushservice", "SysMain", "WSearch", "MapsBroker", "WerSvc", "lfsvc", "Fax", "RemoteRegistry", "TrkWks", "XblAuthManager", "XblGameSave", "XboxNetApiSvc", "PcaSvc")
            Auto    = @("AudioSrv", "AudioEndpointBuilder", "UXSMS")
            Manual  = @("BITS", "Wuauserv")
        }
        Startup     = @{
            Disable = @("OneDrive", "Spotify", "Discord", "Steam", "EpicGamesLauncher", "Teams")
        }
        PowerPlan   = "High Performance"
        Privacy     = @{
            DisableTelemetry    = $true
            DisableCortana      = $true
            DisableLocation     = $true
            DisableAdvertisingID = $true
            DisableFeedback     = $true
        }
        Network     = @{
            OptimizeTCPIP     = $true
            DisableNagle      = $true
            AutoTuningLevel   = "normal"
            OptimizeDNS       = $true
        }
        VisualEffects = @{
            Animations      = $false
            Transparency     = $false
            Shadows          = $false
            SmoothEdges      = $false
        }
        RegistryTweaks = @(
            @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; Name = "SystemResponsiveness"; Value = 0; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "GPU Priority"; Value = 8; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "Priority"; Value = 6; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "Scheduling Category"; Value = "High"; Type = "String" },
            @{ Path = "HKCU:\System\GameConfigStore"; Name = "GameDVR_Enabled"; Value = 0; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"; Name = "AllowGameDVR"; Value = 0; Type = "DWord" }
        )
    },
    @{
        Name        = "Office"
        Description = "Balanced performance, keep productivity services, moderate power plan, keep OneDrive/Teams enabled"
        Category    = "Productivity"
        Services    = @{
            Disable = @("DiagTrack", "dmwappushservice", "Fax", "RemoteRegistry")
            Auto    = @("WSearch", "BITS", "Spooler")
            Manual  = @("SysMain", "WerSvc")
        }
        Startup     = @{
            Disable = @("Spotify", "Discord", "Steam", "EpicGamesLauncher")
        }
        PowerPlan   = "Balanced"
        Privacy     = @{
            DisableTelemetry    = $false
            DisableCortana      = $false
            DisableLocation     = $false
            DisableAdvertisingID = $true
            DisableFeedback     = $true
        }
        Network     = @{
            OptimizeTCPIP     = $false
            DisableNagle      = $false
            AutoTuningLevel   = "normal"
            OptimizeDNS       = $false
        }
        VisualEffects = @{
            Animations      = $true
            Transparency     = $true
            Shadows          = $true
            SmoothEdges      = $true
        }
        RegistryTweaks = @()
    },
    @{
        Name        = "Multimedia"
        Description = "Optimize for media playback, enable hardware acceleration, balanced power, prioritize audio/video services"
        Category    = "Media"
        Services    = @{
            Disable = @("DiagTrack", "dmwappushservice", "Fax", "RemoteRegistry", "WerSvc")
            Auto    = @("AudioSrv", "AudioEndpointBuilder", "MMDevices", "WSearch")
            Manual  = @("SysMain", "BITS")
        }
        Startup     = @{
            Disable = @("OneDrive", "Spotify", "Discord", "Steam")
        }
        PowerPlan   = "High Performance"
        Privacy     = @{
            DisableTelemetry    = $true
            DisableCortana      = $false
            DisableLocation     = $false
            DisableAdvertisingID = $true
            DisableFeedback     = $true
        }
        Network     = @{
            OptimizeTCPIP     = $true
            DisableNagle      = $false
            AutoTuningLevel   = "normal"
            OptimizeDNS       = $false
        }
        VisualEffects = @{
            Animations      = $true
            Transparency     = $true
            Shadows          = $true
            SmoothEdges      = $true
        }
        RegistryTweaks = @(
            @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; Name = "SystemResponsiveness"; Value = 0; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Audio"; Name = "GPU Priority"; Value = 8; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Audio"; Name = "Priority"; Value = 6; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Pro Audio"; Name = "GPU Priority"; Value = 8; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Pro Audio"; Name = "Priority"; Value = 8; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Pro Audio"; Name = "Scheduling Category"; Value = "High"; Type = "String" }
        )
    },
    @{
        Name        = "Developer"
        Description = "Keep dev tools enabled, optimize for compilation, keep WSL/Docker services, balanced power"
        Category    = "Development"
        Services    = @{
            Disable = @("DiagTrack", "dmwappushservice", "Fax", "RemoteRegistry")
            Auto    = @("WSearch", "LxssManager", "Hns")
            Manual  = @("SysMain", "WerSvc", "BITS")
        }
        Startup     = @{
            Disable = @("OneDrive", "Spotify", "Discord")
        }
        PowerPlan   = "High Performance"
        Privacy     = @{
            DisableTelemetry    = $true
            DisableCortana      = $true
            DisableLocation     = $false
            DisableAdvertisingID = $true
            DisableFeedback     = $true
        }
        Network     = @{
            OptimizeTCPIP     = $true
            DisableNagle      = $false
            AutoTuningLevel   = "normal"
            OptimizeDNS       = $false
        }
        VisualEffects = @{
            Animations      = $false
            Transparency     = $false
            Shadows          = $true
            SmoothEdges      = $true
        }
        RegistryTweaks = @(
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"; Name = "LongPathsEnabled"; Value = 1; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"; Name = "AllowDevelopmentWithoutDevLicense"; Value = 1; Type = "DWord" }
        )
    },
    @{
        Name        = "Privacy"
        Description = "Maximum privacy, disable all telemetry, disable Cortana, disable location, disable advertising ID"
        Category    = "Security"
        Services    = @{
            Disable = @("DiagTrack", "dmwappushservice", "lfsvc", "MapsBroker", "WerSvc", "RemoteRegistry", "Fax", "RetailDemo", "diagsvc", "DcpSvc", "WpcMonSvc")
            Auto    = @()
            Manual  = @("SysMain", "BITS", "WSearch")
        }
        Startup     = @{
            Disable = @("OneDrive", "Teams", "Spotify", "Cortana")
        }
        PowerPlan   = "Balanced"
        Privacy     = @{
            DisableTelemetry    = $true
            DisableCortana      = $true
            DisableLocation     = $true
            DisableAdvertisingID = $true
            DisableFeedback     = $true
        }
        Network     = @{
            OptimizeTCPIP     = $false
            DisableNagle      = $false
            AutoTuningLevel   = "normal"
            OptimizeDNS       = $true
        }
        VisualEffects = @{
            Animations      = $true
            Transparency     = $true
            Shadows          = $true
            SmoothEdges      = $true
        }
        RegistryTweaks = @(
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name = "AllowTelemetry"; Value = 0; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name = "DoNotShowFeedbackNotifications"; Value = 1; Type = "DWord" },
            @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo"; Name = "Enabled"; Value = 0; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "AllowCortana"; Value = 0; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors"; Name = "DisableLocation"; Value = 1; Type = "DWord" },
            @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat"; Name = "AITEnable"; Value = 0; Type = "DWord" },
            @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SilentInstalledAppsEnabled"; Value = 0; Type = "DWord" },
            @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SoftLandingEnabled"; Value = 0; Type = "DWord" },
            @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContent-338389Enabled"; Value = 0; Type = "DWord" },
            @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SubscribedContent-310093Enabled"; Value = 0; Type = "DWord" }
        )
    },
    @{
        Name        = "Performance"
        Description = "Absolute maximum performance, disable all non-essential services, ultimate power plan"
        Category    = "Performance"
        Services    = @{
            Disable = @("DiagTrack", "dmwappushservice", "SysMain", "WSearch", "MapsBroker", "WerSvc", "lfsvc", "Fax", "RemoteRegistry", "TrkWks", "PcaSvc", "TabletInputService", "RetailDemo", "diagsvc", "DcpSvc", "WpcMonSvc", "WbioSrvc", "wisvc", "OneSyncSvc", "MessagingService", "CDPSvc", "CDPUserSvc")
            Auto    = @("AudioSrv", "AudioEndpointBuilder", "UXSMS", "Themes", "Schedule")
            Manual  = @("BITS", "Wuauserv", "CryptSvc", "WinDefend")
        }
        Startup     = @{
            Disable = @("OneDrive", "Spotify", "Discord", "Steam", "EpicGamesLauncher", "Teams", "Cortana", "Skype")
        }
        PowerPlan   = "Ultimate Performance"
        Privacy     = @{
            DisableTelemetry    = $true
            DisableCortana      = $true
            DisableLocation     = $true
            DisableAdvertisingID = $true
            DisableFeedback     = $true
        }
        Network     = @{
            OptimizeTCPIP     = $true
            DisableNagle      = $true
            AutoTuningLevel   = "normal"
            OptimizeDNS       = $true
        }
        VisualEffects = @{
            Animations      = $false
            Transparency     = $false
            Shadows          = $false
            SmoothEdges      = $false
        }
        RegistryTweaks = @(
            @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; Name = "SystemResponsiveness"; Value = 0; Type = "DWord" },
            @{ Path = "HKCU:\Control Panel\Desktop"; Name = "MenuShowDelay"; Value = 0; Type = "String" },
            @{ Path = "HKCU:\Control Panel\Desktop\WindowMetrics"; Name = "MinAnimate"; Value = 0; Type = "String" },
            @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"; Name = "VisualFXSetting"; Value = 2; Type = "DWord" },
            @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"; Name = "Win32PrioritySeparation"; Value = 38; Type = "DWord" }
        )
    },
    @{
        Name        = "Balanced"
        Description = "Default Windows behavior with minor optimizations"
        Category    = "General"
        Services    = @{
            Disable = @("DiagTrack", "dmwappushservice", "Fax", "RemoteRegistry")
            Auto    = @()
            Manual  = @()
        }
        Startup     = @{
            Disable = @()
        }
        PowerPlan   = "Balanced"
        Privacy     = @{
            DisableTelemetry    = $true
            DisableCortana      = $false
            DisableLocation     = $false
            DisableAdvertisingID = $true
            DisableFeedback     = $true
        }
        Network     = @{
            OptimizeTCPIP     = $false
            DisableNagle      = $false
            AutoTuningLevel   = "normal"
            OptimizeDNS       = $false
        }
        VisualEffects = @{
            Animations      = $true
            Transparency     = $true
            Shadows          = $true
            SmoothEdges      = $true
        }
        RegistryTweaks = @()
    },
    @{
        Name        = "Battery"
        Description = "Maximum battery life, aggressive power saving, disable background tasks"
        Category    = "Power"
        Services    = @{
            Disable = @("DiagTrack", "dmwappushservice", "SysMain", "WSearch", "MapsBroker", "WerSvc", "lfsvc", "Fax", "RemoteRegistry", "TrkWks", "PcaSvc", "XblAuthManager", "XblGameSave", "XboxNetApiSvc", "RetailDemo")
            Auto    = @("AudioSrv", "AudioEndpointBuilder")
            Manual  = @("BITS", "Wuauserv", "Spooler")
        }
        Startup     = @{
            Disable = @("OneDrive", "Spotify", "Discord", "Steam", "EpicGamesLauncher", "Teams", "Skype")
        }
        PowerPlan   = "Power Saver"
        Privacy     = @{
            DisableTelemetry    = $true
            DisableCortana      = $true
            DisableLocation     = $true
            DisableAdvertisingID = $true
            DisableFeedback     = $true
        }
        Network     = @{
            OptimizeTCPIP     = $false
            DisableNagle      = $false
            AutoTuningLevel   = "normal"
            OptimizeDNS       = $false
        }
        VisualEffects = @{
            Animations      = $false
            Transparency     = $false
            Shadows          = $false
            SmoothEdges      = $false
        }
        RegistryTweaks = @(
            @{ Path = "HKCU:\Control Panel\Desktop"; Name = "MenuShowDelay"; Value = 0; Type = "String" },
            @{ Path = "HKCU:\Control Panel\Desktop\WindowMetrics"; Name = "MinAnimate"; Value = 0; Type = "String" }
        )
    }
)

function global:Initialize-ProfileManager {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DataDirectory
    )

    $script:ProfilesPath = Join-Path $DataDirectory "profiles"

    if (-not (Test-Path $script:ProfilesPath)) {
        New-Item -ItemType Directory -Path $script:ProfilesPath -Force | Out-Null
    }

    $customDir = Join-Path $script:ProfilesPath "custom"
    if (-not (Test-Path $customDir)) {
        New-Item -ItemType Directory -Path $customDir -Force | Out-Null
    }

    $customFiles = Get-ChildItem -Path $customDir -Filter "*.json" -ErrorAction SilentlyContinue
    foreach ($file in $customFiles) {
        try {
            $json = Get-Content -Path $file.FullName -Raw -Encoding UTF8
            $profile = $json | ConvertFrom-Json
            $script:CustomProfiles += $profile
        }
        catch {
            Write-Log -Level "WARNING" -Category "System" -Message "Failed to load custom profile $($file.Name): $($_.Exception.Message)"
        }
    }

    $activeFile = Join-Path $script:ProfilesPath "active_profile.txt"
    if (Test-Path $activeFile) {
        try {
            $activeName = Get-Content -Path $activeFile -Raw -Encoding UTF8
            $script:ActiveProfile = $activeName.Trim()
            Write-Log -Level "INFO" -Category "System" -Message "Active profile loaded: $($script:ActiveProfile)"
        }
        catch {
            Write-Log -Level "WARNING" -Category "System" -Message "Failed to read active profile: $($_.Exception.Message)"
        }
    }

    Write-Log -Level "INFO" -Category "System" -Message "ProfileManager initialized with $($script:BuiltinProfiles.Count) built-in and $($script:CustomProfiles.Count) custom profiles"
}

function global:Get-AvailableProfiles {
    [CmdletBinding()]
    param()

    $profiles = @()

    foreach ($p in $script:BuiltinProfiles) {
        $profiles += [PSCustomObject]@{
            Name        = $p.Name
            Description = $p.Description
            Category    = $p.Category
            BuiltIn     = $true
            Active      = ($script:ActiveProfile -eq $p.Name)
        }
    }

    foreach ($p in $script:CustomProfiles) {
        $profiles += [PSCustomObject]@{
            Name        = $p.Name
            Description = $p.Description
            Category    = if ($p.PSObject.Properties["Category"]) { $p.Category } else { "Custom" }
            BuiltIn     = $false
            Active      = ($script:ActiveProfile -eq $p.Name)
        }
    }

    return $profiles
}

function global:Get-ActiveProfile {
    [CmdletBinding()]
    param()

    if ($null -eq $script:ActiveProfile) {
        return $null
    }

    $profile = $script:BuiltinProfiles | Where-Object { $_.Name -eq $script:ActiveProfile } | Select-Object -First 1
    if ($null -ne $profile) {
        return $profile
    }

    $custom = $script:CustomProfiles | Where-Object { $_.Name -eq $script:ActiveProfile } | Select-Object -First 1
    return $custom
}

function global:Set-ActiveProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter()]
        [switch]$Preview
    )

    $profile = $script:BuiltinProfiles | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
    if ($null -eq $profile) {
        $profile = $script:CustomProfiles | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
    }

    if ($null -eq $profile) {
        Write-Log -Level "ERROR" -Category "System" -Message "Profile not found: $Name"
        return $false
    }

    if ($Preview) {
        Write-Log -Level "INFO" -Category "System" -Message "[PREVIEW] Would apply profile: $Name"
        return $true
    }

    Write-Log -Level "INFO" -Category "System" -Message "Applying profile: $Name"

    $result = @{
        Success    = $true
        Profile    = $Name
        Changes    = 0
        Errors     = @()
    }

    try {
        if ($profile.Services) {
            if ($profile.Services.Disable) {
                foreach ($svcName in $profile.Services.Disable) {
                    try {
                        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
                        if ($null -ne $svc -and $svc.StartType.ToString() -ne "Disabled") {
                            Set-Service -Name $svcName -StartupType Disabled -ErrorAction Stop
                            if ($svc.Status -eq "Running") {
                                Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue
                            }
                            $result.Changes++
                        }
                    }
                    catch {
                        $result.Errors += "Service $svcName : $($_.Exception.Message)"
                        Write-Log -Level "WARNING" -Category "System" -Message "Failed to disable service $svcName : $($_.Exception.Message)"
                    }
                }
            }

            if ($profile.Services.Auto) {
                foreach ($svcName in $profile.Services.Auto) {
                    try {
                        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
                        if ($null -ne $svc -and $svc.StartType.ToString() -ne "Automatic") {
                            Set-Service -Name $svcName -StartupType Automatic -ErrorAction Stop
                            $result.Changes++
                        }
                    }
                    catch {
                        $result.Errors += "Service $svcName : $($_.Exception.Message)"
                        Write-Log -Level "WARNING" -Category "System" -Message "Failed to set service $svcName to Auto: $($_.Exception.Message)"
                    }
                }
            }

            if ($profile.Services.Manual) {
                foreach ($svcName in $profile.Services.Manual) {
                    try {
                        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
                        if ($null -ne $svc -and $svc.StartType.ToString() -ne "Manual") {
                            Set-Service -Name $svcName -StartupType Manual -ErrorAction Stop
                            $result.Changes++
                        }
                    }
                    catch {
                        $result.Errors += "Service $svcName : $($_.Exception.Message)"
                        Write-Log -Level "WARNING" -Category "System" -Message "Failed to set service $svcName to Manual: $($_.Exception.Message)"
                    }
                }
            }
        }

        if ($profile.PSObject.Properties["PowerPlan"] -and $profile.PowerPlan) {
            try {
                $planGuids = @{
                    "Balanced"           = "381b4222-f694-41f0-9685-ff5bb260df2e"
                    "High Performance"   = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
                    "Power Saver"        = "a1841308-3541-4fab-bc81-f71556f20b4a"
                    "Ultimate Performance" = "e9a42b02-d5df-448d-aa00-03f14749eb61"
                }

                $guid = $planGuids[$profile.PowerPlan]
                if ($guid) {
                    if ($profile.PowerPlan -eq "Ultimate Performance") {
                        $exists = powercfg /list 2>&1 | Select-String $guid
                        if (-not $exists) {
                            powercfg -duplicatescheme $guid 2>&1 | Out-Null
                        }
                    }

                    powercfg /setactive $guid 2>&1 | Out-Null
                    $result.Changes++
                    Write-Log -Level "SUCCESS" -Category "System" -Message "Power plan set to $($profile.PowerPlan)"
                }
            }
            catch {
                $result.Errors += "PowerPlan : $($_.Exception.Message)"
                Write-Log -Level "WARNING" -Category "System" -Message "Failed to set power plan: $($_.Exception.Message)"
            }
        }

        if ($profile.PSObject.Properties["RegistryTweaks"] -and $profile.RegistryTweaks) {
            foreach ($tweak in $profile.RegistryTweaks) {
                try {
                    $tweakPath = $tweak.Path
                    $tweakName = $tweak.Name
                    $tweakValue = $tweak.Value
                    $tweakType = $tweak.Type

                    if (-not (Test-Path $tweakPath)) {
                        New-Item -Path $tweakPath -Force | Out-Null
                    }

                    Set-ItemProperty -Path $tweakPath -Name $tweakName -Value $tweakValue -Type $tweakType -Force -ErrorAction Stop
                    $result.Changes++
                }
                catch {
                    $result.Errors += "Registry $($tweak.Path)\$($tweak.Name) : $($_.Exception.Message)"
                    Write-Log -Level "WARNING" -Category "System" -Message "Failed to apply registry tweak $($tweak.Path)\$($tweak.Name): $($_.Exception.Message)"
                }
            }
        }

        if ($profile.PSObject.Properties["VisualEffects"]) {
            $ve = $profile.VisualEffects
            try {
                $desktopPath = "HKCU:\Control Panel\Desktop"

                if ($ve.PSObject.Properties["Animations"] -and -not $ve.Animations) {
                    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value "0" -Force -ErrorAction SilentlyContinue
                    $result.Changes++
                }
                else {
                    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value "1" -Force -ErrorAction SilentlyContinue
                }

                if ($ve.PSObject.Properties["Transparency"] -and -not $ve.Transparency) {
                    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                    $result.Changes++
                }
                else {
                    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
                }
            }
            catch {
                $result.Errors += "VisualEffects : $($_.Exception.Message)"
                Write-Log -Level "WARNING" -Category "System" -Message "Failed to apply visual effects: $($_.Exception.Message)"
            }
        }

        $script:ActiveProfile = $Name

        if ($script:ProfilesPath -ne "") {
            $activeFile = Join-Path $script:ProfilesPath "active_profile.txt"
            $Name | Out-File -FilePath $activeFile -Encoding UTF8 -Force
        }

        Write-Log -Level "SUCCESS" -Category "System" -Message "Profile '$Name' applied: $($result.Changes) changes, $($result.Errors.Count) errors"
    }
    catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "System" -Message "Failed to apply profile: $($_.Exception.Message)"
    }

    return $result
}

function global:New-CustomProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Description,

        [Parameter()]
        [string]$BasedOn = "",

        [Parameter()]
        [hashtable]$Services = @{},

        [Parameter()]
        [hashtable]$Startup = @{},

        [Parameter()]
        [string]$PowerPlan = "Balanced",

        [Parameter()]
        [hashtable]$Privacy = @{},

        [Parameter()]
        [hashtable]$Network = @{},

        [Parameter()]
        [hashtable]$VisualEffects = @{},

        [Parameter()]
        [array]$RegistryTweaks = @()
    )

    $existing = $script:BuiltinProfiles | Where-Object { $_.Name -eq $Name }
    if ($null -eq $existing) {
        $existing = $script:CustomProfiles | Where-Object { $_.Name -eq $Name }
    }

    if ($null -ne $existing) {
        Write-Log -Level "ERROR" -Category "System" -Message "Profile '$Name' already exists"
        return $null
    }

    $baseProfile = $null
    if ($BasedOn -ne "") {
        $baseProfile = $script:BuiltinProfiles | Where-Object { $_.Name -eq $BasedOn } | Select-Object -First 1
        if ($null -eq $baseProfile) {
            $baseProfile = $script:CustomProfiles | Where-Object { $_.Name -eq $BasedOn } | Select-Object -First 1
        }
    }

    $newProfile = [PSCustomObject]@{
        Name           = $Name
        Description    = $Description
        Category       = "Custom"
        BuiltIn        = $false
        Services       = if ($Services.Count -gt 0) { $Services } elseif ($baseProfile) { $baseProfile.Services } else { @{ Disable = @(); Auto = @(); Manual = @() } }
        Startup        = if ($Startup.Count -gt 0) { $Startup } elseif ($baseProfile) { $baseProfile.Startup } else { @{ Disable = @() } }
        PowerPlan      = if ($PowerPlan -ne "Balanced" -or -not $baseProfile) { $PowerPlan } else { $baseProfile.PowerPlan }
        Privacy        = if ($Privacy.Count -gt 0) { $Privacy } elseif ($baseProfile) { $baseProfile.Privacy } else { @{} }
        Network        = if ($Network.Count -gt 0) { $Network } elseif ($baseProfile) { $baseProfile.Network } else { @{} }
        VisualEffects  = if ($VisualEffects.Count -gt 0) { $VisualEffects } elseif ($baseProfile) { $baseProfile.VisualEffects } else { @{} }
        RegistryTweaks = if ($RegistryTweaks.Count -gt 0) { $RegistryTweaks } elseif ($baseProfile) { $baseProfile.RegistryTweaks } else { @() }
    }

    $script:CustomProfiles += $newProfile

    if ($script:ProfilesPath -ne "") {
        $customDir = Join-Path $script:ProfilesPath "custom"
        $filePath = Join-Path $customDir "$($Name -replace '[^a-zA-Z0-9_-]', '_').json"
        $json = $newProfile | ConvertTo-Json -Depth 10
        $json | Out-File -FilePath $filePath -Encoding UTF8 -Force
    }

    Write-Log -Level "SUCCESS" -Category "System" -Message "Custom profile '$Name' created"
    return $newProfile
}

function global:Remove-CustomProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $builtin = $script:BuiltinProfiles | Where-Object { $_.Name -eq $Name }
    if ($null -ne $builtin) {
        Write-Log -Level "ERROR" -Category "System" -Message "Cannot remove built-in profile: $Name"
        return $false
    }

    $custom = $script:CustomProfiles | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
    if ($null -eq $custom) {
        Write-Log -Level "ERROR" -Category "System" -Message "Custom profile not found: $Name"
        return $false
    }

    if ($script:ActiveProfile -eq $Name) {
        $script:ActiveProfile = $null
        $activeFile = Join-Path $script:ProfilesPath "active_profile.txt"
        if (Test-Path $activeFile) {
            Remove-Item -Path $activeFile -Force -ErrorAction SilentlyContinue
        }
    }

    $script:CustomProfiles = @($script:CustomProfiles | Where-Object { $_.Name -ne $Name })

    if ($script:ProfilesPath -ne "") {
        $filePath = Join-Path $script:ProfilesPath "custom" "$($Name -replace '[^a-zA-Z0-9_-]', '_').json"
        if (Test-Path $filePath) {
            Remove-Item -Path $filePath -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Log -Level "SUCCESS" -Category "System" -Message "Custom profile '$Name' removed"
    return $true
}

function global:Export-Profile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    $profile = $script:BuiltinProfiles | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
    if ($null -eq $profile) {
        $profile = $script:CustomProfiles | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
    }

    if ($null -eq $profile) {
        Write-Log -Level "ERROR" -Category "System" -Message "Profile not found for export: $Name"
        return $false
    }

    try {
        $parentDir = Split-Path $OutputPath -Parent
        if ($parentDir -and -not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }

        $json = $profile | ConvertTo-Json -Depth 10
        $json | Out-File -FilePath $OutputPath -Encoding UTF8 -Force

        Write-Log -Level "SUCCESS" -Category "System" -Message "Profile '$Name' exported to $OutputPath"
        return $true
    }
    catch {
        Write-Log -Level "ERROR" -Category "System" -Message "Failed to export profile: $($_.Exception.Message)"
        return $false
    }
}

function global:Import-Profile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter()]
        [string]$AsName = ""
    )

    if (-not (Test-Path $FilePath)) {
        Write-Log -Level "ERROR" -Category "System" -Message "Profile file not found: $FilePath"
        return $null
    }

    try {
        $json = Get-Content -Path $FilePath -Raw -Encoding UTF8
        $profile = $json | ConvertFrom-Json

        $profileName = if ($AsName -ne "") { $AsName } else { $profile.Name }

        $existing = $script:BuiltinProfiles | Where-Object { $_.Name -eq $profileName }
        if ($null -eq $existing) {
            $existing = $script:CustomProfiles | Where-Object { $_.Name -eq $profileName }
        }

        if ($null -ne $existing) {
            Write-Log -Level "ERROR" -Category "System" -Message "Profile '$profileName' already exists, cannot import"
            return $null
        }

        $importedProfile = [PSCustomObject]@{
            Name           = $profileName
            Description    = if ($profile.PSObject.Properties["Description"]) { $profile.Description } else { "Imported profile" }
            Category       = "Custom"
            BuiltIn        = $false
            Services       = if ($profile.PSObject.Properties["Services"]) { $profile.Services } else { @{ Disable = @(); Auto = @(); Manual = @() } }
            Startup        = if ($profile.PSObject.Properties["Startup"]) { $profile.Startup } else { @{ Disable = @() } }
            PowerPlan      = if ($profile.PSObject.Properties["PowerPlan"]) { $profile.PowerPlan } else { "Balanced" }
            Privacy        = if ($profile.PSObject.Properties["Privacy"]) { $profile.Privacy } else { @{} }
            Network        = if ($profile.PSObject.Properties["Network"]) { $profile.Network } else { @{} }
            VisualEffects  = if ($profile.PSObject.Properties["VisualEffects"]) { $profile.VisualEffects } else { @{} }
            RegistryTweaks = if ($profile.PSObject.Properties["RegistryTweaks"]) { $profile.RegistryTweaks } else { @() }
        }

        $script:CustomProfiles += $importedProfile

        if ($script:ProfilesPath -ne "") {
            $customDir = Join-Path $script:ProfilesPath "custom"
            $savePath = Join-Path $customDir "$($profileName -replace '[^a-zA-Z0-9_-]', '_').json"
            $json | Out-File -FilePath $savePath -Encoding UTF8 -Force
        }

        Write-Log -Level "SUCCESS" -Category "System" -Message "Profile '$profileName' imported from $FilePath"
        return $importedProfile
    }
    catch {
        Write-Log -Level "ERROR" -Category "System" -Message "Failed to import profile: $($_.Exception.Message)"
        return $null
    }
}

function global:Compare-Profiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProfileA,

        [Parameter(Mandatory = $true)]
        [string]$ProfileB
    )

    $profile1 = $script:BuiltinProfiles | Where-Object { $_.Name -eq $ProfileA } | Select-Object -First 1
    if ($null -eq $profile1) {
        $profile1 = $script:CustomProfiles | Where-Object { $_.Name -eq $ProfileA } | Select-Object -First 1
    }

    $profile2 = $script:BuiltinProfiles | Where-Object { $_.Name -eq $ProfileB } | Select-Object -First 1
    if ($null -eq $profile2) {
        $profile2 = $script:CustomProfiles | Where-Object { $_.Name -eq $ProfileB } | Select-Object -First 1
    }

    if ($null -eq $profile1) {
        Write-Log -Level "ERROR" -Category "System" -Message "Profile not found: $ProfileA"
        return $null
    }

    if ($null -eq $profile2) {
        Write-Log -Level "ERROR" -Category "System" -Message "Profile not found: $ProfileB"
        return $null
    }

    $differences = @()

    $svcDiff = Compare-Object -ReferenceObject @($profile1.Services.Disable) -DifferenceObject @($profile2.Services.Disable)
    foreach ($diff in $svcDiff) {
        $differences += [PSCustomObject]@{
            Section  = "Services\Disable"
            Value    = $diff.InputObject
            InA      = ($diff.SideIndicator -eq "<=")
            InB      = ($diff.SideIndicator -eq "=>")
        }
    }

    $svcAutoDiff = Compare-Object -ReferenceObject @($profile1.Services.Auto) -DifferenceObject @($profile2.Services.Auto)
    foreach ($diff in $svcAutoDiff) {
        $differences += [PSCustomObject]@{
            Section  = "Services\Auto"
            Value    = $diff.InputObject
            InA      = ($diff.SideIndicator -eq "<=")
            InB      = ($diff.SideIndicator -eq "=>")
        }
    }

    if ($profile1.PowerPlan -ne $profile2.PowerPlan) {
        $differences += [PSCustomObject]@{
            Section  = "PowerPlan"
            Value    = "$($profile1.PowerPlan) vs $($profile2.PowerPlan)"
            InA      = $true
            InB      = $true
        }
    }

    $startupDiff = Compare-Object -ReferenceObject @($profile1.Startup.Disable) -DifferenceObject @($profile2.Startup.Disable)
    foreach ($diff in $startupDiff) {
        $differences += [PSCustomObject]@{
            Section  = "Startup\Disable"
            Value    = $diff.InputObject
            InA      = ($diff.SideIndicator -eq "<=")
            InB      = ($diff.SideIndicator -eq "=>")
        }
    }

    $tweakCount1 = if ($profile1.RegistryTweaks) { $profile1.RegistryTweaks.Count } else { 0 }
    $tweakCount2 = if ($profile2.RegistryTweaks) { $profile2.RegistryTweaks.Count } else { 0 }
    if ($tweakCount1 -ne $tweakCount2) {
        $differences += [PSCustomObject]@{
            Section  = "RegistryTweaks"
            Value    = "$tweakCount1 tweaks vs $tweakCount2 tweaks"
            InA      = $true
            InB      = $true
        }
    }

    $result = [PSCustomObject]@{
        ProfileA     = $ProfileA
        ProfileB     = $ProfileB
        Differences  = $differences
        TotalDiffs   = $differences.Count
        Identical    = ($differences.Count -eq 0)
    }

    Write-Log -Level "INFO" -Category "System" -Message "Profile comparison: $ProfileA vs $ProfileB - $($differences.Count) differences found"

    return $result
}
