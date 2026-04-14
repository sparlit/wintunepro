<#
.SYNOPSIS
    WinTune Pro Adapter Module - Network adapter operations
.DESCRIPTION
    Network adapter reset, configuration backup, and advanced management
.NOTES
    File: Modules\NetworkReset\Adapter.ps1
    Version: 1.0.1
    PowerShell: 5.1+
    Compatible: Windows 10, Windows 11
#>

# ============================================================================
# ADAPTER INFORMATION
# ============================================================================

function global:Get-NetworkAdapterInfo {
    <#
    .SYNOPSIS
        Gets detailed information about network adapters.
    #>
    param(
        [string]$Name,
        [switch]$IncludeDisabled,
        [switch]$IncludeVirtual
    )
    
    $adapters = @()
    
    try {
        $netAdapters = Get-NetAdapter -ErrorAction Stop
        
        if ($Name) {
            $netAdapters = $netAdapters | Where-Object { $_.Name -like "*$Name*" -or $_.InterfaceDescription -like "*$Name*" }
        }
        
        if (-not $IncludeDisabled) {
            $netAdapters = $netAdapters | Where-Object { $_.Status -eq 'Up' }
        }
        
        foreach ($adapter in $netAdapters) {
            # Skip virtual adapters if not requested
            if (-not $IncludeVirtual) {
                if ($adapter.InterfaceDescription -match "(Virtual|Hyper-V|VMware|VirtualBox|Loopback|Tunnel|ISATAP|Teredo|6to4)") {
                    continue
                }
            }
            
            # Get IP configuration
            $ipConfig = Get-NetIPConfiguration -InterfaceAlias $adapter.Name -ErrorAction SilentlyContinue
            
            # Get DNS settings
            $dnsSettings = Get-DnsClientServerAddress -InterfaceAlias $adapter.Name -ErrorAction SilentlyContinue
            
            # Get advanced properties
            $advancedProps = Get-NetAdapterAdvancedProperty -Name $adapter.Name -ErrorAction SilentlyContinue
            
            $adapterInfo = [PSCustomObject]@{
                Name = $adapter.Name
                InterfaceDescription = $adapter.InterfaceDescription
                InterfaceAlias = $adapter.InterfaceAlias
                Status = $adapter.Status
                LinkSpeed = $adapter.LinkSpeed
                MacAddress = $adapter.MacAddress
                MediaType = $adapter.MediaType
                DriverVersion = $adapter.DriverVersion
                DriverDate = $adapter.DriverDate
                DriverProvider = $adapter.DriverProvider
                
                # IP Configuration
                IPv4Address = if ($ipConfig) { $ipConfig.IPv4Address.IPAddress } else { @() }
                IPv6Address = if ($ipConfig) { $ipConfig.IPv6Address.IPAddress } else { @() }
                DefaultGateway = if ($ipConfig) { $ipConfig.IPv4DefaultGateway.NextHop } else { $null }
                DNSServers = if ($dnsSettings) { $dnsSettings.ServerAddresses } else { @() }
                DHCPEnabled = ($ipConfig.NetAdapter.Status -eq 'Up' -and $ipConfig.IPv4Address.PrefixOrigin -eq 'Dhcp')
                
                # Advanced Properties
                JumboPacket = ($advancedProps | Where-Object { $_.DisplayName -eq 'Jumbo Packet' }).DisplayValue
                RSS = ($advancedProps | Where-Object { $_.DisplayName -like '*Receive Side Scaling*' }).DisplayValue
                FlowControl = ($advancedProps | Where-Object { $_.DisplayName -like '*Flow Control*' }).DisplayValue
                InterruptModeration = ($advancedProps | Where-Object { $_.DisplayName -like '*Interrupt Moderation*' }).DisplayValue
                
                # Statistics
                ReceivedBytes = $adapter.ReceivedBytes
                SentBytes = $adapter.SentBytes
                ReceivedDiscarded = $adapter.ReceivedDiscarded
                OutboundDiscarded = $adapter.OutboundDiscarded
                
                # Classification
                IsPhysical = $adapter.InterfaceDescription -notmatch "(Virtual|Hyper-V|VMware|VirtualBox|Loopback|Tunnel)"
                IsWiFi = $adapter.MediaType -eq 'Native 802.11'
                IsEthernet = $adapter.MediaType -eq '802.3'
            }
            
            $adapters += $adapterInfo
        }
    } catch {
        Write-Log -Level "ERROR" -Category "Network" -Message "Error getting network adapters: $($_.Exception.Message)"
    }
    
    return $adapters
}

function global:Get-AdapterStatistics {
    <#
    .SYNOPSIS
        Gets detailed network adapter statistics.
    #>
    param([string]$InterfaceAlias)
    
    try {
        $adapter = Get-NetAdapter -Name $InterfaceAlias -ErrorAction Stop
        
        $stats = @{
            Name = $adapter.Name
            Status = $adapter.Status
            LinkSpeed = $adapter.LinkSpeed
            
            # Bytes
            ReceivedBytes = $adapter.ReceivedBytes
            SentBytes = $adapter.SentBytes
            TotalBytes = $adapter.ReceivedBytes + $adapter.SentBytes
            
            # Packets
            ReceivedUnicastPackets = $adapter.ReceivedUnicastPackets
            SentUnicastPackets = $adapter.SentUnicastPackets
            ReceivedMulticastPackets = $adapter.ReceivedMulticastPackets
            SentMulticastPackets = $adapter.SentMulticastPackets
            ReceivedBroadcastPackets = $adapter.ReceivedBroadcastPackets
            SentBroadcastPackets = $adapter.SentBroadcastPackets
            
            # Errors
            ReceivedErrors = $adapter.InErrors
            SentErrors = $adapter.OutErrors
            ReceivedDiscarded = $adapter.InDiscards
            SentDiscarded = $adapter.OutDiscards
            
            # Formatted
            ReceivedFormatted = Format-FileSize $adapter.ReceivedBytes
            SentFormatted = Format-FileSize $adapter.SentBytes
            TotalFormatted = Format-FileSize ($adapter.ReceivedBytes + $adapter.SentBytes)
        }
        
        return $stats
        
    } catch {
        Write-Log -Level "ERROR" -Category "Network" -Message "Error getting adapter statistics: $($_.Exception.Message)"
        return $null
    }
}

# ============================================================================
# ADAPTER RESET OPERATIONS
# ============================================================================

function global:Reset-NetworkAdapters {
    <#
    .SYNOPSIS
        Resets all network adapters.
    #>
    param(
        [switch]$Preview,
        [switch]$IncludeVirtual,
        [string[]]$Exclude
    )
    
    $result = @{
        Success = $true
        AdaptersReset = 0
        AdaptersSkipped = 0
        Results = @()
        Errors = @()
    }
    
    Write-Log -Level "INFO" -Category "Network" -Message "Resetting network adapters..."
    
    $adapters = Get-NetworkAdapterInfo -IncludeDisabled:$IncludeVirtual -IncludeVirtual:$IncludeVirtual
    
    foreach ($adapter in $adapters) {
        # Skip excluded adapters
        if ($adapter.Name -in $Exclude) {
            $result.AdaptersSkipped++
            continue
        }
        
        if ($Preview) {
            $result.Results += @{
                Adapter = $adapter.Name
                Action = "Would reset"
                Status = "Preview"
            }
            $result.AdaptersReset++
            continue
        }
        
        try {
            # Disable adapter
            Disable-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction Stop
            
            Start-Sleep -Seconds 2
            
            # Re-enable adapter
            Enable-NetAdapter -Name $adapter.Name -ErrorAction Stop
            
            $result.Results += @{
                Adapter = $adapter.Name
                Action = "Reset"
                Status = "Success"
            }
            
            $result.AdaptersReset++
            Write-Log -Level "SUCCESS" -Category "Network" -Message "Reset adapter: $($adapter.Name)"
            
        } catch {
            $result.Errors += "Failed to reset $($adapter.Name): $($_.Exception.Message)"
            $result.Results += @{
                Adapter = $adapter.Name
                Action = "Reset"
                Status = "Failed"
                Error = $_.Exception.Message
            }
        }
    }
    
    Write-Log -Level "SUCCESS" -Category "Network" -Message "Adapter reset complete: $($result.AdaptersReset) reset, $($result.AdaptersSkipped) skipped"
    
    return $result
}

function global:Restart-NetworkAdapter {
    <#
    .SYNOPSIS
        Restarts a specific network adapter.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [switch]$Preview
    )
    
    $result = @{
        Success = $true
        Adapter = $Name
        Message = ""
        Errors = @()
    }
    
    try {
        $adapter = Get-NetAdapter -Name $Name -ErrorAction Stop
        
        if ($Preview) {
            $result.Message = "[PREVIEW] Would restart adapter: $Name"
            return $result
        }
        
        Write-Log -Level "INFO" -Category "Network" -Message "Restarting adapter: $Name"
        
        # Capture current state for rollback
        $previousState = @{
            Status = $adapter.Status
            Name = $adapter.Name
        }
        
        Register-NetworkChange -ChangeType "AdapterRestart" -PreviousState $previousState -NewState @{}
        
        Restart-NetAdapter -Name $Name -ErrorAction Stop
        
        $result.Message = "Adapter $Name restarted successfully"
        Write-Log -Level "SUCCESS" -Category "Network" -Message $result.Message
        
        Write-OperationLog -Operation "Restart-NetworkAdapter" -Target $Name -Result "Success"
        
    } catch {
        $result.Success = $false
        $result.Message = $_.Exception.Message
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "Network" -Message "Failed to restart adapter $Name : $($_.Exception.Message)"
    }
    
    return $result
}

function global:Invoke-CompleteAdapterReset {
    <#
    .SYNOPSIS
        Performs a complete network stack reset (netcfg -d equivalent).
        WARNING: This removes all network adapters and requires reinstall.
    #>
    param(
        [switch]$Preview,
        [switch]$Force
    )
    
    $result = @{
        Success = $true
        Message = ""
        Errors = @()
    }
    
    if (-not $Force) {
        Write-Log -Level "WARNING" -Category "Network" -Message "Complete adapter reset requires -Force parameter"
        $result.Message = "This operation removes all network adapters. Use -Force to proceed."
        $result.Success = $false
        return $result
    }
    
    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Message = "Administrator privileges required"
        return $result
    }
    
    Write-Log -Level "WARNING" -Category "Network" -Message "WARNING: Performing complete network adapter reset!"
    
    if ($Preview) {
        $result.Message = "[PREVIEW] Would perform complete network stack reset (netcfg -d)"
        return $result
    }
    
    try {
        # Backup current configuration
        $adapters = Get-NetworkAdapterInfo -IncludeDisabled -IncludeVirtual
        $backupPath = Join-Path $script:Paths.Backups "NetworkConfig_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
        $adapters | ConvertTo-Json -Depth 5 | Set-Content $backupPath
        
        Write-Log -Level "INFO" -Category "Network" -Message "Network configuration backed up to: $backupPath"
        
        # Execute reset
        $output = & netcfg -d 2>&1
        
        $result.Message = "Complete network reset executed. System restart required."
        Write-Log -Level "WARNING" -Category "Network" -Message "Complete network adapter reset finished. Restart required."
        
    } catch {
        $result.Success = $false
        $result.Message = $_.Exception.Message
        $result.Errors += $_.Exception.Message
    }
    
    return $result
}

# ============================================================================
# ADAPTER CONFIGURATION
# ============================================================================

function global:Set-AdapterDNS {
    <#
    .SYNOPSIS
        Sets DNS servers for a network adapter.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$InterfaceAlias,
        
        [string[]]$DNSServers,
        
        [switch]$ResetToDHCP,
        [switch]$Preview
    )
    
    $result = @{
        Success = $true
        Interface = $InterfaceAlias
        PreviousDNS = @()
        NewDNS = @()
        Message = ""
        Errors = @()
    }
    
    try {
        # Get current DNS
        $currentDNS = Get-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -ErrorAction Stop
        $result.PreviousDNS = $currentDNS.ServerAddresses
        
        if ($Preview) {
            if ($ResetToDHCP) {
                $result.Message = "[PREVIEW] Would reset DNS to DHCP for $InterfaceAlias"
            } else {
                $result.Message = "[PREVIEW] Would set DNS to $($DNSServers -join ', ') for $InterfaceAlias"
            }
            return $result
        }
        
        if ($ResetToDHCP) {
            Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ResetServerAddresses -ErrorAction Stop
            $result.NewDNS = @("DHCP")
            $result.Message = "DNS reset to DHCP for $InterfaceAlias"
        } else {
            Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $DNSServers -ErrorAction Stop
            $result.NewDNS = $DNSServers
            $result.Message = "DNS set to $($DNSServers -join ', ') for $InterfaceAlias"
        }
        
        Write-Log -Level "SUCCESS" -Category "Network" -Message $result.Message
        
    } catch {
        $result.Success = $false
        $result.Message = $_.Exception.Message
        $result.Errors += $_.Exception.Message
    }
    
    return $result
}

function global:Set-AdapterStaticIP {
    <#
    .SYNOPSIS
        Sets a static IP address for a network adapter.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$InterfaceAlias,
        
        [Parameter(Mandatory=$true)]
        [string]$IPAddress,
        
        [Parameter(Mandatory=$true)]
        [int]$PrefixLength,
        
        [string]$DefaultGateway,
        
        [string[]]$DNSServers,
        
        [switch]$Preview
    )
    
    $result = @{
        Success = $true
        Interface = $InterfaceAlias
        PreviousIP = $null
        NewIP = $IPAddress
        Message = ""
        Errors = @()
    }
    
    try {
        # Get current configuration
        $currentConfig = Get-NetIPConfiguration -InterfaceAlias $InterfaceAlias -ErrorAction Stop
        $result.PreviousIP = $currentConfig.IPv4Address.IPAddress
        
        if ($Preview) {
            $result.Message = "[PREVIEW] Would set static IP $IPAddress/$PrefixLength for $InterfaceAlias"
            return $result
        }
        
        # Remove existing IP
        Remove-NetIPAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
        
        # Set new IP
        $params = @{
            InterfaceAlias = $InterfaceAlias
            IPAddress = $IPAddress
            PrefixLength = $PrefixLength
        }
        
        if ($DefaultGateway) {
            $params['DefaultGateway'] = $DefaultGateway
        }
        
        New-NetIPAddress @params -ErrorAction Stop
        
        # Set DNS if provided
        if ($DNSServers) {
            Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $DNSServers -ErrorAction Stop
        }
        
        $result.Message = "Static IP $IPAddress/$PrefixLength set for $InterfaceAlias"
        Write-Log -Level "SUCCESS" -Category "Network" -Message $result.Message
        
    } catch {
        $result.Success = $false
        $result.Message = $_.Exception.Message
        $result.Errors += $_.Exception.Message
    }
    
    return $result
}

function global:Set-AdapterDHCP {
    <#
    .SYNOPSIS
        Enables DHCP for a network adapter.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$InterfaceAlias,
        
        [switch]$Preview
    )
    
    $result = @{
        Success = $true
        Interface = $InterfaceAlias
        Message = ""
        Errors = @()
    }
    
    try {
        if ($Preview) {
            $result.Message = "[PREVIEW] Would enable DHCP for $InterfaceAlias"
            return $result
        }
        
        # Remove static IP
        Remove-NetIPAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
        Remove-NetRoute -InterfaceAlias $InterfaceAlias -DestinationPrefix "0.0.0.0/0" -Confirm:$false -ErrorAction SilentlyContinue
        
        # Enable DHCP
        Set-NetIPInterface -InterfaceAlias $InterfaceAlias -Dhcp Enabled -ErrorAction Stop
        
        # Reset DNS to DHCP
        Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ResetServerAddresses -ErrorAction SilentlyContinue
        
        $result.Message = "DHCP enabled for $InterfaceAlias"
        Write-Log -Level "SUCCESS" -Category "Network" -Message $result.Message
        
    } catch {
        $result.Success = $false
        $result.Message = $_.Exception.Message
        $result.Errors += $_.Exception.Message
    }
    
    return $result
}

# ============================================================================
# ADAPTER DIAGNOSTICS
# ============================================================================

function global:Test-NetworkAdapter {
    <#
    .SYNOPSIS
        Performs diagnostic tests on a network adapter.
    #>
    param(
        [string]$InterfaceAlias,
        
        [string[]]$PingTargets = @("8.8.8.8", "1.1.1.1", "google.com"),
        
        [int]$PingCount = 4
    )
    
    $result = @{
        Success = $true
        Adapter = $InterfaceAlias
        Tests = @{}
        Summary = ""
        Issues = @()
    }
    
    try {
        $adapter = Get-NetAdapter -Name $InterfaceAlias -ErrorAction Stop
        
        # Test 1: Adapter Status
        $result.Tests.Status = @{
            Status = $adapter.Status
            LinkSpeed = $adapter.LinkSpeed
            Pass = ($adapter.Status -eq 'Up')
        }
        
        # Test 2: IP Address
        $ipConfig = Get-NetIPConfiguration -InterfaceAlias $InterfaceAlias -ErrorAction SilentlyContinue
        $result.Tests.IPAddress = @{
            IPv4Address = $ipConfig.IPv4Address.IPAddress
            HasValidIP = ($ipConfig.IPv4Address.IPAddress -ne $null)
            Pass = ($ipConfig.IPv4Address.IPAddress -ne $null)
        }
        
        # Test 3: Gateway
        $result.Tests.Gateway = @{
            Gateway = $ipConfig.IPv4DefaultGateway.NextHop
            HasGateway = ($ipConfig.IPv4DefaultGateway -ne $null)
            Pass = ($ipConfig.IPv4DefaultGateway -ne $null)
        }
        
        # Test 4: DNS
        $dnsSettings = Get-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue
        $result.Tests.DNS = @{
            Servers = $dnsSettings.ServerAddresses
            HasDNS = ($dnsSettings.ServerAddresses.Count -gt 0)
            Pass = ($dnsSettings.ServerAddresses.Count -gt 0)
        }
        
        # Test 5: Connectivity
        $pingResults = @()
        foreach ($target in $PingTargets) {
            try {
                $ping = Test-Connection -ComputerName $target -Count $PingCount -ErrorAction SilentlyContinue
                $avgLatency = ($ping | Measure-Object -Property ResponseTime -Average).Average
                
                $pingResults += @{
                    Target = $target
                    Success = ($ping.Count -gt 0)
                    AvgLatency = [math]::Round($avgLatency, 2)
                }
            } catch {
                $pingResults += @{
                    Target = $target
                    Success = $false
                    AvgLatency = 0
                }
            }
        }
        
        $result.Tests.Connectivity = @{
            Results = $pingResults
            AllTargetsReachable = ($pingResults | Where-Object { $_.Success }).Count -eq $PingTargets.Count
            Pass = (($pingResults | Where-Object { $_.Success }).Count -gt 0)
        }
        
        # Test 6: DNS Resolution
        try {
            $dnsResolve = Resolve-DnsName -Name "google.com" -ErrorAction Stop
            $result.Tests.DNSResolution = @{
                Resolved = $true
                Pass = $true
            }
        } catch {
            $result.Tests.DNSResolution = @{
                Resolved = $false
                Pass = $false
                Error = $_.Exception.Message
            }
        }
        
        # Generate summary
        $allPassed = ($result.Tests.Values.Pass -notcontains $false)
        $result.Success = $allPassed
        
        if ($allPassed) {
            $result.Summary = "All tests passed"
        } else {
            $failedTests = $result.Tests.Keys | Where-Object { -not $result.Tests[$_].Pass }
            $result.Summary = "Failed tests: $($failedTests -join ', ')"
            $result.Issues = $failedTests
        }
        
    } catch {
        $result.Success = $false
        $result.Summary = $_.Exception.Message
    }
    
    return $result
}

function global:Get-AdapterTroubleshootingReport {
    <#
    .SYNOPSIS
        Generates a troubleshooting report for network adapters.
    #>
    param([string]$InterfaceAlias)
    
    $report = @{
        GeneratedAt = Get-Date
        Adapter = $null
        Configuration = @{}
        Diagnostics = @{}
        Issues = @()
        Recommendations = @()
    }
    
    # Get adapter info
    $report.Adapter = Get-NetworkAdapterInfo -Name $InterfaceAlias
    
    if (-not $report.Adapter) {
        $report.Issues += "Adapter not found"
        return $report
    }
    
    # Run diagnostics
    $report.Diagnostics = Test-NetworkAdapter -InterfaceAlias $InterfaceAlias
    
    # Analyze and generate recommendations
    if ($report.Adapter.Status -ne 'Up') {
        $report.Issues += "Adapter is not connected"
        $report.Recommendations += "Check physical connection or restart adapter"
    }
    
    if (-not $report.Diagnostics.Tests.IPAddress.HasValidIP) {
        $report.Issues += "No valid IP address"
        $report.Recommendations += "Check DHCP server or set static IP"
    }
    
    if (-not $report.Diagnostics.Tests.Gateway.HasGateway) {
        $report.Issues += "No default gateway configured"
        $report.Recommendations += "Configure gateway or check router"
    }
    
    if (-not $report.Diagnostics.Tests.DNS.HasDNS) {
        $report.Issues += "No DNS servers configured"
        $report.Recommendations += "Configure DNS servers (8.8.8.8, 1.1.1.1)"
    }
    
    if (-not $report.Diagnostics.Tests.Connectivity.Pass) {
        $report.Issues += "No network connectivity"
        $report.Recommendations += "Check firewall, router, or ISP connection"
    }
    
    if (-not $report.Diagnostics.Tests.DNSResolution.Pass) {
        $report.Issues += "DNS resolution failed"
        $report.Recommendations += "Verify DNS server settings or try alternative DNS"
    }
    
    # Check for packet errors
    if ($report.Adapter.ReceivedDiscarded -gt 100 -or $report.Adapter.OutboundDiscarded -gt 100) {
        $report.Issues += "High packet discard rate detected"
        $report.Recommendations += "Update network driver or check for interference"
    }
    
    return $report
}
