#Requires -Version 5.1
<#
.SYNOPSIS
    WCTkit AI Automation Engine - 17-Operation Autonomous System
.DESCRIPTION
    Comprehensive automation engine with 17 operations for zero-interaction
    Windows optimization, cleaning, debloating, tuning, and hardening.
#>

$script:AutomationState = @{
    IsRunning = $false
    CurrentOperation = ""
    CompletedOperations = @()
    FailedOperations = @()
    TotalSpaceRecovered = 0
    StartTime = $null
}

function global:Invoke-AutoSlimming {
    param([switch]$TestMode)
    $r = @{ Success=$false; Actions=@(); SpaceRecovered=0; Duration=[timespan]::Zero; Errors=@() }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        Write-Log -Level "INFO" -Category "Automation" -Message "AutoSlimming: Starting system streamlining"
        $bloatApps = @("3DBuilder","BingWeather","BingNews","BingSports","Microsoft.People","Microsoft.GetHelp","Microsoft.Getstarted","Microsoft.MicrosoftSolitaireCollection","Microsoft.WindowsFeedbackHub","Microsoft.MixedReality.Portal","Microsoft.ZuneMusic","Microsoft.ZuneVideo")
        foreach ($app in $bloatApps) {
            try {
                Get-AppxPackage -Name "*$app*" -EA SilentlyContinue | Remove-AppxPackage -EA SilentlyContinue
                $r.Actions += "Removed: $app"
            } catch { $r.Errors += "Failed to remove ${app}: $($_.Exception.Message)" }
        }
        # Disable optional features
        $features = @("Print-Foundation-Features","Media.WindowsMediaPlayer","XPS.Viewer")
        foreach ($feat in $features) {
            try {
                if ((Get-WindowsOptionalFeature -Online -FeatureName $feat -EA SilentlyContinue).State -eq "Enabled") {
                    if (-not $TestMode) { Disable-WindowsOptionalFeature -Online -FeatureName $feat -NoRestart -EA SilentlyContinue }
                    $r.Actions += "Disabled feature: $feat"
                }
            } catch { $r.Errors += $_.Exception.Message }
        }
        $r.Success = $true
    } catch { $r.Errors += $_.Exception.Message }
    $sw.Stop(); $r.Duration = $sw.Elapsed
    Write-Log -Level "SUCCESS" -Category "Automation" -Message "AutoSlimming completed: $($r.Actions.Count) actions"
    return $r
}

function global:Invoke-AutoCleaning {
    param([switch]$TestMode)
    $r = @{ Success=$false; Actions=@(); SpaceRecovered=0; Duration=[timespan]::Zero; Errors=@() }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        Write-Log -Level "INFO" -Category "Automation" -Message "AutoCleaning: Starting comprehensive cleanup"
        $paths = @("$env:TEMP","$env:SystemRoot\Temp","$env:SystemRoot\Prefetch","$env:LOCALAPPDATA\Temp","$env:SystemRoot\SoftwareDistribution\Download","$env:SystemRoot\Logs","$env:LOCALAPPDATA\Microsoft\Windows\INetCache","$env:LOCALAPPDATA\Microsoft\Windows\Explorer")
        foreach ($p in $paths) {
            if (Test-Path $p) {
                try {
                    $sz = (Get-ChildItem $p -Recurse -Force -EA SilentlyContinue | Measure-Object Length -Sum -EA SilentlyContinue).Sum
                    if (-not $TestMode) { Get-ChildItem $p -Recurse -Force -EA SilentlyContinue | Remove-Item -Recurse -Force -EA SilentlyContinue }
                    $r.SpaceRecovered += $(if($sz){$sz}else{0})
                    $r.Actions += "Cleaned: $p"
                } catch { $r.Errors += $_.Exception.Message }
            }
        }
        # Clear Recycle Bin
        try {
            if (-not $TestMode) { Clear-RecycleBin -Force -EA SilentlyContinue }
            $r.Actions += "Cleared Recycle Bin"
        } catch { $r.Errors += $_.Exception.Message }
        $r.Success = $true
    } catch { $r.Errors += $_.Exception.Message }
    $sw.Stop(); $r.Duration = $sw.Elapsed
    Write-Log -Level "SUCCESS" -Category "Automation" -Message "AutoCleaning completed: $($r.Actions.Count) actions, $([math]::Round($r.SpaceRecovered/1MB,2)) MB recovered"
    return $r
}

function global:Invoke-AutoCorrection {
    param([switch]$TestMode)
    $r = @{ Success=$false; Actions=@(); SpaceRecovered=0; Duration=[timespan]::Zero; Errors=@() }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        Write-Log -Level "INFO" -Category "Automation" -Message "AutoCorrection: Starting self-healing"
        if (Get-Command Test-SystemIntegrity -EA SilentlyContinue) {
            $issues = Test-SystemIntegrity
            if ($issues.IssuesFound -gt 0) {
                $heal = Invoke-SelfHeal
                $r.Actions += $heal.Actions
                $r.Errors += $heal.Errors
            }
        }
        # Fix common issues
        try { Start-Service wuauserv -EA SilentlyContinue; $r.Actions += "Started Windows Update service" } catch { Write-Log -Level "WARNING" -Category "Automation" -Message $_.Exception.Message }
        try { Start-Service bits -EA SilentlyContinue; $r.Actions += "Started BITS service" } catch { Write-Log -Level "WARNING" -Category "Automation" -Message $_.Exception.Message }
        try { Start-Service CryptSvc -EA SilentlyContinue; $r.Actions += "Started Cryptographic service" } catch { Write-Log -Level "WARNING" -Category "Automation" -Message $_.Exception.Message }
        $r.Success = $true
    } catch { $r.Errors += $_.Exception.Message }
    $sw.Stop(); $r.Duration = $sw.Elapsed
    return $r
}

function global:Invoke-FullAutomate {
    param([switch]$TestMode)
    $r = @{ Success=$false; Actions=@(); SpaceRecovered=0; Duration=[timespan]::Zero; Errors=@() }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $script:AutomationState.IsRunning = $true
    $script:AutomationState.StartTime = Get-Date
    try {
        Write-Log -Level "INFO" -Category "Automation" -Message "FullAutomate: Starting complete automation sequence"
        $ops = @("Invoke-AutoElevated","Invoke-AutoScan","Invoke-AutoCorrection","Invoke-AutoCleaning","Invoke-AutoDebloat","Invoke-AutoSlimming","Invoke-AutoOptimise","Invoke-FullOptimise","Invoke-AutoSecure","Invoke-AutoTask")
        $total = $ops.Count
        $i = 0
        foreach ($op in $ops) {
            $i++
            $script:AutomationState.CurrentOperation = $op
            Write-Progress -Activity "Full Automation" -Status "Running $op ($i/$total)" -PercentComplete (($i/$total)*100)
            try {
                $opResult = & $op -TestMode:$TestMode
                $r.Actions += $opResult.Actions
                $r.SpaceRecovered += $opResult.SpaceRecovered
                $r.Errors += $opResult.Errors
                $script:AutomationState.CompletedOperations += $op
            } catch {
                $r.Errors += "$op failed: $($_.Exception.Message)"
                $script:AutomationState.FailedOperations += $op
                Write-Log -Level "WARNING" -Category "Automation" -Message "$op failed: $($_.Exception.Message)"
            }
        }
        $r.Success = ($r.Errors.Count -eq 0)
        $script:AutomationState.TotalSpaceRecovered = $r.SpaceRecovered
    } catch { $r.Errors += $_.Exception.Message }
    $script:AutomationState.IsRunning = $false
    $sw.Stop(); $r.Duration = $sw.Elapsed
    Write-Log -Level "SUCCESS" -Category "Automation" -Message "FullAutomate completed: $($r.Actions.Count) actions, $([math]::Round($r.SpaceRecovered/1MB,2)) MB recovered in $($r.Duration.ToString('mm\:ss'))"
    return $r
}

function global:Invoke-FullFeatured {
    param([switch]$TestMode)
    $r = @{ Success=$false; Actions=@(); SpaceRecovered=0; Duration=[timespan]::Zero; Errors=@() }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        Write-Log -Level "INFO" -Category "Automation" -Message "FullFeatured: Enabling useful Windows features"
        $features = @("NetFx3","Microsoft-Hyper-V-All","Containers","VirtualMachinePlatform","Microsoft-Windows-Subsystem-Linux")
        foreach ($feat in $features) {
            try {
                $f = Get-WindowsOptionalFeature -Online -FeatureName $feat -EA SilentlyContinue
                if ($f -and $f.State -ne "Enabled") {
                    if (-not $TestMode) { Enable-WindowsOptionalFeature -Online -FeatureName $feat -NoRestart -EA SilentlyContinue }
                    $r.Actions += "Enabled: $feat"
                }
            } catch { $r.Errors += $_.Exception.Message }
        }
        $r.Success = $true
    } catch { $r.Errors += $_.Exception.Message }
    $sw.Stop(); $r.Duration = $sw.Elapsed
    return $r
}

function global:Invoke-FullOptimise {
    param([switch]$TestMode)
    $r = @{ Success=$false; Actions=@(); SpaceRecovered=0; Duration=[timespan]::Zero; Errors=@() }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        Write-Log -Level "INFO" -Category "Automation" -Message "FullOptimise: Applying maximum performance optimizations"
        # High Performance power plan
        try {
            if (-not $TestMode) { powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null }
            $r.Actions += "Set High Performance power plan"
        } catch { $r.Errors += $_.Exception.Message }
        # Disable visual effects
        try {
            $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
            if (-not $TestMode) { Set-ItemProperty -Path $path -Name "VisualFXSetting" -Value 2 -EA SilentlyContinue }
            $r.Actions += "Optimized visual effects"
        } catch { Write-Log -Level "WARNING" -Category "Automation" -Message $_.Exception.Message }
        # Memory optimization
        try {
            [System.GC]::Collect()
            $r.Actions += "Performed garbage collection"
        } catch { Write-Log -Level "WARNING" -Category "Automation" -Message $_.Exception.Message }
        # Disable indexing on non-system drives
        try {
            Get-PSDrive -PSProvider FileSystem -EA SilentlyContinue | Where-Object { $_.Root -ne "$env:SystemDrive\" } | ForEach-Object {
                if (-not $TestMode) { Set-Service -Name "WSearch" -StartupType Manual -EA SilentlyContinue }
            }
            $r.Actions += "Optimized search indexing"
        } catch { Write-Log -Level "WARNING" -Category "Automation" -Message $_.Exception.Message }
        $r.Success = $true
    } catch { $r.Errors += $_.Exception.Message }
    $sw.Stop(); $r.Duration = $sw.Elapsed
    return $r
}

function global:Invoke-AutoScan {
    param([switch]$TestMode)
    $r = @{ Success=$false; Actions=@(); SpaceRecovered=0; Duration=[timespan]::Zero; Errors=@() }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        Write-Log -Level "INFO" -Category "Automation" -Message "AutoScan: Performing system health assessment"
        # Disk space
        Get-PSDrive -PSProvider FileSystem -EA SilentlyContinue | ForEach-Object {
            $freeGB = [math]::Round($_.Free/1GB,2)
            $r.Actions += "Drive $($_.Name): $freeGB GB free"
        }
        # Services
        $running = (Get-Service -EA SilentlyContinue | Where-Object {$_.Status -eq "Running"}).Count
        $r.Actions += "Running services: $running"
        # Memory
        $os = Get-WmiObject -Class Win32_OperatingSystem -EA SilentlyContinue
        if ($os) {
            $freeRAM = [math]::Round($os.FreePhysicalMemory/1MB,2)
            $totalRAM = [math]::Round($os.TotalVisibleMemorySize/1MB,2)
            $r.Actions += "Memory: $freeRAM GB free of $totalRAM GB total"
        }
        # Network
        try {
            $ping = Test-Connection -ComputerName 8.8.8.8 -Count 1 -EA SilentlyContinue
            if ($ping) { $r.Actions += "Network: Online (ping OK)" } else { $r.Actions += "Network: Connectivity issues" }
        } catch { $r.Actions += "Network: Check failed" }
        $r.Success = $true
    } catch { $r.Errors += $_.Exception.Message }
    $sw.Stop(); $r.Duration = $sw.Elapsed
    return $r
}

function global:Invoke-AutoDebloat {
    param([switch]$TestMode)
    $r = @{ Success=$false; Actions=@(); SpaceRecovered=0; Duration=[timespan]::Zero; Errors=@() }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        Write-Log -Level "INFO" -Category "Automation" -Message "AutoDebloat: Removing bloatware and telemetry"
        $bloatPackages = @("*CandyCrush*","*Facebook*","*Spotify*","*Twitter*","*TikTok*","*Disney*","*Netflix*","*Clipchamp*","*PowerAutomate*","*Teams*")
        foreach ($pattern in $bloatPackages) {
            try {
                Get-AppxPackage -AllUsers -Name $pattern -EA SilentlyContinue | ForEach-Object {
                    if (-not $TestMode) { $_ | Remove-AppxPackage -AllUsers -EA SilentlyContinue }
                    $r.Actions += "Removed: $($_.Name)"
                }
            } catch { $r.Errors += $_.Exception.Message }
        }
        # Disable telemetry
        try {
            $telemetryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
            if (-not (Test-Path $telemetryPath)) { New-Item -Path $telemetryPath -Force -EA SilentlyContinue | Out-Null }
            if (-not $TestMode) { Set-ItemProperty -Path $telemetryPath -Name "AllowTelemetry" -Value 0 -EA SilentlyContinue }
            $r.Actions += "Disabled telemetry"
        } catch { Write-Log -Level "WARNING" -Category "Automation" -Message $_.Exception.Message }
        # Disable Cortana
        try {
            $cortanaPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
            if (-not (Test-Path $cortanaPath)) { New-Item -Path $cortanaPath -Force -EA SilentlyContinue | Out-Null }
            if (-not $TestMode) { Set-ItemProperty -Path $cortanaPath -Name "AllowCortana" -Value 0 -EA SilentlyContinue }
            $r.Actions += "Disabled Cortana"
        } catch { Write-Log -Level "WARNING" -Category "Automation" -Message $_.Exception.Message }
        $r.Success = $true
    } catch { $r.Errors += $_.Exception.Message }
    $sw.Stop(); $r.Duration = $sw.Elapsed
    return $r
}

function global:Invoke-AutoOptimise {
    param([switch]$TestMode)
    $r = @{ Success=$false; Actions=@(); SpaceRecovered=0; Duration=[timespan]::Zero; Errors=@() }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        Write-Log -Level "INFO" -Category "Automation" -Message "AutoOptimise: Real-time performance enhancement"
        # Optimize services
        $manualServices = @("DiagTrack","dmwappushservice","MapsBroker","lfsvc","WMPNetworkSvc","wisvc","RetailDemo")
        foreach ($svc in $manualServices) {
            try {
                $s = Get-Service -Name $svc -EA SilentlyContinue
                if ($s -and $s.StartType -ne "Disabled") {
                    if (-not $TestMode) { Set-Service -Name $svc -StartupType Disabled -EA SilentlyContinue }
                    $r.Actions += "Disabled service: $svc"
                }
            } catch { Write-Log -Level "WARNING" -Category "Automation" -Message $_.Exception.Message }
        }
        # Network optimization
        try {
            if (-not $TestMode) {
                netsh int tcp set global autotuninglevel=normal 2>$null
                netsh int tcp set global rss=enabled 2>$null
                netsh int tcp set global chimney=enabled 2>$null
            }
            $r.Actions += "Optimized TCP settings"
        } catch { Write-Log -Level "WARNING" -Category "Automation" -Message $_.Exception.Message }
        $r.Success = $true
    } catch { $r.Errors += $_.Exception.Message }
    $sw.Stop(); $r.Duration = $sw.Elapsed
    return $r
}

function global:Invoke-AutoAnalyse {
    param([switch]$TestMode)
    $r = @{ Success=$false; Actions=@(); SpaceRecovered=0; Duration=[timespan]::Zero; Errors=@() }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        Write-Log -Level "INFO" -Category "Automation" -Message "AutoAnalyse: Deep system analysis"
        if (Get-Command Get-SystemHealthScore -EA SilentlyContinue) {
            $score = Get-SystemHealthScore
            $r.Actions += "Health Score: $($score.TotalScore)/100 ($($score.Grade))"
            foreach ($cat in $score.Categories.Keys) {
                $c = $score.Categories[$cat]
                $r.Actions += "  $cat`: $($c.Score)/$($c.MaxScore) - $($c.Details)"
            }
        }
        $r.Success = $true
    } catch { $r.Errors += $_.Exception.Message }
    $sw.Stop(); $r.Duration = $sw.Elapsed
    return $r
}

function global:Invoke-AutoRun {
    param([switch]$TestMode)
    $r = @{ Success=$false; Actions=@(); SpaceRecovered=0; Duration=[timespan]::Zero; Errors=@() }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        Write-Log -Level "INFO" -Category "Automation" -Message "AutoRun: Detecting and fixing issues automatically"
        # Detect and fix
        $scan = Invoke-AutoScan -TestMode:$TestMode
        $correct = Invoke-AutoCorrection -TestMode:$TestMode
        $r.Actions = $scan.Actions + $correct.Actions
        $r.Errors = $scan.Errors + $correct.Errors
        $r.SpaceRecovered = $correct.SpaceRecovered
        $r.Success = $true
    } catch { $r.Errors += $_.Exception.Message }
    $sw.Stop(); $r.Duration = $sw.Elapsed
    return $r
}

function global:Invoke-AutoRepeat {
    param([switch]$TestMode,[int]$IntervalHours=24)
    $r = @{ Success=$false; Actions=@(); SpaceRecovered=0; Duration=[timespan]::Zero; Errors=@() }
    try {
        Write-Log -Level "INFO" -Category "Automation" -Message "AutoRepeat: Setting up recurring optimization every $IntervalHours hours"
        $taskName = "WinTunePro_AutoRepeat"
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$PSScriptRoot\..\WinTune.ps1`" -Silent -FullOptimization"
        $trigger = New-ScheduledTaskTrigger -Daily -At "3:00AM" -RepetitionInterval (New-TimeSpan -Hours $IntervalHours)
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
        if (-not $TestMode) {
            Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force -EA SilentlyContinue | Out-Null
        }
        $r.Actions += "Created scheduled task: $taskName (every $IntervalHours hours)"
        $r.Success = $true
    } catch { $r.Errors += $_.Exception.Message }
    return $r
}

function global:Invoke-AutoSchedule {
    param([switch]$TestMode)
    $r = @{ Success=$false; Actions=@(); SpaceRecovered=0; Duration=[timespan]::Zero; Errors=@() }
    try {
        Write-Log -Level "INFO" -Category "Automation" -Message "AutoSchedule: Creating maintenance schedule"
        # Weekly cleanup task
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$PSScriptRoot\..\WinTune.ps1`" -Silent -QuickCleanup"
        $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At "2:00AM"
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -StartWhenAvailable
        if (-not $TestMode) {
            Register-ScheduledTask -TaskName "WinTunePro_WeeklyClean" -Action $action -Trigger $trigger -Settings $settings -Force -EA SilentlyContinue | Out-Null
        }
        $r.Actions += "Created weekly cleanup task (Sunday 2AM)"
        # Monthly optimization task
        $action2 = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$PSScriptRoot\..\WinTune.ps1`" -Silent -FullOptimization"
        $trigger2 = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At "3:00AM"
        if (-not $TestMode) {
            Register-ScheduledTask -TaskName "WinTunePro_MonthlyOptimize" -Action $action2 -Trigger $trigger2 -Settings $settings -Force -EA SilentlyContinue | Out-Null
        }
        $r.Actions += "Created monthly optimization task"
        $r.Success = $true
    } catch { $r.Errors += $_.Exception.Message }
    return $r
}

function global:Invoke-AutoTask {
    param([switch]$TestMode)
    $r = @{ Success=$false; Actions=@(); SpaceRecovered=0; Duration=[timespan]::Zero; Errors=@() }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        Write-Log -Level "INFO" -Category "Automation" -Message "AutoTask: Background task management"
        # Kill unnecessary background processes
        $killProcesses = @("OneDrive","Cortana","Skype","YourPhone","GameBar","Teams")
        foreach ($proc in $killProcesses) {
            try {
                Get-Process -Name $proc -EA SilentlyContinue | ForEach-Object {
                    if (-not $TestMode) { Stop-Process -Id $_.Id -Force -EA SilentlyContinue }
                    $r.Actions += "Stopped process: $proc"
                }
            } catch { Write-Log -Level "WARNING" -Category "Automation" -Message $_.Exception.Message }
        }
        $r.Success = $true
    } catch { $r.Errors += $_.Exception.Message }
    $sw.Stop(); $r.Duration = $sw.Elapsed
    return $r
}

function global:Invoke-AutoControl {
    param([switch]$TestMode)
    $r = @{ Success=$false; Actions=@(); SpaceRecovered=0; Duration=[timespan]::Zero; Errors=@() }
    try {
        Write-Log -Level "INFO" -Category "Automation" -Message "AutoControl: Managing system resources"
        # Set process priority
        try {
            $proc = Get-Process -Id $PID -EA SilentlyContinue
            if ($proc) { $proc.PriorityClass = "AboveNormal" }
            $r.Actions += "Set optimization process priority to AboveNormal"
        } catch { Write-Log -Level "WARNING" -Category "Automation" -Message $_.Exception.Message }
        $r.Success = $true
    } catch { $r.Errors += $_.Exception.Message }
    return $r
}

function global:Invoke-AutoElevated {
    param([switch]$TestMode)
    $r = @{ Success=$false; Actions=@(); SpaceRecovered=0; Duration=[timespan]::Zero; Errors=@() }
    try {
        Write-Log -Level "INFO" -Category "Automation" -Message "AutoElevated: Checking privilege level"
        if (Get-Command Test-IsAdmin -EA SilentlyContinue) {
            if (Test-IsAdmin) {
                $r.Actions += "Running with Administrator privileges"
            } else {
                $r.Actions += "Not elevated - some operations may be limited"
                $r.Errors += "Administrator privileges required for full optimization"
            }
        }
        $r.Success = $true
    } catch { $r.Errors += $_.Exception.Message }
    return $r
}

function global:Invoke-AutoSecure {
    param([switch]$TestMode)
    $r = @{ Success=$false; Actions=@(); SpaceRecovered=0; Duration=[timespan]::Zero; Errors=@() }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        Write-Log -Level "INFO" -Category "Automation" -Message "AutoSecure: Applying security hardening"
        # Enable firewall
        try {
            if (-not $TestMode) {
                Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True -EA SilentlyContinue
            }
            $r.Actions += "Enabled Windows Firewall for all profiles"
        } catch { Write-Log -Level "WARNING" -Category "Automation" -Message $_.Exception.Message }
        # Enable Defender real-time protection
        try {
            if (-not $TestMode) {
                Set-MpPreference -DisableRealtimeMonitoring $false -EA SilentlyContinue
            }
            $r.Actions += "Enabled Windows Defender real-time protection"
        } catch { Write-Log -Level "WARNING" -Category "Automation" -Message $_.Exception.Message }
        # Disable SMBv1
        try {
            if (-not $TestMode) {
                Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force -EA SilentlyContinue
            }
            $r.Actions += "Disabled SMBv1 protocol"
        } catch { Write-Log -Level "WARNING" -Category "Automation" -Message $_.Exception.Message }
        # Enable DEP
        try {
            if (-not $TestMode) { bcdedit /set nx OptOut 2>$null }
            $r.Actions += "Enabled DEP (Data Execution Prevention)"
        } catch { Write-Log -Level "WARNING" -Category "Automation" -Message $_.Exception.Message }
        # Disable remote desktop
        try {
            $rdpPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server"
            if (-not $TestMode) { Set-ItemProperty -Path $rdpPath -Name "fDenyTSConnections" -Value 1 -EA SilentlyContinue }
            $r.Actions += "Disabled Remote Desktop"
        } catch { Write-Log -Level "WARNING" -Category "Automation" -Message $_.Exception.Message }
        $r.Success = $true
    } catch { $r.Errors += $_.Exception.Message }
    $sw.Stop(); $r.Duration = $sw.Elapsed
    return $r
}

function global:Invoke-WCTkitAutomation {
    param([switch]$TestMode)
    return Invoke-FullAutomate -TestMode:$TestMode
}

function global:Get-AutomationStatus {
    return $script:AutomationState
}

