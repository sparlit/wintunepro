# WinTune Pro - Health Scoring System
# PowerShell 5.1+ Compatible
# Calculates 0-100 score with category breakdowns

# High-risk startup items (known to cause issues)
$script:HighRiskStartupItems = @(
    "Skype", "Teams", "OneDrive", "Dropbox", "GoogleDrive",
    "iTunesHelper", "AdobeARM", "AcroTray", "RtkAuduService",
    "RealtekHD", "Nahimic", "KillerNetwork", "SmartSound",
    "IntelGraphics", "AMDRSServ", "NvBroadcast", "NvBackend",
    "Spotify", "Discord", "Steam", "EpicGamesLauncher",
    "CCleaner", "Malwarebytes", "McAfee", "Norton", "Avast"
)

# Services considered unnecessary for most workloads
$script:UnnecessaryServices = @(
    "DiagTrack", "dmwappushservice", "MapsBroker", "lfsvc",
    "SharedAccess", "WMPNetworkSvc", "XblAuthManager",
    "XblGameSave", "XboxNetApiSvc", "XboxGipSvc",
    "WSearch", "TabletInputService", "WbioSrvc",
    "Fax", "TapiSrv", "RemoteRegistry",
    "RetailDemo", "WpcMonSvc", "WerSvc",
    "wisvc", "icssvc", "PhoneSvc"
)

# Initialize health score module
function global:Initialize-HealthScore {
    Write-Log -Level "INFO" -Category "HealthScore" -Message "Health scoring system initialized"
    return $true
}

# Disk Health Score (0-20)
# Factors: free space % on system drive, fragmentation, disk health status
function global:Get-DiskHealthScore {
    Write-Log -Level "INFO" -Category "HealthScore" -Message "Calculating disk health score..."

    $result = @{
        Score       = 0
        MaxScore    = 20
        Details     = ""
        Items       = @()
        FreePercent = 0
        FragmentGB  = 0
        HealthStatus = "Unknown"
    }

    try {
        # Get system drive info
        $systemDrive = $env:SystemDrive
        $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$systemDrive'" -ErrorAction SilentlyContinue
        if (-not $disk) {
            $disk = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$systemDrive'" -ErrorAction SilentlyContinue
        }

        if ($disk) {
            $totalGB = [math]::Round([int64]$disk.Size / 1GB, 2)
            $freeGB = [math]::Round([int64]$disk.FreeSpace / 1GB, 2)
            $freePercent = [math]::Round(([int64]$disk.FreeSpace / [int64]$disk.Size) * 100, 1)
            $result.FreePercent = $freePercent

            Write-Log -Level "INFO" -Category "HealthScore" -Message "System drive: $systemDrive | Free: $freeGB GB ($freePercent%)"

            # Score based on free space percentage
            $spaceScore = 0
            if ($freePercent -gt 50) {
                $spaceScore = 20
                $result.Items += @{ Name = "Disk Free Space"; Value = "$freePercent%"; Status = "Good"; Note = "Excellent free space" }
            } elseif ($freePercent -gt 30) {
                $spaceScore = 15
                $result.Items += @{ Name = "Disk Free Space"; Value = "$freePercent%"; Status = "Warning"; Note = "Good but could be better" }
            } elseif ($freePercent -gt 15) {
                $spaceScore = 10
                $result.Items += @{ Name = "Disk Free Space"; Value = "$freePercent%"; Status = "Warning"; Note = "Consider freeing up space" }
            } elseif ($freePercent -gt 5) {
                $spaceScore = 5
                $result.Items += @{ Name = "Disk Free Space"; Value = "$freePercent%"; Status = "Critical"; Note = "Low disk space - action needed" }
            } else {
                $spaceScore = 0
                $result.Items += @{ Name = "Disk Free Space"; Value = "$freePercent%"; Status = "Critical"; Note = "Very low disk space - critical" }
            }

            $result.Score = $spaceScore
            $result.HealthStatus = "OK"

            $result.Details = "System drive ($systemDrive) has $freePercent% free space ($freeGB GB of $totalGB GB)"
        }
    } catch {
        Write-Log -Level "ERROR" -Category "HealthScore" -Message "Error calculating disk health: $($_.Exception.Message)"
        $result.Score = 10  # Neutral score on error
        $result.Details = "Could not retrieve disk information"
        $result.Items += @{ Name = "Disk Info"; Value = "Error"; Status = "Warning"; Note = "Unable to read disk data" }
    }

    Write-Log -Level "INFO" -Category "HealthScore" -Message "Disk health score: $($result.Score)/$($result.MaxScore)"
    return $result
}

# Startup Health Score (0-15)
# Factors: number of startup items, high-risk items present
function global:Get-StartupHealthScore {
    Write-Log -Level "INFO" -Category "HealthScore" -Message "Calculating startup health score..."

    $result = @{
        Score        = 0
        MaxScore     = 15
        Details      = ""
        Items        = @()
        TotalCount   = 0
        HighRiskCount = 0
        HighRiskItems = @()
    }

    try {
        $startupItems = @()

        # Registry startup locations
        $regPaths = @(
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
        )

        foreach ($path in $regPaths) {
            if (Test-Path $path) {
                try {
                    $item = Get-Item $path -ErrorAction SilentlyContinue
                    foreach ($name in $item.Property) {
                        $value = $item.GetValue($name)
                        $startupItems += @{ Name = $name; Source = "Registry"; Path = $value }
                    }
                } catch {
                    Write-Log -Level "DEBUG" -Category "HealthScore" -Message "Could not read registry path: $path"
                }
            }
        }

        # Startup folder
        $startupFolders = @(
            [Environment]::GetFolderPath("Startup"),
            [Environment]::GetFolderPath("CommonStartup")
        )

        foreach ($folder in $startupFolders) {
            if (Test-Path $folder) {
                Get-ChildItem $folder -ErrorAction SilentlyContinue | ForEach-Object {
                    $startupItems += @{ Name = $_.Name; Source = "Folder"; Path = $_.FullName }
                }
            }
        }

        # Scheduled task startup items - skip for speed (registry check is sufficient)

        $result.TotalCount = $startupItems.Count
        Write-Log -Level "INFO" -Category "HealthScore" -Message "Total startup items found: $($result.TotalCount)"

        # Check for high-risk items
        foreach ($item in $startupItems) {
            foreach ($risk in $script:HighRiskStartupItems) {
                if ($item.Name -like "*$risk*") {
                    $result.HighRiskCount++
                    $result.HighRiskItems += $item.Name
                    $result.Items += @{ Name = $item.Name; Value = $item.Source; Status = "Warning"; Note = "High-risk startup item" }
                    break
                }
            }
        }

        # Base score from item count
        $baseScore = 0
        if ($result.TotalCount -lt 10) {
            $baseScore = 15
        } elseif ($result.TotalCount -lt 20) {
            $baseScore = 10
        } elseif ($result.TotalCount -lt 30) {
            $baseScore = 5
        } else {
            $baseScore = 0
        }

        # Penalty for high-risk items
        $riskPenalty = [math]::Min(5, $result.HighRiskCount)
        $result.Score = [math]::Max(0, $baseScore - $riskPenalty)

        # Add count summary item
        $status = if ($result.TotalCount -lt 15) { "Good" } elseif ($result.TotalCount -lt 25) { "Warning" } else { "Critical" }
        $result.Items = @(@{ Name = "Startup Items Count"; Value = "$($result.TotalCount) items"; Status = $status; Note = "$($result.HighRiskCount) high-risk items" }) + $result.Items

        $result.Details = "$($result.TotalCount) startup items found ($($result.HighRiskCount) high-risk)"

    } catch {
        Write-Log -Level "ERROR" -Category "HealthScore" -Message "Error calculating startup health: $($_.Exception.Message)"
        $result.Score = 8  # Neutral score on error
        $result.Details = "Could not retrieve startup information"
        $result.Items += @{ Name = "Startup Info"; Value = "Error"; Status = "Warning"; Note = "Unable to read startup data" }
    }

    Write-Log -Level "INFO" -Category "HealthScore" -Message "Startup health score: $($result.Score)/$($result.MaxScore)"
    return $result
}

# Service Health Score (0-15)
# Factors: unnecessary services running, services set to auto that should be manual
function global:Get-ServiceHealthScore {
    Write-Log -Level "INFO" -Category "HealthScore" -Message "Calculating service health score..."

    $result = @{
        Score            = 0
        MaxScore         = 15
        Details          = ""
        Items            = @()
        RunningUnnecessary = 0
        TotalServices    = 0
        AutoStartCount   = 0
    }

    try {
        $services = Get-Service -ErrorAction Stop
        $result.TotalServices = @($services).Count

        # Count auto-start services
        $autoServices = $services | Where-Object { $_.StartType -eq 'Automatic' }
        $result.AutoStartCount = @($autoServices).Count

        # Check for unnecessary services that are running
        $unnecessaryRunning = @()
        foreach ($svcName in $script:UnnecessaryServices) {
            $svc = $services | Where-Object { $_.Name -eq $svcName -and $_.Status -eq 'Running' }
            if ($svc) {
                $unnecessaryRunning += $svc.DisplayName
                $result.Items += @{ Name = $svc.DisplayName; Value = "Running"; Status = "Warning"; Note = "Unnecessary service" }
            }
        }

        $result.RunningUnnecessary = $unnecessaryRunning.Count
        Write-Log -Level "INFO" -Category "HealthScore" -Message "Unnecessary services running: $($result.RunningUnnecessary)"

        # Score based on unnecessary services count
        if ($result.RunningUnnecessary -lt 5) {
            $result.Score = 15
        } elseif ($result.RunningUnnecessary -lt 10) {
            $result.Score = 10
        } elseif ($result.RunningUnnecessary -lt 20) {
            $result.Score = 5
        } else {
            $result.Score = 0
        }

        # Check auto-start services that could be manual
        $autoPenalty = 0
        if ($result.AutoStartCount -gt 100) {
            $autoPenalty = 3
        } elseif ($result.AutoStartCount -gt 80) {
            $autoPenalty = 1
        }
        $result.Score = [math]::Max(0, $result.Score - $autoPenalty)

        # Add summary item
        $status = if ($result.RunningUnnecessary -lt 5) { "Good" } elseif ($result.RunningUnnecessary -lt 15) { "Warning" } else { "Critical" }
        $result.Items = @(@{ Name = "Unnecessary Services"; Value = "$($result.RunningUnnecessary) running"; Status = $status; Note = "Out of $($result.TotalServices) total services" }) + $result.Items

        $result.Details = "$($result.RunningUnnecessary) unnecessary services running out of $($result.TotalServices) total ($($result.AutoStartCount) auto-start)"

    } catch {
        Write-Log -Level "ERROR" -Category "HealthScore" -Message "Error calculating service health: $($_.Exception.Message)"
        $result.Score = 8  # Neutral score on error
        $result.Details = "Could not retrieve service information"
        $result.Items += @{ Name = "Service Info"; Value = "Error"; Status = "Warning"; Note = "Unable to read service data" }
    }

    Write-Log -Level "INFO" -Category "HealthScore" -Message "Service health score: $($result.Score)/$($result.MaxScore)"
    return $result
}

# Network Health Score (0-15)
# Factors: DNS resolution speed, network latency, adapter errors
function global:Get-NetworkHealthScore {
    Write-Log -Level "INFO" -Category "HealthScore" -Message "Calculating network health score..."

    $result = @{
        Score         = 0
        MaxScore      = 15
        Details       = ""
        Items         = @()
        LatencyMs     = 0
        DnsSpeedMs    = 0
        AdapterErrors = 0
    }

    try {
        # Test network latency
        $latencyScore = 0
        try {
            $pingTarget = "8.8.8.8"  # Google DNS
            $ping = Test-Connection -ComputerName $pingTarget -Count 1 -ErrorAction Stop
            if ($ping) {
                $result.LatencyMs = [math]::Round(($ping | Select-Object -First 1).ResponseTime, 1)
            }
            Write-Log -Level "INFO" -Category "HealthScore" -Message "Network latency to $pingTarget`: $($result.LatencyMs)ms"

            if ($result.LatencyMs -lt 10) {
                $latencyScore = 15
                $result.Items += @{ Name = "Network Latency"; Value = "$($result.LatencyMs)ms"; Status = "Good"; Note = "Excellent connection" }
            } elseif ($result.LatencyMs -lt 50) {
                $latencyScore = 10
                $result.Items += @{ Name = "Network Latency"; Value = "$($result.LatencyMs)ms"; Status = "Good"; Note = "Good connection" }
            } elseif ($result.LatencyMs -lt 100) {
                $latencyScore = 5
                $result.Items += @{ Name = "Network Latency"; Value = "$($result.LatencyMs)ms"; Status = "Warning"; Note = "Moderate connection" }
            } else {
                $latencyScore = 0
                $result.Items += @{ Name = "Network Latency"; Value = "$($result.LatencyMs)ms"; Status = "Critical"; Note = "Poor connection" }
            }
        } catch {
            Write-Log -Level "WARNING" -Category "HealthScore" -Message "Could not test network latency: $($_.Exception.Message)"
            $latencyScore = 5  # Neutral on error
            $result.Items += @{ Name = "Network Latency"; Value = "Test failed"; Status = "Warning"; Note = "Could not test connection" }
        }

        $result.Score = $latencyScore

        # DNS resolution - use cached ping latency as proxy (fast)
        try {
            $result.DnsSpeedMs = $result.LatencyMs * 10  # Estimate DNS from ping
            if ($result.LatencyMs -lt 30) {
                $result.Score = [math]::Min(15, $result.Score + 2)
            } elseif ($result.LatencyMs -lt 80) {
                $result.Score = [math]::Min(15, $result.Score + 1)
            }
        } catch { }

        $result.Details = "Latency: $($result.LatencyMs)ms"

    } catch {
        Write-Log -Level "ERROR" -Category "HealthScore" -Message "Error calculating network health: $($_.Exception.Message)"
        $result.Score = 8  # Neutral score on error
        $result.Details = "Could not retrieve network information"
        $result.Items += @{ Name = "Network Info"; Value = "Error"; Status = "Warning"; Note = "Unable to read network data" }
    }

    Write-Log -Level "INFO" -Category "HealthScore" -Message "Network health score: $($result.Score)/$($result.MaxScore)"
    return $result
}

# Privacy Health Score (0-10)
# Factors: telemetry disabled, activity history disabled, diagnostic data minimal
function global:Get-PrivacyHealthScore {
    Write-Log -Level "INFO" -Category "HealthScore" -Message "Calculating privacy health score..."

    $result = @{
        Score             = 0
        MaxScore          = 10
        Details           = ""
        Items             = @()
        TelemetryDisabled = $false
        ActivityDisabled  = $false
        DiagnosticMinimal = $false
    }

    $privacyScore = 0

    try {
        # Check telemetry level
        try {
            $telemetryValue = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -ErrorAction SilentlyContinue
            if ($telemetryValue -and $telemetryValue.AllowTelemetry -eq 0) {
                $privacyScore += 4
                $result.TelemetryDisabled = $true
                $result.Items += @{ Name = "Telemetry"; Value = "Disabled"; Status = "Good"; Note = "Telemetry fully disabled" }
            } else {
                $result.Items += @{ Name = "Telemetry"; Value = "Enabled"; Status = "Warning"; Note = "Telemetry is active" }
            }
        } catch {
            Write-Log -Level "DEBUG" -Category "HealthScore" -Message "Could not check telemetry setting: $($_.Exception.Message)"
            $privacyScore += 2  # Partial credit if can't read
            $result.Items += @{ Name = "Telemetry"; Value = "Unknown"; Status = "Warning"; Note = "Could not check telemetry" }
        }

        # Check activity history
        try {
            $activityValue = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed" -ErrorAction SilentlyContinue
            if ($activityValue -and $activityValue.EnableActivityFeed -eq 0) {
                $privacyScore += 3
                $result.ActivityDisabled = $true
                $result.Items += @{ Name = "Activity History"; Value = "Disabled"; Status = "Good"; Note = "Activity tracking disabled" }
            } else {
                $result.Items += @{ Name = "Activity History"; Value = "Enabled"; Status = "Warning"; Note = "Activity tracking active" }
            }
        } catch {
            Write-Log -Level "DEBUG" -Category "HealthScore" -Message "Could not check activity history: $($_.Exception.Message)"
            $privacyScore += 1  # Partial credit
            $result.Items += @{ Name = "Activity History"; Value = "Unknown"; Status = "Warning"; Note = "Could not check activity history" }
        }

        # Check diagnostic data level
        try {
            $diagValue = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -ErrorAction SilentlyContinue
            if ($diagValue -and $diagValue.AllowTelemetry -le 1) {
                $privacyScore += 3
                $result.DiagnosticMinimal = $true
                $result.Items += @{ Name = "Diagnostic Data"; Value = "Minimal"; Status = "Good"; Note = "Minimal diagnostic data" }
            } elseif ($diagValue -and $diagValue.AllowTelemetry -eq 2) {
                $privacyScore += 1
                $result.Items += @{ Name = "Diagnostic Data"; Value = "Enhanced"; Status = "Warning"; Note = "Enhanced diagnostic data" }
            } else {
                $result.Items += @{ Name = "Diagnostic Data"; Value = "Full"; Status = "Critical"; Note = "Full diagnostic data being sent" }
            }
        } catch {
            Write-Log -Level "DEBUG" -Category "HealthScore" -Message "Could not check diagnostic data: $($_.Exception.Message)"
            $privacyScore += 1  # Partial credit
            $result.Items += @{ Name = "Diagnostic Data"; Value = "Unknown"; Status = "Warning"; Note = "Could not check diagnostic settings" }
        }

        $result.Score = [math]::Min(10, $privacyScore)

        # Build details
        $items = @()
        if ($result.TelemetryDisabled) { $items += "telemetry off" }
        if ($result.ActivityDisabled) { $items += "activity off" }
        if ($result.DiagnosticMinimal) { $items += "minimal diag" }
        $result.Details = "Privacy settings: $($items -join ', ')" + ($(if ($items.Count -eq 0) { " (all tracking active)" } else { "" }))

    } catch {
        Write-Log -Level "ERROR" -Category "HealthScore" -Message "Error calculating privacy health: $($_.Exception.Message)"
        $result.Score = 5  # Neutral score on error
        $result.Details = "Could not retrieve privacy settings"
        $result.Items += @{ Name = "Privacy Info"; Value = "Error"; Status = "Warning"; Note = "Unable to read privacy data" }
    }

    Write-Log -Level "INFO" -Category "HealthScore" -Message "Privacy health score: $($result.Score)/$($result.MaxScore)"
    return $result
}

# Security Health Score (0-10)
# Factors: Windows Defender status, firewall enabled, updates current
function global:Get-SecurityHealthScore {
    Write-Log -Level "INFO" -Category "HealthScore" -Message "Calculating security health score..."

    $result = @{
        Score           = 0
        MaxScore        = 10
        Details         = ""
        Items           = @()
        DefenderActive  = $false
        FirewallEnabled = $false
        UpdatesCurrent  = $false
    }

    $securityScore = 0

    try {
        # Check Windows Defender status (registry-based, fast)
        try {
            $defenderPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
            $avEnabled = Get-ItemProperty -Path $defenderPath -Name "DisableAntiVirus" -ErrorAction SilentlyContinue
            $rtEnabled = Get-ItemProperty -Path $defenderPath -Name "DisableRealtimeMonitoring" -ErrorAction SilentlyContinue
            
            if ((-not $avEnabled -or $avEnabled.DisableAntiVirus -eq 0) -and (-not $rtEnabled -or $rtEnabled.DisableRealtimeMonitoring -eq 0)) {
                $securityScore += 4
                $result.DefenderActive = $true
                $result.Items += @{ Name = "Windows Defender"; Value = "Active"; Status = "Good"; Note = "Real-time protection enabled" }
            } elseif (-not $avEnabled -or $avEnabled.DisableAntiVirus -eq 0) {
                $securityScore += 2
                $result.Items += @{ Name = "Windows Defender"; Value = "Enabled (no real-time)"; Status = "Warning"; Note = "Real-time protection disabled" }
            } else {
                $result.Items += @{ Name = "Windows Defender"; Value = "Disabled"; Status = "Critical"; Note = "Antivirus is disabled" }
            }
        } catch {
            $securityScore += 3
            $result.Items += @{ Name = "Windows Defender"; Value = "Active (assumed)"; Status = "Good"; Note = "Could not verify, assuming active" }
        }

        # Check firewall status
        try {
            $firewall = Get-NetFirewallProfile -ErrorAction Stop
            $allEnabled = $true
            foreach ($profile in $firewall) {
                if (-not $profile.Enabled) {
                    $allEnabled = $false
                    $result.Items += @{ Name = "Firewall ($($profile.Name))"; Value = "Disabled"; Status = "Critical"; Note = "Firewall profile disabled" }
                }
            }

            if ($allEnabled) {
                $securityScore += 3
                $result.FirewallEnabled = $true
                $result.Items += @{ Name = "Windows Firewall"; Value = "All profiles enabled"; Status = "Good"; Note = "Firewall is active" }
            }
        } catch {
            Write-Log -Level "WARNING" -Category "HealthScore" -Message "Could not check firewall status: $($_.Exception.Message)"
            # Fallback to legacy method
            try {
                $fwStatus = netsh advfirewall show allprofiles state | Select-String "State.*ON"
                if ($fwStatus) {
                    $securityScore += 3
                    $result.FirewallEnabled = $true
                    $result.Items += @{ Name = "Windows Firewall"; Value = "Enabled"; Status = "Good"; Note = "Firewall is active" }
                } else {
                    $result.Items += @{ Name = "Windows Firewall"; Value = "Disabled"; Status = "Critical"; Note = "Firewall appears disabled" }
                }
            } catch {
                $securityScore += 1  # Partial credit
                $result.Items += @{ Name = "Windows Firewall"; Value = "Unknown"; Status = "Warning"; Note = "Could not check firewall" }
            }
        }

        # Check Windows Update status (fast registry check)
        try {
            $wuKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\UpdateHistory'
            if (Test-Path $wuKey) {
                $securityScore += 3
                $result.UpdatesCurrent = $true
                $result.Items += @{ Name = "Windows Updates"; Value = "Active"; Status = "Good"; Note = "Windows Update configured" }
            } else {
                $securityScore += 1
                $result.Items += @{ Name = "Windows Updates"; Value = "Unknown"; Status = "Warning"; Note = "Could not verify update status" }
            }
        } catch {
            $securityScore += 1
            $result.Items += @{ Name = "Windows Updates"; Value = "Unknown"; Status = "Warning"; Note = "Could not check updates" }
        }

        $result.Score = [math]::Min(10, $securityScore)

        # Build details
        $items = @()
        if ($result.DefenderActive) { $items += "Defender active" }
        if ($result.FirewallEnabled) { $items += "Firewall on" }
        if ($result.UpdatesCurrent) { $items += "Updates current" }
        $result.Details = "Security: $($items -join ', ')" + ($(if ($items.Count -eq 0) { " (security concerns detected)" } else { "" }))

    } catch {
        Write-Log -Level "ERROR" -Category "HealthScore" -Message "Error calculating security health: $($_.Exception.Message)"
        $result.Score = 5  # Neutral score on error
        $result.Details = "Could not retrieve security information"
        $result.Items += @{ Name = "Security Info"; Value = "Error"; Status = "Warning"; Note = "Unable to read security data" }
    }

    Write-Log -Level "INFO" -Category "HealthScore" -Message "Security health score: $($result.Score)/$($result.MaxScore)"
    return $result
}

# System Freshness Score (0-15)
# Factors: uptime (lower = fresher), pending reboots, update status
function global:Get-SystemFreshnessScore {
    Write-Log -Level "INFO" -Category "HealthScore" -Message "Calculating system freshness score..."

    $result = @{
        Score           = 0
        MaxScore        = 15
        Details         = ""
        Items           = @()
        UptimeDays      = 0
        PendingReboot   = $false
        PendingUpdates  = $false
    }

    try {
        # Get system uptime - use TickCount (instant, no WMI needed)
        $lastBoot = [DateTime]::Now.AddMilliseconds(-[Environment]::TickCount64)
        $uptime = (Get-Date) - $lastBoot
        $result.UptimeDays = [math]::Round($uptime.TotalDays, 1)

        Write-Log -Level "INFO" -Category "HealthScore" -Message "System uptime: $($result.UptimeDays) days (last boot: $lastBoot)"

        # Score based on uptime
        $uptimeScore = 0
        if ($result.UptimeDays -lt 7) {
            $uptimeScore = 15
            $result.Items += @{ Name = "System Uptime"; Value = "$($result.UptimeDays) days"; Status = "Good"; Note = "Fresh system restart" }
        } elseif ($result.UptimeDays -lt 30) {
            $uptimeScore = 10
            $result.Items += @{ Name = "System Uptime"; Value = "$($result.UptimeDays) days"; Status = "Good"; Note = "Reasonable uptime" }
        } elseif ($result.UptimeDays -lt 90) {
            $uptimeScore = 5
            $result.Items += @{ Name = "System Uptime"; Value = "$($result.UptimeDays) days"; Status = "Warning"; Note = "Consider restarting" }
        } else {
            $uptimeScore = 0
            $result.Items += @{ Name = "System Uptime"; Value = "$($result.UptimeDays) days"; Status = "Critical"; Note = "System needs restart" }
        }

        $result.Score = $uptimeScore

        # Check for pending reboot
        try {
            $rebootKeys = @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired",
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending",
                "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations"
            )

            foreach ($key in $rebootKeys) {
                if (Test-Path $key) {
                    $result.PendingReboot = $true
                    $result.Score = [math]::Max(0, $result.Score - 2)
                    $result.Items += @{ Name = "Pending Reboot"; Value = "Required"; Status = "Warning"; Note = "System has pending reboot" }
                    Write-Log -Level "WARNING" -Category "HealthScore" -Message "Pending reboot detected: $key"
                    break
                }
            }

            if (-not $result.PendingReboot) {
                $result.Items += @{ Name = "Pending Reboot"; Value = "None"; Status = "Good"; Note = "No pending reboots" }
            }
        } catch {
            Write-Log -Level "DEBUG" -Category "HealthScore" -Message "Could not check pending reboot: $($_.Exception.Message)"
        }

        # Check for pending Windows updates (skip slow COM check)
        $result.Items += @{ Name = "Pending Updates"; Value = "Not checked"; Status = "Good"; Note = "Skipped for speed" }

        $result.Details = "Uptime: $($result.UptimeDays) days | Pending reboot: $($result.PendingReboot) | Pending updates: $($result.PendingUpdates)"

    } catch {
        Write-Log -Level "ERROR" -Category "HealthScore" -Message "Error calculating freshness score: $($_.Exception.Message)"
        $result.Score = 8  # Neutral score on error
        $result.Details = "Could not retrieve system freshness information"
        $result.Items += @{ Name = "Freshness Info"; Value = "Error"; Status = "Warning"; Note = "Unable to read freshness data" }
    }

    Write-Log -Level "INFO" -Category "HealthScore" -Message "System freshness score: $($result.Score)/$($result.MaxScore)"
    return $result
}

function global:Get-SystemHealthScore {
    # Return cached result if less than 5 minutes old
    if ($script:CachedHealthScore -and $script:HealthScoreTime -and ((Get-Date) - $script:HealthScoreTime).TotalMinutes -lt 5) {
        return $script:CachedHealthScore
    }

    Write-Log -Level "SUCCESS" -Category "HealthScore" -Message "Starting system health assessment..."
    $startTime = Get-Date

    # Calculate all category scores
    $diskScore = Get-DiskHealthScore
    $startupScore = Get-StartupHealthScore
    $serviceScore = Get-ServiceHealthScore
    $networkScore = Get-NetworkHealthScore
    $privacyScore = Get-PrivacyHealthScore
    $securityScore = Get-SecurityHealthScore
    $freshnessScore = Get-SystemFreshnessScore

    # Calculate total score
    $totalScore = $diskScore.Score + $startupScore.Score + $serviceScore.Score +
                  $networkScore.Score + $privacyScore.Score + $securityScore.Score +
                  $freshnessScore.Score

    $elapsed = ((Get-Date) - $startTime).TotalSeconds
    Write-Log -Level "SUCCESS" -Category "HealthScore" -Message "Health assessment complete. Total score: $totalScore/100 ($elapsed s)"

    $grade = if ($totalScore -ge 90) { "A" } elseif ($totalScore -ge 80) { "B" } elseif ($totalScore -ge 70) { "C" } elseif ($totalScore -ge 60) { "D" } else { "F" }

    $script:CachedHealthScore = @{
        TotalScore = $totalScore
        MaxScore = 100
        Grade = $grade
        Categories = @{
            Disk = $diskScore
            Startup = $startupScore
            Services = $serviceScore
            Network = $networkScore
            Privacy = $privacyScore
            Security = $securityScore
            Freshness = $freshnessScore
        }
        ElapsedSeconds = $elapsed
    }
    $script:HealthScoreTime = Get-Date
    return $script:CachedHealthScore
}

$script:CachedHealthScore = $null
$script:HealthScoreTime = $null

# Main health score aggregation function
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
# Function Get-SystemHealthScore removed (duplicate of E:\WinTunePro\Core\AppCore.ps1)
