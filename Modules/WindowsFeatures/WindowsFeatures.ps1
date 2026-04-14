<#
.SYNOPSIS
    WinTunePro WindowsFeatures Module - Windows optional features management
.DESCRIPTION
    Manages Windows optional features including listing, enabling, disabling,
    and applying feature profiles for different use cases.
.NOTES
    File: Modules\WindowsFeatures\WindowsFeatures.ps1
    Version: 1.0.0
    PowerShell: 5.1+
    Compatible: Windows 10, Windows 11
#>

#Requires -Version 5.1

$script:RecommendedFeatures = @(
    "NetFx3"
    "Microsoft-Windows-Subsystem-Linux"
    "VirtualMachinePlatform"
    "MediaPlayback"
    "WindowsMediaPlayer"
    "Printing-PrintToPDFServices-Features"
    "SearchEngine-Client-Package"
    "WorkFolders-Client"
    "MicrosoftWindowsPowerShellV2Root"
    "MicrosoftWindowsPowerShellV2"
)

$script:UnneededFeatures = @(
    "Internet-Explorer-Optional-amd64"
    "Internet-Explorer-Optional-x86"
    "Media.WindowsMedia"
    "WindowsMediaPlayer"
    "Printing-Foundation-Features"
    "Printing-Foundation-InternetPrinting-Client"
    "FaxServicesClientPackage"
    "Xps-Foundation-Xps-Viewer"
    "Windows-Defender-Default-Definitions"
    "SMB1Protocol"
    "SMB1Protocol-Client"
    "SMB1Protocol-Server"
    "SMB1Protocol-Deprecation"
    "WCF-Services45"
    "WCF-HTTP-Activation45"
    "WCF-TCP-PortSharing45"
)

$script:FeatureProfiles = @{
    Minimal = @(
        { Disable-WindowsOptionalFeature -FeatureName "SMB1Protocol" -Online -NoRestart }
        { Disable-WindowsOptionalFeature -FeatureName "Internet-Explorer-Optional-amd64" -Online -NoRestart }
        { Disable-WindowsOptionalFeature -FeatureName "Media.WindowsMedia" -Online -NoRestart }
        { Disable-WindowsOptionalFeature -FeatureName "Xps-Foundation-Xps-Viewer" -Online -NoRestart }
        { Disable-WindowsOptionalFeature -FeatureName "Printing-Foundation-InternetPrinting-Client" -Online -NoRestart }
    )
    Standard = @(
        { Enable-WindowsOptionalFeature -FeatureName "NetFx3" -Online -NoRestart }
        { Enable-WindowsOptionalFeature -FeatureName "MicrosoftWindowsPowerShellV2" -Online -NoRestart }
        { Enable-WindowsOptionalFeature -FeatureName "Printing-PrintToPDFServices-Features" -Online -NoRestart }
        { Disable-WindowsOptionalFeature -FeatureName "SMB1Protocol" -Online -NoRestart }
        { Disable-WindowsOptionalFeature -FeatureName "Internet-Explorer-Optional-amd64" -Online -NoRestart }
    )
    Full = @(
        { Enable-WindowsOptionalFeature -FeatureName "NetFx3" -Online -NoRestart }
        { Enable-WindowsOptionalFeature -FeatureName "MicrosoftWindowsPowerShellV2" -Online -NoRestart }
        { Enable-WindowsOptionalFeature -FeatureName "Printing-PrintToPDFServices-Features" -Online -NoRestart }
        { Enable-WindowsOptionalFeature -FeatureName "MediaPlayback" -Online -NoRestart }
        { Enable-WindowsOptionalFeature -FeatureName "WorkFolders-Client" -Online -NoRestart }
        { Enable-WindowsOptionalFeature -FeatureName "SearchEngine-Client-Package" -Online -NoRestart }
    )
}

function global:Get-WindowsFeatures {
    <#
    .SYNOPSIS
        List all optional features with state.
    #>
    param(
        [Parameter()]
        [string]$Filter = ""
    )

    $result = @{
        Success  = $true
        Details  = @()
        Errors   = @()
    }

    Write-Log -Level "INFO" -Category "Optimization" -Message "Gathering Windows optional features..."

    try {
        $features = Get-WindowsOptionalFeature -Online -ErrorAction Stop

        foreach ($feature in $features) {
            if ($Filter -and $feature.FeatureName -notlike "*$Filter*") { continue }

            $state = switch ($feature.State) {
                "Enabled" { "Enabled" }
                "Disabled" { "Disabled" }
                "EnabledWithPayloadRemoved" { "Enabled (Payload Removed)" }
                default { $feature.State.ToString() }
            }

            $result.Details += @{
                FeatureName = $feature.FeatureName
                State       = $state
                DisplayName = $feature.DisplayName
                Description = $feature.Description
            }
        }

        Write-Log -Level "INFO" -Category "Optimization" -Message "Found $($result.Details.Count) optional features"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "Optimization" -Message "Failed to get features: $($_.Exception.Message)"
    }

    return $result
}

function global:Enable-FeatureByName {
    <#
    .SYNOPSIS
        Enable a specific feature.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$FeatureName,

        [Parameter()]
        [switch]$IncludeAllSubFeatures
    )

    $result = @{
        Success  = $true
        Details  = @{
            FeatureName = $FeatureName
            PreviousState = ""
            NewState    = ""
        }
        Errors   = @()
    }

    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Errors += "Administrator privileges required"
        return $result
    }

    Write-Log -Level "INFO" -Category "Optimization" -Message "Enabling feature: $FeatureName"

    try {
        $current = Get-WindowsOptionalFeature -FeatureName $FeatureName -Online -ErrorAction Stop
        $result.Details.PreviousState = $current.State.ToString()

        if ($current.State -eq "Enabled") {
            Write-Log -Level "INFO" -Category "Optimization" -Message "Feature $FeatureName is already enabled"
            $result.Details.NewState = "Enabled"
            return $result
        }

        $params = @{
            FeatureName = $FeatureName
            Online      = $true
            NoRestart   = $true
            ErrorAction = "Stop"
        }
        if ($IncludeAllSubFeatures) {
            $params.All = $true
        }

        $enableResult = Enable-WindowsOptionalFeature @params
        $result.Details.NewState = "Enabled"

        Write-Log -Level "SUCCESS" -Category "Optimization" -Message "Feature $FeatureName enabled successfully"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "Optimization" -Message "Failed to enable $FeatureName : $($_.Exception.Message)"
    }

    return $result
}

function global:Disable-FeatureByName {
    <#
    .SYNOPSIS
        Disable a specific feature.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$FeatureName,

        [Parameter()]
        [switch]$RemovePayload
    )

    $result = @{
        Success  = $true
        Details  = @{
            FeatureName = $FeatureName
            PreviousState = ""
            NewState    = ""
        }
        Errors   = @()
    }

    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Errors += "Administrator privileges required"
        return $result
    }

    Write-Log -Level "INFO" -Category "Optimization" -Message "Disabling feature: $FeatureName"

    try {
        $current = Get-WindowsOptionalFeature -FeatureName $FeatureName -Online -ErrorAction Stop
        $result.Details.PreviousState = $current.State.ToString()

        if ($current.State -eq "Disabled") {
            Write-Log -Level "INFO" -Category "Optimization" -Message "Feature $FeatureName is already disabled"
            $result.Details.NewState = "Disabled"
            return $result
        }

        $params = @{
            FeatureName = $FeatureName
            Online      = $true
            NoRestart   = $true
            ErrorAction = "Stop"
        }
        if ($RemovePayload) {
            $params.Remove = $true
        }

        Disable-WindowsOptionalFeature @params
        $result.Details.NewState = "Disabled"

        Write-Log -Level "SUCCESS" -Category "Optimization" -Message "Feature $FeatureName disabled successfully"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "Optimization" -Message "Failed to disable $FeatureName : $($_.Exception.Message)"
    }

    return $result
}

function global:Get-RecommendedFeatures {
    <#
    .SYNOPSIS
        List recommended features to enable.
    #>
    $result = @{
        Success  = $true
        Details  = @()
        Errors   = @()
    }

    Write-Log -Level "INFO" -Category "Optimization" -Message "Checking recommended features..."

    try {
        foreach ($featureName in $script:RecommendedFeatures) {
            try {
                $feature = Get-WindowsOptionalFeature -FeatureName $featureName -Online -ErrorAction Stop
                $result.Details += @{
                    FeatureName = $feature.FeatureName
                    State       = $feature.State.ToString()
                    DisplayName = $feature.DisplayName
                    Recommended = $true
                    Action      = if ($feature.State -eq "Enabled") { "Already Enabled" } else { "Enable Recommended" }
                }
            } catch {
                $result.Errors += "Could not check feature $featureName : $($_.Exception.Message)"
            }
        }

        Write-Log -Level "INFO" -Category "Optimization" -Message "Checked $($result.Details.Count) recommended features"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "Optimization" -Message "Failed to check recommended features: $($_.Exception.Message)"
    }

    return $result
}

function global:Get-UnneededFeatures {
    <#
    .SYNOPSIS
        List features that can be safely disabled.
    #>
    $result = @{
        Success  = $true
        Details  = @()
        Errors   = @()
    }

    Write-Log -Level "INFO" -Category "Optimization" -Message "Checking for unneeded features..."

    try {
        foreach ($featureName in $script:UnneededFeatures) {
            try {
                $feature = Get-WindowsOptionalFeature -FeatureName $featureName -Online -ErrorAction Stop
                $result.Details += @{
                    FeatureName = $feature.FeatureName
                    State       = $feature.State.ToString()
                    DisplayName = $feature.DisplayName
                    CanDisable  = $true
                    Action      = if ($feature.State -eq "Disabled") { "Already Disabled" } else { "Safe to Disable" }
                }
            } catch {
                $result.Errors += "Could not check feature $featureName : $($_.Exception.Message)"
            }
        }

        Write-Log -Level "INFO" -Category "Optimization" -Message "Checked $($result.Details.Count) unneeded features"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "Optimization" -Message "Failed to check unneeded features: $($_.Exception.Message)"
    }

    return $result
}

function global:Apply-FeatureProfile {
    <#
    .SYNOPSIS
        Apply a feature set (minimal/standard/full).
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Minimal", "Standard", "Full")]
        [string]$Profile,

        [Parameter()]
        [switch]$WhatIf
    )

    $result = @{
        Success  = $true
        Details  = @{
            Profile      = $Profile
            Actions      = @()
            RebootNeeded = $false
        }
        Errors   = @()
    }

    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Errors += "Administrator privileges required"
        return $result
    }

    Write-Log -Level "INFO" -Category "Optimization" -Message "Applying feature profile: $Profile"

    try {
        $actions = $script:FeatureProfiles[$Profile]
        if (-not $actions) {
            $result.Success = $false
            $result.Errors += "Unknown profile: $Profile"
            return $result
        }

        foreach ($action in $actions) {
            if ($WhatIf) {
                $result.Details.Actions += "Preview: Would apply action"
                continue
            }

            try {
                $actionResult = & $action
                if ($actionResult.RestartNeeded) {
                    $result.Details.RebootNeeded = $true
                }
                $result.Details.Actions += "Applied action successfully"
                Write-Log -Level "INFO" -Category "Optimization" -Message "Applied feature action"
            } catch {
                $result.Errors += "Action failed: $($_.Exception.Message)"
                Write-Log -Level "WARNING" -Category "Optimization" -Message "Feature action failed: $($_.Exception.Message)"
            }
        }

        if ($result.Details.RebootNeeded) {
            Write-Log -Level "WARNING" -Category "Optimization" -Message "Reboot required to complete feature changes"
        }

        Write-Log -Level "SUCCESS" -Category "Optimization" -Message "Feature profile '$Profile' applied"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "Optimization" -Message "Failed to apply feature profile: $($_.Exception.Message)"
    }

    return $result
}
