<#
.SYNOPSIS
    WinTune Pro AdapterTuning Module - Network adapter advanced tuning
.DESCRIPTION
    Network adapter driver settings optimization for improved performance
.NOTES
    File: Modules\NetworkTune\AdapterTuning.ps1
    Version: 1.0.1
    PowerShell: 5.1+
    Compatible: Windows 10, Windows 11
#>

# ============================================================================
# ADAPTER TUNING PRESETS
# ============================================================================

$script:AdapterTuningPresets = @{
    "Default" = @{
        Description = "Windows default settings"
        RSS = "Enabled"
        RSC = "Enabled"
        JumboPacket = "1514"
        FlowControl = "Rx & Tx Enabled"
        InterruptModeration = "Enabled"
        EnergyEfficientEthernet = "Enabled"
    }
    "Performance" = @{
        Description = "Maximum performance (power consumption tradeoff)"
        RSS = "Enabled"
        RSC = "Enabled"
        JumboPacket = "9014"
        FlowControl = "Tx Enabled"
        InterruptModeration = "Enabled"
        EnergyEfficientEthernet = "Disabled"
    }
    "LowLatency" = @{
        Description = "Optimized for gaming/real-time"
        RSS = "Enabled"
        RSC = "Disabled"
        JumboPacket = "1514"
        FlowControl = "Disabled"
        InterruptModeration = "Disabled"
        EnergyEfficientEthernet = "Disabled"
    }
    "Server" = @{
        Description = "Optimized for file servers"
        RSS = "Enabled"
        RSC = "Enabled"
        JumboPacket = "9014"
        FlowControl = "Rx & Tx Enabled"
        InterruptModeration = "Enabled"
        EnergyEfficientEthernet = "Disabled"
    }
    "PowerSaving" = @{
        Description = "Maximum power savings"
        RSS = "Enabled"
        RSC = "Enabled"
        JumboPacket = "1514"
        FlowControl = "Rx Enabled"
        InterruptModeration = "Enabled"
        EnergyEfficientEthernet = "Enabled"
    }
}

# ============================================================================
# ADAPTER SETTINGS QUERY
# ============================================================================

function global:Get-AdapterAdvancedSettings {
    <#
    .SYNOPSIS
        Gets advanced settings for network adapters.
    #>
    param([string]$InterfaceAlias)
    
    $result = @{
        Success = $true
        Adapter = $InterfaceAlias
        Settings = @{}
        Message = ""
    }
    
    try {
        $adapter = Get-NetAdapter -Name $InterfaceAlias -ErrorAction Stop
        $advanced = Get-NetAdapterAdvancedProperty -Name $InterfaceAlias -ErrorAction Stop
        
        foreach ($prop in $advanced) {
            $result.Settings[$prop.DisplayName] = @{
                DisplayValue = $prop.DisplayValue
                RegistryKeyword = $prop.RegistryKeyword
                RegistryValue = $prop.RegistryValue
                ValidValues = $prop.ValidDisplayValues
            }
        }
        
        $result.Message = "Retrieved $($result.Settings.Count) settings for $InterfaceAlias"
        
    } catch {
        $result.Success = $false
        $result.Message = $_.Exception.Message
    }
    
    return $result
}

function global:Get-AllAdapterSettings {
    <#
    .SYNOPSIS
        Gets advanced settings for all active network adapters.
    #>
    
    $results = @{
        Adapters = @()
        Message = ""
    }
    
    try {
        $adapters = Get-NetAdapter -ErrorAction Stop | Where-Object { 
            $_.Status -eq 'Up' -and 
            $_.InterfaceDescription -notmatch '(Virtual|Hyper-V|VMware|VirtualBox|Loopback|Tunnel)'
        }
        
        foreach ($adapter in $adapters) {
            $settings = Get-AdapterAdvancedSettings -InterfaceAlias $adapter.Name
            if ($settings.Success) {
                $results.Adapters += @{
                    Name = $adapter.Name
                    InterfaceDescription = $adapter.InterfaceDescription
                    LinkSpeed = $adapter.LinkSpeed
                    Settings = $settings.Settings
                }
            }
        }
        
        $results.Message = "Retrieved settings for $($results.Adapters.Count) adapters"
        
    } catch {
        $results.Message = $_.Exception.Message
    }
    
    return $results
}

# ============================================================================
# INDIVIDUAL SETTING FUNCTIONS
# ============================================================================

function global:Set-AdapterRSS {
    <#
    .SYNOPSIS
        Sets Receive Side Scaling for a network adapter.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$InterfaceAlias,
        
        [ValidateSet('Enabled','Disabled')]
        [string]$State = 'Enabled',
        
        [switch]$Preview
    )
    
    $result = @{
        Success = $true
        Adapter = $InterfaceAlias
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
    
    try {
        $props = Get-NetAdapterAdvancedProperty -Name $InterfaceAlias -DisplayName "*Receive Side Scaling*" -ErrorAction Stop
        $result.PreviousValue = $props.DisplayValue
        
        if ($Preview) {
            $result.Message = "[PREVIEW] Would set RSS to $State for $InterfaceAlias"
            return $result
        }
        
        Set-NetAdapterAdvancedProperty -Name $InterfaceAlias -DisplayName $props.DisplayName -DisplayValue $State -ErrorAction Stop
        $result.Message = "RSS set to $State for $InterfaceAlias"
        Write-Log -Level "SUCCESS" -Category "NetworkTune" -Message $result.Message
        
    } catch {
        $result.Success = $false
        $result.Message = $_.Exception.Message
    }
    
    return $result
}

function global:Set-AdapterRSC {
    <#
    .SYNOPSIS
        Sets Receive Segment Coalescing for a network adapter.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$InterfaceAlias,
        
        [ValidateSet('Enabled','Disabled')]
        [string]$State = 'Enabled',
        
        [switch]$Preview
    )
    
    $result = @{
        Success = $true
        Adapter = $InterfaceAlias
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
    
    try {
        $props = Get-NetAdapterAdvancedProperty -Name $InterfaceAlias -DisplayName "*Receive Segment Coalescing*" -ErrorAction Stop
        $result.PreviousValue = $props.DisplayValue
        
        if ($Preview) {
            $result.Message = "[PREVIEW] Would set RSC to $State for $InterfaceAlias"
            return $result
        }
        
        Set-NetAdapterAdvancedProperty -Name $InterfaceAlias -DisplayName $props.DisplayName -DisplayValue $State -ErrorAction Stop
        $result.Message = "RSC set to $State for $InterfaceAlias"
        Write-Log -Level "SUCCESS" -Category "NetworkTune" -Message $result.Message
        
    } catch {
        $result.Success = $false
        $result.Message = $_.Exception.Message
    }
    
    return $result
}

function global:Set-AdapterJumboPacket {
    <#
    .SYNOPSIS
        Sets Jumbo Frame (MTU) for a network adapter.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$InterfaceAlias,
        
        [ValidateSet('1514','4088','9014')]
        [string]$Size = '9014',
        
        [switch]$Preview
    )
    
    $result = @{
        Success = $true
        Adapter = $InterfaceAlias
        Setting = "JumboPacket"
        PreviousValue = ""
        NewValue = $Size
        Message = ""
        Warning = ""
    }
    
    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Message = "Administrator privileges required"
        return $result
    }
    
    try {
        $props = Get-NetAdapterAdvancedProperty -Name $InterfaceAlias -DisplayName "*Jumbo*" -ErrorAction Stop
        $result.PreviousValue = $props.DisplayValue
        
        if ($Preview) {
            $result.Message = "[PREVIEW] Would set Jumbo Packet to $Size bytes for $InterfaceAlias"
            return $result
        }
        
        # Warning for jumbo frames
        if ($Size -gt 1514) {
            $result.Warning = "Jumbo frames require switch/router support. Connectivity may fail."
            Write-Log -Level "WARNING" -Category "NetworkTune" -Message $result.Warning
        }
        
        Set-NetAdapterAdvancedProperty -Name $InterfaceAlias -DisplayName $props.DisplayName -DisplayValue "$Size Bytes" -ErrorAction Stop
        $result.Message = "Jumbo Packet set to $Size bytes for $InterfaceAlias"
        Write-Log -Level "SUCCESS" -Category "NetworkTune" -Message $result.Message
        
    } catch {
        $result.Success = $false
        $result.Message = $_.Exception.Message
    }
    
    return $result
}

function global:Set-AdapterFlowControl {
    <#
    .SYNOPSIS
        Sets Flow Control for a network adapter.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$InterfaceAlias,
        
        [ValidateSet('Disabled','Tx Enabled','Rx Enabled','Rx & Tx Enabled')]
        [string]$Mode = 'Rx & Tx Enabled',
        
        [switch]$Preview
    )
    
    $result = @{
        Success = $true
        Adapter = $InterfaceAlias
        Setting = "FlowControl"
        PreviousValue = ""
        NewValue = $Mode
        Message = ""
    }
    
    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Message = "Administrator privileges required"
        return $result
    }
    
    try {
        $props = Get-NetAdapterAdvancedProperty -Name $InterfaceAlias -DisplayName "*Flow Control*" -ErrorAction Stop
        $result.PreviousValue = $props.DisplayValue
        
        if ($Preview) {
            $result.Message = "[PREVIEW] Would set Flow Control to '$Mode' for $InterfaceAlias"
            return $result
        }
        
        Set-NetAdapterAdvancedProperty -Name $InterfaceAlias -DisplayName $props.DisplayName -DisplayValue $Mode -ErrorAction Stop
        $result.Message = "Flow Control set to '$Mode' for $InterfaceAlias"
        Write-Log -Level "SUCCESS" -Category "NetworkTune" -Message $result.Message
        
    } catch {
        $result.Success = $false
        $result.Message = $_.Exception.Message
    }
    
    return $result
}

function global:Set-AdapterInterruptModeration {
    <#
    .SYNOPSIS
        Sets Interrupt Moderation for a network adapter.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$InterfaceAlias,
        
        [ValidateSet('Enabled','Disabled')]
        [string]$State = 'Enabled',
        
        [switch]$Preview
    )
    
    $result = @{
        Success = $true
        Adapter = $InterfaceAlias
        Setting = "InterruptModeration"
        PreviousValue = ""
        NewValue = $State
        Message = ""
    }
    
    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Message = "Administrator privileges required"
        return $result
    }
    
    try {
        $props = Get-NetAdapterAdvancedProperty -Name $InterfaceAlias -DisplayName "*Interrupt Moderation*" -ErrorAction Stop
        $result.PreviousValue = $props.DisplayValue
        
        if ($Preview) {
            $result.Message = "[PREVIEW] Would set Interrupt Moderation to $State for $InterfaceAlias"
            return $result
        }
        
        Set-NetAdapterAdvancedProperty -Name $InterfaceAlias -DisplayName $props.DisplayName -DisplayValue $State -ErrorAction Stop
        $result.Message = "Interrupt Moderation set to $State for $InterfaceAlias"
        Write-Log -Level "SUCCESS" -Category "NetworkTune" -Message $result.Message
        
    } catch {
        $result.Success = $false
        $result.Message = $_.Exception.Message
    }
    
    return $result
}

function global:Set-AdapterEnergyEfficientEthernet {
    <#
    .SYNOPSIS
        Sets Energy Efficient Ethernet (EEE) for a network adapter.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$InterfaceAlias,
        
        [ValidateSet('Enabled','Disabled')]
        [string]$State = 'Disabled',
        
        [switch]$Preview
    )
    
    $result = @{
        Success = $true
        Adapter = $InterfaceAlias
        Setting = "EnergyEfficientEthernet"
        PreviousValue = ""
        NewValue = $State
        Message = ""
    }
    
    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Message = "Administrator privileges required"
        return $result
    }
    
    try {
        # Try different EEE naming conventions
        $eeeNames = @("*Energy Efficient*","*EEE*","*Green Ethernet*","*Power Saving*")
        $props = $null
        
        foreach ($name in $eeeNames) {
            $props = Get-NetAdapterAdvancedProperty -Name $InterfaceAlias -DisplayName $name -ErrorAction SilentlyContinue
            if ($props) { break }
        }
        
        if (-not $props) {
            $result.Success = $false
            $result.Message = "EEE setting not found for this adapter"
            return $result
        }
        
        $result.PreviousValue = $props.DisplayValue
        
        if ($Preview) {
            $result.Message = "[PREVIEW] Would set Energy Efficient Ethernet to $State for $InterfaceAlias"
            return $result
        }
        
        Set-NetAdapterAdvancedProperty -Name $InterfaceAlias -DisplayName $props.DisplayName -DisplayValue $State -ErrorAction Stop
        $result.Message = "Energy Efficient Ethernet set to $State for $InterfaceAlias"
        Write-Log -Level "SUCCESS" -Category "NetworkTune" -Message $result.Message
        
    } catch {
        $result.Success = $false
        $result.Message = $_.Exception.Message
    }
    
    return $result
}

function global:Set-AdapterBufferSize {
    <#
    .SYNOPSIS
        Sets receive/transmit buffer sizes for a network adapter.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$InterfaceAlias,
        
        [int]$ReceiveBuffers = 2048,
        [int]$TransmitBuffers = 2048,
        
        [switch]$Preview
    )
    
    $result = @{
        Success = $true
        Adapter = $InterfaceAlias
        Changes = @()
        Message = ""
    }
    
    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Message = "Administrator privileges required"
        return $result
    }
    
    try {
        $adapter = Get-NetAdapter -Name $InterfaceAlias -ErrorAction Stop
        
        if ($Preview) {
            $result.Message = "[PREVIEW] Would set buffer sizes for $InterfaceAlias"
            $result.Changes += "[PREVIEW] Receive Buffers: $ReceiveBuffers"
            $result.Changes += "[PREVIEW] Transmit Buffers: $TransmitBuffers"
            return $result
        }
        
        # Set Receive Buffers
        $rxProps = Get-NetAdapterAdvancedProperty -Name $InterfaceAlias -DisplayName "*Receive Buffer*" -ErrorAction SilentlyContinue
        if ($rxProps) {
            Set-NetAdapterAdvancedProperty -Name $InterfaceAlias -DisplayName $rxProps.DisplayName -DisplayValue $ReceiveBuffers -ErrorAction SilentlyContinue
            $result.Changes += "Receive Buffers: $ReceiveBuffers"
        }
        
        # Set Transmit Buffers
        $txProps = Get-NetAdapterAdvancedProperty -Name $InterfaceAlias -DisplayName "*Transmit Buffer*" -ErrorAction SilentlyContinue
        if ($txProps) {
            Set-NetAdapterAdvancedProperty -Name $InterfaceAlias -DisplayName $txProps.DisplayName -DisplayValue $TransmitBuffers -ErrorAction SilentlyContinue
            $result.Changes += "Transmit Buffers: $TransmitBuffers"
        }
        
        $result.Message = "Buffer sizes set for $InterfaceAlias"
        Write-Log -Level "SUCCESS" -Category "NetworkTune" -Message $result.Message
        
    } catch {
        $result.Success = $false
        $result.Message = $_.Exception.Message
    }
    
    return $result
}

# ============================================================================
# ADAPTER TUNING PRESETS
# ============================================================================

function global:Set-AdapterTuningPreset {
    <#
    .SYNOPSIS
        Applies a predefined adapter tuning preset.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$InterfaceAlias,
        
        [ValidateSet('Default','Performance','LowLatency','Server','PowerSaving')]
        [string]$Preset = 'Performance',
        
        [switch]$Preview
    )
    
    $result = @{
        Success = $true
        Adapter = $InterfaceAlias
        Preset = $Preset
        Changes = @()
        Errors = @()
        Message = ""
    }
    
    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Message = "Administrator privileges required"
        return $result
    }
    
    $presetConfig = $script:AdapterTuningPresets[$Preset]
    
    Write-Log -Level "INFO" -Category "NetworkTune" -Message "Applying adapter preset '$Preset' to $InterfaceAlias..."
    
    # RSS
    $rssResult = Set-AdapterRSS -InterfaceAlias $InterfaceAlias -State $presetConfig.RSS -Preview:$Preview
    if ($rssResult.Success) { $result.Changes += "RSS: $($presetConfig.RSS)" }
    else { $result.Errors += $rssResult.Message }
    
    # RSC
    $rscResult = Set-AdapterRSC -InterfaceAlias $InterfaceAlias -State $presetConfig.RSC -Preview:$Preview
    if ($rscResult.Success) { $result.Changes += "RSC: $($presetConfig.RSC)" }
    else { $result.Errors += $rscResult.Message }
    
    # Jumbo Packet
    $jumboResult = Set-AdapterJumboPacket -InterfaceAlias $InterfaceAlias -Size $presetConfig.JumboPacket -Preview:$Preview
    if ($jumboResult.Success) { $result.Changes += "Jumbo Packet: $($presetConfig.JumboPacket)" }
    else { $result.Errors += $jumboResult.Message }
    
    # Flow Control
    $flowResult = Set-AdapterFlowControl -InterfaceAlias $InterfaceAlias -Mode $presetConfig.FlowControl -Preview:$Preview
    if ($flowResult.Success) { $result.Changes += "Flow Control: $($presetConfig.FlowControl)" }
    else { $result.Errors += $flowResult.Message }
    
    # Interrupt Moderation
    $intResult = Set-AdapterInterruptModeration -InterfaceAlias $InterfaceAlias -State $presetConfig.InterruptModeration -Preview:$Preview
    if ($intResult.Success) { $result.Changes += "Interrupt Moderation: $($presetConfig.InterruptModeration)" }
    else { $result.Errors += $intResult.Message }
    
    # EEE
    $eeeResult = Set-AdapterEnergyEfficientEthernet -InterfaceAlias $InterfaceAlias -State $presetConfig.EnergyEfficientEthernet -Preview:$Preview
    if ($eeeResult.Success) { $result.Changes += "EEE: $($presetConfig.EnergyEfficientEthernet)" }
    else { $result.Errors += $eeeResult.Message }
    
    if ($result.Errors.Count -eq 0) {
        $result.Message = "Preset '$Preset' applied to $InterfaceAlias"
    } else {
        $result.Message = "Preset applied with $($result.Errors.Count) errors"
    }
    
    Write-Log -Level "SUCCESS" -Category "NetworkTune" -Message $result.Message
    
    return $result
}

function global:Set-AllAdaptersTuningPreset {
    <#
    .SYNOPSIS
        Applies a preset to all active physical network adapters.
    #>
    param(
        [ValidateSet('Default','Performance','LowLatency','Server','PowerSaving')]
        [string]$Preset = 'Performance',
        
        [switch]$Preview
    )
    
    $results = @{
        Success = $true
        Preset = $Preset
        Adapters = @()
        Message = ""
    }
    
    try {
        $adapters = Get-NetAdapter -ErrorAction Stop | Where-Object { 
            $_.Status -eq 'Up' -and 
            $_.InterfaceDescription -notmatch '(Virtual|Hyper-V|VMware|VirtualBox|Loopback|Tunnel)'
        }
        
        foreach ($adapter in $adapters) {
            $result = Set-AdapterTuningPreset -InterfaceAlias $adapter.Name -Preset $Preset -Preview:$Preview
            $results.Adapters += $result
        }
        
        $results.Message = "Preset '$Preset' applied to $($results.Adapters.Count) adapters"
        
    } catch {
        $results.Success = $false
        $results.Message = $_.Exception.Message
    }
    
    return $results
}

# ============================================================================
# ADAPTER OPTIMIZATION
# ============================================================================

function global:Optimize-NetworkAdapters {
    <#
    .SYNOPSIS
        Applies comprehensive optimization to all network adapters.
    #>
    param(
        [ValidateSet('Performance','LowLatency','Balanced')]
        [string]$Profile = 'Performance',
        
        [switch]$ApplyJumboFrames,
        [switch]$IncreaseBuffers,
        [switch]$Preview
    )
    
    $results = @{
        Success = $true
        Profile = $Profile
        Adapters = @()
        Changes = @()
        Errors = @()
        Message = ""
    }
    
    Write-Log -Level "INFO" -Category "NetworkTune" -Message "Starting network adapter optimization..."
    
    try {
        $adapters = Get-NetAdapter -ErrorAction Stop | Where-Object { 
            $_.Status -eq 'Up' -and 
            $_.InterfaceDescription -notmatch '(Virtual|Hyper-V|VMware|VirtualBox|Loopback|Tunnel)'
        }
        
        foreach ($adapter in $adapters) {
            $adapterResult = @{
                Name = $adapter.Name
                Changes = @()
                Errors = @()
            }
            
            # Apply preset
            $presetName = if ($Profile -eq 'Balanced') { 'Default' } else { $Profile }
            $presetResult = Set-AdapterTuningPreset -InterfaceAlias $adapter.Name -Preset $presetName -Preview:$Preview
            $adapterResult.Changes += $presetResult.Changes
            $adapterResult.Errors += $presetResult.Errors
            
            # Increase buffers if requested
            if ($IncreaseBuffers) {
                $bufferResult = Set-AdapterBufferSize -InterfaceAlias $adapter.Name -ReceiveBuffers 4096 -TransmitBuffers 4096 -Preview:$Preview
                if ($bufferResult.Success) {
                    $adapterResult.Changes += $bufferResult.Changes
                }
            }
            
            # Apply jumbo frames if requested
            if ($ApplyJumboFrames) {
                $jumboResult = Set-AdapterJumboPacket -InterfaceAlias $adapter.Name -Size '9014' -Preview:$Preview
                if ($jumboResult.Success) {
                    $adapterResult.Changes += "Jumbo Frames: 9014"
                }
            }
            
            $results.Adapters += $adapterResult
            $results.Changes += $adapterResult.Changes
            $results.Errors += $adapterResult.Errors
        }
        
        $results.Message = "Network adapter optimization complete. $($results.Adapters.Count) adapters processed."
        Write-Log -Level "SUCCESS" -Category "NetworkTune" -Message $results.Message
        
    } catch {
        $results.Success = $false
        $results.Message = $_.Exception.Message
    }
    
    return $results
}

function global:Get-AdapterOptimizationRecommendations {
    <#
    .SYNOPSIS
        Generates adapter optimization recommendations.
    #>
    param([string]$InterfaceAlias)
    
    $recommendations = @{
        Adapter = $InterfaceAlias
        CurrentSettings = @{}
        Recommendations = @()
        Warnings = @()
    }
    
    try {
        $settings = Get-AdapterAdvancedSettings -InterfaceAlias $InterfaceAlias
        
        if ($settings.Success) {
            $recommendations.CurrentSettings = $settings.Settings
            
            # RSS recommendation
            $rss = $settings.Settings["Receive Side Scaling"]
            if ($rss -and $rss.DisplayValue -ne "Enabled") {
                $recommendations.Recommendations += "Enable RSS for better multi-core CPU utilization"
            }
            
            # RSC recommendation
            $rsc = $settings.Settings["Receive Segment Coalescing (IPv4)"]
            if ($rsc -and $rsc.DisplayValue -ne "Enabled") {
                $recommendations.Recommendations += "Enable RSC to reduce CPU overhead"
            }
            
            # Jumbo frames recommendation
            $jumbo = $settings.Settings["Jumbo Packet"]
            if ($jumbo -and $jumbo.DisplayValue -match "1514") {
                $recommendations.Recommendations += "Consider Jumbo Frames (9014) if your network supports it"
                $recommendations.Warnings += "Jumbo frames require switch support"
            }
            
            # EEE recommendation
            $eee = $settings.Settings["Energy Efficient Ethernet"]
            if ($eee -and $eee.DisplayValue -eq "Enabled") {
                $recommendations.Recommendations += "Disable EEE for lower latency (increases power usage)"
            }
            
            # Flow control
            $flow = $settings.Settings["Flow Control"]
            if ($flow -and $flow.DisplayValue -eq "Disabled") {
                $recommendations.Recommendations += "Enable Flow Control to prevent packet loss"
            }
            
            # Buffer sizes
            $rxBuffer = $settings.Settings["Receive Buffers"]
            $txBuffer = $settings.Settings["Transmit Buffers"]
            if (($rxBuffer -and [int]$rxBuffer.DisplayValue -lt 1024) -or 
                ($txBuffer -and [int]$txBuffer.DisplayValue -lt 1024)) {
                $recommendations.Recommendations += "Increase buffer sizes to at least 2048"
            }
        }
        
    } catch {
        $recommendations.Warnings += $_.Exception.Message
    }
    
    return $recommendations
}
