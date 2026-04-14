<#
.SYNOPSIS
    WinTune Pro DNS Module - DNS operations
.DESCRIPTION
    DNS cache clearing and DNS configuration management
#>

function global:Clear-DNSCache {
    <#
    .SYNOPSIS
        Clears the DNS resolver cache.
    #>
    param([switch]$Preview)
    
    $result = @{
        Success = $true
        Message = ""
        EntriesCleared = 0
        Errors = @()
    }
    
    Write-Log -Level "INFO" -Category "Network" -Message "Clearing DNS cache..."
    
    if ($Preview) {
        try {
            $cache = Get-DnsClientCache -ErrorAction SilentlyContinue
            $result.EntriesCleared = ($cache | Measure-Object).Count
        } catch { Write-Log -Level "WARNING" -Category "Network" -Message $_.Exception.Message }
        $result.Message = "[PREVIEW] Would clear $($result.EntriesCleared) DNS cache entries"
        return $result
    }
    
    try {
        # Method 1: ipconfig
        $output = & ipconfig /flushdns 2>&1
        
        # Method 2: PowerShell
        Clear-DnsClientCache -ErrorAction SilentlyContinue
        
        $result.Message = "DNS cache cleared successfully"
        Write-Log -Level "SUCCESS" -Category "Network" -Message "DNS cache cleared"
        
    } catch {
        $result.Success = $false
        $result.Message = $_.Exception.Message
        $result.Errors += $_.Exception.Message
    }
    
    return $result
}

function global:Register-DNS {
    <#
    .SYNOPSIS
        Re-registers DNS names for this client.
    #>
    param([switch]$Preview)
    
    $result = @{
        Success = $true
        Message = ""
        Errors = @()
    }
    
    Write-Log -Level "INFO" -Category "Network" -Message "Registering DNS..."
    
    if ($Preview) {
        $result.Message = "[PREVIEW] Would register DNS"
        return $result
    }
    
    try {
        $output = & ipconfig /registerdns 2>&1
        $result.Message = "DNS registration initiated"
        Write-Log -Level "SUCCESS" -Category "Network" -Message "DNS registration initiated"
    } catch {
        $result.Success = $false
        $result.Message = $_.Exception.Message
        $result.Errors += $_.Exception.Message
    }
    
    return $result
}

function global:Get-DNSSettings {
    <#
    .SYNOPSIS
        Gets current DNS server settings for all adapters.
    #>
    param([string]$AdapterName = "")
    
    $dnsSettings = @()
    
    try {
        $adapters = Get-DnsClientServerAddress -ErrorAction SilentlyContinue
        
        if ($AdapterName -ne "") {
            $adapters = $adapters | Where-Object { $_.InterfaceAlias -like "*$AdapterName*" }
        }
        
        foreach ($adapter in $adapters) {
            if ($adapter.ServerAddresses.Count -gt 0) {
                $dnsSettings += [PSCustomObject]@{
                    Adapter = $adapter.InterfaceAlias
                    AddressFamily = if ($adapter.AddressFamily -eq 2) { "IPv4" } else { "IPv6" }
                    DNSServers = ($adapter.ServerAddresses -join ", ")
                }
            }
        }
    } catch {
        Write-Log -Level "WARNING" -Category "Network" -Message "Error getting DNS settings: $($_.Exception.Message)"
    }
    
    return $dnsSettings
}

# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Set-DNSServer removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)

# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
# Function Invoke-FlushDNS removed (duplicate of E:\WinTunePro\Modules\DNSOptimizer\DNSOptimizer.ps1)
