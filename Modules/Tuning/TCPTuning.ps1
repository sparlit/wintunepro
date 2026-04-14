<#
.SYNOPSIS
    WinTune Pro TCPTuning Module - TCP/IP advanced tuning
.DESCRIPTION
    TCP parameter optimization for improved network performance
.NOTES
    File: Modules\NetworkTune\TCPTuning.ps1
    Version: 1.0.1
    PowerShell: 5.1+
    Compatible: Windows 10, Windows 11
#>

# ============================================================================
# TCP TUNING PRESETS
# ============================================================================

$script:TCPTuningPresets = @{
    "Default" = @{
        Description = "Windows default settings"
        AutoTuningLevel = "normal"
        RSS = "enabled"
        RSC = "enabled"
        SACK = "enabled"
        ECN = "disabled"
        Timestamps = "disabled"
    }
    "Optimized" = @{
        Description = "General optimization for most scenarios"
        AutoTuningLevel = "normal"
        RSS = "enabled"
        RSC = "enabled"
        SACK = "enabled"
        ECN = "enabled"
        Timestamps = "disabled"
    }
    "HighPerformance" = @{
        Description = "Maximum throughput for high-speed connections"
        AutoTuningLevel = "experimental"
        RSS = "enabled"
        RSC = "enabled"
        SACK = "enabled"
        ECN = "enabled"
        Timestamps = "enabled"
    }
    "LowLatency" = @{
        Description = "Optimized for gaming/real-time applications"
        AutoTuningLevel = "normal"
        RSS = "enabled"
        RSC = "disabled"
        SACK = "enabled"
        ECN = "disabled"
        Timestamps = "disabled"
    }
    "Compatibility" = @{
        Description = "For networks with legacy equipment"
        AutoTuningLevel = "restricted"
        RSS = "disabled"
        RSC = "disabled"
        SACK = "enabled"
        ECN = "disabled"
        Timestamps = "disabled"
    }
}

# ============================================================================
# TCP CONFIGURATION QUERY
# ============================================================================

function global:Get-TCPConfiguration {
    <#
    .SYNOPSIS
        Gets current TCP/IP configuration.
    #>
    
    $config = @{
        GlobalSettings = @{}
        InterfaceSettings = @{}
        Recommendations = @()
    }
    
    Write-Log -Level "DEBUG" -Category "NetworkTune" -Message "Retrieving TCP configuration..."
    
    try {
        # Get global TCP settings using netsh
        $globalOutput = netsh int tcp show global 2>&1
        
        # Parse global settings
        if ($globalOutput -match 'Receive-Side Scaling State\s+:\s+(\w+)') {
            $config.GlobalSettings.RSS = $Matches[1]
        }
        if ($globalOutput -match 'Receive Window Auto-Tuning Level\s+:\s+(\w+)') {
            $config.GlobalSettings.AutoTuningLevel = $Matches[1]
        }
        if ($globalOutput -match 'Add-On Congestion Control Provider\s+:\s+(\w+)') {
            $config.GlobalSettings.CongestionProvider = $Matches[1]
        }
        if ($globalOutput -match 'ECN Capability\s+:\s+(\w+)') {
            $config.GlobalSettings.ECN = $Matches[1]
        }
        if ($globalOutput -match 'RFC 1323 Timestamps\s+:\s+(\w+)') {
            $config.GlobalSettings.Timestamps = $Matches[1]
        }
        if ($globalOutput -match 'Initial RTO\s+:\s+(\d+)') {
            $config.GlobalSettings.InitialRTO = [int]$Matches[1]
        }
        if ($globalOutput -match 'Receive Segment Coalescing State\s+:\s+(\w+)') {
            $config.GlobalSettings.RSC = $Matches[1]
        }
        if ($globalOutput -match 'Non Sack RTT Resiliency\s+:\s+(\w+)') {
            $config.GlobalSettings.NonSackRTTResiliency = $Matches[1]
        }
        if ($globalOutput -match 'Max Syn Retransmissions\s+:\s+(\d+)') {
            $config.GlobalSettings.MaxSynRetransmissions = [int]$Matches[1]
        }
        
        # Get supplemental TCP settings
        $suppOutput = netsh int tcp show supplemental 2>&1
        
        if ($suppOutput -match 'Template\s+:\s+(\w+)') {
            $config.GlobalSettings.Template = $Matches[1]
        }
        if ($suppOutput -match 'Congestion Provider\s+:\s+(\w+)') {
            $config.GlobalSettings.SupplementalCongestionProvider = $Matches[1]
        }
        
        # Get per-interface settings
        $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' }
        
        foreach ($adapter in $adapters) {
            $interfaceConfig = @{
                Name = $adapter.Name
                InterfaceDescription = $adapter.InterfaceDescription
                LinkSpeed = $adapter.LinkSpeed
            }
            
            # Get advanced properties
            $advanced = Get-NetAdapterAdvancedProperty -Name $adapter.Name -ErrorAction SilentlyContinue
            
            if ($advanced) {
                $rss = $advanced | Where-Object { $_.DisplayName -like '*Receive Side Scaling*' }
                if ($rss) { $interfaceConfig.RSS = $rss.DisplayValue }
                
                $rsc = $advanced | Where-Object { $_.DisplayName -like '*Receive Segment Coalescing*' }
                if ($rsc) { $interfaceConfig.RSC = $rsc.DisplayValue }
                
                $jumbo = $advanced | Where-Object { $_.DisplayName -like '*Jumbo*' }
                if ($jumbo) { $interfaceConfig.JumboPacket = $jumbo.DisplayValue }
                
                $flowControl = $advanced | Where-Object { $_.DisplayName -like '*Flow Control*' }
                if ($flowControl) { $interfaceConfig.FlowControl = $flowControl.DisplayValue }
            }
            
            $config.InterfaceSettings[$adapter.Name] = $interfaceConfig
        }
        
        # Generate recommendations
        $config.Recommendations = Get-TCPRecommendations -Config $config
        
    } catch {
        Write-Log -Level "ERROR" -Category "NetworkTune" -Message "Error getting TCP configuration: $($_.Exception.Message)"
    }
    
    return $config
}

function global:Get-TCPRecommendations {
    <#
    .SYNOPSIS
        Generates recommendations based on current TCP configuration.
    #>
    param([hashtable]$Config)
    
    $recommendations = @()
    
    # RSS recommendations
    if ($Config.GlobalSettings.RSS -ne 'enabled') {
        $recommendations += @{
            Setting = "RSS"
            Current = $Config.GlobalSettings.RSS
            Recommended = "enabled"
            Reason = "RSS distributes network processing across CPU cores, improving performance"
        }
    }
    
    # Auto-tuning recommendations
    if ($Config.GlobalSettings.AutoTuningLevel -in @('disabled','restricted')) {
        $recommendations += @{
            Setting = "AutoTuningLevel"
            Current = $Config.GlobalSettings.AutoTuningLevel
            Recommended = "normal"
            Reason = "Restricted auto-tuning limits TCP window size, reducing throughput"
        }
    }
    
    # RSC recommendations
    if ($Config.GlobalSettings.RSC -eq 'disabled') {
        $recommendations += @{
            Setting = "RSC"
            Current = $Config.GlobalSettings.RSC
            Recommended = "enabled"
            Reason = "RSC combines packets to reduce CPU overhead"
        }
    }
    
    # ECN recommendations (optional)
    if ($Config.GlobalSettings.ECN -eq 'disabled') {
        $recommendations += @{
            Setting = "ECN"
            Current = $Config.GlobalSettings.ECN
            Recommended = "enabled"
            Reason = "ECN improves network efficiency by reducing packet loss"
            Optional = $true
        }
    }
    
    return $recommendations
}

# ============================================================================
# TCP TUNING OPERATIONS
# ============================================================================

function global:Set-TCPAutoTuning {
    <#
    .SYNOPSIS
        Sets TCP receive window auto-tuning level.
    #>
    param(
        [ValidateSet('disabled','restricted','normal','highlyrestricted','experimental')]
        [string]$Level = 'normal',
        
        [switch]$Preview
    )
    
    $result = @{
        Success = $true
        Setting = "AutoTuningLevel"
        PreviousValue = ""
        NewValue = $Level
        Message = ""
    }
    
    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Message = "Administrator privileges required"
        return $result
    }
    
    # Get current value
    $current = netsh int tcp show global 2>&1
    if ($current -match 'Receive Window Auto-Tuning Level\s+:\s+(\w+)') {
        $result.PreviousValue = $Matches[1]
    }
    
    if ($Preview) {
        $result.Message = "[PREVIEW] Would set TCP auto-tuning level to: $Level"
        return $result
    }
    
    Write-Log -Level "INFO" -Category "NetworkTune" -Message "Setting TCP auto-tuning level to: $Level"
    
    try {
        netsh int tcp set global autotuninglevel=$Level 2>&1 | Out-Null
        $result.Message = "TCP auto-tuning level set to: $Level"
        Write-Log -Level "SUCCESS" -Category "NetworkTune" -Message $result.Message
    } catch {
        $result.Success = $false
        $result.Message = $_.Exception.Message
    }
    
    return $result
}

function global:Set-TCPRSS {
    <#
    .SYNOPSIS
        Enables or disables Receive Side Scaling.
    #>
    param(
        [ValidateSet('enabled','disabled')]
        [string]$State = 'enabled',
        
        [switch]$Preview
    )
    
    $result = @{
        Success = $true
        Setting = "RSS"
        PreviousValue = ""
        NewValue = $State
        Message = ""
    }
    
    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Message = "Administrator privileges required"
        return $result
    }
    
    # Get current value
    $current = netsh int tcp show global 2>&1
    if ($current -match 'Receive-Side Scaling State\s+:\s+(\w+)') {
        $result.PreviousValue = $Matches[1]
    }
    
    if ($Preview) {
        $result.Message = "[PREVIEW] Would set TCP RSS to: $State"
        return $result
    }
    
    Write-Log -Level "INFO" -Category "NetworkTune" -Message "Setting TCP RSS to: $State"
    
    try {
        netsh int tcp set global rss=$State 2>&1 | Out-Null
        $result.Message = "TCP RSS set to: $State"
        Write-Log -Level "SUCCESS" -Category "NetworkTune" -Message $result.Message
    } catch {
        $result.Success = $false
        $result.Message = $_.Exception.Message
    }
    
    return $result
}

function global:Set-TCPRSC {
    <#
    .SYNOPSIS
        Enables or disables Receive Segment Coalescing.
    #>
    param(
        [ValidateSet('enabled','disabled')]
        [string]$State = 'enabled',
        
        [switch]$Preview
    )
    
    $result = @{
        Success = $true
        Setting = "RSC"
        PreviousValue = ""
        NewValue = $State
        Message = ""
    }
    
    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Message = "Administrator privileges required"
        return $result
    }
    
    # Get current value
    $current = netsh int tcp show global 2>&1
    if ($current -match 'Receive Segment Coalescing State\s+:\s+(\w+)') {
        $result.PreviousValue = $Matches[1]
    }
    
    if ($Preview) {
        $result.Message = "[PREVIEW] Would set TCP RSC to: $State"
        return $result
    }
    
    Write-Log -Level "INFO" -Category "NetworkTune" -Message "Setting TCP RSC to: $State"
    
    try {
        netsh int tcp set global rsc=$State 2>&1 | Out-Null
        $result.Message = "TCP RSC set to: $State"
        Write-Log -Level "SUCCESS" -Category "NetworkTune" -Message $result.Message
    } catch {
        $result.Success = $false
        $result.Message = $_.Exception.Message
    }
    
    return $result
}

function global:Set-TCPEcn {
    <#
    .SYNOPSIS
        Enables or disables ECN (Explicit Congestion Notification).
    #>
    param(
        [ValidateSet('enabled','disabled')]
        [string]$State = 'enabled',
        
        [switch]$Preview
    )
    
    $result = @{
        Success = $true
        Setting = "ECN"
        PreviousValue = ""
        NewValue = $State
        Message = ""
    }
    
    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Message = "Administrator privileges required"
        return $result
    }
    
    # Get current value
    $current = netsh int tcp show global 2>&1
    if ($current -match 'ECN Capability\s+:\s+(\w+)') {
        $result.PreviousValue = $Matches[1]
    }
    
    if ($Preview) {
        $result.Message = "[PREVIEW] Would set TCP ECN to: $State"
        return $result
    }
    
    Write-Log -Level "INFO" -Category "NetworkTune" -Message "Setting TCP ECN to: $State"
    
    try {
        netsh int tcp set global ecncapability=$State 2>&1 | Out-Null
        $result.Message = "TCP ECN set to: $State"
        Write-Log -Level "SUCCESS" -Category "NetworkTune" -Message $result.Message
    } catch {
        $result.Success = $false
        $result.Message = $_.Exception.Message
    }
    
    return $result
}

function global:Set-TCPTimestamps {
    <#
    .SYNOPSIS
        Enables or disables RFC 1323 timestamps.
    #>
    param(
        [ValidateSet('enabled','disabled')]
        [string]$State = 'disabled',
        
        [switch]$Preview
    )
    
    $result = @{
        Success = $true
        Setting = "Timestamps"
        PreviousValue = ""
        NewValue = $State
        Message = ""
    }
    
    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Message = "Administrator privileges required"
        return $result
    }
    
    # Get current value
    $current = netsh int tcp show global 2>&1
    if ($current -match 'RFC 1323 Timestamps\s+:\s+(\w+)') {
        $result.PreviousValue = $Matches[1]
    }
    
    if ($Preview) {
        $result.Message = "[PREVIEW] Would set TCP timestamps to: $State"
        return $result
    }
    
    Write-Log -Level "INFO" -Category "NetworkTune" -Message "Setting TCP timestamps to: $State"
    
    try {
        netsh int tcp set global timestamps=$State 2>&1 | Out-Null
        $result.Message = "TCP timestamps set to: $State"
        Write-Log -Level "SUCCESS" -Category "NetworkTune" -Message $result.Message
    } catch {
        $result.Success = $false
        $result.Message = $_.Exception.Message
    }
    
    return $result
}

function global:Set-TCPCongestionProvider {
    <#
    .SYNOPSIS
        Sets the TCP congestion control algorithm.
    #>
    param(
        [ValidateSet('default','ctcp','dctcp','newreno','cubic')]
        [string]$Provider = 'cubic',
        
        [switch]$Preview
    )
    
    $result = @{
        Success = $true
        Setting = "CongestionProvider"
        PreviousValue = ""
        NewValue = $Provider
        Message = ""
    }
    
    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Message = "Administrator privileges required"
        return $result
    }
    
    if ($Preview) {
        $result.Message = "[PREVIEW] Would set TCP congestion provider to: $Provider"
        return $result
    }
    
    Write-Log -Level "INFO" -Category "NetworkTune" -Message "Setting TCP congestion provider to: $Provider"
    
    try {
        netsh int tcp set supplemental template=internet congestionprovider=$Provider 2>&1 | Out-Null
        $result.Message = "TCP congestion provider set to: $Provider"
        Write-Log -Level "SUCCESS" -Category "NetworkTune" -Message $result.Message
    } catch {
        $result.Success = $false
        $result.Message = $_.Exception.Message
    }
    
    return $result
}

# ============================================================================
# TCP TUNING PRESETS
# ============================================================================

function global:Set-TCPTuningPreset {
    <#
    .SYNOPSIS
        Applies a predefined TCP tuning preset.
    #>
    param(
        [ValidateSet('Default','Optimized','HighPerformance','LowLatency','Compatibility')]
        [string]$Preset = 'Optimized',
        
        [switch]$Preview
    )
    
    $result = @{
        Success = $true
        Preset = $Preset
        Changes = @()
        Message = ""
        Errors = @()
    }
    
    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Message = "Administrator privileges required"
        return $result
    }
    
    $presetConfig = $script:TCPTuningPresets[$Preset]
    
    if ($Preview) {
        $result.Message = "[PREVIEW] Would apply $Preset preset"
        $result.Changes += "[PREVIEW] Auto-tuning: $($presetConfig.AutoTuningLevel)"
        $result.Changes += "[PREVIEW] RSS: $($presetConfig.RSS)"
        $result.Changes += "[PREVIEW] RSC: $($presetConfig.RSC)"
        $result.Changes += "[PREVIEW] ECN: $($presetConfig.ECN)"
        $result.Changes += "[PREVIEW] Timestamps: $($presetConfig.Timestamps)"
        return $result
    }
    
    Write-Log -Level "INFO" -Category "NetworkTune" -Message "Applying TCP tuning preset: $Preset"
    
    # Apply auto-tuning
    $autoResult = Set-TCPAutoTuning -Level $presetConfig.AutoTuningLevel
    if ($autoResult.Success) { $result.Changes += "Auto-tuning: $($presetConfig.AutoTuningLevel)" }
    else { $result.Errors += $autoResult.Message }
    
    # Apply RSS
    $rssResult = Set-TCPRSS -State $presetConfig.RSS
    if ($rssResult.Success) { $result.Changes += "RSS: $($presetConfig.RSS)" }
    else { $result.Errors += $rssResult.Message }
    
    # Apply RSC
    $rscResult = Set-TCPRSC -State $presetConfig.RSC
    if ($rscResult.Success) { $result.Changes += "RSC: $($presetConfig.RSC)" }
    else { $result.Errors += $rscResult.Message }
    
    # Apply ECN
    $ecnResult = Set-TCPEcn -State $presetConfig.ECN
    if ($ecnResult.Success) { $result.Changes += "ECN: $($presetConfig.ECN)" }
    else { $result.Errors += $ecnResult.Message }
    
    # Apply Timestamps
    $tsResult = Set-TCPTimestamps -State $presetConfig.Timestamps
    if ($tsResult.Success) { $result.Changes += "Timestamps: $($presetConfig.Timestamps)" }
    else { $result.Errors += $tsResult.Message }
    
    if ($result.Errors.Count -eq 0) {
        $result.Message = "TCP preset '$Preset' applied successfully"
        Write-Log -Level "SUCCESS" -Category "NetworkTune" -Message $result.Message
    } else {
        $result.Message = "TCP preset applied with $($result.Errors.Count) errors"
    }
    
    return $result
}

# ============================================================================
# NETWORK REGISTRY TUNING
# ============================================================================

function global:Set-NetworkRegistryTuning {
    <#
    .SYNOPSIS
        Applies advanced network tuning via registry.
    #>
    param(
        [int]$MaxUserPort = 65534,
        [int]$TcpTimedWaitDelay = 30,
        [int]$MaxFreeTcbs = 2000,
        [int]$MaxHashTableSize = 65536,
        [switch]$Preview
    )
    
    $result = @{
        Success = $true
        Changes = @()
        Message = ""
        RequiresRestart = $true
        Errors = @()
    }
    
    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Message = "Administrator privileges required"
        return $result
    }
    
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
    
    if ($Preview) {
        $result.Message = "[PREVIEW] Would apply network registry tuning"
        $result.Changes += "[PREVIEW] MaxUserPort: $MaxUserPort"
        $result.Changes += "[PREVIEW] TcpTimedWaitDelay: $TcpTimedWaitDelay"
        return $result
    }
    
    Write-Log -Level "INFO" -Category "NetworkTune" -Message "Applying network registry tuning..."
    
    # Backup registry
    New-RegistryBackup -Keys @($regPath) -BackupName "NetworkTuning_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    
    try {
        # MaxUserPort - Maximum port number for dynamic allocation
        Set-ItemProperty -Path $regPath -Name "MaxUserPort" -Value $MaxUserPort -Type DWord -Force
        $result.Changes += "MaxUserPort: $MaxUserPort"
        
        # TcpTimedWaitDelay - Time in TIME_WAIT state
        Set-ItemProperty -Path $regPath -Name "TcpTimedWaitDelay" -Value $TcpTimedWaitDelay -Type DWord -Force
        $result.Changes += "TcpTimedWaitDelay: $TcpTimedWaitDelay"
        
        $result.Message = "Network registry tuning applied. Restart required."
        Write-Log -Level "SUCCESS" -Category "NetworkTune" -Message $result.Message
        
    } catch {
        $result.Success = $false
        $result.Message = $_.Exception.Message
        $result.Errors += $_.Exception.Message
    }
    
    return $result
}

function global:Invoke-CompleteTCPTuning {
    <#
    .SYNOPSIS
        Applies comprehensive TCP tuning optimizations.
    #>
    param(
        [ValidateSet('Optimized','HighPerformance','LowLatency')]
        [string]$Preset = 'Optimized',
        
        [switch]$ApplyRegistryTuning,
        [switch]$Preview
    )
    
    $results = @{
        Success = $true
        Preset = $Preset
        Changes = @()
        Message = ""
        RequiresRestart = $false
        Errors = @()
    }
    
    Write-Log -Level "INFO" -Category "NetworkTune" -Message "Starting complete TCP tuning..."
    
    # Apply preset
    $presetResult = Set-TCPTuningPreset -Preset $Preset -Preview:$Preview
    $results.Changes += $presetResult.Changes
    
    if (-not $presetResult.Success) {
        $results.Errors += $presetResult.Errors
    }
    
    # Apply registry tuning if requested
    if ($ApplyRegistryTuning) {
        $regResult = Set-NetworkRegistryTuning -Preview:$Preview
        $results.Changes += $regResult.Changes
        
        if ($regResult.RequiresRestart) {
            $results.RequiresRestart = $true
        }
    }
    
    if ($results.Errors.Count -eq 0) {
        $results.Message = "TCP tuning complete. $($results.Changes.Count) changes applied."
    } else {
        $results.Message = "TCP tuning complete with $($results.Errors.Count) errors."
    }
    
    Write-Log -Level "SUCCESS" -Category "NetworkTune" -Message $results.Message
    
    return $results
}
