<#
.SYNOPSIS
    WinTune Pro RegistryCleaner Module - Safe registry cleaning
.DESCRIPTION
    Conservative registry cleaning with backup and verification
.NOTES
    File: Modules\OSCleaner\RegistryCleaner.ps1
    Version: 1.0.1
    PowerShell: 5.1+
    Compatible: Windows 10, Windows 11
#>

# ============================================================================
# SAFE REGISTRY CLEANING
# ============================================================================

function global:Clear-InvalidStartupEntries {
    <#
    .SYNOPSIS
        Removes invalid startup entries from registry.
    #>
    param(
        [switch]$Preview,
        [switch]$Backup
    )
    
    $result = @{
        Success = $true
        EntriesRemoved = 0
        Errors = @()
        RemovedItems = @()
    }
    
    $runKeys = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
    )
    
    Write-Log -Level "INFO" -Category "Cleaning" -Message "Scanning for invalid startup entries..."
    
    # Backup registry if requested
    if ($Backup -and -not $Preview) {
        $backupResult = New-RegistryBackup -Keys $runKeys -BackupName "StartupBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        if (-not $backupResult.Success) {
            Write-Log -Level "WARNING" -Category "Cleaning" -Message "Registry backup failed, proceeding with caution"
        }
    }
    
    foreach ($keyPath in $runKeys) {
        try {
            if (-not (Test-Path $keyPath)) { continue }
            
            $properties = Get-ItemProperty -Path $keyPath -ErrorAction Stop
            
            foreach ($prop in $properties.PSObject.Properties) {
                # Skip system properties
                if ($prop.Name -in @('PSPath','PSParentPath','PSChildName','PSDrive','PSProvider')) { continue }
                
                $value = $prop.Value
                $isValid = Test-StartupEntryValid -Value $value
                
                if (-not $isValid) {
                    $result.RemovedItems += @{
                        Key = $keyPath
                        Name = $prop.Name
                        Value = $value
                    }
                    
                    if (-not $Preview) {
                        # Register for rollback
                        Register-StartupChange -Name $prop.Name -Location $keyPath -Command $value -Action "Removed"
                        
                        Remove-ItemProperty -Path $keyPath -Name $prop.Name -Force -ErrorAction Stop
                        Write-Log -Level "INFO" -Category "Cleaning" -Message "Removed invalid startup entry: $($prop.Name)"
                    }
                    
                    $result.EntriesRemoved++
                }
            }
        } catch {
            $result.Errors += "Error processing $keyPath : $($_.Exception.Message)"
        }
    }
    
    Write-Log -Level "SUCCESS" -Category "Cleaning" -Message "Invalid startup entries cleaned: $($result.EntriesRemoved)"
    
    return $result
}

function global:Test-StartupEntryValid {
    <#
    .SYNOPSIS
        Tests if a startup entry points to a valid file.
    #>
    param([string]$Value)
    
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    
    # Extract file path from command
    $filePath = $Value
    
    # Handle quoted paths
    if ($Value -match '"([^"]+)"') {
        $filePath = $Matches[1]
    } else {
        # Unquoted - get first token
        $filePath = $Value.Split(' ')[0]
    }
    
    # Handle environment variables
    $filePath = [Environment]::ExpandEnvironmentVariables($filePath)
    
    # Check if file exists
    if ([string]::IsNullOrWhiteSpace($filePath)) { return $false }
    
    # Some entries are intentionally empty or use rundll32
    if ($filePath -match "^(rundll32|regsvr32|msiexec|schtasks|powershell|cmd|cscript|wscript)") {
        return $true  # These are system utilities, assume valid
    }
    
    return (Test-Path -Path $filePath -PathType Leaf)
}

function global:Clear-MRULists {
    <#
    .SYNOPSIS
        Clears Most Recently Used lists from registry.
    #>
    param(
        [switch]$Preview,
        [switch]$Backup
    )
    
    $result = @{
        Success = $true
        ListsCleared = 0
        Errors = @()
    }
    
    $mruKeys = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSavePidlMRU",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\LastVisitedPidlMRU",
        "HKCU:\Software\Microsoft\Internet Explorer\TypedURLs",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StreamMRU"
    )
    
    Write-Log -Level "INFO" -Category "Cleaning" -Message "Clearing MRU lists..."
    
    if ($Backup -and -not $Preview) {
        New-RegistryBackup -Keys $mruKeys -BackupName "MRUBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    }
    
    foreach ($keyPath in $mruKeys) {
        try {
            if (-not (Test-Path $keyPath)) { continue }
            
            $properties = Get-ItemProperty -Path $keyPath -ErrorAction SilentlyContinue
            
            if ($properties) {
                foreach ($prop in $properties.PSObject.Properties) {
                    if ($prop.Name -in @('PSPath','PSParentPath','PSChildName','PSDrive','PSProvider')) { continue }
                    
                    if (-not $Preview) {
                        Remove-ItemProperty -Path $keyPath -Name $prop.Name -Force -ErrorAction SilentlyContinue
                    }
                }
                $result.ListsCleared++
            }
        } catch {
            $result.Errors += "Error clearing $keyPath"
        }
    }
    
    Write-Log -Level "SUCCESS" -Category "Cleaning" -Message "MRU lists cleared: $($result.ListsCleared)"
    
    return $result
}

# Function Invoke-RegistryCleanup removed (duplicate of E:\WinTunePro\Modules\Cleaning\AdvancedCleaning.ps1)
# Function Invoke-RegistryCleanup removed (duplicate of E:\WinTunePro\Modules\Cleaning\AdvancedCleaning.ps1)
# Function Invoke-RegistryCleanup removed (duplicate of E:\WinTunePro\Modules\Cleaning\AdvancedCleaning.ps1)
# Function Invoke-RegistryCleanup removed (duplicate of E:\WinTunePro\Modules\Cleaning\AdvancedCleaning.ps1)
# Function Invoke-RegistryCleanup removed (duplicate of E:\WinTunePro\Modules\Cleaning\AdvancedCleaning.ps1)
# Function Invoke-RegistryCleanup removed (duplicate of E:\WinTunePro\Modules\Cleaning\AdvancedCleaning.ps1)
# Function Invoke-RegistryCleanup removed (duplicate of E:\WinTunePro\Modules\Cleaning\AdvancedCleaning.ps1)
# Function Invoke-RegistryCleanup removed (duplicate of E:\WinTunePro\Modules\Cleaning\AdvancedCleaning.ps1)
# Function Invoke-RegistryCleanup removed (duplicate of E:\WinTunePro\Modules\Cleaning\AdvancedCleaning.ps1)
# Function Invoke-RegistryCleanup removed (duplicate of E:\WinTunePro\Modules\Cleaning\AdvancedCleaning.ps1)
# Function Invoke-RegistryCleanup removed (duplicate of E:\WinTunePro\Modules\Cleaning\AdvancedCleaning.ps1)
# Function Invoke-RegistryCleanup removed (duplicate of E:\WinTunePro\Modules\Cleaning\AdvancedCleaning.ps1)
# Function Invoke-RegistryCleanup removed (duplicate of E:\WinTunePro\Modules\Cleaning\AdvancedCleaning.ps1)
# Function Invoke-RegistryCleanup removed (duplicate of E:\WinTunePro\Modules\Cleaning\AdvancedCleaning.ps1)
# Function Invoke-RegistryCleanup removed (duplicate of E:\WinTunePro\Modules\Cleaning\AdvancedCleaning.ps1)
# Function Invoke-RegistryCleanup removed (duplicate of E:\WinTunePro\Modules\Cleaning\AdvancedCleaning.ps1)
# Function Invoke-RegistryCleanup removed (duplicate of E:\WinTunePro\Modules\Cleaning\AdvancedCleaning.ps1)
# Function Invoke-RegistryCleanup removed (duplicate of E:\WinTunePro\Modules\Cleaning\AdvancedCleaning.ps1)
# Function Invoke-RegistryCleanup removed (duplicate of E:\WinTunePro\Modules\Cleaning\AdvancedCleaning.ps1)
# Function Invoke-RegistryCleanup removed (duplicate of E:\WinTunePro\Modules\Cleaning\AdvancedCleaning.ps1)
# Function Invoke-RegistryCleanup removed (duplicate of E:\WinTunePro\Modules\Cleaning\AdvancedCleaning.ps1)
# Function Invoke-RegistryCleanup removed (duplicate of E:\WinTunePro\Modules\Cleaning\AdvancedCleaning.ps1)
# Function Invoke-RegistryCleanup removed (duplicate of E:\WinTunePro\Modules\Cleaning\AdvancedCleaning.ps1)
# Function Invoke-RegistryCleanup removed (duplicate of E:\WinTunePro\Modules\Cleaning\AdvancedCleaning.ps1)
# Function Invoke-RegistryCleanup removed (duplicate of E:\WinTunePro\Modules\Cleaning\AdvancedCleaning.ps1)
# Function Invoke-RegistryCleanup removed (duplicate of E:\WinTunePro\Modules\Cleaning\AdvancedCleaning.ps1)
# Function Invoke-RegistryCleanup removed (duplicate of E:\WinTunePro\Modules\Cleaning\AdvancedCleaning.ps1)
# Function Invoke-RegistryCleanup removed (duplicate of E:\WinTunePro\Modules\Cleaning\AdvancedCleaning.ps1)
# Function Invoke-RegistryCleanup removed (duplicate of E:\WinTunePro\Modules\Cleaning\AdvancedCleaning.ps1)
# Function Invoke-RegistryCleanup removed (duplicate of E:\WinTunePro\Modules\Cleaning\AdvancedCleaning.ps1)
# Function Invoke-RegistryCleanup removed (duplicate of E:\WinTunePro\Modules\Cleaning\AdvancedCleaning.ps1)
# Function Invoke-RegistryCleanup removed (duplicate of E:\WinTunePro\Modules\Cleaning\AdvancedCleaning.ps1)
# Function Invoke-RegistryCleanup removed (duplicate of E:\WinTunePro\Modules\Cleaning\AdvancedCleaning.ps1)
# Function Invoke-RegistryCleanup removed (duplicate of E:\WinTunePro\Modules\Cleaning\AdvancedCleaning.ps1)
# Function Invoke-RegistryCleanup removed (duplicate of E:\WinTunePro\Modules\Cleaning\AdvancedCleaning.ps1)
