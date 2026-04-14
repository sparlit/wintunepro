#Requires -Version 5.1
<#
.SYNOPSIS
    TCP/IP Stack Module
.DESCRIPTION
    TCP/IP stack management functions including reset, backup,
    configuration, and performance optimization.
#>

function global:Reset-TCPIPStack {
    <#
    .SYNOPSIS
        Resets the TCP/IP stack to default state.
    #>
    param(
        [switch]$Backup,
        [switch]$Force
    )

    $result = @{
        Success = $false
        Message = ""
        BackupPath = ""
    }

    if (-not $Force) {
        Write-Log -Level "WARNING" -Category "TCPIP" -Message "Use -Force to confirm TCP/IP stack reset. This will require a reboot."
        $result.Message = "TCP/IP reset cancelled. Use -Force to confirm."
        return $result
    }

    Write-Log -Level "INFO" -Category "TCPIP" -Message "Resetting TCP/IP stack..."

    try {
        if ($Backup) {
            $backupResult = Backup-TCPIPConfig
            if ($backupResult.Success) {
                $result.BackupPath = $backupResult.BackupPath
                Write-Log -Level "SUCCESS" -Category "TCPIP" -Message "TCP/IP backup created at $($backupResult.BackupPath)"
            }
        }

        $netshOutput = netsh int ip reset 2>&1
        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0) {
            $result.Success = $true
            $result.Message = "TCP/IP stack reset successfully. Reboot required."
            Write-Log -Level "SUCCESS" -Category "TCPIP" -Message $result.Message
        } else {
            $result.Message = "TCP/IP reset failed with exit code $exitCode. Output: $netshOutput"
            Write-Log -Level "ERROR" -Category "TCPIP" -Message $result.Message
        }
    } catch {
        $result.Message = "Error resetting TCP/IP stack: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "TCPIP" -Message $result.Message
    }

    return $result
}

function global:Backup-TCPIPConfig {
    <#
    .SYNOPSIS
        Creates a backup of the current TCP/IP configuration.
    #>
    $result = @{
        Success = $false
        Message = ""
        BackupPath = ""
        FilesCreated = @()
    }

    try {
        $backupDir = "$env:TEMP\WinTunePro\Backups\TCPIP"
        if (-not (Test-Path $backupDir)) {
            New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
        }

        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

        $ipFile = Join-Path $backupDir "ipconfig_$timestamp.txt"
        ipconfig /all 2>&1 | Out-File -FilePath $ipFile -Encoding UTF8
        $result.FilesCreated += $ipFile

        $routeFile = Join-Path $backupDir "route_$timestamp.txt"
        route print 2>&1 | Out-File -FilePath $routeFile -Encoding UTF8
        $result.FilesCreated += $routeFile

        $tcpFile = Join-Path $backupDir "tcp_registry_$timestamp.reg"
        reg export "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" $tcpFile /y 2>$null
        if (Test-Path $tcpFile) {
            $result.FilesCreated += $tcpFile
        }

        $adapterFile = Join-Path $backupDir "adapters_$timestamp.txt"
        Get-NetAdapter -ErrorAction SilentlyContinue | Format-List * | Out-File -FilePath $adapterFile -Encoding UTF8
        $result.FilesCreated += $adapterFile

        $dnsFile = Join-Path $backupDir "dns_cache_$timestamp.txt"
        ipconfig /displaydns 2>&1 | Out-File -FilePath $dnsFile -Encoding UTF8
        $result.FilesCreated += $dnsFile

        $result.Success = $true
        $result.BackupPath = $backupDir
        $result.Message = "TCP/IP configuration backed up to $backupDir ($($result.FilesCreated.Count) files)"
        Write-Log -Level "SUCCESS" -Category "TCPIP" -Message $result.Message
    } catch {
        $result.Message = "Error backing up TCP/IP configuration: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "TCPIP" -Message $result.Message
    }

    return $result
}

function global:Optimize-TCPIPSettings {
    <#
    .SYNOPSIS
        Optimizes TCP/IP settings for better network performance.
    #>
    param(
        [switch]$Preview,
        [switch]$OptimizeAutoTuning,
        [switch]$OptimizeReceiveBuffers,
        [switch]$DisableChimney
    )

    $result = @{
        Success = $true
        Message = ""
        Changes = @()
        Errors = @()
    }

    if ($Preview) {
        $result.Message = "[PREVIEW] Would optimize TCP/IP settings"
        $result.Changes = @(
            "Optimize auto-tuning level",
            "Optimize receive buffers",
            "Disable chimney offload"
        )
        return $result
    }

    Write-Log -Level "INFO" -Category "TCPIP" -Message "Optimizing TCP/IP settings..."

    if ($OptimizeAutoTuning -or (-not $PSBoundParameters.ContainsKey('OptimizeAutoTuning'))) {
        try {
            netsh int tcp set global autotuninglevel=normal 2>$null
            $result.Changes += "Set TCP auto-tuning to normal"
        } catch {
            $result.Errors += "Auto-tuning: $($_.Exception.Message)"
        }
    }

    if ($DisableChimney -or (-not $PSBoundParameters.ContainsKey('DisableChimney'))) {
        try {
            netsh int tcp set global chimney=disabled 2>$null
            $result.Changes += "Disabled TCP chimney offload"
        } catch {
            $result.Errors += "Chimney: $($_.Exception.Message)"
        }
    }

    try {
        netsh int tcp set global rsc=enabled 2>$null
        $result.Changes += "Enabled receive segment coalescing"
    } catch {
        $result.Errors += "RSC: $($_.Exception.Message)"
    }

    try {
        netsh int tcp set global rss=enabled 2>$null
        $result.Changes += "Enabled receive side scaling"
    } catch {
        $result.Errors += "RSS: $($_.Exception.Message)"
    }

    try {
        netsh int tcp set global timestamps=disabled 2>$null
        $result.Changes += "Disabled TCP timestamps"
    } catch {
        $result.Errors += "Timestamps: $($_.Exception.Message)"
    }

    try {
        $tcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
        Set-ItemProperty -Path $tcpPath -Name "TcpWindowSize" -Value 65535 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $tcpPath -Name "TcpMaxDataRetransmissions" -Value 5 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $tcpPath -Name "Tcp1323Opts" -Value 3 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $tcpPath -Name "TcpDelAckTicks" -Value 0 -Force -ErrorAction SilentlyContinue
        $result.Changes += "Applied TCP registry optimizations"
    } catch {
        $result.Errors += "Registry: $($_.Exception.Message)"
    }

    if ($result.Errors.Count -gt 0) {
        $result.Success = $false
        $result.Message = "TCP/IP optimization completed with $($result.Errors.Count) errors"
        Write-Log -Level "WARNING" -Category "TCPIP" -Message $result.Message
    } else {
        $result.Message = "TCP/IP optimization complete: $($result.Changes.Count) changes"
        Write-Log -Level "SUCCESS" -Category "TCPIP" -Message $result.Message
    }

    return $result
}

function global:Get-TCPIPConfiguration {
    <#
    .SYNOPSIS
        Gets current TCP/IP configuration and optimization status.
    #>
    $config = @{
        AutoTuningLevel = "Unknown"
        ChimneyOffload = "Unknown"
        RSC = "Unknown"
        RSS = "Unknown"
        Timestamps = "Unknown"
        TcpWindowSize = "Unknown"
        TcpMaxDataRetransmissions = "Unknown"
        Tcp1323Opts = "Unknown"
        NetworkAdapters = @()
    }

    try {
        $autoTuning = netsh int tcp show global 2>&1
        foreach ($line in $autoTuning) {
            if ($line -match "Receive-Side Scaling State\s+:\s+(.+)$") {
                $config.RSS = $Matches[1].Trim()
            } elseif ($line -match "Receive Segment Coalescing State\s+:\s+(.+)$") {
                $config.RSC = $Matches[1].Trim()
            } elseif ($line -match "Chimney Offload State\s+:\s+(.+)$") {
                $config.ChimneyOffload = $Matches[1].Trim()
            } elseif ($line -match "TCP Timestamps\s+:\s+(.+)$") {
                $config.Timestamps = $Matches[1].Trim()
            }
        }
    } catch {
        Write-Log -Level "WARNING" -Category "TCPIP" -Message "Error reading TCP global settings: $($_.Exception.Message)"
    }

    try {
        $tcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
        $tcpReg = Get-ItemProperty -Path $tcpPath -ErrorAction SilentlyContinue
        if ($tcpReg) {
            $config.TcpWindowSize = if ($tcpReg.TcpWindowSize) { $tcpReg.TcpWindowSize } else { "Default" }
            $config.TcpMaxDataRetransmissions = if ($tcpReg.TcpMaxDataRetransmissions) { $tcpReg.TcpMaxDataRetransmissions } else { "Default" }
            $config.Tcp1323Opts = if ($tcpReg.Tcp1323Opts) { $tcpReg.Tcp1323Opts } else { "Default" }
        }
    } catch {
        Write-Log -Level "WARNING" -Category "TCPIP" -Message "Error reading TCP registry settings: $($_.Exception.Message)"
    }

    try {
        $adapters = Get-NetAdapter -ErrorAction SilentlyContinue
        foreach ($adapter in $adapters) {
            $config.NetworkAdapters += @{
                Name = $adapter.Name
                Status = $adapter.Status
                LinkSpeed = $adapter.LinkSpeed
                MediaType = $adapter.MediaType
                InterfaceDescription = $adapter.InterfaceDescription
            }
        }
    } catch {
        Write-Log -Level "WARNING" -Category "TCPIP" -Message "Error reading network adapters: $($_.Exception.Message)"
    }

    return $config
}
