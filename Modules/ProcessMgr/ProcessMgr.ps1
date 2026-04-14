<#
.SYNOPSIS
    WinTunePro ProcessMgr Module - Process and service management
.DESCRIPTION
    Manages processes and services including high resource monitoring, process
    control, service analysis, and optimization.
.NOTES
    File: Modules\ProcessMgr\ProcessMgr.ps1
    Version: 1.0.0
    PowerShell: 5.1+
    Compatible: Windows 10, Windows 11
#>

#Requires -Version 5.1

$script:UnnecessaryBackgroundProcesses = @(
    "OneDrive"
    "Teams"
    "Skype"
    "Cortana"
    "SearchUI"
    "YourPhone"
    "GameBarPresenceWriter"
    "GameBar"
    "Xbox.TCUI"
    "RuntimeBroker"
    "ShellExperienceHost"
    "TextInputHost"
    "ctfmon"
    "MicrosoftEdgeUpdate"
    "EdgeUpdate"
    "GoogleUpdate"
    "AdobeARM"
    "AdobeUpdater"
    "jusched"
    "jucheck"
    "iTunesHelper"
    "iTunes"
    "Spotify"
    "Discord"
    "Zoom"
    "Slack"
    "Telegram"
    "WhatsApp"
    "Steam"
    "EpicGamesLauncher"
    "Origin"
    "UbisoftConnect"
    "Battle.net"
    "GOG Galaxy"
)

$script:EssentialServices = @(
    "wuauserv"
    "bits"
    "cryptsvc"
    "msiserver"
    "EventLog"
    "PlugPlay"
    "Power"
    "RpcSs"
    "RpcEptMapper"
    "DcomLaunch"
    "nsi"
    "Winmgmt"
    "LanmanWorkstation"
    "LanmanServer"
    "Dhcp"
    "Dnscache"
    "NlaSvc"
    "Themes"
    "AudioSrv"
    "AudioEndpointBuilder"
    "WlanSvc"
    "EventSystem"
    "Schedule"
    "ShellHWDetection"
    "ProfSvc"
    "gpsvc"
    "SessionEnv"
    "Appinfo"
    "UsoSvc"
    "WSearch"
    "SecurityHealthService"
    "WinDefend"
    "Sense"
    "WdNisSvc"
    "mpssvc"
)

function global:Get-HighResourceProcesses {
    <#
    .SYNOPSIS
        List processes using high CPU/memory.
    #>
    param(
        [Parameter()]
        [double]$CPUThresholdPercent = 5,

        [Parameter()]
        [long]$MemoryThresholdMB = 200,

        [Parameter()]
        [int]$TopN = 0
    )

    $result = @{
        Success  = $true
        Details  = @()
        Errors   = @()
    }

    Write-Log -Level "INFO" -Category "System" -Message "Scanning for high resource processes (CPU>${CPUThresholdPercent}%, Mem>${MemoryThresholdMB}MB)..."

    try {
        $processes = Get-Process -ErrorAction Stop
        $cpuCount = (Get-CimInstance -ClassName Win32_Processor | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
        if (-not $cpuCount -or $cpuCount -lt 1) { $cpuCount = 1 }

        foreach ($proc in $processes) {
            try {
                $cpuPercent = 0
                if ($proc.CPU) {
                    $cpuPercent = [math]::Round(($proc.CPU / $cpuCount) * 100, 2)
                }

                $memMB = [math]::Round($proc.WorkingSet64 / 1MB, 2)

                if ($cpuPercent -ge $CPUThresholdPercent -or $memMB -ge $MemoryThresholdMB) {
                    $isUnnecessary = $false
                    foreach ($unnecessary in $script:UnnecessaryBackgroundProcesses) {
                        if ($proc.ProcessName -like "*$unnecessary*") {
                            $isUnnecessary = $true
                            break
                        }
                    }

                    $result.Details += @{
                        ProcessName    = $proc.ProcessName
                        PID            = $proc.Id
                        CPUPercent     = $cpuPercent
                        MemoryMB       = $memMB
                        Handles        = $proc.HandleCount
                        Threads        = $proc.Threads.Count
                        StartTime      = if ($proc.StartTime) { $proc.StartTime.ToString("yyyy-MM-dd HH:mm:ss") } else { "N/A" }
                        IsUnnecessary  = $isUnnecessary
                        MainWindowTitle = $proc.MainWindowTitle
                    }
                }
            } catch {
                continue
            }
        }

        $result.Details = @($result.Details | Sort-Object MemoryMB -Descending)
        if ($TopN -gt 0 -and $result.Details.Count -gt $TopN) {
            $result.Details = @($result.Details | Select-Object -First $TopN)
        }

        Write-Log -Level "INFO" -Category "System" -Message "Found $($result.Details.Count) high resource processes"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "System" -Message "Failed to scan processes: $($_.Exception.Message)"
    }

    return $result
}

function global:Stop-ProcessByName {
    <#
    .SYNOPSIS
        Stop a process with confirmation.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProcessName,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$Confirm
    )

    $result = @{
        Success  = $true
        Details  = @{
            ProcessName = $ProcessName
            StoppedPIDs = @()
            SkippedPIDs = @()
            AlreadyStopped = $false
        }
        Errors   = @()
    }

    Write-Log -Level "INFO" -Category "System" -Message "Stopping process: $ProcessName"

    try {
        $processes = Get-Process -Name $ProcessName -ErrorAction Stop

        if (-not $processes) {
            $result.Details.AlreadyStopped = $true
            Write-Log -Level "INFO" -Category "System" -Message "Process $ProcessName is not running"
            return $result
        }

        foreach ($proc in $processes) {
            if ($Confirm -and -not $Force) {
                Write-Log -Level "WARNING" -Category "System" -Message "Would stop $($proc.ProcessName) (PID: $($proc.Id)) - use -Force to confirm"
                $result.Details.SkippedPIDs += $proc.Id
                continue
            }

            try {
                if ($Force) {
                    Stop-Process -Id $proc.Id -Force -ErrorAction Stop
                } else {
                    Stop-Process -Id $proc.Id -ErrorAction Stop
                }
                $result.Details.StoppedPIDs += $proc.Id
                Write-Log -Level "SUCCESS" -Category "System" -Message "Stopped $($proc.ProcessName) (PID: $($proc.Id))"
            } catch {
                $result.Errors += "Failed to stop PID $($proc.Id): $($_.Exception.Message)"
                Write-Log -Level "WARNING" -Category "System" -Message "Failed to stop PID $($proc.Id): $($_.Exception.Message)"
            }
        }

        Write-Log -Level "SUCCESS" -Category "System" -Message "Process $ProcessName : $($result.Details.StoppedPIDs.Count) stopped, $($result.Details.SkippedPIDs.Count) skipped"
    } catch [Microsoft.PowerShell.Commands.ProcessCommandException] {
        $result.Details.AlreadyStopped = $true
        Write-Log -Level "INFO" -Category "System" -Message "Process $ProcessName is not running"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "System" -Message "Failed to stop process $ProcessName : $($_.Exception.Message)"
    }

    return $result
}

function global:Set-ProcessPriority {
    <#
    .SYNOPSIS
        Set process priority.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProcessName,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Idle", "BelowNormal", "Normal", "AboveNormal", "High", "RealTime")]
        [string]$Priority
    )

    $result = @{
        Success  = $true
        Details  = @{
            ProcessName     = $ProcessName
            PreviousPriority = ""
            NewPriority     = $Priority
            ModifiedPIDs    = @()
        }
        Errors   = @()
    }

    Write-Log -Level "INFO" -Category "System" -Message "Setting priority for $ProcessName to $Priority"

    $priorityClass = switch ($Priority) {
        "Idle"        { [System.Diagnostics.ProcessPriorityClass]::Idle }
        "BelowNormal" { [System.Diagnostics.ProcessPriorityClass]::BelowNormal }
        "Normal"      { [System.Diagnostics.ProcessPriorityClass]::Normal }
        "AboveNormal" { [System.Diagnostics.ProcessPriorityClass]::AboveNormal }
        "High"        { [System.Diagnostics.ProcessPriorityClass]::High }
        "RealTime"    { [System.Diagnostics.ProcessPriorityClass]::RealTime }
    }

    try {
        $processes = Get-Process -Name $ProcessName -ErrorAction Stop

        foreach ($proc in $processes) {
            try {
                $result.Details.PreviousPriority = $proc.PriorityClass.ToString()
                $proc.PriorityClass = $priorityClass
                $result.Details.ModifiedPIDs += $proc.Id
                Write-Log -Level "SUCCESS" -Category "System" -Message "Set $($proc.ProcessName) (PID: $($proc.Id)) to $Priority"
            } catch {
                $result.Errors += "Failed to set priority for PID $($proc.Id): $($_.Exception.Message)"
            }
        }

        Write-Log -Level "SUCCESS" -Category "System" -Message "Priority set for $($result.Details.ModifiedPIDs.Count) instances of $ProcessName"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "System" -Message "Failed to set priority for $ProcessName : $($_.Exception.Message)"
    }

    return $result
}

function global:Get-ServiceAnalysis {
    <#
    .SYNOPSIS
        Analyze services for optimization opportunities.
    #>
    $result = @{
        Success  = $true
        Details  = @{
            RunningAuto      = @()
            RunningManual     = @()
            RunningDisabled   = @()
            StoppedAuto       = @()
            OptimizationCandidates = @()
        }
        Errors   = @()
    }

    Write-Log -Level "INFO" -Category "System" -Message "Analyzing services for optimization..."

    $servicesToConsider = @(
        @{ Name = "DiagTrack"; DisplayName = "Diagnostics Tracking Service"; SuggestedStart = "Disabled"; Description = "Telemetry" }
        @{ Name = "dmwappushservice"; DisplayName = "WAP Push Message Routing"; SuggestedStart = "Disabled"; Description = "Telemetry" }
        @{ Name = "MapsBroker"; DisplayName = "Downloaded Maps Manager"; SuggestedStart = "Manual"; Description = "Rarely used" }
        @{ Name = "lfsvc"; DisplayName = "Geolocation Service"; SuggestedStart = "Manual"; Description = "Privacy" }
        @{ Name = "SharedAccess"; DisplayName = "Internet Connection Sharing"; SuggestedStart = "Manual"; Description = "Home networking" }
        @{ Name = "WMPNetworkSvc"; DisplayName = "Windows Media Player Network Sharing"; SuggestedStart = "Manual"; Description = "Media sharing" }
        @{ Name = "XblAuthManager"; DisplayName = "Xbox Live Auth Manager"; SuggestedStart = "Manual"; Description = "Xbox" }
        @{ Name = "XblGameSave"; DisplayName = "Xbox Live Game Save"; SuggestedStart = "Manual"; Description = "Xbox" }
        @{ Name = "XboxNetApiSvc"; DisplayName = "Xbox Live Networking"; SuggestedStart = "Manual"; Description = "Xbox" }
        @{ Name = "XboxGipSvc"; DisplayName = "Xbox Accessory Management"; SuggestedStart = "Manual"; Description = "Xbox" }
        @{ Name = "RetailDemo"; DisplayName = "Retail Demo Service"; SuggestedStart = "Disabled"; Description = "Demo mode" }
        @{ Name = "RemoteRegistry"; DisplayName = "Remote Registry"; SuggestedStart = "Disabled"; Description = "Security risk" }
        @{ Name = "WbioSrvc"; DisplayName = "Windows Biometric Service"; SuggestedStart = "Manual"; Description = "Fingerprint" }
        @{ Name = "TabletInputService"; DisplayName = "Touch Keyboard and Handwriting"; SuggestedStart = "Manual"; Description = "Tablet" }
        @{ Name = "WpnService"; DisplayName = "Windows Push Notifications"; SuggestedStart = "Manual"; Description = "Notifications" }
        @{ Name = "WSearch"; DisplayName = "Windows Search"; SuggestedStart = "Manual"; Description = "Indexing" }
        @{ Name = "SysMain"; DisplayName = "Superfetch"; SuggestedStart = "Manual"; Description = "Prefetch" }
        @{ Name = "BITS"; DisplayName = "Background Intelligent Transfer"; SuggestedStart = "Manual"; Description = "Updates" }
        @{ Name = "wuauserv"; DisplayName = "Windows Update"; SuggestedStart = "Manual"; Description = "Updates" }
    )

    try {
        $services = Get-Service -ErrorAction Stop

        foreach ($svc in $services) {
            $cimSvc = $null
            try {
                $cimSvc = Get-CimInstance -ClassName Win32_Service -Filter "Name='$($svc.Name)'" -ErrorAction Stop
            } catch {
                continue
            }

            $startMode = $cimSvc.StartMode
            $status = $svc.Status.ToString()

            $entry = @{
                Name        = $svc.Name
                DisplayName = $svc.DisplayName
                Status      = $status
                StartType   = $startMode
            }

            if ($status -eq "Running" -and $startMode -eq "Auto") {
                $result.Details.RunningAuto += $entry
            } elseif ($status -eq "Running" -and $startMode -eq "Manual") {
                $result.Details.RunningManual += $entry
            } elseif ($status -eq "Running" -and $startMode -eq "Disabled") {
                $result.Details.RunningDisabled += $entry
            } elseif ($status -eq "Stopped" -and $startMode -eq "Auto") {
                $result.Details.StoppedAuto += $entry
            }
        }

        foreach ($candidate in $servicesToConsider) {
            $svc = $services | Where-Object { $_.Name -eq $candidate.Name } | Select-Object -First 1
            if ($svc) {
                $cimSvc = $null
                try {
                    $cimSvc = Get-CimInstance -ClassName Win32_Service -Filter "Name='$($svc.Name)'" -ErrorAction Stop
                } catch {
                    continue
                }

                if ($cimSvc.StartMode -ne $candidate.SuggestedStart) {
                    $isEssential = $script:EssentialServices -contains $svc.Name

                    $result.Details.OptimizationCandidates += @{
                        Name           = $svc.Name
                        DisplayName    = $candidate.DisplayName
                        CurrentStart   = $cimSvc.StartMode
                        SuggestedStart = $candidate.SuggestedStart
                        Status         = $svc.Status.ToString()
                        Description    = $candidate.Description
                        IsEssential    = $isEssential
                        SafeToChange   = -not $isEssential
                    }
                }
            }
        }

        Write-Log -Level "INFO" -Category "System" -Message "Service analysis: $($result.Details.RunningAuto.Count) running auto, $($result.Details.OptimizationCandidates.Count) optimization candidates"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "System" -Message "Service analysis failed: $($_.Exception.Message)"
    }

    return $result
}

function global:Optimize-ServiceStartup {
    <#
    .SYNOPSIS
        Optimize service startup types.
    #>
    param(
        [Parameter()]
        [string[]]$ServiceNames = @(),

        [Parameter()]
        [switch]$WhatIf
    )

    $result = @{
        Success  = $true
        Details  = @{
            Modified = @()
            Skipped  = @()
            Failed   = @()
        }
        Errors   = @()
    }

    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Errors += "Administrator privileges required"
        return $result
    }

    Write-Log -Level "INFO" -Category "System" -Message "Optimizing service startup types..."

    $optimizationMap = @{
        "DiagTrack"         = "Disabled"
        "dmwappushservice"  = "Disabled"
        "MapsBroker"        = "Manual"
        "lfsvc"             = "Manual"
        "SharedAccess"      = "Manual"
        "WMPNetworkSvc"     = "Manual"
        "XblAuthManager"    = "Manual"
        "XblGameSave"       = "Manual"
        "XboxNetApiSvc"     = "Manual"
        "XboxGipSvc"        = "Manual"
        "RetailDemo"        = "Disabled"
        "RemoteRegistry"    = "Disabled"
        "TabletInputService" = "Manual"
        "WpnService"        = "Manual"
        "WSearch"           = "Manual"
        "SysMain"           = "Manual"
    }

    if ($ServiceNames.Count -gt 0) {
        $targetServices = @{}
        foreach ($name in $ServiceNames) {
            if ($optimizationMap.ContainsKey($name)) {
                $targetServices[$name] = $optimizationMap[$name]
            }
        }
        $optimizationMap = $targetServices
    }

    foreach ($svcName in $optimizationMap.Keys) {
        $suggestedStart = $optimizationMap[$svcName]

        try {
            $svc = Get-Service -Name $svcName -ErrorAction Stop
            $cimSvc = Get-CimInstance -ClassName Win32_Service -Filter "Name='$svcName'" -ErrorAction Stop

            if ($cimSvc.StartMode -eq $suggestedStart) {
                $result.Details.Skipped += @{ Name = $svcName; Reason = "Already $suggestedStart" }
                continue
            }

            if ($script:EssentialServices -contains $svcName) {
                $result.Details.Skipped += @{ Name = $svcName; Reason = "Essential service" }
                continue
            }

            if ($WhatIf) {
                Write-Log -Level "INFO" -Category "System" -Message "Preview: Would set $svcName to $suggestedStart"
                $result.Details.Skipped += @{ Name = $svcName; Reason = "Preview mode" }
                continue
            }

            $startupType = switch ($suggestedStart) {
                "Disabled" { "Disabled" }
                "Manual" { "Manual" }
                "Auto" { "Automatic" }
                default { $suggestedStart }
            }

            Set-Service -Name $svcName -StartupType $startupType -ErrorAction Stop

            if ($suggestedStart -eq "Disabled" -and $svc.Status -eq "Running") {
                Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue
            }

            $result.Details.Modified += @{
                Name       = $svcName
                Previous   = $cimSvc.StartMode
                New        = $suggestedStart
            }

            Write-Log -Level "SUCCESS" -Category "System" -Message "Set $svcName : $($cimSvc.StartMode) -> $suggestedStart"
        } catch [Microsoft.PowerShell.Commands.ServiceCommandException] {
            $result.Details.Skipped += @{ Name = $svcName; Reason = "Service not found" }
        } catch {
            $result.Details.Failed += $svcName
            $result.Errors += "Failed to optimize $svcName : $($_.Exception.Message)"
            Write-Log -Level "WARNING" -Category "System" -Message "Failed to optimize $svcName : $($_.Exception.Message)"
        }
    }

    Write-Log -Level "SUCCESS" -Category "System" -Message "Service optimization: $($result.Details.Modified.Count) modified, $($result.Details.Skipped.Count) skipped, $($result.Details.Failed.Count) failed"
    return $result
}

function global:Get-BackgroundProcesses {
    <#
    .SYNOPSIS
        List unnecessary background processes.
    #>
    $result = @{
        Success  = $true
        Details  = @()
        Errors   = @()
    }

    Write-Log -Level "INFO" -Category "System" -Message "Scanning for unnecessary background processes..."

    try {
        $processes = Get-Process -ErrorAction Stop

        foreach ($proc in $processes) {
            foreach ($pattern in $script:UnnecessaryBackgroundProcesses) {
                if ($proc.ProcessName -like "*$pattern*") {
                    $memMB = [math]::Round($proc.WorkingSet64 / 1MB, 2)

                    $result.Details += @{
                        ProcessName     = $proc.ProcessName
                        PID            = $proc.Id
                        MemoryMB       = $memMB
                        Handles        = $proc.HandleCount
                        StartTime      = if ($proc.StartTime) { $proc.StartTime.ToString("yyyy-MM-dd HH:mm:ss") } else { "N/A" }
                        MatchedPattern = $pattern
                        MainWindowTitle = $proc.MainWindowTitle
                    }
                    break
                }
            }
        }

        $result.Details = @($result.Details | Sort-Object MemoryMB -Descending)
        Write-Log -Level "INFO" -Category "System" -Message "Found $($result.Details.Count) unnecessary background processes"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "System" -Message "Failed to scan background processes: $($_.Exception.Message)"
    }

    return $result
}

function global:Invoke-ProcessCleanup {
    <#
    .SYNOPSIS
        Clean up unnecessary processes.
    #>
    param(
        [Parameter()]
        [string[]]$ExcludeProcesses = @(),

        [Parameter()]
        [switch]$WhatIf
    )

    $result = @{
        Success  = $true
        Details  = @{
            Stopped  = @()
            Skipped  = @()
            Failed   = @()
            MemoryFreedMB = 0
        }
        Errors   = @()
    }

    Write-Log -Level "INFO" -Category "System" -Message "Starting process cleanup..."

    try {
        $background = Get-BackgroundProcesses
        if (-not $background.Success) {
            $result.Success = $false
            $result.Errors += $background.Errors
            return $result
        }

        foreach ($proc in $background.Details) {
            if ($ExcludeProcesses -contains $proc.ProcessName) {
                $result.Details.Skipped += $proc.ProcessName
                continue
            }

            $actualProc = $null
            try {
                $actualProc = Get-Process -Id $proc.PID -ErrorAction Stop
            } catch {
                continue
            }

            $memBefore = [math]::Round($actualProc.WorkingSet64 / 1MB, 2)

            if ($WhatIf) {
                Write-Log -Level "INFO" -Category "System" -Message "Preview: Would stop $($proc.ProcessName) (PID: $($proc.PID), $($proc.MemoryMB) MB)"
                $result.Details.Skipped += $proc.ProcessName
                continue
            }

            try {
                Stop-Process -Id $proc.PID -Force -ErrorAction Stop
                $result.Details.Stopped += @{
                    ProcessName = $proc.ProcessName
                    PID         = $proc.PID
                    MemoryFreedMB = $memBefore
                }
                $result.Details.MemoryFreedMB += $memBefore
                Write-Log -Level "SUCCESS" -Category "System" -Message "Stopped $($proc.ProcessName) (freed ${memBefore} MB)"
            } catch {
                $result.Details.Failed += $proc.ProcessName
                $result.Errors += "Failed to stop $($proc.ProcessName) (PID: $($proc.PID)): $($_.Exception.Message)"
                Write-Log -Level "WARNING" -Category "System" -Message "Failed to stop $($proc.ProcessName): $($_.Exception.Message)"
            }
        }

        Write-Log -Level "SUCCESS" -Category "System" -Message "Process cleanup complete: $($result.Details.Stopped.Count) stopped, $($result.Details.Failed.Count) failed, $($result.Details.MemoryFreedMB) MB freed"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "System" -Message "Process cleanup failed: $($_.Exception.Message)"
    }

    return $result
}
