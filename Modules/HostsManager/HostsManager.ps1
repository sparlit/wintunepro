#Requires -Version 5.1
<#
.SYNOPSIS
    WinTune Pro HostsManager Module - Hosts file management
.DESCRIPTION
    Hosts file management, blocking, backup, and integrity validation
#>

$global:HostsFilePath = "C:\Windows\System32\drivers\etc\hosts"
$global:DefaultHostsContent = @"
# Copyright (c) 1993-2009 Microsoft Corp.
#
# This is a sample HOSTS file used by Microsoft TCP/IP for Windows.
#
127.0.0.1       localhost
::1             localhost
"@

function global:Get-HostsFileContent {
    <#
    .SYNOPSIS
        Reads and parses the hosts file.
    #>

    $result = @{
        Success   = $true
        Entries   = @()
        Comments  = @()
        Lines     = @()
        Error     = $null
    }

    if (-not (Test-Path $global:HostsFilePath)) {
        Write-Log -Level "ERROR" -Category "HostsManager" -Message "Hosts file not found"
        $result.Success = $false
        $result.Error = "Hosts file not found"
        return $result
    }

    try {
        $content = Get-Content -Path $global:HostsFilePath -ErrorAction Stop
        $result.Lines = $content

        foreach ($line in $content) {
            $trimmed = $line.Trim()
            if ([string]::IsNullOrEmpty($trimmed) -or $trimmed.StartsWith("#")) {
                if (-not [string]::IsNullOrEmpty($trimmed)) {
                    $result.Comments += $trimmed
                }
                continue
            }

            $parts = $trimmed -split '\s+' | Where-Object { -not [string]::IsNullOrEmpty($_) }
            if ($parts.Count -ge 2) {
                $result.Entries += [PSCustomObject]@{
                    IP      = $parts[0]
                    Hostname = $parts[1]
                    Comment  = if ($parts.Count -gt 2) { ($parts[2..($parts.Count-1)] -join ' ') } else { "" }
                    Line     = $trimmed
                }
            }
        }

        Write-Log -Level "INFO" -Category "HostsManager" -Message "Parsed hosts file: $($result.Entries.Count) entries, $($result.Comments.Count) comments"
    } catch {
        Write-Log -Level "ERROR" -Category "HostsManager" -Message "Error reading hosts file: $($_.Exception.Message)"
        $result.Success = $false
        $result.Error = $_.Exception.Message
    }

    return $result
}

function global:Add-HostsEntry {
    <#
    .SYNOPSIS
        Adds an entry to the hosts file.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$IP,
        [Parameter(Mandatory = $true)]
        [string]$Hostname,
        [string]$Comment = "",
        [switch]$Preview
    )

    $result = @{
        Success  = $true
        Added    = $false
        Error    = $null
    }

    if (-not $script:State.IsElevated) {
        Write-Log -Level "ERROR" -Category "HostsManager" -Message "Admin privileges required to modify hosts file"
        $result.Success = $false
        $result.Error = "Admin privileges required"
        return $result
    }

    $current = Get-HostsFileContent
    $existing = $current.Entries | Where-Object { $_.Hostname -eq $Hostname -and $_.IP -eq $IP }

    if ($existing) {
        Write-Log -Level "INFO" -Category "HostsManager" -Message "Entry already exists: $IP $Hostname"
        return $result
    }

    $newLine = "$IP`t$Hostname"
    if ($Comment) {
        $newLine += "`t# $Comment"
    }

    if ($Preview) {
        Write-Log -Level "INFO" -Category "HostsManager" -Message "[Preview] Would add: $newLine"
        return $result
    }

    try {
        Add-Content -Path $global:HostsFilePath -Value $newLine -Encoding UTF8 -ErrorAction Stop
        $result.Added = $true
        Write-Log -Level "SUCCESS" -Category "HostsManager" -Message "Added hosts entry: $IP $Hostname"
    } catch {
        Write-Log -Level "ERROR" -Category "HostsManager" -Message "Error adding hosts entry: $($_.Exception.Message)"
        $result.Success = $false
        $result.Error = $_.Exception.Message
    }

    return $result
}

function global:Remove-HostsEntry {
    <#
    .SYNOPSIS
        Removes an entry by hostname or IP.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Hostname,
        [string]$IP = "",
        [switch]$Preview
    )

    $result = @{
        Success  = $true
        Removed  = $false
        Error    = $null
    }

    if (-not $script:State.IsElevated) {
        Write-Log -Level "ERROR" -Category "HostsManager" -Message "Admin privileges required to modify hosts file"
        $result.Success = $false
        $result.Error = "Admin privileges required"
        return $result
    }

    try {
        $content = Get-Content -Path $global:HostsFilePath -ErrorAction Stop
        $newContent = @()
        $found = $false

        foreach ($line in $content) {
            $trimmed = $line.Trim()
            if ($trimmed -match "^\s*#" -or [string]::IsNullOrEmpty($trimmed)) {
                $newContent += $line
                continue
            }

            $parts = $trimmed -split '\s+' | Where-Object { -not [string]::IsNullOrEmpty($_) }
            if ($parts.Count -ge 2) {
                $matchHostname = $parts[1] -eq $Hostname
                $matchIP = [string]::IsNullOrEmpty($IP) -or $parts[0] -eq $IP

                if ($matchHostname -and $matchIP) {
                    $found = $true
                    if ($Preview) {
                        Write-Log -Level "INFO" -Category "HostsManager" -Message "[Preview] Would remove: $line"
                    }
                    continue
                }
            }

            $newContent += $line
        }

        if (-not $found) {
            Write-Log -Level "INFO" -Category "HostsManager" -Message "Entry not found: $Hostname"
            return $result
        }

        if (-not $Preview) {
            $newContent | Out-File -FilePath $global:HostsFilePath -Encoding UTF8 -Force
            $result.Removed = $true
            Write-Log -Level "SUCCESS" -Category "HostsManager" -Message "Removed hosts entry: $Hostname"
        }
    } catch {
        Write-Log -Level "ERROR" -Category "HostsManager" -Message "Error removing hosts entry: $($_.Exception.Message)"
        $result.Success = $false
        $result.Error = $_.Exception.Message
    }

    return $result
}

function global:Block-HostsDomain {
    <#
    .SYNOPSIS
        Adds a 127.0.0.1 redirect for a domain.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Domain,
        [string]$Comment = "Blocked by WinTune",
        [switch]$Preview
    )

    return Add-HostsEntry -IP "127.0.0.1" -Hostname $Domain -Comment $Comment -Preview:$Preview
}

function global:Unblock-HostsDomain {
    <#
    .SYNOPSIS
        Removes a domain block.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Domain,
        [switch]$Preview
    )

    return Remove-HostsEntry -Hostname $Domain -IP "127.0.0.1" -Preview:$Preview
}

function global:Import-HostsBlocklist {
    <#
    .SYNOPSIS
        Imports a blocklist from URL or file.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,
        [switch]$Preview
    )

    $result = @{
        Success       = $true
        DomainsAdded  = 0
        Error         = $null
    }

    if (-not $script:State.IsElevated) {
        Write-Log -Level "ERROR" -Category "HostsManager" -Message "Admin privileges required to import blocklist"
        $result.Success = $false
        $result.Error = "Admin privileges required"
        return $result
    }

    $lines = @()

    try {
        if ($Source -match "^https?://") {
            Write-Log -Level "INFO" -Category "HostsManager" -Message "Downloading blocklist from: $Source"
            $webClient = New-Object System.Net.WebClient
            $content = $webClient.DownloadString($Source)
            $lines = $content -split "`n"
        } elseif (Test-Path $Source) {
            Write-Log -Level "INFO" -Category "HostsManager" -Message "Reading blocklist from file: $Source"
            $lines = Get-Content -Path $Source -ErrorAction Stop
        } else {
            $result.Success = $false
            $result.Error = "Source not found: $Source"
            Write-Log -Level "ERROR" -Category "HostsManager" -Message "Blocklist source not found: $Source"
            return $result
        }

        $current = Get-HostsFileContent
        $existingHostnames = $current.Entries | ForEach-Object { $_.Hostname }

        foreach ($line in $lines) {
            $trimmed = $line.Trim()
            if ([string]::IsNullOrEmpty($trimmed) -or $trimmed.StartsWith("#")) { continue }

            $parts = $trimmed -split '\s+' | Where-Object { -not [string]::IsNullOrEmpty($_) }
            if ($parts.Count -ge 2 -and $parts[0] -eq "127.0.0.1") {
                $domain = $parts[1]
                if ($existingHostnames -notcontains $domain) {
                    $addResult = Add-HostsEntry -IP "127.0.0.1" -Hostname $domain -Comment "Blocklist import" -Preview:$Preview
                    if ($addResult.Success -and $addResult.Added) {
                        $result.DomainsAdded++
                    }
                }
            } elseif ($parts.Count -eq 1 -and $trimmed -notmatch "^#") {
                $domain = $parts[0]
                if ($existingHostnames -notcontains $domain) {
                    $addResult = Add-HostsEntry -IP "127.0.0.1" -Hostname $domain -Comment "Blocklist import" -Preview:$Preview
                    if ($addResult.Success -and $addResult.Added) {
                        $result.DomainsAdded++
                    }
                }
            }
        }

        Write-Log -Level "SUCCESS" -Category "HostsManager" -Message "Imported $($result.DomainsAdded) domains from blocklist"
    } catch {
        Write-Log -Level "ERROR" -Category "HostsManager" -Message "Error importing blocklist: $($_.Exception.Message)"
        $result.Success = $false
        $result.Error = $_.Exception.Message
    }

    return $result
}

function global:Export-HostsBackup {
    <#
    .SYNOPSIS
        Creates a backup of the current hosts file.
    #>
    param(
        [string]$BackupPath = ""
    )

    $result = @{
        Success    = $true
        BackupPath = ""
        Error      = $null
    }

    if (-not (Test-Path $global:HostsFilePath)) {
        Write-Log -Level "ERROR" -Category "HostsManager" -Message "Hosts file not found - nothing to backup"
        $result.Success = $false
        $result.Error = "Hosts file not found"
        return $result
    }

    if ([string]::IsNullOrEmpty($BackupPath)) {
        $BackupPath = "$env:TEMP\hosts_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').bak"
    }

    try {
        Copy-Item -Path $global:HostsFilePath -Destination $BackupPath -Force -ErrorAction Stop
        $result.BackupPath = $BackupPath
        Write-Log -Level "SUCCESS" -Category "HostsManager" -Message "Hosts file backed up to: $BackupPath"
    } catch {
        Write-Log -Level "ERROR" -Category "HostsManager" -Message "Error backing up hosts file: $($_.Exception.Message)"
        $result.Success = $false
        $result.Error = $_.Exception.Message
    }

    return $result
}

function global:Restore-HostsBackup {
    <#
    .SYNOPSIS
        Restores the hosts file from a backup.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$BackupPath,
        [switch]$Preview
    )

    $result = @{
        Success = $true
        Error   = $null
    }

    if (-not $script:State.IsElevated) {
        Write-Log -Level "ERROR" -Category "HostsManager" -Message "Admin privileges required to restore hosts file"
        $result.Success = $false
        $result.Error = "Admin privileges required"
        return $result
    }

    if (-not (Test-Path $BackupPath)) {
        Write-Log -Level "ERROR" -Category "HostsManager" -Message "Backup file not found: $BackupPath"
        $result.Success = $false
        $result.Error = "Backup file not found"
        return $result
    }

    if ($Preview) {
        Write-Log -Level "INFO" -Category "HostsManager" -Message "[Preview] Would restore hosts from: $BackupPath"
        return $result
    }

    try {
        Copy-Item -Path $BackupPath -Destination $global:HostsFilePath -Force -ErrorAction Stop
        Write-Log -Level "SUCCESS" -Category "HostsManager" -Message "Hosts file restored from: $BackupPath"
    } catch {
        Write-Log -Level "ERROR" -Category "HostsManager" -Message "Error restoring hosts file: $($_.Exception.Message)"
        $result.Success = $false
        $result.Error = $_.Exception.Message
    }

    return $result
}

function global:Test-HostsIntegrity {
    <#
    .SYNOPSIS
        Validates the hosts file format.
    #>

    $result = @{
        Valid          = $true
        TotalLines     = 0
        ValidEntries   = 0
        InvalidLines   = @()
        Duplicates     = @()
        Error          = $null
    }

    if (-not (Test-Path $global:HostsFilePath)) {
        Write-Log -Level "ERROR" -Category "HostsManager" -Message "Hosts file not found"
        $result.Valid = $false
        $result.Error = "Hosts file not found"
        return $result
    }

    try {
        $content = Get-Content -Path $global:HostsFilePath -ErrorAction Stop
        $result.TotalLines = $content.Count

        $seenEntries = @{}
        $lineNum = 0

        foreach ($line in $content) {
            $lineNum++
            $trimmed = $line.Trim()

            if ([string]::IsNullOrEmpty($trimmed) -or $trimmed.StartsWith("#")) { continue }

            $parts = $trimmed -split '\s+' | Where-Object { -not [string]::IsNullOrEmpty($_) }

            if ($parts.Count -lt 2) {
                $result.InvalidLines += "Line $lineNum : $trimmed"
                $result.Valid = $false
                continue
            }

            $ip = $parts[0]
            $hostname = $parts[1]

            if ($ip -notmatch "^(\d{1,3}\.){3}\d{1,3}$" -and $ip -ne "::1" -and $ip -ne "::0") {
                $result.InvalidLines += "Line $lineNum : Invalid IP '$ip'"
                $result.Valid = $false
                continue
            }

            $key = "$ip|$hostname"
            if ($seenEntries.ContainsKey($key)) {
                $result.Duplicates += "Line $lineNum : Duplicate entry $ip $hostname"
            } else {
                $seenEntries[$key] = $lineNum
            }

            $result.ValidEntries++
        }

        if ($result.InvalidLines.Count -eq 0 -and $result.Duplicates.Count -eq 0) {
            Write-Log -Level "SUCCESS" -Category "HostsManager" -Message "Hosts file integrity check passed"
        } else {
            Write-Log -Level "WARNING" -Category "HostsManager" -Message "Hosts file has $($result.InvalidLines.Count) invalid lines and $($result.Duplicates.Count) duplicates"
        }
    } catch {
        Write-Log -Level "ERROR" -Category "HostsManager" -Message "Error validating hosts file: $($_.Exception.Message)"
        $result.Valid = $false
        $result.Error = $_.Exception.Message
    }

    return $result
}

function global:Reset-HostsFile {
    <#
    .SYNOPSIS
        Resets the hosts file to Windows default.
    #>
    param(
        [switch]$Preview
    )

    $result = @{
        Success = $true
        Error   = $null
    }

    if (-not $script:State.IsElevated) {
        Write-Log -Level "ERROR" -Category "HostsManager" -Message "Admin privileges required to reset hosts file"
        $result.Success = $false
        $result.Error = "Admin privileges required"
        return $result
    }

    if ($Preview) {
        Write-Log -Level "INFO" -Category "HostsManager" -Message "[Preview] Would reset hosts file to Windows default"
        return $result
    }

    try {
        $backupResult = Export-HostsBackup
        if ($backupResult.Success) {
            Write-Log -Level "INFO" -Category "HostsManager" -Message "Backup created before reset: $($backupResult.BackupPath)"
        }

        $global:DefaultHostsContent | Out-File -FilePath $global:HostsFilePath -Encoding UTF8 -Force
        Write-Log -Level "SUCCESS" -Category "HostsManager" -Message "Hosts file reset to Windows default"
    } catch {
        Write-Log -Level "ERROR" -Category "HostsManager" -Message "Error resetting hosts file: $($_.Exception.Message)"
        $result.Success = $false
        $result.Error = $_.Exception.Message
    }

    return $result
}

function global:Get-HostsStatistics {
    <#
    .SYNOPSIS
        Counts entries, blocks, and comments in the hosts file.
    #>

    $result = @{
        TotalEntries  = 0
        BlockEntries  = 0
        RedirectEntries = 0
        Comments      = 0
        BlankLines    = 0
        TotalLines    = 0
        UniqueHosts   = @()
    }

    $content = Get-HostsFileContent
    if (-not $content.Success) { return $result }

    $result.TotalEntries = $content.Entries.Count
    $result.Comments = $content.Comments.Count
    $result.TotalLines = $content.Lines.Count

    foreach ($entry in $content.Entries) {
        if ($entry.IP -eq "127.0.0.1" -or $entry.IP -eq "::1" -or $entry.IP -eq "0.0.0.0") {
            $result.BlockEntries++
        } else {
            $result.RedirectEntries++
        }
    }

    $result.UniqueHosts = ($content.Entries | Select-Object -Property Hostname -Unique).Hostname
    $result.BlankLines = ($content.Lines | Where-Object { [string]::IsNullOrEmpty($_.Trim()) }).Count

    return $result
}
