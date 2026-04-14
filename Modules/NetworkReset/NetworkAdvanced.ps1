#Requires -Version 5.1
<#
.SYNOPSIS
    Network Advanced Optimization Module
.DESCRIPTION
    Advanced network optimization functions including firewall rules,
    QoS settings, and network profile configuration.
#>

function global:Optimize-NetworkAdvanced {
    <#
    .SYNOPSIS
        Applies advanced network optimizations.
    #>
    param(
        [switch]$Preview,
        [switch]$OptimizeQoS,
        [switch]$OptimizeFirewall
    )

    $result = @{
        Success = $true
        Message = ""
        Changes = @()
        Errors = @()
    }

    if ($Preview) {
        $result.Message = "[PREVIEW] Would apply advanced network optimizations"
        $result.Changes = @("Optimize QoS settings", "Optimize firewall rules")
        return $result
    }

    Write-Log -Level "INFO" -Category "NetworkAdvanced" -Message "Starting advanced network optimization..."

    if ($OptimizeQoS) {
        $qosResult = Optimize-QoS
        if ($qosResult.Success) {
            $result.Changes += "QoS optimized"
        } else {
            $result.Errors += "QoS: $($qosResult.Message)"
        }
    }

    if ($OptimizeFirewall) {
        $fwResult = Optimize-FirewallAdvanced
        if ($fwResult.Success) {
            $result.Changes += "Firewall optimized"
        } else {
            $result.Errors += "Firewall: $($fwResult.Message)"
        }
    }

    $result.Message = "Advanced network optimization complete: $($result.Changes.Count) changes"
    if ($result.Errors.Count -gt 0) {
        Write-Log -Level "WARNING" -Category "NetworkAdvanced" -Message $result.Message
    } else {
        Write-Log -Level "SUCCESS" -Category "NetworkAdvanced" -Message $result.Message
    }

    return $result
}

function global:Reset-FirewallRules {
    <#
    .SYNOPSIS
        Resets Windows Firewall rules to default.
    #>
    $result = @{
        Success = $false
        Message = ""
        RulesRemoved = 0
    }

    try {
        $rulesBefore = @(Get-NetFirewallRule -ErrorAction SilentlyContinue).Count
        netsh advfirewall reset 2>$null
        $rulesAfter = @(Get-NetFirewallRule -ErrorAction SilentlyContinue).Count
        $result.RulesRemoved = $rulesBefore - $rulesAfter

        $result.Success = $true
        $result.Message = "Firewall rules reset to default. $($result.RulesRemoved) custom rules removed."
        Write-Log -Level "SUCCESS" -Category "NetworkAdvanced" -Message $result.Message
    } catch {
        $result.Message = "Error resetting firewall rules: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "NetworkAdvanced" -Message $result.Message
    }

    return $result
}

function global:Optimize-QoS {
    <#
    .SYNOPSIS
        Optimizes Quality of Service settings for better network performance.
    #>
    $result = @{
        Success = $false
        Message = ""
        Changes = @()
    }

    try {
        $qosPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched"
        if (-not (Test-Path $qosPath)) {
            New-Item -Path $qosPath -Force | Out-Null
        }
        Set-ItemProperty -Path $qosPath -Name "NonBestEffortLimit" -Value 0 -Force -ErrorAction SilentlyContinue
        $result.Changes += "Disabled QoS non-best-effort bandwidth limit"

        $multimediaPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        Set-ItemProperty -Path $multimediaPath -Name "NetworkThrottlingIndex" -Value 0xFFFFFFFF -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $multimediaPath -Name "SystemResponsiveness" -Value 0 -Force -ErrorAction SilentlyContinue
        $result.Changes += "Disabled network throttling"

        $result.Success = $true
        $result.Message = "QoS optimized: $($result.Changes.Count) changes"
        Write-Log -Level "SUCCESS" -Category "NetworkAdvanced" -Message $result.Message
    } catch {
        $result.Message = "Error optimizing QoS: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "NetworkAdvanced" -Message $result.Message
    }

    return $result
}

function global:Get-NetworkAdvancedStatus {
    <#
    .SYNOPSIS
        Gets current advanced network configuration status.
    #>
    $status = @{
        QoSNonBestEffortLimit = "Unknown"
        NetworkThrottling = "Unknown"
        SystemResponsiveness = "Unknown"
        FirewallProfiles = @()
    }

    try {
        $qosPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched"
        $qos = Get-ItemProperty -Path $qosPath -Name "NonBestEffortLimit" -ErrorAction SilentlyContinue
        if ($qos) {
            $status.QoSNonBestEffortLimit = $qos.NonBestEffortLimit
        } else {
            $status.QoSNonBestEffortLimit = "Default"
        }
    } catch {
        Write-Log -Level "WARNING" -Category "NetworkAdvanced" -Message "Error reading QoS settings: $($_.Exception.Message)"
    }

    try {
        $multimediaPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        $multi = Get-ItemProperty -Path $multimediaPath -ErrorAction SilentlyContinue
        if ($multi) {
            $status.NetworkThrottling = if ($multi.NetworkThrottlingIndex -eq 0xFFFFFFFF) { "Disabled" } else { "Enabled" }
            $status.SystemResponsiveness = $multi.SystemResponsiveness
        }
    } catch {
        Write-Log -Level "WARNING" -Category "NetworkAdvanced" -Message "Error reading multimedia settings: $($_.Exception.Message)"
    }

    try {
        $profiles = Get-NetFirewallProfile -ErrorAction SilentlyContinue
        foreach ($profile in $profiles) {
            $status.FirewallProfiles += @{
                Name = $profile.Name
                Enabled = $profile.Enabled
                DefaultInboundAction = $profile.DefaultInboundAction
                DefaultOutboundAction = $profile.DefaultOutboundAction
            }
        }
    } catch {
        Write-Log -Level "WARNING" -Category "NetworkAdvanced" -Message "Error reading firewall profiles: $($_.Exception.Message)"
    }

    return $status
}

function global:Optimize-FirewallAdvanced {
    <#
    .SYNOPSIS
        Applies advanced firewall optimizations.
    #>
    $result = @{
        Success = $false
        Message = ""
        Changes = @()
    }

    try {
        Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True -ErrorAction SilentlyContinue
        $result.Changes += "Enabled firewall for all profiles"

        Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultInboundAction Block -DefaultOutboundAction Allow -ErrorAction SilentlyContinue
        $result.Changes += "Set default firewall actions"

        Set-NetFirewallProfile -Profile Domain,Public,Private -LogBlocked True -LogMaxSizeKilobytes 4096 -ErrorAction SilentlyContinue
        $result.Changes += "Enabled firewall logging"

        $result.Success = $true
        $result.Message = "Firewall advanced settings applied: $($result.Changes.Count) changes"
        Write-Log -Level "SUCCESS" -Category "NetworkAdvanced" -Message $result.Message
    } catch {
        $result.Message = "Error applying firewall settings: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "NetworkAdvanced" -Message $result.Message
    }

    return $result
}
