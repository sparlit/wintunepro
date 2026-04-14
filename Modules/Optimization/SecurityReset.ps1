#Requires -Version 5.1
<#
.SYNOPSIS
    Security Reset Module
.DESCRIPTION
    Security settings reset functions including Windows Defender settings,
    Quarantine, Signatures, Security Center, SmartScreen, UAC, and Credentials.
#>

function global:Reset-WindowsDefenderSettings {
    <#
    .SYNOPSIS
        Resets Windows Defender to default settings.
    #>
    $result = @{
        Success = $false
        Message = ""
        SettingsReset = @()
    }

    try {
        try {
            Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
            Set-MpPreference -DisableIOAVProtection $false -ErrorAction SilentlyContinue
            Set-MpPreference -DisableBehaviorMonitoring $false -ErrorAction SilentlyContinue
            Set-MpPreference -DisableBlockAtFirstSeen $false -ErrorAction SilentlyContinue
            Set-MpPreference -DisableScriptScanning $false -ErrorAction SilentlyContinue
            Set-MpPreference -DisableArchiveScanning $false -ErrorAction SilentlyContinue
            Set-MpPreference -DisableAutoExclusions $false -ErrorAction SilentlyContinue
            Set-MpPreference -DisableCpuThrottleOnIdleScans $false -ErrorAction SilentlyContinue
            Set-MpPreference -DisableCatchupFullScan $false -ErrorAction SilentlyContinue
            Set-MpPreference -DisableCatchupQuickScan $false -ErrorAction SilentlyContinue
            $result.SettingsReset += "Real-time Protection"
        } catch {
            Write-Log -Level "WARNING" -Category "SecurityReset" -Message "Error resetting Defender preferences: $($_.Exception.Message)"
        }

        try {
            $exclusions = Get-MpPreference -ErrorAction SilentlyContinue
            if ($exclusions.ExclusionPath) {
                foreach ($path in $exclusions.ExclusionPath) {
                    Remove-MpPreference -ExclusionPath $path -ErrorAction SilentlyContinue
                }
            }
            if ($exclusions.ExclusionExtension) {
                foreach ($ext in $exclusions.ExclusionExtension) {
                    Remove-MpPreference -ExclusionExtension $ext -ErrorAction SilentlyContinue
                }
            }
            if ($exclusions.ExclusionProcess) {
                foreach ($proc in $exclusions.ExclusionProcess) {
                    Remove-MpPreference -ExclusionProcess $proc -ErrorAction SilentlyContinue
                }
            }
            $result.SettingsReset += "Exclusion Lists"
        } catch {
            Write-Log -Level "WARNING" -Category "SecurityReset" -Message "Error resetting exclusions: $($_.Exception.Message)"
        }

        try {
            Set-MpPreference -HighThreatDefaultAction 2 -ErrorAction SilentlyContinue
            Set-MpPreference -SevereThreatDefaultAction 2 -ErrorAction SilentlyContinue
            Set-MpPreference -ModerateThreatDefaultAction 2 -ErrorAction SilentlyContinue
            Set-MpPreference -LowThreatDefaultAction 2 -ErrorAction SilentlyContinue
            $result.SettingsReset += "Threat Actions"
        } catch {
            Write-Log -Level "WARNING" -Category "SecurityReset" -Message "Error resetting threat actions: $($_.Exception.Message)"
        }

        $result.Success = $true
        $result.Message = "Windows Defender settings reset to default"
    } catch {
        $result.Message = "Error resetting Defender settings: $($_.Exception.Message)"
    }

    return $result
}

function global:Clear-DefenderQuarantine {
    <#
    .SYNOPSIS
        Clears Windows Defender quarantine items.
    #>
    $result = @{
        Success = $false
        Message = ""
        ItemsRemoved = 0
    }

    try {
        $threats = Get-MpThreatDetection -ErrorAction SilentlyContinue

        $mpCmdRun = "$env:ProgramFiles\Windows Defender\MpCmdRun.exe"
        if (Test-Path $mpCmdRun) {
            $process = Start-Process -FilePath $mpCmdRun -ArgumentList "-DeleteAll" -WindowStyle Hidden -Wait -PassThru -ErrorAction SilentlyContinue
            if ($process.ExitCode -eq 0) {
                $result.ItemsRemoved = if ($threats) { @($threats).Count } else { 0 }
            }
        }

        $quarantinePath = "$env:ProgramData\Microsoft\Windows Defender\Quarantine"
        if (Test-Path $quarantinePath) {
            Remove-Item -Path "$quarantinePath\*" -Recurse -Force -ErrorAction SilentlyContinue
        }

        $result.Success = $true
        $result.Message = "Defender quarantine cleared successfully"
    } catch {
        $result.Message = "Error clearing Defender quarantine: $($_.Exception.Message)"
    }

    return $result
}

function global:Update-DefenderSignatures {
    <#
    .SYNOPSIS
        Updates Windows Defender signatures.
    #>
    $result = @{
        Success = $false
        Message = ""
        PreviousVersion = ""
        NewVersion = ""
    }

    try {
        $mpPreferences = Get-MpComputerStatus -ErrorAction SilentlyContinue
        $result.PreviousVersion = if ($mpPreferences) { $mpPreferences.AntispywareSignatureVersion } else { "Unknown" }

        $mpCmdRun = "$env:ProgramFiles\Windows Defender\MpCmdRun.exe"
        if (Test-Path $mpCmdRun) {
            $process = Start-Process -FilePath $mpCmdRun -ArgumentList "-SignatureUpdate" -WindowStyle Hidden -Wait -PassThru -ErrorAction SilentlyContinue
        }

        try {
            Update-MpSignature -ErrorAction SilentlyContinue
        } catch {
            Write-Log -Level "DEBUG" -Category "SecurityReset" -Message "Alternative signature update not available: $($_.Exception.Message)"
        }

        Start-Sleep -Seconds 5
        $mpPreferences = Get-MpComputerStatus -ErrorAction SilentlyContinue
        $result.NewVersion = if ($mpPreferences) { $mpPreferences.AntispywareSignatureVersion } else { "Unknown" }

        $result.Success = $true
        $result.Message = "Defender signatures updated successfully"
    } catch {
        $result.Message = "Error updating Defender signatures: $($_.Exception.Message)"
    }

    return $result
}

function global:Reset-SecurityCenter {
    <#
    .SYNOPSIS
        Resets Windows Security Center settings.
    #>
    $result = @{
        Success = $false
        Message = ""
        SettingsReset = @()
    }

    try {
        $scService = Get-Service -Name "wscsvc" -ErrorAction SilentlyContinue
        if ($scService) {
            Restart-Service -Name "wscsvc" -Force -ErrorAction SilentlyContinue
            $result.SettingsReset += "Security Center Service"
        }

        $scPath = "HKLM:\SOFTWARE\Microsoft\Security Center"
        if (Test-Path $scPath) {
            Set-ItemProperty -Path $scPath -Name "AntiVirusDisableNotify" -Value 0 -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $scPath -Name "FirewallDisableNotify" -Value 0 -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $scPath -Name "UpdatesDisableNotify" -Value 0 -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $scPath -Name "AntiVirusOverride" -Value 0 -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $scPath -Name "FirewallOverride" -Value 0 -ErrorAction SilentlyContinue
            $result.SettingsReset += "Security Center Notifications"
        }

        $scPath64 = "HKLM:\SOFTWARE\Microsoft\Security Center\Svc"
        if (Test-Path $scPath64) {
            Set-ItemProperty -Path $scPath64 -Name "AntiVirusDisableNotify" -Value 0 -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $scPath64 -Name "FirewallDisableNotify" -Value 0 -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $scPath64 -Name "UpdatesDisableNotify" -Value 0 -ErrorAction SilentlyContinue
        }

        $result.Success = $true
        $result.Message = "Security Center settings reset to default"
    } catch {
        $result.Message = "Error resetting Security Center: $($_.Exception.Message)"
    }

    return $result
}

function global:Reset-SmartScreen {
    <#
    .SYNOPSIS
        Resets Windows SmartScreen settings.
    #>
    $result = @{
        Success = $false
        Message = ""
        SettingsReset = @()
    }

    try {
        $smartScreenPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer"
        Set-ItemProperty -Path $smartScreenPath -Name "SmartScreenEnabled" -Value "Prompt" -ErrorAction SilentlyContinue
        $result.SettingsReset += "SmartScreen for Windows"

        $edgePath = "HKCU:\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppContainer\Storage\microsoft.microsoftedge_8wekyb3d8bbwe\MicrosoftEdge\PhishingFilter"
        if (Test-Path $edgePath) {
            Set-ItemProperty -Path $edgePath -Name "EnabledV9" -Value 1 -ErrorAction SilentlyContinue
            $result.SettingsReset += "SmartScreen for Edge"
        }

        $storePath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost"
        Set-ItemProperty -Path $storePath -Name "EnableWebContentEvaluation" -Value 1 -ErrorAction SilentlyContinue
        $result.SettingsReset += "SmartScreen for Apps"

        $ssCachePaths = @(
            "$env:LOCALAPPDATA\Microsoft\Windows\AppCache",
            "$env:LOCALAPPDATA\Microsoft\Windows\INetCache"
        )
        foreach ($path in $ssCachePaths) {
            if (Test-Path $path) {
                Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        $result.SettingsReset += "SmartScreen Cache"

        $result.Success = $true
        $result.Message = "SmartScreen settings reset successfully"
    } catch {
        $result.Message = "Error resetting SmartScreen: $($_.Exception.Message)"
    }

    return $result
}

function global:Reset-UACSettings {
    <#
    .SYNOPSIS
        Resets User Account Control (UAC) to default settings.
    #>
    $result = @{
        Success = $false
        Message = ""
        PreviousLevel = ""
        NewLevel = 2
    }

    try {
        $uacPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
        $previousLevel = Get-ItemProperty -Path $uacPath -Name "ConsentPromptBehaviorAdmin" -ErrorAction SilentlyContinue
        $result.PreviousLevel = if ($previousLevel) { $previousLevel.ConsentPromptBehaviorAdmin } else { "Unknown" }

        Set-ItemProperty -Path $uacPath -Name "ConsentPromptBehaviorAdmin" -Value 2 -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $uacPath -Name "ConsentPromptBehaviorUser" -Value 1 -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $uacPath -Name "EnableInstallerDetection" -Value 1 -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $uacPath -Name "EnableLUA" -Value 1 -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $uacPath -Name "EnableSecureUIAPaths" -Value 1 -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $uacPath -Name "EnableUIADesktopToggle" -Value 0 -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $uacPath -Name "EnableVirtualization" -Value 1 -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $uacPath -Name "PromptOnSecureDesktop" -Value 1 -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $uacPath -Name "ValidateAdminCodeSignatures" -Value 0 -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $uacPath -Name "FilterAdministratorToken" -Value 0 -ErrorAction SilentlyContinue

        $result.Success = $true
        $result.Message = "UAC settings reset to default level"
    } catch {
        $result.Message = "Error resetting UAC settings: $($_.Exception.Message)"
    }

    return $result
}

function global:Clear-WindowsCredentials {
    <#
    .SYNOPSIS
        Clears Windows stored credentials (WARNING: User will need to re-enter passwords).
    #>
    $result = @{
        Success = $false
        Message = ""
        CredentialsRemoved = 0
        TypesCleared = @()
    }

    try {
        $credentials = cmdkey /list 2>&1
        $credCount = ($credentials | Select-String "Target:").Count
        $result.CredentialsRemoved = $credCount

        Get-ChildItem -Path "Cert:\CurrentUser\My" -ErrorAction SilentlyContinue | ForEach-Object {
            # Only clear cached credentials, not personal certificates
        }

        $credPath = "$env:LOCALAPPDATA\Microsoft\Credentials"
        if (Test-Path $credPath) {
            Remove-Item -Path "$credPath\*" -Recurse -Force -ErrorAction SilentlyContinue
            $result.TypesCleared += "User Credentials"
        }

        $sysCredPath = "C:\Windows\System32\config\systemprofile\AppData\Local\Microsoft\Credentials"
        if (Test-Path $sysCredPath) {
            Remove-Item -Path "$sysCredPath\*" -Recurse -Force -ErrorAction SilentlyContinue
            $result.TypesCleared += "System Credentials"
        }

        $vaultPath = "$env:LOCALAPPDATA\Microsoft\Vault"
        if (Test-Path $vaultPath) {
            Remove-Item -Path "$vaultPath\*" -Recurse -Force -ErrorAction SilentlyContinue
            $result.TypesCleared += "Windows Vault"
        }

        $result.Success = $true
        $result.Message = "Windows credentials cleared successfully. User will need to re-enter passwords."
    } catch {
        $result.Message = "Error clearing credentials: $($_.Exception.Message)"
    }

    return $result
}

function global:Clear-CertificateCache {
    <#
    .SYNOPSIS
        Clears certificate cache (keeps personal certificates).
    #>
    $result = @{
        Success = $false
        Message = ""
        BytesRecovered = 0
        CertificatesCleared = 0
    }

    try {
        $certCachePaths = @(
            "$env:LOCALAPPDATA\Microsoft\CertificateServices\Cache",
            "$env:APPDATA\Microsoft\CertificateServices\Cache",
            "$env:LOCALAPPDATA\Microsoft\CryptnetUrlCache",
            "$env:LOCALAPPDATA\Microsoft\CryptnetUrlCache\Content",
            "$env:LOCALAPPDATA\Microsoft\CryptnetUrlCache\MetaData"
        )

        foreach ($path in $certCachePaths) {
            if (Test-Path $path) {
                $sizeBefore = Get-SecurityFolderSize $path
                Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
                $result.BytesRecovered += $sizeBefore
                $result.CertificatesCleared++
            }
        }

        $result.Success = $true
        $result.Message = "Certificate cache cleared successfully"
    } catch {
        $result.Message = "Error clearing certificate cache: $($_.Exception.Message)"
    }

    return $result
}

function global:Reset-BitLockerSettings {
    <#
    .SYNOPSIS
        Resets BitLocker settings (does not decrypt drives).
    #>
    $result = @{
        Success = $false
        Message = ""
        SettingsReset = @()
    }

    try {
        $bitLockerVolumes = Get-BitLockerVolume -ErrorAction SilentlyContinue

        $bitLockerPath = "HKLM:\SOFTWARE\Policies\Microsoft\FVE"
        if (Test-Path $bitLockerPath) {
            Remove-Item -Path "$bitLockerPath\*" -Recurse -Force -ErrorAction SilentlyContinue
            $result.SettingsReset += "BitLocker Policies"
        }

        $fdvPath = "HKLM:\SOFTWARE\Policies\Microsoft\FVE\FDV"
        if (Test-Path $fdvPath) {
            Remove-Item -Path "$fdvPath\*" -Recurse -Force -ErrorAction SilentlyContinue
            $result.SettingsReset += "Fixed Drive Policies"
        }

        $result.Success = $true
        $result.Message = "BitLocker settings reset successfully (drives remain encrypted)"
    } catch {
        $result.Message = "Error resetting BitLocker settings: $($_.Exception.Message)"
    }

    return $result
}

# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)
# Function Clear-SecurityLogs removed (duplicate of E:\WinTunePro\Modules\Cleaning\LogCleanup.ps1)

# Function Reset-FirewallRules removed (duplicate of E:\WinTunePro\Modules\NetworkReset\NetworkAdvanced.ps1)
# Function Reset-FirewallRules removed (duplicate of E:\WinTunePro\Modules\NetworkReset\NetworkAdvanced.ps1)
# Function Reset-FirewallRules removed (duplicate of E:\WinTunePro\Modules\NetworkReset\NetworkAdvanced.ps1)
# Function Reset-FirewallRules removed (duplicate of E:\WinTunePro\Modules\NetworkReset\NetworkAdvanced.ps1)
# Function Reset-FirewallRules removed (duplicate of E:\WinTunePro\Modules\NetworkReset\NetworkAdvanced.ps1)
# Function Reset-FirewallRules removed (duplicate of E:\WinTunePro\Modules\NetworkReset\NetworkAdvanced.ps1)
# Function Reset-FirewallRules removed (duplicate of E:\WinTunePro\Modules\NetworkReset\NetworkAdvanced.ps1)
# Function Reset-FirewallRules removed (duplicate of E:\WinTunePro\Modules\NetworkReset\NetworkAdvanced.ps1)
# Function Reset-FirewallRules removed (duplicate of E:\WinTunePro\Modules\NetworkReset\NetworkAdvanced.ps1)
# Function Reset-FirewallRules removed (duplicate of E:\WinTunePro\Modules\NetworkReset\NetworkAdvanced.ps1)
# Function Reset-FirewallRules removed (duplicate of E:\WinTunePro\Modules\NetworkReset\NetworkAdvanced.ps1)
# Function Reset-FirewallRules removed (duplicate of E:\WinTunePro\Modules\NetworkReset\NetworkAdvanced.ps1)
# Function Reset-FirewallRules removed (duplicate of E:\WinTunePro\Modules\NetworkReset\NetworkAdvanced.ps1)
# Function Reset-FirewallRules removed (duplicate of E:\WinTunePro\Modules\NetworkReset\NetworkAdvanced.ps1)
# Function Reset-FirewallRules removed (duplicate of E:\WinTunePro\Modules\NetworkReset\NetworkAdvanced.ps1)
# Function Reset-FirewallRules removed (duplicate of E:\WinTunePro\Modules\NetworkReset\NetworkAdvanced.ps1)
# Function Reset-FirewallRules removed (duplicate of E:\WinTunePro\Modules\NetworkReset\NetworkAdvanced.ps1)
# Function Reset-FirewallRules removed (duplicate of E:\WinTunePro\Modules\NetworkReset\NetworkAdvanced.ps1)
# Function Reset-FirewallRules removed (duplicate of E:\WinTunePro\Modules\NetworkReset\NetworkAdvanced.ps1)
# Function Reset-FirewallRules removed (duplicate of E:\WinTunePro\Modules\NetworkReset\NetworkAdvanced.ps1)
# Function Reset-FirewallRules removed (duplicate of E:\WinTunePro\Modules\NetworkReset\NetworkAdvanced.ps1)
# Function Reset-FirewallRules removed (duplicate of E:\WinTunePro\Modules\NetworkReset\NetworkAdvanced.ps1)
# Function Reset-FirewallRules removed (duplicate of E:\WinTunePro\Modules\NetworkReset\NetworkAdvanced.ps1)
# Function Reset-FirewallRules removed (duplicate of E:\WinTunePro\Modules\NetworkReset\NetworkAdvanced.ps1)
# Function Reset-FirewallRules removed (duplicate of E:\WinTunePro\Modules\NetworkReset\NetworkAdvanced.ps1)

function global:Clear-AllSecurityCaches {
    <#
    .SYNOPSIS
        Executes all security cache cleaning operations.
    #>
    $results = @{
        TotalBytesRecovered = 0
        Operations = @()
    }

    $operations = @(
        @{ Name = "Windows Defender Settings"; Function = "Reset-WindowsDefenderSettings" },
        @{ Name = "Defender Quarantine"; Function = "Clear-DefenderQuarantine" },
        @{ Name = "Defender Signatures Update"; Function = "Update-DefenderSignatures" },
        @{ Name = "Security Center"; Function = "Reset-SecurityCenter" },
        @{ Name = "SmartScreen"; Function = "Reset-SmartScreen" },
        @{ Name = "UAC Settings"; Function = "Reset-UACSettings" },
        @{ Name = "Windows Credentials"; Function = "Clear-WindowsCredentials" },
        @{ Name = "Certificate Cache"; Function = "Clear-CertificateCache" },
        @{ Name = "BitLocker Settings"; Function = "Reset-BitLockerSettings" },
        @{ Name = "Security Logs"; Function = "Clear-SecurityLogs" },
        @{ Name = "Firewall Rules"; Function = "Reset-FirewallRules" }
    )

    foreach ($op in $operations) {
        Write-Host "  Cleaning $($op.Name)..." -ForegroundColor Cyan
        try {
            $result = & $op.Function
            $results.Operations += @{
                Name = $op.Name
                Success = $result.Success
                BytesRecovered = $result.BytesRecovered
                Message = $result.Message
            }
            $results.TotalBytesRecovered += $result.BytesRecovered
        } catch {
            $results.Operations += @{
                Name = $op.Name
                Success = $false
                BytesRecovered = 0
                Message = "Error: $($_.Exception.Message)"
            }
        }
    }

    return $results
}

function global:Get-SecurityFolderSize {
    param([string]$Path)

    if (Get-Command 'Get-FolderSize' -ErrorAction SilentlyContinue) {
        return Get-FolderSize -Path $Path
    }

    if (-not (Test-Path $Path)) { return 0 }

    try {
        $size = (Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
                 Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        return [int]$(if ($size) { $size } else { 0 })
    } catch {
        return 0
    }
}
