# WinTune Pro - Enhanced Features Registry
# Centralized registry of all optimization features from E:\Tools analysis

# ============================================================================
# PRIVACY REGISTRY TWEAKS
# ============================================================================
$script:PrivacyRegistry = @{
    "Telemetry" = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name = "AllowTelemetry"; Value = 0; Type = "DWord"; Description = "Disable telemetry collection" },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"; Name = "MaxTelemetryAllowed"; Value = 0; Type = "DWord"; Description = "Set max telemetry to zero" },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name = "DoNotShowFeedbackNotifications"; Value = 1; Type = "DWord"; Description = "Disable feedback notifications" }
    )
    "Cortana" = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "AllowCortana"; Value = 0; Type = "DWord"; Description = "Disable Cortana" },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "DisableWebSearch"; Value = 1; Type = "DWord"; Description = "Disable web search" },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search"; Name = "BingSearchEnabled"; Value = 0; Type = "DWord"; Description = "Disable Bing search" }
    )
    "Location" = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors"; Name = "DisableLocation"; Value = 1; Type = "DWord"; Description = "Disable location tracking" }
    )
    "Advertising" = @(
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo"; Name = "Enabled"; Value = 0; Type = "DWord"; Description = "Disable advertising ID" },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo"; Name = "DisabledByGroupPolicy"; Value = 1; Type = "DWord"; Description = "Disable ad ID via policy" }
    )
    "Feedback" = @(
        @{ Path = "HKCU:\Software\Microsoft\Siuf\Rules"; Name = "NumberOfSIUFInPeriod"; Value = 0; Type = "DWord"; Description = "Disable feedback prompts" }
    )
    "ConsumerFeatures" = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"; Name = "DisableWindowsConsumerFeatures"; Value = 1; Type = "DWord"; Description = "Disable app suggestions" }
    )
    "ActivityHistory" = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"; Name = "EnableActivityFeed"; Value = 0; Type = "DWord"; Description = "Disable activity feed" },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"; Name = "PublishUserActivities"; Value = 0; Type = "DWord"; Description = "Disable activity publishing" }
    )
    "InputPersonalization" = @(
        @{ Path = "HKCU:\SOFTWARE\Microsoft\InputPersonalization"; Name = "RestrictImplicitInkCollection"; Value = 1; Type = "DWord"; Description = "Restrict ink collection" },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\InputPersonalization"; Name = "RestrictImplicitTextCollection"; Value = 1; Type = "DWord"; Description = "Restrict text collection" }
    )
    "Defender" = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet"; Name = "SubmitSamplesConsent"; Value = 2; Type = "DWord"; Description = "Disable sample submission" }
    )
}

# ============================================================================
# PERFORMANCE REGISTRY TWEAKS
# ============================================================================
$script:PerformanceRegistry = @{
    "MemoryManagement" = @(
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name = "DisablePagingExecutive"; Value = 1; Type = "DWord"; Description = "Keep kernel in RAM" },
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name = "LargeSystemCache"; Value = 0; Type = "DWord"; Description = "Optimize system cache" }
    )
    "CPUPriority" = @(
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"; Name = "Win32PrioritySeparation"; Value = 38; Type = "DWord"; Description = "Optimize CPU priority for responsiveness" }
    )
    "Multimedia" = @(
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; Name = "SystemResponsiveness"; Value = 1; Type = "DWord"; Description = "Prioritize foreground apps" },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"; Name = "NetworkThrottlingIndex"; Value = 4294967295; Type = "DWord"; Description = "Disable network throttling" }
    )
    "FileSystem" = @(
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"; Name = "LongPathsEnabled"; Value = 1; Type = "DWord"; Description = "Enable long path support" },
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"; Name = "NtfsDisableLastAccessUpdate"; Value = 80000001; Type = "DWord"; Description = "Disable last access time" }
    )
    "ResponseTime" = @(
        @{ Path = "HKCU:\Control Panel\Desktop"; Name = "MenuShowDelay"; Value = "0"; Type = "String"; Description = "Instant menu display" },
        @{ Path = "HKCU:\Control Panel\Desktop"; Name = "WaitToKillAppTimeout"; Value = "2000"; Type = "String"; Description = "Faster app close" },
        @{ Path = "HKCU:\Control Panel\Desktop"; Name = "HungAppTimeout"; Value = "1000"; Type = "String"; Description = "Faster hung app detection" },
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control"; Name = "WaitToKillServiceTimeout"; Value = "2000"; Type = "String"; Description = "Faster service shutdown" }
    )
    "VisualEffects" = @(
        @{ Path = "HKCU:\Control Panel\Desktop"; Name = "DragFullWindows"; Value = "0"; Type = "String"; Description = "Disable full window drag" },
        @{ Path = "HKCU:\Control Panel\Desktop\WindowMetrics"; Name = "MinAnimate"; Value = "0"; Type = "String"; Description = "Disable minimize animation" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "TaskbarAnimations"; Value = 0; Type = "DWord"; Description = "Disable taskbar animations" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "ListviewAlphaSelect"; Value = 0; Type = "DWord"; Description = "Disable listview alpha" },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "ListviewShadow"; Value = 0; Type = "DWord"; Description = "Disable listview shadow" }
    )
    "GPUScheduling" = @(
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"; Name = "HwSchMode"; Value = 2; Type = "DWord"; Description = "Enable hardware GPU scheduling" }
    )
    "Gaming" = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"; Name = "AllowgameDVR"; Value = 0; Type = "DWord"; Description = "Disable Game DVR" },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "GPU Priority"; Value = 8; Type = "DWord"; Description = "High GPU priority for games" },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "Priority"; Value = 6; Type = "DWord"; Description = "High priority for games" },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Name = "Scheduling Category"; Value = "High"; Type = "String"; Description = "High scheduling for games" }
    )
}

# ============================================================================
# NETWORK REGISTRY TWEAKS
# ============================================================================
$script:NetworkRegistry = @{
    "TCP" = @(
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name = "Tcp1323Opts"; Value = 1; Type = "DWord"; Description = "Enable RFC 1323" },
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name = "TCPNoDelay"; Value = 1; Type = "DWord"; Description = "Disable Nagle algorithm" },
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name = "TcpAckFrequency"; Value = 1; Type = "DWord"; Description = "Immediate ACK" },
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name = "DefaultTTL"; Value = 64; Type = "DWord"; Description = "Set TTL to 64" },
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name = "SackOpts"; Value = 1; Type = "DWord"; Description = "Enable SACK" },
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name = "EnablePMTUDiscovery"; Value = 1; Type = "DWord"; Description = "Enable PMTU discovery" }
    )
    "DNS" = @(
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"; Name = "MaxCacheTtl"; Value = 86400; Type = "DWord"; Description = "DNS cache TTL" },
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"; Name = "MaxNegativeCacheTtl"; Value = 900; Type = "DWord"; Description = "Negative DNS cache TTL" }
    )
    "Security" = @(
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name = "SynAttackProtect"; Value = 1; Type = "DWord"; Description = "SYN flood protection" },
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name = "EnableICMPRedirect"; Value = 0; Type = "DWord"; Description = "Disable ICMP redirect" }
    )
    "AutoRun" = @(
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"; Name = "NoDriveTypeAutoRun"; Value = 255; Type = "DWord"; Description = "Disable autorun" }
    )
}

# ============================================================================
# SECURITY REGISTRY TWEAKS
# ============================================================================
$script:SecurityRegistry = @{
    "Firewall" = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\DomainProfile"; Name = "EnableFirewall"; Value = 1; Type = "DWord"; Description = "Enable domain firewall" },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\PrivateProfile"; Name = "EnableFirewall"; Value = 1; Type = "DWord"; Description = "Enable private firewall" },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\PublicProfile"; Name = "EnableFirewall"; Value = 1; Type = "DWord"; Description = "Enable public firewall" }
    )
    "UAC" = @(
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"; Name = "EnableLUA"; Value = 1; Type = "DWord"; Description = "Enable UAC" },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"; Name = "ConsentPromptBehaviorAdmin"; Value = 5; Type = "DWord"; Description = "Prompt on secure desktop" },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"; Name = "PromptOnSecureDesktop"; Value = 1; Type = "DWord"; Description = "Secure desktop prompt" }
    )
    "RemoteAccess" = @(
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server"; Name = "fDenyTSConnections"; Value = 1; Type = "DWord"; Description = "Disable remote desktop" }
    )
    "SMB" = @(
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\lanmanserver\parameters"; Name = "SMB1"; Value = 0; Type = "DWord"; Description = "Disable SMB1" }
    )
}

# ============================================================================
# SERVICE PROFILES
# ============================================================================
$script:ServiceProfiles = @{
    "Performance" = @{
        Disable = @("SysMain", "WSearch", "DiagTrack", "dmwappushservice", "WerSvc", "WinRM", "Fax", "Spooler")
        Manual = @("BITS", "wuauserv", "TrustedInstaller")
    }
    "Gaming" = @{
        Disable = @("DiagTrack", "dmwappushservice", "WerSvc", "Fax", "TabletInputService", "Spooler", "WinRM", "RemoteRegistry")
        Manual = @("BITS", "wuauserv")
    }
    "Privacy" = @{
        Disable = @("DiagTrack", "dmwappushservice", "WerSvc", "OneSyncSvc", "MessagingService", "WbioSrvc", "RetailDemo", "WMPNetworkSvc")
        Manual = @("BITS")
    }
    "Security" = @{
        Disable = @("RemoteRegistry", "WinRM", "Telnet", "SNMP", "NetTcpPortSharing", "SharedAccess")
        Manual = @("PolicyAgent")
    }
    "Minimal" = @{
        Disable = @("SysMain", "WSearch", "DiagTrack", "dmwappushservice", "WerSvc", "Fax", "Spooler", "WMPNetworkSvc", "MapsBroker", "lfsvc")
        Manual = @("BITS", "wuauserv", "TrustedInstaller", "AudioSrv")
    }
}

$script:CriticalServices = @("RpcSs", "RpcEptMapper", "DcomLaunch", "EventLog", "PlugPlay", "Power", "ProfSvc", "Schedule", "LanmanServer", "LanmanWorkstation", "Winlogon", "csrss", "lsass", "services", "smss", "wininit")

# ============================================================================
# BLOATWARE LISTS
# ============================================================================
$script:BloatwareApps = @(
    @{ Pattern = "*3DViewer*"; Category = "3D" },
    @{ Pattern = "*BingFinance*"; Category = "Bing" },
    @{ Pattern = "*BingNews*"; Category = "Bing" },
    @{ Pattern = "*BingSports*"; Category = "Bing" },
    @{ Pattern = "*BingWeather*"; Category = "Bing" },
    @{ Pattern = "*CandyCrush*"; Category = "Games" },
    @{ Pattern = "*GetHelp*"; Category = "System" },
    @{ Pattern = "*Getstarted*"; Category = "Tips" },
    @{ Pattern = "*Maps*"; Category = "Maps" },
    @{ Pattern = "*Messaging*"; Category = "Social" },
    @{ Pattern = "*MicrosoftSolitaireCollection*"; Category = "Games" },
    @{ Pattern = "*Mixed*"; Category = "VR" },
    @{ Pattern = "*MixedReality*"; Category = "VR" },
    @{ Pattern = "*OneConnect*"; Category = "Cloud" },
    @{ Pattern = "*OneNote*"; Category = "Office" },
    @{ Pattern = "*Paint3D*"; Category = "3D" },
    @{ Pattern = "*People*"; Category = "Social" },
    @{ Pattern = "*Print3D*"; Category = "3D" },
    @{ Pattern = "*ScreenSketch*"; Category = "System" },
    @{ Pattern = "*Skype*"; Category = "Communication" },
    @{ Pattern = "*StickyNotes*"; Category = "Productivity" },
    @{ Pattern = "*Sway*"; Category = "Office" },
    @{ Pattern = "*Todo*"; Category = "Productivity" },
    @{ Pattern = "*Whiteboard*"; Category = "Productivity" },
    @{ Pattern = "*WindowsFeedbackHub*"; Category = "Feedback" },
    @{ Pattern = "*WindowsMaps*"; Category = "Maps" },
    @{ Pattern = "*Xbox*"; Category = "Gaming" },
    @{ Pattern = "*YourPhone*"; Category = "Phone" },
    @{ Pattern = "*ZuneMusic*"; Category = "Media" },
    @{ Pattern = "*ZuneVideo*"; Category = "Media" },
    @{ Pattern = "*Clipchamp*"; Category = "Video" },
    @{ Pattern = "*Disney*"; Category = "Entertainment" },
    @{ Pattern = "*Spotify*"; Category = "Music" },
    @{ Pattern = "*TikTok*"; Category = "Social" },
    @{ Pattern = "*Facebook*"; Category = "Social" },
    @{ Pattern = "*Instagram*"; Category = "Social" },
    @{ Pattern = "*Duolingo*"; Category = "Education" },
    @{ Pattern = "*Adobe*"; Category = "Trial" },
    @{ Pattern = "*NetworkSpeedTest*"; Category = "Tools" }
)

# ============================================================================
# TELEMETRY SCHEDULED TASKS
# ============================================================================
$script:TelemetryTasks = @(
    '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser',
    '\Microsoft\Windows\Application Experience\ProgramDataUpdater',
    '\Microsoft\Windows\Autochk\Proxy',
    '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
    '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip',
    '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector',
    '\Microsoft\Windows\Feedback\Siuf\DmClient',
    '\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload',
    '\Microsoft\Windows\Windows Error Reporting\QueueReporting'
)

# ============================================================================
# CLEANING PATHS
# ============================================================================
$script:CleaningPaths = @{
    "UserTemp" = @("$env:TEMP", "$env:LOCALAPPDATA\Temp")
    "SystemTemp" = @("$env:WINDIR\Temp")
    "WindowsLogs" = @("$env:WINDIR\Logs", "$env:WINDIR\System32\LogFiles")
    "Prefetch" = @("$env:WINDIR\Prefetch")
    "ThumbnailCache" = @("$env:LOCALAPPDATA\Microsoft\Windows\Explorer")
    "WindowsUpdate" = @("$env:WINDIR\SoftwareDistribution\Download")
    "CrashDumps" = @("$env:WINDIR\Minidump", "$env:LOCALAPPDATA\CrashDumps", "$env:PROGRAMDATA\Microsoft\Windows\WER\ReportQueue", "$env:PROGRAMDATA\Microsoft\Windows\WER\ReportArchive")
    "OldWindows" = @("$env:SystemDrive\Windows.old", "$env:SystemDrive\`$Windows.~BT")
}

# ============================================================================
# FUNCTIONS
# ============================================================================
function global:Get-PrivacyRegistry { return $script:PrivacyRegistry }
function global:Get-PerformanceRegistry { return $script:PerformanceRegistry }
function global:Get-NetworkRegistry { return $script:NetworkRegistry }
function global:Get-SecurityRegistry { return $script:SecurityRegistry }
function global:Get-ServiceProfiles { return $script:ServiceProfiles }
function global:Get-BloatwareApps { return $script:BloatwareApps }
function global:Get-TelemetryTasks { return $script:TelemetryTasks }
function global:Get-CleaningPaths { return $script:CleaningPaths }
function global:Get-CriticalServices { return $script:CriticalServices }

function global:Apply-RegistryTweaks {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Tweaks,
        [bool]$TestMode = $false,
        [string]$Category = "General"
    )
    $results = @{ Applied = 0; Failed = 0; Actions = @() }

    foreach ($groupName in $Tweaks.Keys) {
        foreach ($tweak in $Tweaks[$groupName]) {
            if ($TestMode) {
                $results.Actions += "[Preview] $($tweak.Description)"
            } else {
                try {
                    if (-not (Test-Path $tweak.Path)) {
                        New-Item -Path $tweak.Path -Force | Out-Null
                    }
                    Set-ItemProperty -Path $tweak.Path -Name $tweak.Name -Value $tweak.Value -Type $tweak.Type -Force
                    $results.Applied++
                    $results.Actions += "Applied: $($tweak.Description)"
                } catch {
                    $results.Failed++
                    $results.Actions += "Failed: $($tweak.Description) - $($_.Exception.Message)"
                }
            }
        }
    }
    return $results
}

function global:Get-RegistryState {
    param([hashtable]$Tweaks)
    $state = @{}
    foreach ($groupName in $Tweaks.Keys) {
        $state[$groupName] = @()
        foreach ($tweak in $Tweaks[$groupName]) {
            try {
                $current = Get-ItemProperty -Path $tweak.Path -Name $tweak.Name -ErrorAction SilentlyContinue
                $isApplied = ($null -ne $current) -and ($current.($tweak.Name) -eq $tweak.Value)
                $state[$groupName] += @{
                    Name = $tweak.Description
                    Applied = $isApplied
                    Current = if ($current) { $current.($tweak.Name) } else { "Not set" }
                    Expected = $tweak.Value
                }
            } catch {
                $state[$groupName] += @{ Name = $tweak.Description; Applied = $false; Current = "Error"; Expected = $tweak.Value }
            }
        }
    }
    return $state
}

# ============================================================================
# ADDITIONAL FEATURES FROM E:\Tools (Win10-Initial-Setup-Script, privatezilla, etc.)
# ============================================================================

# SECURITY HARDENING
$script:SecurityHardeningRegistry = @{
    "ScriptHost" = @(
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows Script Host\Settings"; Name = "Enabled"; Value = 0; Type = "DWord"; Description = "Disable Windows Script Host (blocks .VBS/.JS malware)" }
    )
    "NetBIOS" = @(
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Netbt\Parameters"; Name = "NoNameReleaseOnDemand"; Value = 1; Type = "DWord"; Description = "Prevent NetBIOS name release on demand" }
    )
    "LLMNR" = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient"; Name = "EnableMulticast"; Value = 0; Type = "DWord"; Description = "Disable LLMNR (prevents credential theft)" }
    )
    "AdminShares" = @(
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters"; Name = "AutoShareServer"; Value = 0; Type = "DWord"; Description = "Disable hidden admin shares (C$, D$)" },
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters"; Name = "AutoShareWks"; Value = 0; Type = "DWord"; Description = "Disable hidden admin shares (workstation)" }
    )
}

# PERFORMANCE ENHANCEMENTS
$script:PerformanceEnhancements = @{
    "UWPSwapFile" = @(
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name = "SwapfileControl"; Value = 0; Type = "DWord"; Description = "Disable UWP swap file (frees ~256MB)" }
    )
    "StartupSound" = @(
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\BootAnimation"; Name = "DisableStartupSound"; Value = 1; Type = "DWord"; Description = "Disable startup sound (faster boot)" }
    )
    "MouseAcceleration" = @(
        @{ Path = "HKCU:\Control Panel\Mouse"; Name = "MouseSpeed"; Value = "0"; Type = "String"; Description = "Disable mouse acceleration (gaming)" },
        @{ Path = "HKCU:\Control Panel\Mouse"; Name = "MouseThreshold1"; Value = "0"; Type = "String"; Description = "Disable mouse threshold 1" },
        @{ Path = "HKCU:\Control Panel\Mouse"; Name = "MouseThreshold2"; Value = "0"; Type = "String"; Description = "Disable mouse threshold 2" }
    )
}

# UI/UX ENHANCEMENTS
$script:UIEnhancements = @{
    "TaskbarSeconds" = @(
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "ShowSecondsInSystemClock"; Value = 1; Type = "DWord"; Description = "Show seconds in taskbar clock" }
    )
    "SearchAppInStore" = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"; Name = "NoUseStoreOpenWith"; Value = 1; Type = "DWord"; Description = "Disable 'Search for app in Store' prompt" }
    )
    "NewAppPrompt" = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"; Name = "NoNewAppAlert"; Value = 1; Type = "DWord"; Description = "Suppress 'How do you want to open this file?' dialog" }
    )
    "RecentlyAddedApps" = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"; Name = "HideRecentlyAddedApps"; Value = 1; Type = "DWord"; Description = "Hide 'Recently added' from Start Menu" }
    )
    "MostUsedApps" = @(
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"; Name = "NoStartMenuMFUprogramsList"; Value = 1; Type = "DWord"; Description = "Hide 'Most used' apps from Start Menu" }
    )
    "ShortcutArrow" = @(
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Icons"; Name = "29"; Value = "%SystemRoot%\System32\imageres.dll,-1015"; Type = "String"; Description = "Hide shortcut arrow overlay" }
    )
    "NumlockOnStartup" = @(
        @{ Path = "HKU:\.DEFAULT\Control Panel\Keyboard"; Name = "InitialKeyboardIndicators"; Value = 2147483650; Type = "DWord"; Description = "Enable NumLock on startup" }
    )
}

# PRIVACY ADDITIONS
$script:PrivacyAdditional = @{
    "TailoredExperiences" = @(
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy"; Name = "TailoredExperiencesWithDiagnosticDataEnabled"; Value = 0; Type = "DWord"; Description = "Disable tailored experiences with diagnostic data" }
    )
    "MediaMetadata" = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\WindowsMediaPlayer"; Name = "PreventMusicFileMetadataRetrieval"; Value = 1; Type = "DWord"; Description = "Prevent WMP from fetching media metadata online" }
    )
    "NetworkDeviceAutoInst" = @(
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\NcdAutoSetup\Private"; Name = "AutoSetup"; Value = 0; Type = "DWord"; Description = "Disable automatic network device installation" }
    )
}

function global:Get-SecurityHardeningRegistry { return $script:SecurityHardeningRegistry }
function global:Get-PerformanceEnhancements { return $script:PerformanceEnhancements }
function global:Get-UIEnhancements { return $script:UIEnhancements }
function global:Get-PrivacyAdditional { return $script:PrivacyAdditional }

function global:Apply-SecurityHardening {
    param([bool]$TestMode = $false)
    return Apply-RegistryTweaks -Tweaks $script:SecurityHardeningRegistry -TestMode $TestMode -Category "Security"
}

function global:Apply-PerformanceEnhancements {
    param([bool]$TestMode = $false)
    return Apply-RegistryTweaks -Tweaks $script:PerformanceEnhancements -TestMode $TestMode -Category "Performance"
}

function global:Apply-UIEnhancements {
    param([bool]$TestMode = $false)
    return Apply-RegistryTweaks -Tweaks $script:UIEnhancements -TestMode $TestMode -Category "UI"
}

function global:Apply-PrivacyAdditional {
    param([bool]$TestMode = $false)
    return Apply-RegistryTweaks -Tweaks $script:PrivacyAdditional -TestMode $TestMode -Category "Privacy"
}

function global:Apply-AllToolsTweaks {
    param([bool]$TestMode = $false)
    $results = @{ Actions = @(); Applied = 0; Failed = 0 }
    $results.Actions += (Apply-SecurityHardening -TestMode $TestMode).Actions
    $results.Actions += (Apply-PerformanceEnhancements -TestMode $TestMode).Actions
    $results.Actions += (Apply-UIEnhancements -TestMode $TestMode).Actions
    $results.Actions += (Apply-PrivacyAdditional -TestMode $TestMode).Actions
    return $results
}
