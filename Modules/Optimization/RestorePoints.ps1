#Requires -Version 5.1
<#
.SYNOPSIS
    Restore Points Management Module
.DESCRIPTION
    Manages System Restore points including creation, listing,
    and cleanup of old restore points.
#>


function global:Get-SystemRestorePoints {
    <#
    .SYNOPSIS
        Lists all system restore points.
    #>
    $result = @{
        Success = $false
        RestorePoints = @()
        Message = ""
    }
    
    try {
        # Check if System Restore is enabled
        $systemDrive = Get-PSDrive C -ErrorAction SilentlyContinue
        if (-not $systemDrive) {
            $result.Message = "System drive not found"
            return $result
        }
        
        # Get restore points using WMI
        $restorePoints = Get-CimInstance -ClassName Win32_SystemRestore -ErrorAction SilentlyContinue
        
        if ($restorePoints) {
            foreach ($rp in $restorePoints) {
                $result.RestorePoints += @{
                    SequenceNumber = $rp.SequenceNumber
                    CreationTime = $rp.CreationTime
                    Description = $rp.Description
                    RestorePointType = $rp.RestorePointType
                    EventType = $rp.EventType
                }
            }
        }
        
        $result.Success = $true
        $result.Message = "Found $($result.RestorePoints.Count) restore points"
        
    } catch {
        $result.Message = "Error getting restore points: $($_.Exception.Message)"
    }
    
    return $result
}



function global:New-ManualRestorePoint {
    <#
    .SYNOPSIS
        Creates a new manual system restore point.
    #>
    param(
        [string]$Description = "WinTune Pro - Manual Restore Point"
    )
    
    $result = @{
        Success = $false
        RestorePointCreated = $false
        SequenceNumber = $null
        Message = ""
    }
    
    try {
        # Check if running as administrator
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if (-not $isAdmin) {
            $result.Message = "Administrator privileges required to create restore point"
            return $result
        }
        
        # Enable system restore on C: drive if not enabled
        try {
            Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
        } catch { Write-Log -Level "WARNING" -Category "System" -Message $_.Exception.Message }


function global:Clear-OldRestorePoints {
    <#
    .SYNOPSIS
        Removes old restore points, keeping the most recent ones.
    #>
    param(
        [int]$KeepLatest = 3
    )
    
    $result = @{
        Success = $false
        BytesRecovered = 0
        RestorePointsRemoved = 0
        Message = ""
        ItemsCleaned = @()
    }
    
    try {
        # Get all restore points
        $restorePoints = Get-CimInstance -ClassName Win32_SystemRestore -ErrorAction SilentlyContinue |
                         Sort-Object SequenceNumber -Descending
        
        if (-not $restorePoints) {
            $result.Success = $true
            $result.Message = "No restore points found"
            return $result
        }
        
        # Keep only the latest ones
        $toRemove = $restorePoints | Select-Object -Skip $KeepLatest
        
        foreach ($rp in $toRemove) {
            try {
                # Delete restore point using vssadmin
                $vssOutput = vssadmin delete shadows /shadow="{ $($rp.SequenceNumber) }" /quiet 2>&1
                $result.RestorePointsRemoved++
                $result.ItemsCleaned += "Restore Point #$($rp.SequenceNumber) - $($rp.Description)"
            } catch {
                # Try alternative method
                try {
                    Remove-CimInstance -InputObject $rp -ErrorAction SilentlyContinue
                    $result.RestorePointsRemoved++
                } catch { Write-Log -Level "WARNING" -Category "System" -Message $_.Exception.Message }
            }
        }
        
        # Calculate approximate space recovered
        # Approximate calculation based on removed count
        if ($result.RestorePointsRemoved -gt 0) {
            $result.BytesRecovered = $result.RestorePointsRemoved * 500MB
        }
        
        $result.Success = $true
        $result.Message = "Removed $($result.RestorePointsRemoved) old restore points"
        
    } catch {
        $result.Message = "Error clearing old restore points: $($_.Exception.Message)"
    }
    
    return $result
}



function global:Clear-AllRestorePoints {
    <#
    .SYNOPSIS
        Removes all system restore points.
    #>
    $result = @{
        Success = $false
        BytesRecovered = 0
        RestorePointsRemoved = 0
        Message = ""
        ItemsCleaned = @()
    }
    
    try {
        # Get count before deletion
        $restorePoints = Get-CimInstance -ClassName Win32_SystemRestore -ErrorAction SilentlyContinue
        $countBefore = if ($restorePoints) { @($restorePoints).Count } else { 0 }
        
        if ($countBefore -eq 0) {
            $result.Success = $true
            $result.Message = "No restore points to remove"
            return $result
        }
        
        # Delete all shadow copies (includes restore points)
        vssadmin delete shadows /all /quiet 2>$null
        
        # Verify deletion
        $restorePointsAfter = Get-CimInstance -ClassName Win32_SystemRestore -ErrorAction SilentlyContinue
        $countAfter = if ($restorePointsAfter) { @($restorePointsAfter).Count } else { 0 }
        
        $result.RestorePointsRemoved = $countBefore - $countAfter
        $result.BytesRecovered = $result.RestorePointsRemoved * 500MB  # Approximate
        
        $result.Success = $true
        $result.Message = "Removed all $($result.RestorePointsRemoved) restore points"
        
    } catch {
        $result.Message = "Error clearing all restore points: $($_.Exception.Message)"
    }
    
    return $result
}



function global:Clear-ShadowCopiesDeep {
    <#
    .SYNOPSIS
        Removes all shadow copies (extended version).
    #>
    $result = @{
        Success = $false
        BytesRecovered = 0
        ShadowCopiesRemoved = 0
        Message = ""
        ItemsCleaned = @()
    }
    
    try {
        # Get shadow copies before deletion
        $shadowsBefore = Get-CimInstance -ClassName Win32_ShadowCopy -ErrorAction SilentlyContinue
        $countBefore = if ($shadowsBefore) { @($shadowsBefore).Count } else { 0 }
        
        # Get total size
        $totalSize = 0
        foreach ($shadow in $shadowsBefore) {
            $totalSize += 500MB  # Approximate per shadow copy
        }
        
        if ($countBefore -eq 0) {
            $result.Success = $true
            $result.Message = "No shadow copies to remove"
            return $result
        }
        
        # Delete all shadow copies
        vssadmin delete shadows /all /quiet 2>$null
        
        # Verify
        $shadowsAfter = Get-CimInstance -ClassName Win32_ShadowCopy -ErrorAction SilentlyContinue
        $countAfter = if ($shadowsAfter) { @($shadowsAfter).Count } else { 0 }
        
        $result.ShadowCopiesRemoved = $countBefore - $countAfter
        $result.BytesRecovered = $result.ShadowCopiesRemoved * 500MB
        
        $result.Success = $true
        $result.Message = "Removed $($result.ShadowCopiesRemoved) shadow copies"
        
    } catch {
        $result.Message = "Error clearing shadow copies: $($_.Exception.Message)"
    }
    
    return $result
}



function global:Set-RestorePointStorage {
    <#
    .SYNOPSIS
        Configures system restore storage settings.
    #>
    param(
        [ValidateRange(1, 100)]
        [int]$MaxUsagePercent = 10
    )
    
    $result = @{
        Success = $false
        Message = ""
        PreviousSettings = @{}
        NewSettings = @{}
    }
    
    try {
        # Get current settings
        $systemDrive = "C:\"
        $vssAdminOutput = vssadmin list shadowstorage 2>&1
        
        # Set new storage limit using vssadmin
        $setMax = vssadmin resize shadowstorage /for=C: /on=C: /maxsize="$MaxUsagePercent`%" 2>&1
        
        $result.Success = $true
        $result.NewSettings = @{
            MaxUsagePercent = $MaxUsagePercent
        }
        $result.Message = "Restore point storage set to $MaxUsagePercent% of drive"
        
    } catch {
        $result.Message = "Error setting restore point storage: $($_.Exception.Message)"
    }
    
    return $result
}



# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Test-SystemRestoreEnabled removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)



# Function Enable-SystemRestore removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Enable-SystemRestore removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Enable-SystemRestore removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Enable-SystemRestore removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Enable-SystemRestore removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Enable-SystemRestore removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Enable-SystemRestore removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Enable-SystemRestore removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Enable-SystemRestore removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Enable-SystemRestore removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Enable-SystemRestore removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Enable-SystemRestore removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Enable-SystemRestore removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Enable-SystemRestore removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Enable-SystemRestore removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Enable-SystemRestore removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Enable-SystemRestore removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Enable-SystemRestore removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Enable-SystemRestore removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Enable-SystemRestore removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Enable-SystemRestore removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Enable-SystemRestore removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Enable-SystemRestore removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Enable-SystemRestore removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Enable-SystemRestore removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Enable-SystemRestore removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)
# Function Enable-SystemRestore removed (duplicate of E:\WinTunePro\Core\SafetyNet.ps1)



function global:Disable-SystemRestore {
    <#
    .SYNOPSIS
        Disables System Restore on the system drive.
    #>
    $result = @{
        Success = $false
        Message = ""
        BytesRecovered = 0
    }
    
    try {
        # Get current restore points count
        $rpCount = @(Get-CimInstance -ClassName Win32_SystemRestore -ErrorAction SilentlyContinue).Count
        
        # Disable system restore
        Disable-ComputerRestore -Drive "C:\" -ErrorAction Stop
        
        # Set registry to disable
        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore"
        Set-ItemProperty -Path $regPath -Name "DisableSR" -Value 1 -ErrorAction SilentlyContinue
        
        # Approximate space recovered
        $result.BytesRecovered = $rpCount * 500MB
        
        $result.Success = $true
        $result.Message = "System Restore disabled successfully. $rpCount restore points removed."
        
    } catch {
        $result.Message = "Error disabling System Restore: $($_.Exception.Message)"
    }
    
    return $result
}



function global:Restore-FromRestorePoint {
    <#
    .SYNOPSIS
        Initiates a system restore from a specified restore point.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [int]$SequenceNumber
    )
    
    $result = @{
        Success = $false
        Message = ""
    }
    
    try {
        # Verify restore point exists
        $rp = Get-CimInstance -ClassName Win32_SystemRestore -Filter "SequenceNumber = $SequenceNumber" -ErrorAction SilentlyContinue
        
        if (-not $rp) {
            $result.Message = "Restore point $SequenceNumber not found"
            return $result
        }
        
        # Initiate restore
        $restore = Restore-Computer -RestorePoint $SequenceNumber -ErrorAction Stop
        
        $result.Success = $true
        $result.Message = "System restore initiated. Computer will restart."
        
    } catch {
        $result.Message = "Error restoring from restore point: $($_.Exception.Message)"
    }
    
    return $result
}



function global:Manage-AllRestorePoints {
    <#
    .SYNOPSIS
        Executes restore point management operations.
    #>
    param(
        [ValidateSet("List", "Cleanup", "ClearAll", "Create")]
        [string]$Action = "Cleanup",
        [int]$KeepLatest = 3,
        [string]$Description = "WinTune Pro - Manual Restore Point"
    )
    
    $results = @{
        Success = $false
        Action = $Action
        Results = @{}
    }
    
    switch ($Action) {
        "List" {
            $results.Results = Get-SystemRestorePoints
            $results.Success = $results.Results.Success
        }
        "Cleanup" {
            $results.Results = Clear-OldRestorePoints -KeepLatest $KeepLatest
            $results.Success = $results.Results.Success
        }
        "ClearAll" {
            $results.Results = Clear-AllRestorePoints
            $results.Success = $results.Results.Success
        }
        "Create" {
            $results.Results = New-ManualRestorePoint -Description $Description
            $results.Success = $results.Results.Success
        }
    }
    
    return $results
}
        
        # Create restore point
        $checkPoint = Checkpoint-Computer -Description $Description -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        
        # Get the created restore point
        Start-Sleep -Seconds 3
        $latestRP = Get-CimInstance -ClassName Win32_SystemRestore -ErrorAction SilentlyContinue | 
                    Sort-Object SequenceNumber -Descending | Select-Object -First 1
        
        $result.Success = $true
        $result.RestorePointCreated = $true
        $result.SequenceNumber = if ($latestRP) { $latestRP.SequenceNumber } else { "Unknown" }
        $result.Message = "Restore point created successfully"
        
    } catch {
        $result.Message = "Error creating restore point: $($_.Exception.Message)"
    }
    
    return $result
}
