#Requires -Version 5.1
<#
.SYNOPSIS
    Winsock Catalog Module
.DESCRIPTION
    Winsock catalog management functions including reset, backup,
    and provider enumeration.
#>

function global:Reset-WinsockCatalog {
    <#
    .SYNOPSIS
        Resets the Winsock catalog to default state.
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
        Write-Log -Level "WARNING" -Category "Winsock" -Message "Use -Force to confirm Winsock catalog reset. This will require a reboot."
        $result.Message = "Winsock reset cancelled. Use -Force to confirm."
        return $result
    }

    Write-Log -Level "INFO" -Category "Winsock" -Message "Resetting Winsock catalog..."

    try {
        if ($Backup) {
            $backupResult = Backup-WinsockState
            if ($backupResult.Success) {
                $result.BackupPath = $backupResult.BackupPath
                Write-Log -Level "SUCCESS" -Category "Winsock" -Message "Winsock backup created at $($backupResult.BackupPath)"
            }
        }

        $netshOutput = netsh winsock reset 2>&1
        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0) {
            $result.Success = $true
            $result.Message = "Winsock catalog reset successfully. Reboot required."
            Write-Log -Level "SUCCESS" -Category "Winsock" -Message $result.Message
        } else {
            $result.Message = "Winsock reset failed with exit code $exitCode. Output: $netshOutput"
            Write-Log -Level "ERROR" -Category "Winsock" -Message $result.Message
        }
    } catch {
        $result.Message = "Error resetting Winsock catalog: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "Winsock" -Message $result.Message
    }

    return $result
}

function global:Backup-WinsockState {
    <#
    .SYNOPSIS
        Creates a backup of the current Winsock catalog state.
    #>
    $result = @{
        Success = $false
        Message = ""
        BackupPath = ""
    }

    try {
        $backupDir = "$env:TEMP\WinTunePro\Backups\Winsock"
        if (-not (Test-Path $backupDir)) {
            New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
        }

        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupFile = Join-Path $backupDir "winsock_backup_$timestamp.txt"

        $netshOutput = netsh winsock show catalog 2>&1
        $netshOutput | Out-File -FilePath $backupFile -Encoding UTF8

        $lspFile = Join-Path $backupDir "winsock_lsp_$timestamp.txt"
        $lspOutput = netsh winsock show catalog catalog=1 2>&1
        $lspOutput | Out-File -FilePath $lspFile -Encoding UTF8

        $nsFile = Join-Path $backupDir "winsock_namespace_$timestamp.txt"
        $nsOutput = netsh winsock show catalog catalog=2 2>&1
        $nsOutput | Out-File -FilePath $nsFile -Encoding UTF8

        $result.Success = $true
        $result.BackupPath = $backupDir
        $result.Message = "Winsock state backed up to $backupDir"
        Write-Log -Level "SUCCESS" -Category "Winsock" -Message $result.Message
    } catch {
        $result.Message = "Error backing up Winsock state: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "Winsock" -Message $result.Message
    }

    return $result
}

function global:Get-WinsockProviders {
    <#
    .SYNOPSIS
        Gets Winsock catalog providers information.
    #>
    param(
        [switch]$IncludeLSP,
        [switch]$IncludeNamespace
    )

    $providers = @{
        CatalogEntries = @()
        LayeredProviders = @()
        NamespaceProviders = @()
    }

    try {
        $catalogOutput = netsh winsock show catalog 2>&1

        $currentEntry = @{}
        $entries = @()

        foreach ($line in $catalogOutput) {
            if ($line -match "^Entry\s+(\d+):") {
                if ($currentEntry.Count -gt 0) {
                    $entries += [PSCustomObject]$currentEntry
                }
                $currentEntry = @{
                    EntryNumber = $Matches[1]
                    Description = ""
                    ProviderPath = ""
                    CatalogId = ""
                    ServiceFlags = ""
                    ProtocolChain = ""
                    Version = ""
                    AddressFamily = ""
                    MaxSockAddr = ""
                    MinSockAddr = ""
                }
            } elseif ($line -match "^\s+Description:\s+(.+)$") {
                $currentEntry.Description = $Matches[1].Trim()
            } elseif ($line -match "^\s+Library\s+Path:\s+(.+)$") {
                $currentEntry.ProviderPath = $Matches[1].Trim()
            } elseif ($line -match "^\s+Catalog\s+Entry\s+Id:\s+(.+)$") {
                $currentEntry.CatalogId = $Matches[1].Trim()
            } elseif ($line -match "^\s+Service\s+Flags:\s+(.+)$") {
                $currentEntry.ServiceFlags = $Matches[1].Trim()
            } elseif ($line -match "^\s+Protocol\s+Chain:\s+(.+)$") {
                $currentEntry.ProtocolChain = $Matches[1].Trim()
            } elseif ($line -match "^\s+Version:\s+(.+)$") {
                $currentEntry.Version = $Matches[1].Trim()
            } elseif ($line -match "^\s+Address\s+Family:\s+(.+)$") {
                $currentEntry.AddressFamily = $Matches[1].Trim()
            } elseif ($line -match "^\s+Max\s+Sock\s+Addr\s+Length:\s+(.+)$") {
                $currentEntry.MaxSockAddr = $Matches[1].Trim()
            } elseif ($line -match "^\s+Min\s+Sock\s+Addr\s+Length:\s+(.+)$") {
                $currentEntry.MinSockAddr = $Matches[1].Trim()
            }
        }

        if ($currentEntry.Count -gt 0) {
            $entries += [PSCustomObject]$currentEntry
        }

        $providers.CatalogEntries = $entries

        # Correct operator precedence: (Description -match "Layered") -or (ProviderPath -and (ProviderPath -notmatch "mswsock.dll"))
        $layeredProviders = $entries | Where-Object { ($_.Description -match "Layered") -or ($_.ProviderPath -and ($_.ProviderPath -notmatch "mswsock.dll")) }
        $providers.LayeredProviders = @($layeredProviders)

        if ($IncludeNamespace) {
            $nsOutput = netsh winsock show catalog catalog=2 2>&1
            $nsEntries = @()

            $currentNs = @{}
            foreach ($line in $nsOutput) {
                if ($line -match "^Namespace\s+Entry\s+(\d+):") {
                    if ($currentNs.Count -gt 0) {
                        $nsEntries += [PSCustomObject]$currentNs
                    }
                    $currentNs = @{
                        EntryNumber = $Matches[1]
                        Description = ""
                        ProviderPath = ""
                        NamespaceId = ""
                        Active = ""
                    }
                } elseif ($line -match "^\s+Description:\s+(.+)$") {
                    $currentNs.Description = $Matches[1].Trim()
                } elseif ($line -match "^\s+Library\s+Path:\s+(.+)$") {
                    $currentNs.ProviderPath = $Matches[1].Trim()
                } elseif ($line -match "^\s+Namespace\s+Id:\s+(.+)$") {
                    $currentNs.NamespaceId = $Matches[1].Trim()
                } elseif ($line -match "^\s+Active:\s+(.+)$") {
                    $currentNs.Active = $Matches[1].Trim()
                }
            }

            if ($currentNs.Count -gt 0) {
                $nsEntries += [PSCustomObject]$currentNs
            }

            $providers.NamespaceProviders = $nsEntries
        }
    } catch {
        Write-Log -Level "ERROR" -Category "Winsock" -Message "Error getting Winsock providers: $($_.Exception.Message)"
    }

    return $providers
}
