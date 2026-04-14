#Requires -Version 5.1

$script:CriticalDevicePatterns = @(
    "NCR", "Honeywell", "Axis", "POS", "Controller", "PLC", "SCADA", "HMI",
    "Industrial", "sqlservr", "store", "Exchange", "dc", "DomainController"
)

$script:CriticalServices = @(
    "MSSQLSERVER", "MSSQL$*", "MSExchange*", "NTDS", "DNS", "Dhcp"
)

function global:Initialize-SafetyCheck {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]$AdditionalPatterns = @()
    )

    if ($AdditionalPatterns.Count -gt 0) {
        $script:CriticalDevicePatterns = $script:CriticalDevicePatterns + $AdditionalPatterns
    }

    Write-Log -Level "INFO" -Category "Safety" -Message "Safety check initialized with $($script:CriticalDevicePatterns.Count) detection patterns"
}

function global:Test-SystemRestore {
    [CmdletBinding()]
    param()

    try {
        $srService = Get-Service -Name "srservice" -ErrorAction SilentlyContinue
        if ($null -eq $srService) {
            Write-Log -Level "WARNING" -Category "Safety" -Message "System Restore service not found on this system"
            return $false
        }

        if ($srService.Status -ne "Running") {
            Write-Log -Level "WARNING" -Category "Safety" -Message "System Restore service is not running (Status: $($srService.Status))"
            return $false
        }

        try {
            $srEnabled = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name "RPSessionInterval" -ErrorAction SilentlyContinue
            if ($null -ne $srEnabled) {
                Write-Log -Level "SUCCESS" -Category "Safety" -Message "System Restore is available and active"
                return $true
            }
        }
        catch { Write-Log -Level "WARNING" -Category "System" -Message $_.Exception.Message }

        Write-Log -Level "SUCCESS" -Category "Safety" -Message "System Restore service is running"
        return $true
    }
    catch {
        Write-Log -Level "ERROR" -Category "Safety" -Message "Failed to check System Restore: $($_.Exception.Message)"
        return $false
    }
}

function global:New-RestorePoint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Description,

        [Parameter()]
        [ValidateSet("APPLICATION_INSTALL", "APPLICATION_UNINSTALL", "DEVICE_DRIVER_INSTALL", "MODIFY_SETTINGS", "CANCELLED_OPERATION", "BACKUP_RECOVERY")]
        [string]$Type = "MODIFY_SETTINGS"
    )

    if ($script:State -and $script:State.IsTestMode) {
        Write-Log -Level "INFO" -Category "Safety" -Message "[TEST MODE] Would create restore point: $Description"
        return $true
    }

    $srAvailable = Test-SystemRestore
    if (-not $srAvailable) {
        Write-Log -Level "WARNING" -Category "Safety" -Message "Cannot create restore point - System Restore not available"
        return $false
    }

    try {
        Write-Log -Level "INFO" -Category "Safety" -Message "Creating system restore point: $Description"

        $restoreTypes = @{
            "APPLICATION_INSTALL" = 0
            "APPLICATION_UNINSTALL" = 1
            "DEVICE_DRIVER_INSTALL" = 10
            "MODIFY_SETTINGS" = 12
            "CANCELLED_OPERATION" = 13
            "BACKUP_RECOVERY" = 14
        }

        $typeValue = $restoreTypes[$Type]

        $sr = Get-WmiObject -List -Namespace "root\default" | Where-Object { $_.Name -eq "SystemRestore" }
        if ($null -eq $sr) {
            Write-Log -Level "ERROR" -Category "Safety" -Message "SystemRestore WMI class not available"
            return $false
        }

        $result = $sr.CreateRestorePoint($Description, $typeValue, 100)
        if ($result.ReturnValue -eq 0) {
            Write-Log -Level "SUCCESS" -Category "Safety" -Message "Restore point created successfully: $Description"

            $rpEntry = [PSCustomObject]@{
                Description = $Description
                Type        = $Type
                Timestamp   = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                SessionId   = if ($script:State) { $script:State.SessionId } else { "unknown" }
            }

            if ($script:State) {
                $script:State.RestorePointsCreated += $rpEntry
            }

            return $true
        }
        else {
            Write-Log -Level "ERROR" -Category "Safety" -Message "Restore point creation failed with code: $($result.ReturnValue)"
            return $false
        }
    }
    catch {
        Write-Log -Level "ERROR" -Category "Safety" -Message "Failed to create restore point: $($_.Exception.Message)"
        return $false
    }
}

function global:Get-CriticalDevices {
    [CmdletBinding()]
    param()

    $detected = @()

    try {
        $processes = Get-Process -ErrorAction SilentlyContinue
        foreach ($proc in $processes) {
            foreach ($pattern in $script:CriticalDevicePatterns) {
                if ($proc.ProcessName -like "*$pattern*") {
                    $detected += [PSCustomObject]@{
                        Type       = "Process"
                        Name       = $proc.ProcessName
                        PID        = $proc.Id
                        Pattern    = $pattern
                        Source     = "RunningProcess"
                    }
                    break
                }
            }
        }
    }
    catch {
        Write-Log -Level "WARNING" -Category "Safety" -Message "Error scanning processes: $($_.Exception.Message)"
    }

    try {
        $services = Get-Service -ErrorAction SilentlyContinue
        foreach ($svc in $services) {
            foreach ($pattern in $script:CriticalServices) {
                if ($svc.Name -like $pattern) {
                    $detected += [PSCustomObject]@{
                        Type    = "Service"
                        Name    = $svc.Name
                        Status  = $svc.Status
                        Pattern = $pattern
                        Source  = "SystemService"
                    }
                    break
                }
            }
        }
    }
    catch {
        Write-Log -Level "WARNING" -Category "Safety" -Message "Error scanning services: $($_.Exception.Message)"
    }

    try {
        $roles = Get-WmiObject -Class Win32_ServerFeature -ErrorAction SilentlyContinue
        if ($null -ne $roles) {
            foreach ($role in $roles) {
                if ($role.Name -match "Domain Controller|Active Directory") {
                    $detected += [PSCustomObject]@{
                        Type    = "Role"
                        Name    = $role.Name
                        ID      = $role.ID
                        Pattern = "DomainController"
                        Source  = "ServerRole"
                    }
                }
            }
        }
    }
    catch { Write-Log -Level "WARNING" -Category "System" -Message $_.Exception.Message }

    Write-Log -Level "INFO" -Category "Safety" -Message "Critical device scan complete: $($detected.Count) items detected"
    return $detected
}

function global:Test-CriticalDevicePresent {
    [CmdletBinding()]
    param()

    $devices = Get-CriticalDevices
    if ($devices.Count -gt 0) {
        foreach ($d in $devices) {
            Write-Log -Level "WARNING" -Category "Safety" -Message "Critical device detected: [$($d.Type)] $($d.Name) (pattern: $($d.Pattern))"
        }
        return $true
    }

    Write-Log -Level "INFO" -Category "Safety" -Message "No critical devices detected"
    return $false
}

function global:New-RegistryBackup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$RegistryKeys,

        [Parameter()]
        [string]$BackupDirectory = ""
    )

    if ($BackupDirectory -eq "") {
        if ($script:Paths -and $script:Paths.Backups) {
            $BackupDirectory = Join-Path $script:Paths.Backups "RegistryBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        }
        else {
            $BackupDirectory = Join-Path $env:TEMP "WinTunePro_RegistryBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        }
    }

    if (-not (Test-Path $BackupDirectory)) {
        New-Item -ItemType Directory -Path $BackupDirectory -Force | Out-Null
    }

    $results = @()

    foreach ($key in $RegistryKeys) {
        $exported = Export-RegistryKey -Key $key -OutputDirectory $BackupDirectory
        $results += $exported
    }

    Write-Log -Level "INFO" -Category "Safety" -Message "Registry backup completed: $($results.Count) keys exported to $BackupDirectory"
    return $results
}

function global:Export-RegistryKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key,

        [Parameter(Mandatory = $true)]
        [string]$OutputDirectory
    )

    try {
        $safeName = $Key -replace "[:\\]", "_"
        $safeName = $safeName -replace "HKLM", "HKEY_LOCAL_MACHINE"
        $safeName = $safeName -replace "HKCU", "HKEY_CURRENT_USER"
        $safeName = $safeName -replace "HKU", "HKEY_USERS"
        $safeName = $safeName -replace "HKCR", "HKEY_CLASSES_ROOT"

        $fileName = "$safeName.reg"
        $filePath = Join-Path $OutputDirectory $fileName

        $hKey = $Key -replace "HKLM:\\", "HKEY_LOCAL_MACHINE\" -replace "HKCU:\\", "HKEY_CURRENT_USER\" -replace "HKLM:", "HKEY_LOCAL_MACHINE" -replace "HKCU:", "HKEY_CURRENT_USER"

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "reg.exe"
        $psi.Arguments = "export `"$hKey`" `"$filePath`" /y"
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $psi
        $process.Start() | Out-Null
        $process.WaitForExit()

        if ($process.ExitCode -eq 0 -and (Test-Path $filePath)) {
            Write-Log -Level "SUCCESS" -Category "Safety" -Message "Exported registry key: $Key -> $filePath"
            return [PSCustomObject]@{
                Key      = $Key
                FilePath = $filePath
                Success  = $true
            }
        }
        else {
            $stderr = $process.StandardError.ReadToEnd()
            Write-Log -Level "ERROR" -Category "Safety" -Message "Failed to export registry key $Key : $stderr"
            return [PSCustomObject]@{
                Key      = $Key
                FilePath = ""
                Success  = $false
                Error    = $stderr
            }
        }
    }
    catch {
        Write-Log -Level "ERROR" -Category "Safety" -Message "Exception exporting $Key : $($_.Exception.Message)"
        return [PSCustomObject]@{
            Key      = $Key
            FilePath = ""
            Success  = $false
            Error    = $_.Exception.Message
        }
    }
}
