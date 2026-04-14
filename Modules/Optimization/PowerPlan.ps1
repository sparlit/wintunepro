<#
.SYNOPSIS
    WinTune Pro PowerPlan Module - Power plan management
.DESCRIPTION
    Power plan configuration and optimization for Windows
#>

# ============================================================================
# POWER PLAN INFORMATION
# ============================================================================

function global:Get-PowerPlanInfo {
    <#
    .SYNOPSIS
        Gets detailed information about all power plans.
    #>
    
    $powerPlans = @()
    
    try {
        $plans = powercfg /list 2>&1 | Select-String "Power Scheme GUID"
        
        foreach ($plan in $plans) {
            if ($plan -match 'Power Scheme GUID: ([a-f0-9-]+)  \(([^\)]+)\)(\s+\*)?') {
                $guid = $Matches[1]
                $name = $Matches[2]
                $isActive = $Matches[3] -match '\*'
                
                # Get additional details
                $details = Get-PowerPlanDetails -Guid $guid
                
                $powerPlans += [PSCustomObject]@{
                    Guid = $guid
                    Name = $name
                    IsActive = $isActive
                    Description = $details.Description
                    Settings = $details.Settings
                    EstimatedBatteryLife = $details.EstimatedBatteryLife
                }
            }
        }
    } catch {
        Write-Log -Level "ERROR" -Category "PowerPlan" -Message "Error getting power plans: $($_.Exception.Message)"
    }
    
    return $powerPlans
}

function global:Get-PowerPlanDetails {
    <#
    .SYNOPSIS
        Gets detailed settings for a specific power plan.
    #>
    param([string]$Guid)
    
    $details = @{
        Description = ""
        Settings = @{}
        EstimatedBatteryLife = "Unknown"
    }
    
    try {
        # Get power plan description
        $query = powercfg /query $Guid 2>&1
        
        # Parse key settings
        $settings = @{
            "MonitorTimeout" = "Unknown"
            "SleepTimeout" = "Unknown"
            "HibernateTimeout" = "Unknown"
            "ProcessorMinState" = "Unknown"
            "ProcessorMaxState" = "Unknown"
            "HardDiskTimeout" = "Unknown"
        }
        
        # Extract monitor timeout (AC)
        if ($query -match 'Video timeout.*?AC power.*?Current AC Power Setting Index: 0x([a-f0-9]+)') {
            $settings.MonitorTimeout = [Convert]::ToInt32($Matches[1], 16)
        }
        
        # Extract sleep timeout
        if ($query -match 'Sleep timeout.*?Current AC Power Setting Index: 0x([a-f0-9]+)') {
            $settings.SleepTimeout = [Convert]::ToInt32($Matches[1], 16)
        }
        
        # Extract hibernate timeout
        if ($query -match 'Hibernate timeout.*?Current AC Power Setting Index: 0x([a-f0-9]+)') {
            $settings.HibernateTimeout = [Convert]::ToInt32($Matches[1], 16)
        }
        
        # Extract processor min state
        if ($query -match 'Minimum processor state.*?Current AC Power Setting Index: 0x([a-f0-9]+)') {
            $settings.ProcessorMinState = [Convert]::ToInt32($Matches[1], 16)
        }
        
        # Extract processor max state
        if ($query -match 'Maximum processor state.*?Current AC Power Setting Index: 0x([a-f0-9]+)') {
            $settings.ProcessorMaxState = [Convert]::ToInt32($Matches[1], 16)
        }
        
        $details.Settings = $settings
        
    } catch {
        Write-Log -Level "DEBUG" -Category "PowerPlan" -Message "Error getting power plan details: $($_.Exception.Message)"
    }
    
    return $details
}

# Function Get-CurrentPowerPlan removed (duplicate of E:\WinTunePro\Modules\Optimization\OptimizationCore.ps1)
# Function Get-CurrentPowerPlan removed (duplicate of E:\WinTunePro\Modules\Optimization\OptimizationCore.ps1)
# Function Get-CurrentPowerPlan removed (duplicate of E:\WinTunePro\Modules\Optimization\OptimizationCore.ps1)
# Function Get-CurrentPowerPlan removed (duplicate of E:\WinTunePro\Modules\Optimization\OptimizationCore.ps1)
# Function Get-CurrentPowerPlan removed (duplicate of E:\WinTunePro\Modules\Optimization\OptimizationCore.ps1)
# Function Get-CurrentPowerPlan removed (duplicate of E:\WinTunePro\Modules\Optimization\OptimizationCore.ps1)
# Function Get-CurrentPowerPlan removed (duplicate of E:\WinTunePro\Modules\Optimization\OptimizationCore.ps1)
# Function Get-CurrentPowerPlan removed (duplicate of E:\WinTunePro\Modules\Optimization\OptimizationCore.ps1)
# Function Get-CurrentPowerPlan removed (duplicate of E:\WinTunePro\Modules\Optimization\OptimizationCore.ps1)
# Function Get-CurrentPowerPlan removed (duplicate of E:\WinTunePro\Modules\Optimization\OptimizationCore.ps1)
# Function Get-CurrentPowerPlan removed (duplicate of E:\WinTunePro\Modules\Optimization\OptimizationCore.ps1)
# Function Get-CurrentPowerPlan removed (duplicate of E:\WinTunePro\Modules\Optimization\OptimizationCore.ps1)
# Function Get-CurrentPowerPlan removed (duplicate of E:\WinTunePro\Modules\Optimization\OptimizationCore.ps1)
# Function Get-CurrentPowerPlan removed (duplicate of E:\WinTunePro\Modules\Optimization\OptimizationCore.ps1)
# Function Get-CurrentPowerPlan removed (duplicate of E:\WinTunePro\Modules\Optimization\OptimizationCore.ps1)
# Function Get-CurrentPowerPlan removed (duplicate of E:\WinTunePro\Modules\Optimization\OptimizationCore.ps1)
# Function Get-CurrentPowerPlan removed (duplicate of E:\WinTunePro\Modules\Optimization\OptimizationCore.ps1)
# Function Get-CurrentPowerPlan removed (duplicate of E:\WinTunePro\Modules\Optimization\OptimizationCore.ps1)

# ============================================================================
# STANDARD POWER PLANS
# ============================================================================

$script:StandardPowerPlans = @{
    "Balanced" = "381b4222-f694-41f0-9685-ff5bb260df2e"
    "High Performance" = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
    "Power Saver" = "a1841308-3541-4fab-bc81-f71556f20b4a"
    "Ultimate Performance" = "e9a42b02-d5df-448d-aa00-03f14749eb61"
}

function global:Set-PowerPlan {
    <#
    .SYNOPSIS
        Sets the active power plan.
    #>
    param(
        [Parameter(ParameterSetName='ByName')]
        [ValidateSet('Balanced','High Performance','Power Saver','Ultimate Performance')]
        [string]$Name,
        
        [Parameter(ParameterSetName='ByGuid')]
        [string]$Guid,
        
        [switch]$Preview
    )
    
    $result = @{
        Success = $true
        PreviousPlan = $null
        NewPlan = $null
        Message = ""
        Errors = @()
    }
    
    # Get current plan
    $result.PreviousPlan = Get-CurrentPowerPlan
    
    # Resolve name to GUID if needed
    if ($Name) {
        $Guid = $script:StandardPowerPlans[$Name]
        if (-not $Guid) {
            $result.Success = $false
            $result.Message = "Unknown power plan: $Name"
            return $result
        }
        
        # Check if Ultimate Performance exists (may need to be created)
        if ($Name -eq "Ultimate Performance") {
            $exists = powercfg /list 2>&1 | Select-String $Guid
            if (-not $exists) {
                # Create Ultimate Performance plan
                $createResult = New-UltimatePerformancePlan -Preview:$Preview
                if (-not $createResult.Success) {
                    $result.Success = $false
                    $result.Message = "Failed to create Ultimate Performance plan"
                    return $result
                }
            }
        }
    }
    
    if ($Preview) {
        $result.Message = "[PREVIEW] Would set power plan to: $Name"
        return $result
    }
    
    Write-Log -Level "INFO" -Category "PowerPlan" -Message "Setting power plan to: $Name ($Guid)"
    
    try {
        powercfg /setactive $Guid 2>&1 | Out-Null
        
        $result.NewPlan = @{
            Guid = $Guid
            Name = $Name
        }
        
        $result.Message = "Power plan set to: $Name"
        Write-Log -Level "SUCCESS" -Category "PowerPlan" -Message $result.Message
        
        # Register for rollback
        Register-RollbackOperation -OperationType "Set-PowerPlan" -Target $Name -RollbackCommand {
            if ($result.PreviousPlan.Guid) {
                powercfg /setactive $result.PreviousPlan.Guid
            }
        } -Metadata @{ PreviousPlan = $result.PreviousPlan; NewPlan = $result.NewPlan } -Category "PowerPlan"
        
    } catch {
        $result.Success = $false
        $result.Message = $_.Exception.Message
        $result.Errors += $_.Exception.Message
    }
    
    return $result
}

function global:New-UltimatePerformancePlan {
    <#
    .SYNOPSIS
        Creates the Ultimate Performance power plan (Windows 10 1803+).
    #>
    param([switch]$Preview)
    
    $result = @{
        Success = $true
        Message = ""
        Guid = $script:StandardPowerPlans["Ultimate Performance"]
    }
    
    # Check if already exists
    $exists = powercfg /list 2>&1 | Select-String $result.Guid
    if ($exists) {
        $result.Message = "Ultimate Performance plan already exists"
        return $result
    }
    
    if ($Preview) {
        $result.Message = "[PREVIEW] Would create Ultimate Performance power plan"
        return $result
    }
    
    Write-Log -Level "INFO" -Category "PowerPlan" -Message "Creating Ultimate Performance power plan..."
    
    try {
        $output = powercfg -duplicatescheme $result.Guid 2>&1
        $result.Message = "Ultimate Performance plan created"
        Write-Log -Level "SUCCESS" -Category "PowerPlan" -Message $result.Message
    } catch {
        $result.Success = $false
        $result.Message = "Failed to create Ultimate Performance plan: $($_.Exception.Message)"
    }
    
    return $result
}

# ============================================================================
# POWER PLAN CUSTOMIZATION
# ============================================================================

function global:Set-PowerPlanSetting {
    <#
    .SYNOPSIS
        Modifies a specific power plan setting.
    #>
    param(
        [string]$Guid,
        
        [ValidateSet('MonitorTimeout','SleepTimeout','HibernateTimeout','ProcessorMinState','ProcessorMaxState','HardDiskTimeout','USBSelectiveSuspend')]
        [string]$Setting,
        
        [int]$ValueAC,
        [int]$ValueDC,
        
        [switch]$Preview
    )
    
    $result = @{
        Success = $true
        Setting = $Setting
        ValueAC = $ValueAC
        ValueDC = $ValueDC
        Message = ""
        Errors = @()
    }
    
    if (-not $Guid) {
        $currentPlan = Get-CurrentPowerPlan
        $Guid = $currentPlan.Guid
    }
    
    if ($Preview) {
        $result.Message = "[PREVIEW] Would set $Setting to AC:$ValueAC, DC:$ValueDC"
        return $result
    }
    
    # Power setting GUIDs
    $settingGuids = @{
        "MonitorTimeout" = @{
            Subgroup = "7516b95f-f776-4464-8c53-06167f40cc99"
            Setting = "3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e"
        }
        "SleepTimeout" = @{
            Subgroup = "238C9FA8-0AAD-41ED-83F4-97BE242C8F20"
            Setting = "29f6c1db-86da-48c5-9fdb-f2b67b1f44da"
        }
        "HibernateTimeout" = @{
            Subgroup = "238C9FA8-0AAD-41ED-83F4-97BE242C8F20"
            Setting = "9d7815a6-7ee4-497e-8888-515a05f02364"
        }
        "ProcessorMinState" = @{
            Subgroup = "54533251-82be-4824-96c1-47b60b740d00"
            Setting = "893dee8e-2bef-41e0-89c6-b55d0929964c"
        }
        "ProcessorMaxState" = @{
            Subgroup = "54533251-82be-4824-96c1-47b60b740d00"
            Setting = "bc5038f7-23e0-4960-96da-33abaf5935ec"
        }
        "HardDiskTimeout" = @{
            Subgroup = "0012ee47-9041-4b5d-9b77-535fba8b1442"
            Setting = "6738e2c4-e8a5-4a42-b16a-e040e7699103"
        }
        "USBSelectiveSuspend" = @{
            Subgroup = "2a737441-1930-4402-8d77-b2bebba308a3"
            Setting = "48e6b7a6-50f5-4782-a5d4-53bb8f07e226"
        }
    }
    
    $settingInfo = $settingGuids[$Setting]
    if (-not $settingInfo) {
        $result.Success = $false
        $result.Message = "Unknown setting: $Setting"
        return $result
    }
    
    try {
        # Set AC value
        if ($ValueAC -ge 0) {
            powercfg /setacvalueindex $Guid $settingInfo.Subgroup $settingInfo.Setting $ValueAC 2>&1 | Out-Null
        }
        
        # Set DC value
        if ($ValueDC -ge 0) {
            powercfg /setdcvalueindex $Guid $settingInfo.Subgroup $settingInfo.Setting $ValueDC 2>&1 | Out-Null
        }
        
        # Apply changes
        powercfg /setactive $Guid 2>&1 | Out-Null
        
        $result.Message = "$Setting set to AC:$ValueAC, DC:$ValueDC"
        Write-Log -Level "SUCCESS" -Category "PowerPlan" -Message $result.Message
        
    } catch {
        $result.Success = $false
        $result.Message = $_.Exception.Message
        $result.Errors += $_.Exception.Message
    }
    
    return $result
}

function global:Disable-USBSelectiveSuspend {
    <#
    .SYNOPSIS
        Disables USB selective suspend for better device responsiveness.
    #>
    param([switch]$Preview)
    
    $result = @{
        Success = $true
        Message = ""
    }
    
    if ($Preview) {
        $result.Message = "[PREVIEW] Would disable USB selective suspend"
        return $result
    }
    
    Write-Log -Level "INFO" -Category "PowerPlan" -Message "Disabling USB selective suspend..."
    
    $settingResult = Set-PowerPlanSetting -Setting "USBSelectiveSuspend" -ValueAC 0 -ValueDC 0
    
    if ($settingResult.Success) {
        $result.Message = "USB selective suspend disabled"
    } else {
        $result.Success = $false
        $result.Message = $settingResult.Message
    }
    
    return $result
}

function global:Optimize-PowerPlanForPerformance {
    <#
    .SYNOPSIS
        Applies performance-optimized settings to current power plan.
    #>
    param([switch]$Preview)
    
    $results = @{
        Success = $true
        Changes = @()
        Errors = @()
    }
    
    if ($Preview) {
        $results.Changes += "[PREVIEW] Would set High Performance power plan"
        $results.Changes += "[PREVIEW] Would disable USB selective suspend"
        $results.Changes += "[PREVIEW] Would set processor to 100% min/max"
        $results.Changes += "[PREVIEW] Would disable hibernate"
        return $results
    }
    
    Write-Log -Level "INFO" -Category "PowerPlan" -Message "Optimizing power plan for performance..."
    
    # Set High Performance plan
    $planResult = Set-PowerPlan -Name "High Performance"
    if ($planResult.Success) {
        $results.Changes += "Set High Performance power plan"
    } else {
        $results.Errors += "Failed to set power plan"
    }
    
    # Disable USB selective suspend
    $usbResult = Disable-USBSelectiveSuspend
    if ($usbResult.Success) {
        $results.Changes += "Disabled USB selective suspend"
    }
    
    # Set processor to always 100%
    $procMin = Set-PowerPlanSetting -Setting "ProcessorMinState" -ValueAC 100 -ValueDC 5
    $procMax = Set-PowerPlanSetting -Setting "ProcessorMaxState" -ValueAC 100 -ValueDC 100
    
    if ($procMin.Success) { $results.Changes += "Set processor min state to 100% (AC)" }
    if ($procMax.Success) { $results.Changes += "Set processor max state to 100%" }
    
    # Disable hibernate
    $hibernateResult = Disable-Hibernate -Preview:$Preview
    if ($hibernateResult.Success) {
        $results.Changes += "Disabled hibernate"
    }
    
    Write-Log -Level "SUCCESS" -Category "PowerPlan" -Message "Power plan optimization complete"
    
    return $results
}

# ============================================================================
# HIBERNATION MANAGEMENT
# ============================================================================

function global:Disable-Hibernate {
    <#
    .SYNOPSIS
        Disables hibernation and removes hiberfil.sys.
    #>
    param([switch]$Preview)
    
    $result = @{
        Success = $true
        Message = ""
        SpaceRecovered = 0
        Errors = @()
    }
    
    if ($Preview) {
        $result.Message = "[PREVIEW] Would disable hibernation"
        return $result
    }
    
    Write-Log -Level "INFO" -Category "PowerPlan" -Message "Disabling hibernation..."
    
    try {
        # Get hiberfil.sys size before
        $hiberfil = Get-Item "C:\hiberfil.sys" -Force -ErrorAction SilentlyContinue
        $result.SpaceRecovered = $hiberfil.Length
        
        # Disable hibernate
        powercfg /hibernate off 2>&1 | Out-Null
        
        $result.Message = "Hibernation disabled"
        if ($result.SpaceRecovered -gt 0) {
            $result.Message += ". Recovered: $(Format-FileSize $result.SpaceRecovered)"
        }
        
        Write-Log -Level "SUCCESS" -Category "PowerPlan" -Message $result.Message
        
    } catch {
        $result.Success = $false
        $result.Message = $_.Exception.Message
        $result.Errors += $_.Exception.Message
    }
    
    return $result
}

function global:Enable-Hibernate {
    <#
    .SYNOPSIS
        Enables hibernation.
    #>
    param([switch]$Preview)
    
    $result = @{
        Success = $true
        Message = ""
    }
    
    if ($Preview) {
        $result.Message = "[PREVIEW] Would enable hibernation"
        return $result
    }
    
    try {
        powercfg /hibernate on 2>&1 | Out-Null
        $result.Message = "Hibernation enabled"
        Write-Log -Level "SUCCESS" -Category "PowerPlan" -Message $result.Message
    } catch {
        $result.Success = $false
        $result.Message = $_.Exception.Message
    }
    
    return $result
}

function global:Set-HibernateFileSize {
    <#
    .SYNOPSIS
        Sets hiberfil.sys size as percentage of RAM.
    #>
    param(
        [ValidateRange(50,100)]
        [int]$SizePercent = 75,
        
        [switch]$Preview
    )
    
    $result = @{
        Success = $true
        Message = ""
        SizePercent = $SizePercent
    }
    
    if ($Preview) {
        $result.Message = "[PREVIEW] Would set hibernate file size to $SizePercent%"
        return $result
    }
    
    try {
        powercfg /hibernate /size $SizePercent 2>&1 | Out-Null
        $result.Message = "Hibernate file size set to $SizePercent%"
        Write-Log -Level "SUCCESS" -Category "PowerPlan" -Message $result.Message
    } catch {
        $result.Success = $false
        $result.Message = $_.Exception.Message
    }
    
    return $result
}

# ============================================================================
# FAST STARTUP
# ============================================================================

function global:Disable-FastStartup {
    <#
    .SYNOPSIS
        Disables Windows Fast Startup (hybrid boot).
    #>
    param([switch]$Preview)
    
    $result = @{
        Success = $true
        Message = ""
    }
    
    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Message = "Administrator privileges required"
        return $result
    }
    
    if ($Preview) {
        $result.Message = "[PREVIEW] Would disable Fast Startup"
        return $result
    }
    
    Write-Log -Level "INFO" -Category "PowerPlan" -Message "Disabling Fast Startup..."
    
    try {
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
        Set-ItemProperty -Path $regPath -Name "HiberbootEnabled" -Value 0 -Type DWord -Force
        
        $result.Message = "Fast Startup disabled"
        Write-Log -Level "SUCCESS" -Category "PowerPlan" -Message $result.Message
    } catch {
        $result.Success = $false
        $result.Message = $_.Exception.Message
    }
    
    return $result
}

function global:Enable-FastStartup {
    <#
    .SYNOPSIS
        Enables Windows Fast Startup.
    #>
    param([switch]$Preview)
    
    $result = @{
        Success = $true
        Message = ""
    }
    
    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Message = "Administrator privileges required"
        return $result
    }
    
    if ($Preview) {
        $result.Message = "[PREVIEW] Would enable Fast Startup"
        return $result
    }
    
    try {
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
        Set-ItemProperty -Path $regPath -Name "HiberbootEnabled" -Value 1 -Type DWord -Force
        
        $result.Message = "Fast Startup enabled"
        Write-Log -Level "SUCCESS" -Category "PowerPlan" -Message $result.Message
    } catch {
        $result.Success = $false
        $result.Message = $_.Exception.Message
    }
    
    return $result
}

function global:Get-PowerPlanRecommendations {
    <#
    .SYNOPSIS
        Gets power plan recommendations based on system type.
    #>
    
    $recommendations = @{
        CurrentPlan = Get-CurrentPowerPlan
        SystemType = "Unknown"
        Recommendations = @()
        Warnings = @()
    }
    
    # Detect system type
    $battery = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
    if ($battery) {
        $recommendations.SystemType = "Laptop"
        $recommendations.Recommendations += "Use Balanced or Power Saver on battery for longer runtime"
        $recommendations.Recommendations += "Use High Performance when plugged in"
    } else {
        $recommendations.SystemType = "Desktop"
        $recommendations.Recommendations += "Use High Performance for desktop systems"
        $recommendations.Recommendations += "Consider disabling hibernation to save disk space"
    }
    
    # Check current settings
    $currentPlan = $recommendations.CurrentPlan
    if ($currentPlan.Name -eq "Power Saver" -and $recommendations.SystemType -eq "Desktop") {
        $recommendations.Warnings += "Power Saver mode on desktop may reduce performance"
    }
    
    return $recommendations
}

# ============================================================================
# STANDARD POWER PLANS
# ============================================================================

$script:StandardPowerPlans = @{
    "Balanced" = "381b4222-f694-41f0-9685-ff5bb260df2e"
    "High Performance" = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
    "Power Saver" = "a1841308-3541-4fab-bc81-f71556f20b4a"
    "Ultimate Performance" = "e9a42b02-d5df-448d-aa00-03f14749eb61"
}
