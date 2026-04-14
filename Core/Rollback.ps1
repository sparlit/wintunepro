#Requires -Version 5.1

$script:RollbackManifest = @{
    SessionId       = ""
    StartTime       = ""
    RollbackEntries = @()
}

$script:RollbackTypes = @("ServiceChange", "RegistryChange", "FileDelete", "NetworkChange", "StartupChange")

function global:Initialize-Rollback {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BackupsDirectory,

        [Parameter(Mandatory = $true)]
        [string]$SessionId
    )

    if (-not (Test-Path $BackupsDirectory)) {
        New-Item -ItemType Directory -Path $BackupsDirectory -Force | Out-Null
    }

    $script:RollbackManifest = @{
        SessionId       = $SessionId
        StartTime       = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        RollbackEntries = @()
    }

    $manifestPath = Join-Path $BackupsDirectory "rollback_manifest_${SessionId}.json"
    $json = $script:RollbackManifest | ConvertTo-Json -Depth 10
    $json | Out-File -FilePath $manifestPath -Encoding UTF8 -Force

    Write-Log -Level "INFO" -Category "System" -Message "Rollback system initialized | Session: $SessionId | Manifest: $manifestPath"
}

function global:Register-Rollback {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("ServiceChange", "RegistryChange", "FileDelete", "NetworkChange", "StartupChange")]
        [string]$Type,

        [Parameter(Mandatory = $true)]
        [string]$Target,

        [Parameter(Mandatory = $true)]
        [object]$OriginalValue,

        [Parameter(Mandatory = $true)]
        [object]$NewValue,

        [Parameter()]
        [string]$Description = ""
    )

    $entry = @{
        Type          = $Type
        Target        = $Target
        OriginalValue = $OriginalValue
        NewValue      = $NewValue
        Timestamp     = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
        SessionId     = $script:RollbackManifest.SessionId
        Description   = $Description
    }

    $script:RollbackManifest.RollbackEntries += $entry

    $manifestPath = Get-RollbackManifestPath
    if ($manifestPath -ne "") {
        $json = $script:RollbackManifest | ConvertTo-Json -Depth 10
        $json | Out-File -FilePath $manifestPath -Encoding UTF8 -Force
    }

    Write-Log -Level "DEBUG" -Category "System" -Message "Rollback registered: [$Type] $Target | $Description"
    return $entry
}

function global:Invoke-Rollback {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet("ServiceChange", "RegistryChange", "FileDelete", "NetworkChange", "StartupChange", "")]
        [string]$Type = "",

        [Parameter()]
        [string]$Target = "",

        [Parameter()]
        [switch]$All
    )

    $entries = $script:RollbackManifest.RollbackEntries

    if (-not $All) {
        if ($Type -ne "") {
            $entries = @($entries | Where-Object { $_.Type -eq $Type })
        }
        if ($Target -ne "") {
            $entries = @($entries | Where-Object { $_.Target -eq $Target })
        }
    }

    if ($entries.Count -eq 0) {
        Write-Log -Level "INFO" -Category "System" -Message "No rollback entries to process"
        return @{ Processed = 0; Succeeded = 0; Failed = 0 }
    }

    $reversed = @($entries | Sort-Object Timestamp -Descending)
    $succeeded = 0
    $failed = 0

    foreach ($entry in $reversed) {
        $result = Invoke-SingleRollback -Entry $entry
        if ($result) {
            $succeeded++
        }
        else {
            $failed++
        }
    }

    Write-Log -Level "INFO" -Category "System" -Message "Rollback complete | Processed: $($reversed.Count) | Succeeded: $succeeded | Failed: $failed"

    return @{
        Processed = $reversed.Count
        Succeeded = $succeeded
        Failed    = $failed
    }
}

function global:Get-RollbackHistory {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$BackupsDirectory = ""
    )

    if ($BackupsDirectory -eq "") {
        if ($script:Paths -and $script:Paths.Backups) {
            $BackupsDirectory = $script:Paths.Backups
        }
        else {
            return @()
        }
    }

    if (-not (Test-Path $BackupsDirectory)) {
        return @()
    }

    $manifestFiles = Get-ChildItem -Path $BackupsDirectory -Filter "rollback_manifest_*.json" -ErrorAction SilentlyContinue
    $history = @()

    foreach ($file in $manifestFiles) {
        try {
            $json = Get-Content -Path $file.FullName -Raw -Encoding UTF8
            $manifest = $json | ConvertFrom-Json
            $history += [PSCustomObject]@{
                SessionId     = $manifest.SessionId
                StartTime     = $manifest.StartTime
                EntryCount    = $manifest.RollbackEntries.Count
                ManifestPath  = $file.FullName
            }
        }
        catch {
            Write-Log -Level "WARNING" -Category "System" -Message "Corrupted rollback manifest: $($file.FullName)"
        }
    }

    return @($history | Sort-Object StartTime -Descending)
}

function global:Clear-OldRollbacks {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$BackupsDirectory = "",

        [Parameter()]
        [int]$RetentionDays = 30
    )

    if ($BackupsDirectory -eq "") {
        if ($script:Paths -and $script:Paths.Backups) {
            $BackupsDirectory = $script:Paths.Backups
        }
        else {
            Write-Log -Level "WARNING" -Category "System" -Message "No backups directory specified"
            return 0
        }
    }

    if (-not (Test-Path $BackupsDirectory)) {
        return 0
    }

    $cutoff = (Get-Date).AddDays(-$RetentionDays)
    $manifestFiles = Get-ChildItem -Path $BackupsDirectory -Filter "rollback_manifest_*.json" -ErrorAction SilentlyContinue
    $cleared = 0

    foreach ($file in $manifestFiles) {
        if ($file.LastWriteTime -lt $cutoff) {
            try {
                Remove-Item -Path $file.FullName -Force
                $cleared++
                Write-Log -Level "INFO" -Category "System" -Message "Removed old rollback manifest: $($file.Name)"
            }
            catch {
                Write-Log -Level "WARNING" -Category "System" -Message "Failed to remove: $($file.Name)"
            }
        }
    }

    $registryDirs = Get-ChildItem -Path $BackupsDirectory -Directory -Filter "RegistryBackup_*" -ErrorAction SilentlyContinue
    foreach ($dir in $registryDirs) {
        if ($dir.LastWriteTime -lt $cutoff) {
            try {
                Remove-Item -Path $dir.FullName -Recurse -Force
                $cleared++
                Write-Log -Level "INFO" -Category "System" -Message "Removed old registry backup: $($dir.Name)"
            }
            catch {
                Write-Log -Level "WARNING" -Category "System" -Message "Failed to remove: $($dir.Name)"
            }
        }
    }

    Write-Log -Level "INFO" -Category "System" -Message "Cleanup complete: $cleared items older than $RetentionDays days removed"
    return $cleared
}

function global:Invoke-SingleRollback {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Entry
    )

    try {
        switch ($Entry.Type) {
            "ServiceChange" {
                $svcName = $Entry.Target
                $origStartType = $Entry.OriginalValue

                $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
                if ($null -ne $svc) {
                    Set-Service -Name $svcName -StartupType $origStartType -ErrorAction Stop
                    Write-Log -Level "SUCCESS" -Category "System" -Message "Rollback service: $svcName -> $origStartType"
                    return $true
                }
                else {
                    Write-Log -Level "WARNING" -Category "System" -Message "Service not found for rollback: $svcName"
                    return $false
                }
            }
            "RegistryChange" {
                $regPath = $Entry.Target
                $regValue = $Entry.OriginalValue

                if ($regPath -match "^(.+?)\\(.+?)$") {
                    $keyPath = $Matches[1]
                    $valueName = $Matches[2]

                    if ($keyPath -notmatch "^HK") {
                        if ($keyPath -match "^HKEY_LOCAL_MACHINE") {
                            $keyPath = $keyPath -replace "^HKEY_LOCAL_MACHINE", "HKLM:"
                        }
                        elseif ($keyPath -match "^HKEY_CURRENT_USER") {
                            $keyPath = $keyPath -replace "^HKEY_CURRENT_USER", "HKCU:"
                        }
                    }

                    if (-not (Test-Path $keyPath)) {
                        New-Item -Path $keyPath -Force | Out-Null
                    }

                    Set-ItemProperty -Path $keyPath -Name $valueName -Value $regValue -ErrorAction Stop
                    Write-Log -Level "SUCCESS" -Category "System" -Message "Rollback registry: $keyPath\$valueName"
                    return $true
                }
                return $false
            }
            "FileDelete" {
                $quarantinePath = $Entry.NewValue
                $originalPath = $Entry.OriginalValue

                if (Test-Path $quarantinePath) {
                    $parentDir = Split-Path $originalPath -Parent
                    if (-not (Test-Path $parentDir)) {
                        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
                    }
                    Move-Item -Path $quarantinePath -Destination $originalPath -Force
                    Write-Log -Level "SUCCESS" -Category "System" -Message "Rollback file: restored $originalPath"
                    return $true
                }
                else {
                    Write-Log -Level "WARNING" -Category "System" -Message "Quarantine file not found: $quarantinePath"
                    return $false
                }
            }
            "NetworkChange" {
                $originalState = $Entry.OriginalValue
                if ($originalState -is [hashtable] -and $originalState.ContainsKey("DNSServers")) {
                    $interface = $Entry.Target
                    $dnsServers = $originalState.DNSServers

                    foreach ($dns in $dnsServers) {
                        try {
                            $netshArgs = "interface ip set dns `"$interface`" static $dns primary"
                            $proc = Start-Process -FilePath "netsh" -ArgumentList $netshArgs -Wait -PassThru -WindowStyle Hidden
                            if ($proc.ExitCode -ne 0) {
                                Write-Log -Level "WARNING" -Category "System" -Message "netsh returned non-zero for DNS rollback"
                            }
                        }
                        catch { Write-Log -Level "WARNING" -Category "System" -Message $_.Exception.Message }
                    }

                    Write-Log -Level "SUCCESS" -Category "Network" -Message "Rollback network: DNS restored on $interface"
                    return $true
                }
                return $false
            }
            "StartupChange" {
                $regPath = $Entry.Target
                $origValue = $Entry.OriginalValue

                if ($origValue -ne $null -and $origValue -ne "") {
                    if (-not (Test-Path $regPath)) {
                        New-Item -Path $regPath -Force | Out-Null
                    }
                    $valueName = Split-Path $Entry.Target -Leaf
                    Set-ItemProperty -Path (Split-Path $regPath -Parent) -Name $valueName -Value $origValue -ErrorAction Stop
                    Write-Log -Level "SUCCESS" -Category "System" -Message "Rollback startup item: $valueName restored"
                    return $true
                }
                return $false
            }
            default {
                Write-Log -Level "WARNING" -Category "System" -Message "Unknown rollback type: $($Entry.Type)"
                return $false
            }
        }
    }
    catch {
        Write-Log -Level "ERROR" -Category "System" -Message "Rollback failed for [$($Entry.Type)] $($Entry.Target): $($_.Exception.Message)"
        return $false
    }
}

function global:Get-RollbackManifestPath {
    [CmdletBinding()]
    param()

    if ($script:Paths -and $script:Paths.Backups) {
        $manifestFiles = Get-ChildItem -Path $script:Paths.Backups -Filter "rollback_manifest_$($script:RollbackManifest.SessionId).json" -ErrorAction SilentlyContinue
        if ($manifestFiles.Count -gt 0) {
            return $manifestFiles[0].FullName
        }
    }
    return ""
}
