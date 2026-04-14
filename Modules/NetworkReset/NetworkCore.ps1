# WinTune Pro - Network Reset Module
# PowerShell 5.1+ Compatible

function global:Get-NetworkAdapters {
    $adapters = @()
    Get-NetAdapter | ForEach-Object {
        $adapter = @{
            Name = $_.Name
            InterfaceDescription = $_.InterfaceDescription
            Status = $_.Status
            LinkSpeed = $_.LinkSpeed
            MacAddress = $_.MacAddress
            IPAddress = ""
            DNS = @()
        }
        $ip = Get-NetIPAddress -InterfaceAlias $_.Name -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($ip) { $adapter.IPAddress = $ip.IPAddress }
        $dns = Get-DnsClientServerAddress -InterfaceAlias $_.Name -AddressFamily IPv4 -ErrorAction SilentlyContinue
        if ($dns) { $adapter.DNS = $dns.ServerAddresses }
        $adapters += $adapter
    }
    return $adapters
}

function global:Get-DNSConfiguration {
    $config = @{ Primary = ""; Secondary = ""; Interface = "" }
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
    if ($adapters) {
        $config.Interface = $adapters.Name
        $dns = Get-DnsClientServerAddress -InterfaceAlias $adapters.Name -AddressFamily IPv4 -ErrorAction SilentlyContinue
        if ($dns -and $dns.ServerAddresses.Count -gt 0) {
            $config.Primary = $dns.ServerAddresses[0]
            if ($dns.ServerAddresses.Count -gt 1) { $config.Secondary = $dns.ServerAddresses[1] }
        }
    }
    return $config
}

function global:Invoke-NetworkReset {
    param(
        [bool]$ResetTCPIP = $true,
        [bool]$ResetWinsock = $true,
        [bool]$FlushDNS = $true,
        [bool]$ClearARP = $true,
        [bool]$TestMode = $false
    )
    $results = @{ Actions = @(); Success = $true }
    if ($TestMode) { $results.Actions += "Test Mode: Would reset network settings"; return $results }
    if ($FlushDNS) { try { ipconfig /flushdns | Out-Null; $results.Actions += "Flushed DNS cache" } catch { $results.Actions += "Failed to flush DNS: $($_.Exception.Message)" } }
    if ($ClearARP) { try { netsh interface ip delete arpcache | Out-Null; $results.Actions += "Cleared ARP cache" } catch { $results.Actions += "Failed to clear ARP cache" } }
    if ($ResetWinsock) { try { netsh winsock reset | Out-Null; $results.Actions += "Reset Winsock catalog" } catch { $results.Actions += "Failed to reset Winsock" } }
    if ($ResetTCPIP) { try { netsh int ip reset | Out-Null; $results.Actions += "Reset TCP/IP stack" } catch { $results.Actions += "Failed to reset TCP/IP" } }
    $results.Actions += "Note: A restart may be required for changes to take effect."
    return $results
}

function global:Invoke-NetworkTuning {
    param(
        [bool]$OptimizeTCP = $true,
        [bool]$SetDNS = $false,
        [string]$DNSPrimary = "8.8.8.8",
        [string]$DNSSecondary = "8.8.4.4",
        [bool]$TestMode = $false
    )
    $results = @{ Actions = @(); Success = $true }
    if ($TestMode) { $results.Actions += "Test Mode: Would tune network settings"; return $results }
    if ($SetDNS) { try { $adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1; if ($adapter) { Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ServerAddresses $DNSPrimary, $DNSSecondary; $results.Actions += "Set DNS servers" } } catch { $results.Actions += "Failed to set DNS: $($_.Exception.Message)" } }
    if ($OptimizeTCP) { try { netsh int tcp set global autotuninglevel=normal | Out-Null; $results.Actions += "Optimized TCP autotuning"; netsh int tcp set global ecncapability=enabled | Out-Null; $results.Actions += "Enabled ECN" } catch { $results.Actions += "Failed to optimize TCP: $($_.Exception.Message)" } }
    return $results
}

function global:Test-NetworkConnectivity {
    $results = @{ Internet = $false; DNS = $false; Latency = 0 }
    try { $ping = Test-Connection -ComputerName "8.8.8.8" -Count 1 -ErrorAction SilentlyContinue; if ($ping) { $results.Internet = $true; $results.Latency = $ping.ResponseTime } } catch { Write-Log $_.Exception.Message -Level 'WARNING' -Category 'System' }
    try { $dns = Resolve-DnsName -Name "google.com" -ErrorAction SilentlyContinue; if ($dns) { $results.DNS = $true } } catch { Write-Log $_.Exception.Message -Level 'WARNING' -Category 'System' }
    return $results
}
