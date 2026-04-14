#Requires -Version 5.1
<#
.SYNOPSIS
    WinTune Pro StartupEnhanced Module - Enhanced startup optimizer
.DESCRIPTION
    Enhanced startup optimization with risk assessment and dependency mapping
#>

$global:StartupRiskLevels = @{
    Critical   = @{ Min = 0; Max = 10; Description = "Windows core, antivirus, driver services" }
    System     = @{ Min = 11; Max = 30; Description = "Microsoft services, security software" }
    Driver     = @{ Min = 31; Max = 50; Description = "Hardware drivers, manufacturer software" }
    ThirdParty = @{ Min = 51; Max = 70; Description = "User-installed applications" }
    Unknown    = @{ Min = 71; Max = 100; Description = "Unrecognized items" }
}

$global:StartupCriticalPatterns = @(
    "*windows*"
    "*microsoft*"
    "*defender*"
    "*security*"
    "*antivirus*"
    "*nvidia*"
    "*amd*"
    "*intel*"
    "*audio*"
    "*realtek*"
    "*synaptics*"
    "*elan*"
)

$global:StartupOptimizationLog = @()

function global:Get-StartupRiskAssessment {
    <#
    .SYNOPSIS
        Assesses risk level of each startup item.
    #>

    $result = @{
        Success = $true
        Items   = @()
        Error   = $null
    }

    Write-Log -Level "INFO" -Category "StartupEnhanced" -Message "Assessing startup item risks..."

    try {
        $startupItems = @()

        $regPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
        )

        foreach ($regPath in $regPaths) {
            if (Test-Path $regPath) {
                $props = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
                if ($props) {
                    $props.PSObject.Properties | Where-Object { $_.Name -notmatch "^PS" } | ForEach-Object {
                        $riskScore = Get-StartupItemRiskScore -Name $_.Name -Command $_.Value
                        $riskLevel = Get-RiskLevelFromScore -Score $riskScore

                        $startupItems += [PSCustomObject]@{
                            Name       = $_.Name
                            Command    = $_.Value
                            Source     = $regPath
                            RiskScore  = $riskScore
                            RiskLevel  = $riskLevel
                            Enabled    = $true
                        }
                    }
                }
            }
        }

        $startupFolder = [System.Environment]::GetFolderPath("Startup")
        $commonStartup = [System.Environment]::GetFolderPath("CommonStartup")

        foreach ($folder in @($startupFolder, $commonStartup)) {
            if (Test-Path $folder) {
                Get-ChildItem -Path $folder -ErrorAction SilentlyContinue | ForEach-Object {
                    $riskScore = Get-StartupItemRiskScore -Name $_.Name -Command $_.FullName
                    $riskLevel = Get-RiskLevelFromScore -Score $riskScore

                    $startupItems += [PSCustomObject]@{
                        Name       = $_.BaseName
                        Command    = $_.FullName
                        Source     = $folder
                        RiskScore  = $riskScore
                        RiskLevel  = $riskLevel
                        Enabled    = $true
                    }
                }
            }
        }

        $taskItems = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
            $_.State -ne "Disabled" -and $_.Triggers | Where-Object { $_ -is [CimInstance] -and $_.CimClass.CimClassName -match "Boot|Logon" }
        }

        foreach ($task in $taskItems) {
            $taskName = $task.TaskName
            $riskScore = Get-StartupItemRiskScore -Name $taskName -Command $task.Actions.Execute
            $riskLevel = Get-RiskLevelFromScore -Score $riskScore

            $startupItems += [PSCustomObject]@{
                Name       = $taskName
                Command    = $task.Actions.Execute
                Source     = "ScheduledTask"
                RiskScore  = $riskScore
                RiskLevel  = $riskLevel
                Enabled    = ($task.State -ne "Disabled")
            }
        }

        $result.Items = $startupItems
        Write-Log -Level "INFO" -Category "StartupEnhanced" -Message "Assessed $($startupItems.Count) startup items"
    } catch {
        Write-Log -Level "ERROR" -Category "StartupEnhanced" -Message "Error assessing startup items: $($_.Exception.Message)"
        $result.Success = $false
        $result.Error = $_.Exception.Message
    }

    return $result
}

function global:Get-StartupPerformanceImpact {
    <#
    .SYNOPSIS
        Estimates boot time impact per startup item.
    #>

    $result = @{
        Success           = $true
        Items             = @()
        EstimatedImpactMs = 0
        Error             = $null
    }

    Write-Log -Level "INFO" -Category "StartupEnhanced" -Message "Analyzing startup performance impact..."

    $assessment = Get-StartupRiskAssessment
    if (-not $assessment.Success) {
        $result.Success = $false
        $result.Error = $assessment.Error
        return $result
    }

    foreach ($item in $assessment.Items) {
        $impactMs = 0

        if ($item.Command -match "\.exe") {
            if ($item.Command -match "antivirus|defender|security") {
                $impactMs = 500
            } elseif ($item.Command -match "nvidia|amd|intel|driver") {
                $impactMs = 300
            } elseif ($item.Command -match "update|updater|autoupdate") {
                $impactMs = 400
            } elseif ($item.RiskLevel -eq "ThirdParty") {
                $impactMs = 200
            } else {
                $impactMs = 150
            }
        } elseif ($item.Command -match "\.lnk") {
            $impactMs = 100
        } elseif ($item.Command -match "\.vbs|\.ps1|\.bat|\.cmd") {
            $impactMs = 250
        } else {
            $impactMs = 100
        }

        $item | Add-Member -NotePropertyName "ImpactMs" -NotePropertyValue $impactMs -Force
        $result.Items += $item
        $result.EstimatedImpactMs += $impactMs
    }

    Write-Log -Level "INFO" -Category "StartupEnhanced" -Message "Estimated total startup impact: $($result.EstimatedImpactMs)ms"
    return $result
}

function global:Get-StartupRecommendations {
    <#
    .SYNOPSIS
        AI-like recommendation engine for startup optimization.
    #>

    $result = @{
        Success        = $true
        Recommendations = @()
        SafeToDisable  = @()
        CautionItems   = @()
        NeverDisable   = @()
        Error          = $null
    }

    Write-Log -Level "INFO" -Category "StartupEnhanced" -Message "Generating startup recommendations..."

    $assessment = Get-StartupRiskAssessment
    if (-not $assessment.Success) {
        $result.Success = $false
        $result.Error = $assessment.Error
        return $result
    }

    foreach ($item in $assessment.Items) {
        switch ($item.RiskLevel) {
            "Critical" {
                $result.NeverDisable += $item
                $result.Recommendations += [PSCustomObject]@{
                    Item        = $item.Name
                    Action      = "Keep"
                    Risk        = "Critical"
                    Reason      = "System-critical component - never disable"
                }
            }
            "System" {
                $result.CautionItems += $item
                $result.Recommendations += [PSCustomObject]@{
                    Item        = $item.Name
                    Action      = "Review"
                    Risk        = "System"
                    Reason      = "Microsoft/service component - review before disabling"
                }
            }
            "Driver" {
                $result.CautionItems += $item
                $result.Recommendations += [PSCustomObject]@{
                    Item        = $item.Name
                    Action      = "Review"
                    Risk        = "Driver"
                    Reason      = "Hardware driver - verify functionality after disabling"
                }
            }
            "ThirdParty" {
                $result.SafeToDisable += $item
                $result.Recommendations += [PSCustomObject]@{
                    Item        = $item.Name
                    Action      = "Disable"
                    Risk        = "Low"
                    Reason      = "Third-party app - generally safe to disable at startup"
                }
            }
            "Unknown" {
                $result.CautionItems += $item
                $result.Recommendations += [PSCustomObject]@{
                    Item        = $item.Name
                    Action      = "Investigate"
                    Risk        = "Unknown"
                    Reason      = "Unrecognized item - investigate before modifying"
                }
            }
        }
    }

    Write-Log -Level "INFO" -Category "StartupEnhanced" -Message "Recommendations: $($result.SafeToDisable.Count) safe, $($result.CautionItems.Count) caution, $($result.NeverDisable.Count) critical"
    return $result
}

function global:Invoke-SmartStartupOptimization {
    <#
    .SYNOPSIS
        Applies safe optimizations while preserving critical items.
    #>
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{
        Success         = $true
        ItemsDisabled   = 0
        ItemsKept       = 0
        Error           = $null
    }

    if (-not $script:State.IsElevated) {
        Write-Log -Level "ERROR" -Category "StartupEnhanced" -Message "Admin privileges required for startup optimization"
        $result.Success = $false
        $result.Error = "Admin privileges required"
        return $result
    }

    Write-Log -Level "INFO" -Category "StartupEnhanced" -Message "Running smart startup optimization..."

    $recommendations = Get-StartupRecommendations
    if (-not $recommendations.Success) {
        $result.Success = $false
        $result.Error = $recommendations.Error
        return $result
    }

    foreach ($item in $recommendations.SafeToDisable) {
        try {
            if ($Preview) {
                Write-Log -Level "INFO" -Category "StartupEnhanced" -Message "[Preview] Would disable: $($item.Name)"
            } elseif ($TestMode) {
                Write-Log -Level "INFO" -Category "StartupEnhanced" -Message "[TestMode] Item $($item.Name) flagged for disabling"
            } else {
                $disableResult = Disable-StartupItem -Item $item
                if ($disableResult) {
                    Write-Log -Level "SUCCESS" -Category "StartupEnhanced" -Message "Disabled: $($item.Name)"

                    $global:StartupOptimizationLog += [PSCustomObject]@{
                        Name        = $item.Name
                        Command     = $item.Command
                        Source      = $item.Source
                        DisabledAt  = Get-Date
                        RiskLevel   = $item.RiskLevel
                    }
                }
            }
            $result.ItemsDisabled++
        } catch {
            Write-Log -Level "WARNING" -Category "StartupEnhanced" -Message "Error disabling $($item.Name): $($_.Exception.Message)"
        }
    }

    $result.ItemsKept = $recommendations.NeverDisable.Count + $recommendations.CautionItems.Count
    Write-Log -Level "SUCCESS" -Category "StartupEnhanced" -Message "Optimization complete: $($result.ItemsDisabled) disabled, $($result.ItemsKept) kept"
    return $result
}

function global:Disable-HighRiskStartupItems {
    <#
    .SYNOPSIS
        Disables only items with risk >= threshold.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [int]$RiskThreshold,
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{
        Success       = $true
        ItemsDisabled = 0
        Error         = $null
    }

    if (-not $script:State.IsElevated) {
        Write-Log -Level "ERROR" -Category "StartupEnhanced" -Message "Admin privileges required to disable startup items"
        $result.Success = $false
        $result.Error = "Admin privileges required"
        return $result
    }

    Write-Log -Level "INFO" -Category "StartupEnhanced" -Message "Disabling startup items with risk score >= $RiskThreshold..."

    $assessment = Get-StartupRiskAssessment
    $itemsToDisable = $assessment.Items | Where-Object { $_.RiskScore -ge $RiskThreshold }

    foreach ($item in $itemsToDisable) {
        try {
            if ($Preview) {
                Write-Log -Level "INFO" -Category "StartupEnhanced" -Message "[Preview] Would disable: $($item.Name) (risk $($item.RiskScore))"
            } elseif ($TestMode) {
                Write-Log -Level "INFO" -Category "StartupEnhanced" -Message "[TestMode] Item $($item.Name) (risk $($item.RiskScore)) flagged"
            } else {
                Disable-StartupItem -Item $item | Out-Null
                Write-Log -Level "SUCCESS" -Category "StartupEnhanced" -Message "Disabled: $($item.Name) (risk $($item.RiskScore))"
            }
            $result.ItemsDisabled++
        } catch {
            Write-Log -Level "WARNING" -Category "StartupEnhanced" -Message "Error disabling $($item.Name): $($_.Exception.Message)"
        }
    }

    Write-Log -Level "SUCCESS" -Category "StartupEnhanced" -Message "Disabled $($result.ItemsDisabled) items above risk threshold"
    return $result
}

function global:Get-StartupDependencyMap {
    <#
    .SYNOPSIS
        Maps dependencies between startup items.
    #>

    $result = @{
        Success      = $true
        Dependencies = @()
        Services     = @()
        Error        = $null
    }

    Write-Log -Level "INFO" -Category "StartupEnhanced" -Message "Mapping startup dependencies..."

    try {
        $services = Get-Service -ErrorAction SilentlyContinue | Where-Object {
            $_.StartType -eq "Automatic" -or $_.StartType -eq "AutomaticDelayedStart"
        }

        foreach ($svc in $services) {
            $deps = @()
            if ($svc.ServicesDependedOn) {
                $deps = $svc.ServicesDependedOn | ForEach-Object { $_.Name }
            }

            $result.Services += [PSCustomObject]@{
                Name         = $svc.Name
                DisplayName  = $svc.DisplayName
                Status       = $svc.Status
                StartType    = $svc.StartType
                Dependencies = $deps
                Dependents   = @()
            }
        }

        foreach ($svc in $result.Services) {
            foreach ($dep in $svc.Dependencies) {
                $parent = $result.Services | Where-Object { $_.Name -eq $dep }
                if ($parent) {
                    $parent.Dependents += $svc.Name
                }
            }
        }

        Write-Log -Level "INFO" -Category "StartupEnhanced" -Message "Mapped $($result.Services.Count) services with dependencies"
    } catch {
        Write-Log -Level "ERROR" -Category "StartupEnhanced" -Message "Error mapping dependencies: $($_.Exception.Message)"
        $result.Success = $false
        $result.Error = $_.Exception.Message
    }

    return $result
}

function global:Export-StartupOptimizationPlan {
    <#
    .SYNOPSIS
        Exports what would be changed before applying.
    #>
    param(
        [string]$OutputPath = "$env:TEMP\StartupPlan_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    )

    $result = @{
        Success    = $true
        OutputPath = $OutputPath
        Error      = $null
    }

    Write-Log -Level "INFO" -Category "StartupEnhanced" -Message "Generating startup optimization plan..."

    try {
        $recommendations = Get-StartupRecommendations

        $plan = @()
        $plan += "============================================="
        $plan += "WinTune Startup Optimization Plan"
        $plan += "Generated: $(Get-Date)"
        $plan += "============================================="
        $plan += ""

        $plan += "--- SAFE TO DISABLE ($($recommendations.SafeToDisable.Count) items) ---"
        foreach ($item in $recommendations.SafeToDisable) {
            $plan += "  [DISABLE] $($item.Name)"
            $plan += "    Source: $($item.Source)"
            $plan += "    Command: $($item.Command)"
            $plan += ""
        }

        $plan += "--- CAUTION REQUIRED ($($recommendations.CautionItems.Count) items) ---"
        foreach ($item in $recommendations.CautionItems) {
            $plan += "  [REVIEW] $($item.Name)"
            $plan += "    Source: $($item.Source)"
            $plan += "    Risk: $($item.RiskLevel) (Score: $($item.RiskScore))"
            $plan += ""
        }

        $plan += "--- NEVER DISABLE ($($recommendations.NeverDisable.Count) items) ---"
        foreach ($item in $recommendations.NeverDisable) {
            $plan += "  [KEEP] $($item.Name)"
            $plan += "    Source: $($item.Source)"
            $plan += ""
        }

        $plan += "--- RECOMMENDATIONS ---"
        foreach ($rec in $recommendations.Recommendations) {
            $plan += "  [$($rec.Action)] $($rec.Item) - $($rec.Reason)"
        }

        $plan | Out-File -FilePath $OutputPath -Encoding UTF8 -Force
        Write-Log -Level "SUCCESS" -Category "StartupEnhanced" -Message "Optimization plan exported to: $OutputPath"
    } catch {
        Write-Log -Level "ERROR" -Category "StartupEnhanced" -Message "Error exporting plan: $($_.Exception.Message)"
        $result.Success = $false
        $result.Error = $_.Exception.Message
    }

    return $result
}

function global:Restore-StartupDefaults {
    <#
    .SYNOPSIS
        Undoes all startup changes.
    #>
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{
        Success        = $true
        ItemsRestored  = 0
        Error          = $null
    }

    if (-not $script:State.IsElevated) {
        Write-Log -Level "ERROR" -Category "StartupEnhanced" -Message "Admin privileges required to restore startup items"
        $result.Success = $false
        $result.Error = "Admin privileges required"
        return $result
    }

    Write-Log -Level "INFO" -Category "StartupEnhanced" -Message "Restoring startup defaults..."

    if ($global:StartupOptimizationLog.Count -eq 0) {
        Write-Log -Level "INFO" -Category "StartupEnhanced" -Message "No items to restore"
        return $result
    }

    foreach ($entry in $global:StartupOptimizationLog) {
        try {
            if ($Preview) {
                Write-Log -Level "INFO" -Category "StartupEnhanced" -Message "[Preview] Would restore: $($entry.Name)"
            } elseif ($TestMode) {
                Write-Log -Level "INFO" -Category "StartupEnhanced" -Message "[TestMode] Item $($entry.Name) flagged for restoration"
            } else {
                if ($entry.Source -match "HKLM:|HKCU:") {
                    Set-ItemProperty -Path $entry.Source -Name $entry.Name -Value $entry.Command -Force -ErrorAction SilentlyContinue
                    Write-Log -Level "SUCCESS" -Category "StartupEnhanced" -Message "Restored registry entry: $($entry.Name)"
                } elseif ($entry.Source -match "ScheduledTask") {
                    Enable-ScheduledTask -TaskName $entry.Name -ErrorAction SilentlyContinue | Out-Null
                    Write-Log -Level "SUCCESS" -Category "StartupEnhanced" -Message "Re-enabled task: $($entry.Name)"
                }
            }
            $result.ItemsRestored++
        } catch {
            Write-Log -Level "WARNING" -Category "StartupEnhanced" -Message "Error restoring $($entry.Name): $($_.Exception.Message)"
        }
    }

    if (-not $Preview -and -not $TestMode) {
        $global:StartupOptimizationLog = @()
    }

    Write-Log -Level "SUCCESS" -Category "StartupEnhanced" -Message "Restored $($result.ItemsRestored) items"
    return $result
}

function global:Get-StartupItemRiskScore {
    param(
        [string]$Name,
        [string]$Command
    )

    $score = 71

    $combined = "$Name $Command".ToLower()

    foreach ($pattern in $global:StartupCriticalPatterns) {
        $regex = $pattern.Replace("*", ".*")
        if ($combined -match $regex) {
            $score = 5
            return $score
        }
    }

    if ($combined -match "microsoft|windows|msi" -and $combined -notmatch "teams|onedrive|edge|office") {
        $score = 15
    } elseif ($combined -match "driver|service|audio|display|network") {
        $score = 35
    } elseif ($combined -match "update|updater|autoupdate|helper") {
        $score = 55
    } elseif ($combined -match "adobe|java|dropbox|spotify|discord|slack|zoom|steam|epic|origin") {
        $score = 60
    }

    return $score
}

function global:Get-RiskLevelFromScore {
    param([int]$Score)

    foreach ($level in $global:StartupRiskLevels.Keys) {
        $range = $global:StartupRiskLevels[$level]
        if ($Score -ge $range.Min -and $Score -le $range.Max) {
            return $level
        }
    }
    return "Unknown"
}

# Function Disable-StartupItem removed (duplicate of E:\WinTunePro\Modules\Optimization\Startup.ps1)
# Function Disable-StartupItem removed (duplicate of E:\WinTunePro\Modules\Optimization\Startup.ps1)
# Function Disable-StartupItem removed (duplicate of E:\WinTunePro\Modules\Optimization\Startup.ps1)
# Function Disable-StartupItem removed (duplicate of E:\WinTunePro\Modules\Optimization\Startup.ps1)
# Function Disable-StartupItem removed (duplicate of E:\WinTunePro\Modules\Optimization\Startup.ps1)
# Function Disable-StartupItem removed (duplicate of E:\WinTunePro\Modules\Optimization\Startup.ps1)
# Function Disable-StartupItem removed (duplicate of E:\WinTunePro\Modules\Optimization\Startup.ps1)
# Function Disable-StartupItem removed (duplicate of E:\WinTunePro\Modules\Optimization\Startup.ps1)
# Function Disable-StartupItem removed (duplicate of E:\WinTunePro\Modules\Optimization\Startup.ps1)
# Function Disable-StartupItem removed (duplicate of E:\WinTunePro\Modules\Optimization\Startup.ps1)
# Function Disable-StartupItem removed (duplicate of E:\WinTunePro\Modules\Optimization\Startup.ps1)
# Function Disable-StartupItem removed (duplicate of E:\WinTunePro\Modules\Optimization\Startup.ps1)
# Function Disable-StartupItem removed (duplicate of E:\WinTunePro\Modules\Optimization\Startup.ps1)
# Function Disable-StartupItem removed (duplicate of E:\WinTunePro\Modules\Optimization\Startup.ps1)
# Function Disable-StartupItem removed (duplicate of E:\WinTunePro\Modules\Optimization\Startup.ps1)
# Function Disable-StartupItem removed (duplicate of E:\WinTunePro\Modules\Optimization\Startup.ps1)
# Function Disable-StartupItem removed (duplicate of E:\WinTunePro\Modules\Optimization\Startup.ps1)
# Function Disable-StartupItem removed (duplicate of E:\WinTunePro\Modules\Optimization\Startup.ps1)
# Function Disable-StartupItem removed (duplicate of E:\WinTunePro\Modules\Optimization\Startup.ps1)
# Function Disable-StartupItem removed (duplicate of E:\WinTunePro\Modules\Optimization\Startup.ps1)
# Function Disable-StartupItem removed (duplicate of E:\WinTunePro\Modules\Optimization\Startup.ps1)
# Function Disable-StartupItem removed (duplicate of E:\WinTunePro\Modules\Optimization\Startup.ps1)
