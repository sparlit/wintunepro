#Requires -Version 5.1
<#
.SYNOPSIS
    WinTune Pro PowerPlanCustom Module - Power plan customization
.DESCRIPTION
    Advanced power plan customization using powercfg commands
#>

$global:PowerPlanGUIDs = @{
    UltimatePerformance = "e9a42b02-d5df-448d-aa00-03f14749eb61"
    HighPerformance     = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
    Balanced            = "381b4222-f694-41f0-9685-ff5bb260df2e"
    PowerSaver          = "a1841308-3541-4fab-bc81-f71556f20b4a"
}

$global:PowerSubGroupGUIDs = @{
    Processor       = "54533251-82be-4824-96c1-47b60b740d00"
    Display         = "7516b95f-f776-4464-8c53-06167f40cc99"
    Disk            = "0012ee47-9041-4b5d-9b77-535fba8b1442"
    Sleep           = "238c9fa8-0aad-41ed-83f4-97be242c8f20"
    USB             = "2a737441-1930-4402-8d77-b2bebba308a3"
    PCIExpress      = "501a4d13-42af-4429-9fd1-a8218c268e20"
    WirelessAdapter = "19cbb8fa-5279-450e-9fac-8a3d5fedd0c1"
    Battery         = "e73a048d-bf27-4f12-9731-8b2076e8891f"
}

$global:PowerSettingGUIDs = @{
    ProcessorMinState    = "893dee8e-2bef-41e0-89c6-b55d0929964c"
    ProcessorMaxState    = "bc5038f7-23e0-4960-96da-33abaf5935ec"
    MonitorTimeoutAC     = "3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e"
    MonitorTimeoutDC     = "3c0bc021-c8a8-4e07-a973-6b14cbcb2b7f"
    DiskTimeoutAC        = "6738e2c4-e8a5-4a42-b16a-e040e769756e"
    DiskTimeoutDC        = "6738e2c4-e8a5-4a42-b16a-e040e769756f"
    SleepTimeoutAC       = "29f6c1db-86da-48c5-9fdb-f2b67b1f44da"
    SleepTimeoutDC       = "29f6c1db-86da-48c5-9fdb-f2b67b1f44db"
    HibernateTimeoutAC   = "9d7815a6-7ee4-497e-8888-515a05f02364"
    HibernateTimeoutDC   = "9d7815a6-7ee4-497e-8888-515a05f02365"
    USBSuspendAC         = "48e6b7a6-50f5-4782-a5d4-53bb8f07e226"
    USBSuspendDC         = "48e6b7a6-50f5-4782-a5d4-53bb8f07e227"
    PCILinkStateAC       = "ee12f906-d277-404b-b6da-e5fa1a576df5"
    PCILinkStateDC       = "ee12f906-d277-404b-b6da-e5fa1a576df6"
    WirelessAdapterPower = "12bbebe6-58d6-4636-95bb-3217ef867c1a"
}

function global:New-CustomPowerPlan {
    <#
    .SYNOPSIS
        Creates a custom power plan from scratch.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$PlanName,
        [string]$BasePlan = "Balanced",
        [switch]$Preview
    )

    $result = @{
        Success = $true
        PlanGUID = ""
        PlanName = $PlanName
        Error    = $null
    }

    if (-not $script:State.IsElevated) {
        Write-Log -Level "ERROR" -Category "PowerPlanCustom" -Message "Admin privileges required to create power plan"
        $result.Success = $false
        $result.Error = "Admin privileges required"
        return $result
    }

    $baseGUID = $global:PowerPlanGUIDs[$BasePlan]
    if (-not $baseGUID) {
        $baseGUID = $global:PowerPlanGUIDs.Balanced
    }

    Write-Log -Level "INFO" -Category "PowerPlanCustom" -Message "Creating custom power plan '$PlanName' based on $BasePlan..."

    if ($Preview) {
        Write-Log -Level "INFO" -Category "PowerPlanCustom" -Message "[Preview] Would duplicate $BasePlan plan as '$PlanName'"
        return $result
    }

    try {
        $output = powercfg /duplicatescheme $baseGUID 2>&1
        if ($output -match "GUID: ([a-f0-9-]+)") {
            $newGUID = $Matches[1]
            powercfg /changename $newGUID $PlanName 2>&1 | Out-Null
            $result.PlanGUID = $newGUID
            Write-Log -Level "SUCCESS" -Category "PowerPlanCustom" -Message "Created power plan '$PlanName' with GUID: $newGUID"
        } else {
            $result.Success = $false
            $result.Error = "Failed to duplicate power plan"
            Write-Log -Level "ERROR" -Category "PowerPlanCustom" -Message "Failed to create power plan: $output"
        }
    } catch {
        Write-Log -Level "ERROR" -Category "PowerPlanCustom" -Message "Error creating power plan: $($_.Exception.Message)"
        $result.Success = $false
        $result.Error = $_.Exception.Message
    }

    return $result
}

function global:Set-ProcessorThrottling {
    <#
    .SYNOPSIS
        Sets CPU min/max state percentages.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$PlanGUID,
        [int]$MinStateAC = -1,
        [int]$MaxStateAC = -1,
        [int]$MinStateDC = -1,
        [int]$MaxStateDC = -1,
        [switch]$Preview
    )

    $result = @{
        Success = $true
        Error   = $null
    }

    if (-not $script:State.IsElevated) {
        Write-Log -Level "ERROR" -Category "PowerPlanCustom" -Message "Admin privileges required to set processor throttling"
        $result.Success = $false
        $result.Error = "Admin privileges required"
        return $result
    }

    Write-Log -Level "INFO" -Category "PowerPlanCustom" -Message "Setting processor throttling for plan $PlanGUID..."

    if ($Preview) {
        Write-Log -Level "INFO" -Category "PowerPlanCustom" -Message "[Preview] Would set processor min/max states"
        return $result
    }

    try {
        $subGroup = $global:PowerSubGroupGUIDs.Processor
        $minSetting = $global:PowerSettingGUIDs.ProcessorMinState
        $maxSetting = $global:PowerSettingGUIDs.ProcessorMaxState

        if ($MinStateAC -ge 0) {
            powercfg /setacvalueindex $PlanGUID $subGroup $minSetting $MinStateAC 2>&1 | Out-Null
            Write-Log -Level "SUCCESS" -Category "PowerPlanCustom" -Message "Set processor min state (AC) to $MinStateAC%"
        }
        if ($MaxStateAC -ge 0) {
            powercfg /setacvalueindex $PlanGUID $subGroup $maxSetting $MaxStateAC 2>&1 | Out-Null
            Write-Log -Level "SUCCESS" -Category "PowerPlanCustom" -Message "Set processor max state (AC) to $MaxStateAC%"
        }
        if ($MinStateDC -ge 0) {
            powercfg /setdcvalueindex $PlanGUID $subGroup $minSetting $MinStateDC 2>&1 | Out-Null
            Write-Log -Level "SUCCESS" -Category "PowerPlanCustom" -Message "Set processor min state (DC) to $MinStateDC%"
        }
        if ($MaxStateDC -ge 0) {
            powercfg /setdcvalueindex $PlanGUID $subGroup $maxSetting $MaxStateDC 2>&1 | Out-Null
            Write-Log -Level "SUCCESS" -Category "PowerPlanCustom" -Message "Set processor max state (DC) to $MaxStateDC%"
        }
    } catch {
        Write-Log -Level "ERROR" -Category "PowerPlanCustom" -Message "Error setting processor throttling: $($_.Exception.Message)"
        $result.Success = $false
        $result.Error = $_.Exception.Message
    }

    return $result
}

function global:Set-DiskTimeout {
    <#
    .SYNOPSIS
        Sets disk idle timeout.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$PlanGUID,
        [int]$TimeoutAC = -1,
        [int]$TimeoutDC = -1,
        [switch]$Preview
    )

    $result = @{
        Success = $true
        Error   = $null
    }

    if (-not $script:State.IsElevated) {
        Write-Log -Level "ERROR" -Category "PowerPlanCustom" -Message "Admin privileges required to set disk timeout"
        $result.Success = $false
        $result.Error = "Admin privileges required"
        return $result
    }

    Write-Log -Level "INFO" -Category "PowerPlanCustom" -Message "Setting disk timeout for plan $PlanGUID..."

    if ($Preview) {
        Write-Log -Level "INFO" -Category "PowerPlanCustom" -Message "[Preview] Would set disk timeout AC=$TimeoutAC DC=$TimeoutDC"
        return $result
    }

    try {
        $subGroup = $global:PowerSubGroupGUIDs.Disk
        $settingAC = $global:PowerSettingGUIDs.DiskTimeoutAC
        $settingDC = $global:PowerSettingGUIDs.DiskTimeoutDC

        if ($TimeoutAC -ge 0) {
            powercfg /setacvalueindex $PlanGUID $subGroup $settingAC $TimeoutAC 2>&1 | Out-Null
            Write-Log -Level "SUCCESS" -Category "PowerPlanCustom" -Message "Set disk timeout (AC) to $TimeoutAC seconds"
        }
        if ($TimeoutDC -ge 0) {
            powercfg /setdcvalueindex $PlanGUID $subGroup $settingDC $TimeoutDC 2>&1 | Out-Null
            Write-Log -Level "SUCCESS" -Category "PowerPlanCustom" -Message "Set disk timeout (DC) to $TimeoutDC seconds"
        }
    } catch {
        Write-Log -Level "ERROR" -Category "PowerPlanCustom" -Message "Error setting disk timeout: $($_.Exception.Message)"
        $result.Success = $false
        $result.Error = $_.Exception.Message
    }

    return $result
}

function global:Set-DisplayTimeout {
    <#
    .SYNOPSIS
        Sets display timeout.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$PlanGUID,
        [int]$TimeoutAC = -1,
        [int]$TimeoutDC = -1,
        [switch]$Preview
    )

    $result = @{
        Success = $true
        Error   = $null
    }

    if (-not $script:State.IsElevated) {
        Write-Log -Level "ERROR" -Category "PowerPlanCustom" -Message "Admin privileges required to set display timeout"
        $result.Success = $false
        $result.Error = "Admin privileges required"
        return $result
    }

    Write-Log -Level "INFO" -Category "PowerPlanCustom" -Message "Setting display timeout for plan $PlanGUID..."

    if ($Preview) {
        Write-Log -Level "INFO" -Category "PowerPlanCustom" -Message "[Preview] Would set display timeout AC=$TimeoutAC DC=$TimeoutDC"
        return $result
    }

    try {
        $subGroup = $global:PowerSubGroupGUIDs.Display
        $settingAC = $global:PowerSettingGUIDs.MonitorTimeoutAC
        $settingDC = $global:PowerSettingGUIDs.MonitorTimeoutDC

        if ($TimeoutAC -ge 0) {
            powercfg /setacvalueindex $PlanGUID $subGroup $settingAC $TimeoutAC 2>&1 | Out-Null
            Write-Log -Level "SUCCESS" -Category "PowerPlanCustom" -Message "Set display timeout (AC) to $TimeoutAC seconds"
        }
        if ($TimeoutDC -ge 0) {
            powercfg /setdcvalueindex $PlanGUID $subGroup $settingDC $TimeoutDC 2>&1 | Out-Null
            Write-Log -Level "SUCCESS" -Category "PowerPlanCustom" -Message "Set display timeout (DC) to $TimeoutDC seconds"
        }
    } catch {
        Write-Log -Level "ERROR" -Category "PowerPlanCustom" -Message "Error setting display timeout: $($_.Exception.Message)"
        $result.Success = $false
        $result.Error = $_.Exception.Message
    }

    return $result
}

function global:Set-SleepTimeout {
    <#
    .SYNOPSIS
        Sets sleep/hibernate timeouts.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$PlanGUID,
        [int]$SleepAC = -1,
        [int]$SleepDC = -1,
        [int]$HibernateAC = -1,
        [int]$HibernateDC = -1,
        [switch]$Preview
    )

    $result = @{
        Success = $true
        Error   = $null
    }

    if (-not $script:State.IsElevated) {
        Write-Log -Level "ERROR" -Category "PowerPlanCustom" -Message "Admin privileges required to set sleep timeout"
        $result.Success = $false
        $result.Error = "Admin privileges required"
        return $result
    }

    Write-Log -Level "INFO" -Category "PowerPlanCustom" -Message "Setting sleep/hibernate timeout for plan $PlanGUID..."

    if ($Preview) {
        Write-Log -Level "INFO" -Category "PowerPlanCustom" -Message "[Preview] Would set sleep/hibernate timeouts"
        return $result
    }

    try {
        $subGroup = $global:PowerSubGroupGUIDs.Sleep

        if ($SleepAC -ge 0) {
            powercfg /setacvalueindex $PlanGUID $subGroup $global:PowerSettingGUIDs.SleepTimeoutAC $SleepAC 2>&1 | Out-Null
            Write-Log -Level "SUCCESS" -Category "PowerPlanCustom" -Message "Set sleep timeout (AC) to $SleepAC seconds"
        }
        if ($SleepDC -ge 0) {
            powercfg /setdcvalueindex $PlanGUID $subGroup $global:PowerSettingGUIDs.SleepTimeoutDC $SleepDC 2>&1 | Out-Null
            Write-Log -Level "SUCCESS" -Category "PowerPlanCustom" -Message "Set sleep timeout (DC) to $SleepDC seconds"
        }
        if ($HibernateAC -ge 0) {
            powercfg /setacvalueindex $PlanGUID $subGroup $global:PowerSettingGUIDs.HibernateTimeoutAC $HibernateAC 2>&1 | Out-Null
            Write-Log -Level "SUCCESS" -Category "PowerPlanCustom" -Message "Set hibernate timeout (AC) to $HibernateAC seconds"
        }
        if ($HibernateDC -ge 0) {
            powercfg /setdcvalueindex $PlanGUID $subGroup $global:PowerSettingGUIDs.HibernateTimeoutDC $HibernateDC 2>&1 | Out-Null
            Write-Log -Level "SUCCESS" -Category "PowerPlanCustom" -Message "Set hibernate timeout (DC) to $HibernateDC seconds"
        }
    } catch {
        Write-Log -Level "ERROR" -Category "PowerPlanCustom" -Message "Error setting sleep timeout: $($_.Exception.Message)"
        $result.Success = $false
        $result.Error = $_.Exception.Message
    }

    return $result
}

function global:Set-USBPowerManagement {
    <#
    .SYNOPSIS
        Configures USB suspend settings.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$PlanGUID,
        [ValidateSet("Enable", "Disable")]
        [string]$SuspendAC = "",
        [ValidateSet("Enable", "Disable")]
        [string]$SuspendDC = "",
        [switch]$Preview
    )

    $result = @{
        Success = $true
        Error   = $null
    }

    if (-not $script:State.IsElevated) {
        Write-Log -Level "ERROR" -Category "PowerPlanCustom" -Message "Admin privileges required to set USB power"
        $result.Success = $false
        $result.Error = "Admin privileges required"
        return $result
    }

    Write-Log -Level "INFO" -Category "PowerPlanCustom" -Message "Setting USB power management for plan $PlanGUID..."

    if ($Preview) {
        Write-Log -Level "INFO" -Category "PowerPlanCustom" -Message "[Preview] Would set USB suspend AC=$SuspendAC DC=$SuspendDC"
        return $result
    }

    try {
        $subGroup = $global:PowerSubGroupGUIDs.USB

        if ($SuspendAC -eq "Enable") {
            powercfg /setacvalueindex $PlanGUID $subGroup $global:PowerSettingGUIDs.USBSuspendAC 0 2>&1 | Out-Null
            Write-Log -Level "SUCCESS" -Category "PowerPlanCustom" -Message "USB suspend (AC) enabled"
        } elseif ($SuspendAC -eq "Disable") {
            powercfg /setacvalueindex $PlanGUID $subGroup $global:PowerSettingGUIDs.USBSuspendAC 1 2>&1 | Out-Null
            Write-Log -Level "SUCCESS" -Category "PowerPlanCustom" -Message "USB suspend (AC) disabled"
        }

        if ($SuspendDC -eq "Enable") {
            powercfg /setdcvalueindex $PlanGUID $subGroup $global:PowerSettingGUIDs.USBSuspendDC 0 2>&1 | Out-Null
            Write-Log -Level "SUCCESS" -Category "PowerPlanCustom" -Message "USB suspend (DC) enabled"
        } elseif ($SuspendDC -eq "Disable") {
            powercfg /setdcvalueindex $PlanGUID $subGroup $global:PowerSettingGUIDs.USBSuspendDC 1 2>&1 | Out-Null
            Write-Log -Level "SUCCESS" -Category "PowerPlanCustom" -Message "USB suspend (DC) disabled"
        }
    } catch {
        Write-Log -Level "ERROR" -Category "PowerPlanCustom" -Message "Error setting USB power: $($_.Exception.Message)"
        $result.Success = $false
        $result.Error = $_.Exception.Message
    }

    return $result
}

function global:Set-PCIExpressPower {
    <#
    .SYNOPSIS
        Configures PCI Express link state power management.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$PlanGUID,
        [ValidateSet("Off", "Moderate", "Maximum")]
        [string]$LinkStateAC = "",
        [ValidateSet("Off", "Moderate", "Maximum")]
        [string]$LinkStateDC = "",
        [switch]$Preview
    )

    $result = @{
        Success = $true
        Error   = $null
    }

    if (-not $script:State.IsElevated) {
        Write-Log -Level "ERROR" -Category "PowerPlanCustom" -Message "Admin privileges required to set PCIe power"
        $result.Success = $false
        $result.Error = "Admin privileges required"
        return $result
    }

    Write-Log -Level "INFO" -Category "PowerPlanCustom" -Message "Setting PCI Express power for plan $PlanGUID..."

    $linkStateValues = @{
        "Off"      = 0
        "Moderate" = 1
        "Maximum"  = 2
    }

    if ($Preview) {
        Write-Log -Level "INFO" -Category "PowerPlanCustom" -Message "[Preview] Would set PCIe link state AC=$LinkStateAC DC=$LinkStateDC"
        return $result
    }

    try {
        $subGroup = $global:PowerSubGroupGUIDs.PCIExpress

        if ($linkStateValues.ContainsKey($LinkStateAC)) {
            powercfg /setacvalueindex $PlanGUID $subGroup $global:PowerSettingGUIDs.PCILinkStateAC $linkStateValues[$LinkStateAC] 2>&1 | Out-Null
            Write-Log -Level "SUCCESS" -Category "PowerPlanCustom" -Message "PCIe link state (AC) set to $LinkStateAC"
        }
        if ($linkStateValues.ContainsKey($LinkStateDC)) {
            powercfg /setdcvalueindex $PlanGUID $subGroup $global:PowerSettingGUIDs.PCILinkStateDC $linkStateValues[$LinkStateDC] 2>&1 | Out-Null
            Write-Log -Level "SUCCESS" -Category "PowerPlanCustom" -Message "PCIe link state (DC) set to $LinkStateDC"
        }
    } catch {
        Write-Log -Level "ERROR" -Category "PowerPlanCustom" -Message "Error setting PCIe power: $($_.Exception.Message)"
        $result.Success = $false
        $result.Error = $_.Exception.Message
    }

    return $result
}

function global:Set-WirelessAdapterPower {
    <#
    .SYNOPSIS
        Configures wireless adapter power saving.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$PlanGUID,
        [ValidateSet("MaximumPerformance", "LowPowerSaving", "MediumPowerSaving", "MaximumPowerSaving")]
        [string]$PowerMode = "",
        [switch]$Preview
    )

    $result = @{
        Success = $true
        Error   = $null
    }

    if (-not $script:State.IsElevated) {
        Write-Log -Level "ERROR" -Category "PowerPlanCustom" -Message "Admin privileges required to set wireless power"
        $result.Success = $false
        $result.Error = "Admin privileges required"
        return $result
    }

    Write-Log -Level "INFO" -Category "PowerPlanCustom" -Message "Setting wireless adapter power for plan $PlanGUID..."

    $modeValues = @{
        "MaximumPerformance"  = 0
        "LowPowerSaving"      = 1
        "MediumPowerSaving"   = 2
        "MaximumPowerSaving"  = 3
    }

    if ($Preview) {
        Write-Log -Level "INFO" -Category "PowerPlanCustom" -Message "[Preview] Would set wireless adapter power to $PowerMode"
        return $result
    }

    try {
        $subGroup = $global:PowerSubGroupGUIDs.WirelessAdapter

        if ($modeValues.ContainsKey($PowerMode)) {
            powercfg /setacvalueindex $PlanGUID $subGroup $global:PowerSettingGUIDs.WirelessAdapterPower $modeValues[$PowerMode] 2>&1 | Out-Null
            powercfg /setdcvalueindex $PlanGUID $subGroup $global:PowerSettingGUIDs.WirelessAdapterPower $modeValues[$PowerMode] 2>&1 | Out-Null
            Write-Log -Level "SUCCESS" -Category "PowerPlanCustom" -Message "Wireless adapter power set to $PowerMode"
        }
    } catch {
        Write-Log -Level "ERROR" -Category "PowerPlanCustom" -Message "Error setting wireless power: $($_.Exception.Message)"
        $result.Success = $false
        $result.Error = $_.Exception.Message
    }

    return $result
}

function global:Export-PowerPlanSettings {
    <#
    .SYNOPSIS
        Exports power plan settings to a file.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$PlanGUID,
        [string]$OutputPath = "$env:TEMP\PowerPlan_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    )

    $result = @{
        Success    = $true
        OutputPath = $OutputPath
        Error      = $null
    }

    Write-Log -Level "INFO" -Category "PowerPlanCustom" -Message "Exporting power plan settings for $PlanGUID..."

    try {
        $output = powercfg /query $PlanGUID 2>&1
        $output | Out-File -FilePath $OutputPath -Encoding UTF8 -Force
        Write-Log -Level "SUCCESS" -Category "PowerPlanCustom" -Message "Power plan exported to: $OutputPath"
    } catch {
        Write-Log -Level "ERROR" -Category "PowerPlanCustom" -Message "Error exporting power plan: $($_.Exception.Message)"
        $result.Success = $false
        $result.Error = $_.Exception.Message
    }

    return $result
}

function global:Import-PowerPlanSettings {
    <#
    .SYNOPSIS
        Imports power plan settings from a file.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ImportPath,
        [switch]$Preview
    )

    $result = @{
        Success = $true
        Error   = $null
    }

    if (-not $script:State.IsElevated) {
        Write-Log -Level "ERROR" -Category "PowerPlanCustom" -Message "Admin privileges required to import power plan"
        $result.Success = $false
        $result.Error = "Admin privileges required"
        return $result
    }

    if (-not (Test-Path $ImportPath)) {
        Write-Log -Level "ERROR" -Category "PowerPlanCustom" -Message "Import file not found: $ImportPath"
        $result.Success = $false
        $result.Error = "Import file not found"
        return $result
    }

    Write-Log -Level "INFO" -Category "PowerPlanCustom" -Message "Importing power plan settings from $ImportPath..."

    if ($Preview) {
        Write-Log -Level "INFO" -Category "PowerPlanCustom" -Message "[Preview] Would import power plan from $ImportPath"
        return $result
    }

    try {
        $output = powercfg /import $ImportPath 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log -Level "SUCCESS" -Category "PowerPlanCustom" -Message "Power plan imported successfully"
        } else {
            $result.Success = $false
            $result.Error = "Import failed: $output"
            Write-Log -Level "ERROR" -Category "PowerPlanCustom" -Message "Power plan import failed: $output"
        }
    } catch {
        Write-Log -Level "ERROR" -Category "PowerPlanCustom" -Message "Error importing power plan: $($_.Exception.Message)"
        $result.Success = $false
        $result.Error = $_.Exception.Message
    }

    return $result
}

function global:Compare-PowerPlans {
    <#
    .SYNOPSIS
        Compares two power plans' settings.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$PlanGUID1,
        [Parameter(Mandatory = $true)]
        [string]$PlanGUID2
    )

    $result = @{
        Success = $true
        Plan1   = ""
        Plan2   = ""
        Differences = @()
        Error   = $null
    }

    Write-Log -Level "INFO" -Category "PowerPlanCustom" -Message "Comparing power plans $PlanGUID1 vs $PlanGUID2..."

    try {
        $query1 = powercfg /query $PlanGUID1 2>&1
        $query2 = powercfg /query $PlanGUID2 2>&1

        $plans = powercfg /list 2>&1
        if ($plans -match "$PlanGUID1.*\(([^\)]+)\)") {
            $result.Plan1 = $Matches[1]
        }
        if ($plans -match "$PlanGUID2.*\(([^\)]+)\)") {
            $result.Plan2 = $Matches[1]
        }

        $lines1 = $query1 -split "`n"
        $lines2 = $query2 -split "`n"

        $maxLines = [Math]::Max($lines1.Count, $lines2.Count)

        for ($i = 0; $i -lt $maxLines; $i++) {
            $line1 = if ($i -lt $lines1.Count) { $lines1[$i].Trim() } else { "" }
            $line2 = if ($i -lt $lines2.Count) { $lines2[$i].Trim() } else { "" }

            if ($line1 -ne $line2 -and -not [string]::IsNullOrEmpty($line1) -and -not [string]::IsNullOrEmpty($line2)) {
                $result.Differences += [PSCustomObject]@{
                    Line  = $i + 1
                    Plan1 = $line1
                    Plan2 = $line2
                }
            }
        }

        Write-Log -Level "INFO" -Category "PowerPlanCustom" -Message "Found $($result.Differences.Count) differences between plans"
    } catch {
        Write-Log -Level "ERROR" -Category "PowerPlanCustom" -Message "Error comparing power plans: $($_.Exception.Message)"
        $result.Success = $false
        $result.Error = $_.Exception.Message
    }

    return $result
}

function global:Get-PowerPlanOptimizationReport {
    <#
    .SYNOPSIS
        Generates power plan optimization recommendations.
    #>

    $result = @{
        Success         = $true
        CurrentPlan     = ""
        Recommendations = @()
        Error           = $null
    }

    Write-Log -Level "INFO" -Category "PowerPlanCustom" -Message "Generating power plan optimization report..."

    try {
        $plans = powercfg /list 2>&1
        if ($plans -match "Power Scheme GUID: ([a-f0-9-]+)  \(([^\)]+)\)\s+\*") {
            $result.CurrentPlan = $Matches[2]
            Write-Log -Level "INFO" -Category "PowerPlanCustom" -Message "Current plan: $($result.CurrentPlan)"
        }

        $query = powercfg /queryactivescheme 2>&1
        $queryText = $query -join "`n"

        if ($queryText -match "Processor.*?0x([a-f0-9]+).*?0x([a-f0-9]+)") {
            $minState = [Convert]::ToInt32($Matches[1], 16)
            $maxState = [Convert]::ToInt32($Matches[2], 16)

            if ($maxState -lt 100) {
                $result.Recommendations += [PSCustomObject]@{
                    Category = "Processor"
                    Issue    = "CPU max state is $maxState%"
                    Action   = "Set processor max state to 100% for maximum performance"
                    Priority = "High"
                }
            }
            if ($minState -gt 5) {
                $result.Recommendations += [PSCustomObject]@{
                    Category = "Processor"
                    Issue    = "CPU min state is $minState%"
                    Action   = "Consider lowering min state to 5% for better power savings on idle"
                    Priority = "Medium"
                }
            }
        }

        $sleepOutput = powercfg /query $global:PowerPlanGUIDs.Balanced $global:PowerSubGroupGUIDs.Sleep $global:PowerSettingGUIDs.SleepTimeoutAC 2>&1
        if ($sleepOutput -match "0x0") {
            $result.Recommendations += [PSCustomObject]@{
                Category = "Sleep"
                Issue    = "Sleep is disabled on AC power"
                Action   = "Enable sleep timeout to save power when idle"
                Priority = "Low"
            }
        }

        $usbOutput = powercfg /query $global:PowerPlanGUIDs.Balanced $global:PowerSubGroupGUIDs.USB $global:PowerSettingGUIDs.USBSuspendAC 2>&1
        if ($usbOutput -match "0x1") {
            $result.Recommendations += [PSCustomObject]@{
                Category = "USB"
                Issue    = "USB selective suspend is disabled"
                Action   = "Enable USB suspend for better battery life on laptops"
                Priority = "Medium"
            }
        }

        Write-Log -Level "INFO" -Category "PowerPlanCustom" -Message "Generated $($result.Recommendations.Count) optimization recommendations"
    } catch {
        Write-Log -Level "ERROR" -Category "PowerPlanCustom" -Message "Error generating report: $($_.Exception.Message)"
        $result.Success = $false
        $result.Error = $_.Exception.Message
    }

    return $result
}
