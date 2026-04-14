# WinTune Pro - DNS Optimizer Module
# PowerShell 5.1+ Compatible

function global:Get-DNSProviders {
    return @{
        Cloudflare = @{ Primary = "1.1.1.1"; Secondary = "1.0.0.1"; Name = "Cloudflare DNS" }
        Google = @{ Primary = "8.8.8.8"; Secondary = "8.8.4.4"; Name = "Google DNS" }
        Quad9 = @{ Primary = "9.9.9.9"; Secondary = "149.112.112.112"; Name = "Quad9 DNS" }
        OpenDNS = @{ Primary = "208.67.222.222"; Secondary = "208.67.220.220"; Name = "OpenDNS" }
        AdGuard = @{ Primary = "94.140.14.14"; Secondary = "94.140.15.15"; Name = "AdGuard DNS" }
        NextDNS = @{ Primary = "45.90.28.167"; Secondary = "45.90.30.167"; Name = "NextDNS" }
        ControlD = @{ Primary = "76.76.2.0"; Secondary = "76.76.10.0"; Name = "Control D" }
    }
}

function global:Get-CurrentDNS {
    $dns = @{ Primary = ""; Secondary = ""; Interface = ""; IsDHCP = $true }
    try {
        $adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
        if ($adapter) {
            $dns.Interface = $adapter.Name
            $dnsConfig = Get-DnsClientServerAddress -InterfaceAlias $adapter.Name -AddressFamily IPv4 -ErrorAction SilentlyContinue
            if ($dnsConfig -and $dnsConfig.ServerAddresses.Count -gt 0) {
                $dns.Primary = $dnsConfig.ServerAddresses[0]
                if ($dnsConfig.ServerAddresses.Count -gt 1) { $dns.Secondary = $dnsConfig.ServerAddresses[1] }
                $dns.IsDHCP = $false
            }
        }
    } catch { Write-Log $_.Exception.Message -Level 'WARNING' -Category 'System' }
    return $dns
}

function global:Set-DNSServer {
    param([string]$Primary, [string]$Secondary = "", [string]$InterfaceAlias = "")
    try {
        if ([string]::IsNullOrEmpty($InterfaceAlias)) { $adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1; if ($adapter) { $InterfaceAlias = $adapter.Name } }
        if ([string]::IsNullOrEmpty($Secondary)) { Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $Primary } else { Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $Primary, $Secondary }
        Log-Success "Set DNS to $Primary, $Secondary on $InterfaceAlias" -Category "DNS"
        return $true
    } catch { Log-Error "Failed to set DNS: $($_.Exception.Message)" -Category "DNS"; return $false }
}

function global:Reset-DNSToDHCP {
    param([string]$InterfaceAlias = "")
    try {
        if ([string]::IsNullOrEmpty($InterfaceAlias)) { $adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1; if ($adapter) { $InterfaceAlias = $adapter.Name } }
        Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ResetServerAddresses
        Log-Success "Reset DNS to DHCP on $InterfaceAlias" -Category "DNS"
        return $true
    } catch { Log-Error "Failed to reset DNS: $($_.Exception.Message)" -Category "DNS"; return $false }
}

function global:Invoke-DNSBenchmark {
    param([bool]$TestMode = $false)
    $results = @(); $providers = Get-DNSProviders
    if ($TestMode) { foreach ($provider in $providers.Keys) { $results += @{ Provider = $provider; Primary = $providers[$provider].Primary; ResponseTime = (Get-Random -Minimum 10 -Maximum 100); Success = $true } }; return $results | Sort-Object ResponseTime }
    foreach ($provider in $providers.Keys) {
        $dnsIP = $providers[$provider].Primary
        try {
            $measure = Measure-Command { $null = [System.Net.Dns]::GetHostEntry("google.com") }
            $ping = Test-Connection -ComputerName $dnsIP -Count 3 -ErrorAction SilentlyContinue
            $avgPing = if ($ping) { ($ping | Measure-Object -Property ResponseTime -Average).Average } else { 999 }
            $results += @{ Provider = $provider; Primary = $dnsIP; ResponseTime = [math]::Round($avgPing, 2); Success = $true }
        } catch { $results += @{ Provider = $provider; Primary = $dnsIP; ResponseTime = 999; Success = $false } }
    }
    return $results | Sort-Object ResponseTime
}

function global:Invoke-FlushDNS {
    try { ipconfig /flushdns | Out-Null; Log-Success "Flushed DNS cache" -Category "DNS"; return $true } catch { Log-Error "Failed to flush DNS: $($_.Exception.Message)" -Category "DNS"; return $false }
}

function global:Get-FastestDNS {
    param([bool]$TestMode = $false)
    $results = Invoke-DNSBenchmark -TestMode $TestMode; $fastest = $results | Where-Object { $_.Success } | Select-Object -First 1
    return $fastest
}
