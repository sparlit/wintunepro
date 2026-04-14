<#
.SYNOPSIS
    WinTune Pro SafetyNet Module - System protection and restore points
.DESCRIPTION
    Provides restore point management, registry backup, and safety checks
#>

# ============================================================================
# SAFETYNET CONSTANTS
# ============================================================================

$script:RestorePointType = @{
    APPLICATION_INSTALL = 0
    APPLICATION_UNINSTALL = 1
    MODIFY_SETTINGS = 12
    CANCELLED_OPERATION = 13
    BACKUP_RECOVERY = 14
}

$script:HighRiskOperations = @(
    "Remove-WindowsOld",
    "Clear-ShadowCopies", 
    "Reset-NetworkStack",
    "Dism-ResetBase",
    "Clear-Registry"
)

# ============================================================================
# RESTORE POINT FUNCTIONS
# ============================================================================

function global:Test-SystemRestoreEnabled {
    <#
    .SYNOPSIS
        Checks if System Restore is enabled on the system.
    #>
    try {
        $service = Get-Service -Name "srservice" -ErrorAction SilentlyContinue
        return $service.Status -eq "Running"
    } catch {
        return $false
    }
}

function global:Enable-SystemRestore {
    <#
    .SYNOPSIS
        Enables System Restore on the system drive.
    #>
    param(
        [string]$Drive = "C:"
    )
    
    try {
        Enable-ComputerRestore -Drive $Drive -ErrorAction Stop
        Write-Log -Level "SUCCESS" -Category "SafetyNet" -Message "System Restore enabled on $Drive"
        return @{ Success = $true; Message = "System Restore enabled successfully" }
    } catch {
        Write-Log -Level "ERROR" -Category "SafetyNet" -Message "Failed to enable System Restore: $($_.Exception.Message)"
        return @{ Success = $false; Message = $_.Exception.Message }
    }
}

function global:New-SafeRestorePoint {
    <#
    .SYNOPSIS
        Creates a system restore point with error handling.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [ValidateSet('APPLICATION_INSTALL','APPLICATION_UNINSTALL','MODIFY_SETTINGS','CANCELLED_OPERATION','BACKUP_RECOVERY')]
        [string]$Type = 'MODIFY_SETTINGS',
        
        [switch]$Preview,
        [switch]$TestMode
    )
    
    if ($Preview -or $TestMode) {
        return @{ Success = $true; Message = "[Preview] Would create restore point: WinTune Pro - $Name" }
    }
    
    # Check if System Restore is enabled
    if (-not (Test-SystemRestoreEnabled)) {
        Write-Log -Level "WARNING" -Category "SafetyNet" -Message "System Restore is not enabled. Attempting to enable..."
        $enableResult = Enable-SystemRestore
        if (-not $enableResult.Success) {
            return @{ Success = $false; Message = "System Restore is not available: $($enableResult.Message)" }
        }
    }
    
    # Check if we're elevated
    if (-not $script:State.IsElevated) {
        return @{ Success = $false; Message = "Administrator privileges required to create restore point" }
    }
    
    try {
        # Create restore point
        $description = "WinTune Pro - $Name"
        
        # Map the string type to the actual enum value that Checkpoint-Computer expects
        # Checkpoint-Computer accepts: APPLICATION_INSTALL, APPLICATION_UNINSTALL, MODIFY_SETTINGS, CANCELLED_OPERATION, BACKUP_RECOVERY
        # These must be passed as the actual string, not a numeric value
        $validRestorePointType = $Type
        
        Checkpoint-Computer -Description $description -RestorePointType $validRestorePointType -ErrorAction Stop
        
        # Update state
        if ($script:State) {
            $script:State.RestorePointCreated = $true
            $script:State.RestorePointName = $description
        }
        
        Write-Log -Level "SUCCESS" -Category "SafetyNet" -Message "Restore point created: $description"
        
        return @{ 
            Success = $true
            Message = "Restore point created successfully"
            Name = $description
            Timestamp = Get-Date
        }
    } catch {
        Write-Log -Level "ERROR" -Category "SafetyNet" -Message "Failed to create restore point: $($_.Exception.Message)"
        return @{ Success = $false; Message = $_.Exception.Message }
    }
}

function global:Get-RestorePoints {
    <#
    .SYNOPSIS
        Lists all available restore points.
    #>
    try {
        $restorePoints = Get-ComputerRestorePoint -ErrorAction Stop | 
            Select-Object SequenceNumber, CreationTime, Description |
            Sort-Object CreationTime -Descending
        
        return @{
            Success = $true
            RestorePoints = $restorePoints
        }
    } catch {
        return @{
            Success = $false
            Message = $_.Exception.Message
            RestorePoints = @()
        }
    }
}

function global:Restore-SystemFromPoint {
    <#
    .SYNOPSIS
        Restores the system to a specific restore point.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [int]$SequenceNumber
    )
    
    if (-not $script:State.IsElevated) {
        return @{ Success = $false; Message = "Administrator privileges required for system restore" }
    }
    
    try {
        Write-Log -Level "WARNING" -Category "SafetyNet" -Message "Initiating system restore to point $SequenceNumber..."
        
        # This will restart the computer
        Restore-Computer -RestorePoint $SequenceNumber -ErrorAction Stop
        
        return @{ 
            Success = $true
            Message = "System restore initiated. The computer will restart."
        }
    } catch {
        Write-Log -Level "ERROR" -Category "SafetyNet" -Message "Failed to restore system: $($_.Exception.Message)"
        return @{ Success = $false; Message = $_.Exception.Message }
    }
}

# ============================================================================
# REGISTRY BACKUP FUNCTIONS
# ============================================================================

function global:Restore-RegistryBackup {
    <#
    .SYNOPSIS
        Restores registry keys from a backup.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$BackupPath
    )
    
    if (-not (Test-Path $BackupPath)) {
        return @{ Success = $false; Message = "Backup path not found: $BackupPath" }
    }
    
    $regFiles = Get-ChildItem -Path $BackupPath -Filter "*.reg"
    
    if ($regFiles.Count -eq 0) {
        return @{ Success = $false; Message = "No registry backup files found in $BackupPath" }
    }
    
    $results = @{
        Success = $true
        RestoredFiles = @()
        FailedFiles = @()
    }
    
    foreach ($file in $regFiles) {
        try {
            $process = Start-Process -FilePath "reg.exe" -ArgumentList "import", "`"$($file.FullName)`"" -NoNewWindow -Wait -PassThru
            
            if ($process.ExitCode -eq 0) {
                $results.RestoredFiles += $file.Name
                Write-Log -Level "SUCCESS" -Category "SafetyNet" -Message "Restored registry from: $($file.Name)"
            } else {
                $results.FailedFiles += $file.Name
                Write-Log -Level "WARNING" -Category "SafetyNet" -Message "Failed to restore registry from: $($file.Name)"
            }
        } catch {
            $results.FailedFiles += $file.Name
            $results.Success = $false
            Write-Log -Level "ERROR" -Category "SafetyNet" -Message "Error restoring registry from $($file.Name): $($_.Exception.Message)"
        }
    }
    
    return $results
}

# ============================================================================
# SAFETY CHECK FUNCTIONS
# ============================================================================

function global:Test-OperationSafety {
    <#
    .SYNOPSIS
        Evaluates the safety level of an operation.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$OperationName,
        
        [hashtable]$Parameters = @{}
    )
    
    $assessment = @{
        Operation = $OperationName
        IsHighRisk = $false
        Warnings = @()
        BlockReasons = @()
        RequiresConfirmation = $false
        CanProceed = $true
    }
    
    # Check if operation is in high-risk list
    if ($OperationName -in $script:HighRiskOperations) {
        $assessment.IsHighRisk = $true
        $assessment.RequiresConfirmation = $true
        $assessment.Warnings += "This operation is classified as high-risk"
    }
    
    # Check if we're on a critical system
    if ($script:State.CriticalSystemDetected) {
        if ($assessment.IsHighRisk) {
            $assessment.BlockReasons += "High-risk operation blocked on critical system ($($script:State.CriticalSystemType))"
            $assessment.CanProceed = $false
        } else {
            $assessment.Warnings += "Operation on critical system: $($script:State.CriticalSystemType)"
            $assessment.RequiresConfirmation = $true
        }
    }
    
    # Check if restore point exists
    if (-not $script:State.RestorePointCreated -and -not $script:State.IsTestMode) {
        $assessment.Warnings += "No restore point has been created for this session"
        $assessment.RequiresConfirmation = $true
    }
    
    # Check for admin privileges
    if (-not $script:State.IsElevated) {
        $adminRequiredOperations = @(
            "Clear-SystemTempFiles",
            "Reset-TCPIPStack",
            "Reset-WinsockCatalog",
            "Optimize-Services",
            "Clear-WindowsUpdateCache"
        )
        
        if ($OperationName -in $adminRequiredOperations) {
            $assessment.BlockReasons += "Administrator privileges required"
            $assessment.CanProceed = $false
        }
    }
    
    return $assessment
}

function global:Invoke-SafeOperation {
    <#
    .SYNOPSIS
        Executes an operation with safety checks and logging.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [scriptblock]$Operation,
        
        [Parameter(Mandatory=$true)]
        [string]$OperationName,
        
        [hashtable]$Parameters = @{},
        
        [switch]$Force,
        
        [switch]$Preview
    )
    
    if ($Preview) {
        return @{ Success = $true; Result = "[Preview] Would execute: $OperationName"; Operation = $OperationName }
    }
    
    # Run safety assessment
    $assessment = Test-OperationSafety -OperationName $OperationName -Parameters $Parameters
    
    # Check if we can proceed
    if (-not $assessment.CanProceed -and -not $Force) {
        Write-Log -Level "ERROR" -Category "SafetyNet" -Message "Operation blocked: $($assessment.BlockReasons -join '; ')"
        return @{
            Success = $false
            Blocked = $true
            Reasons = $assessment.BlockReasons
        }
    }
    
    # Show warnings
    if ($assessment.Warnings.Count -gt 0) {
        foreach ($warning in $assessment.Warnings) {
            Write-Log -Level "WARNING" -Category "SafetyNet" -Message "Warning: $warning"
        }
    }
    
    # Require confirmation if needed
    if ($assessment.RequiresConfirmation -and -not $Force) {
        # Auto-approve file edit operations when configured to do so
        try {
            $autoFile = Get-ConfigValue "AutoApproveFileEdits"
        } catch { $autoFile = $false }
        if ($autoFile -and ($OperationName -match "(?i)edit|write|save|delete|import|export|restore|restore-registry")) {
            Write-Log -Level "INFO" -Category "SafetyNet" -Message "Auto-approving file/edit operation: $OperationName"
        }
        else {
            if (-not $script:State.IsTestMode) {
                Write-Warning "This operation requires confirmation: $OperationName"
                # In GUI mode, this would show a dialog. For now, we'll proceed.
            }
        }
    }
    
    # Execute operation
    try {
        Write-Log -Level "INFO" -Category "SafetyNet" -Message "Starting operation: $OperationName"
        
        $result = & $Operation @Parameters
        
        Write-Log -Level "SUCCESS" -Category "SafetyNet" -Message "Operation completed: $OperationName"
        
        return @{
            Success = $true
            Result = $result
            Operation = $OperationName
        }
    } catch {
        Write-Log -Level "ERROR" -Category "SafetyNet" -Message "Operation failed: $OperationName - $($_.Exception.Message)"
        
        return @{
            Success = $false
            Error = $_.Exception.Message
            Operation = $OperationName
        }
    }
}

# ============================================================================
# BACKUP CLEANUP FUNCTIONS
# ============================================================================

function global:Clear-OldBackups {
    <#
    .SYNOPSIS
        Removes backups older than the specified age.
    #>
    param(
        [int]$MaxAgeDays = 30
    )
    
    $cutoffDate = (Get-Date).AddDays(-$MaxAgeDays)
    $backupFolders = Get-ChildItem -Path $script:Paths.Backups -Directory -ErrorAction SilentlyContinue
    
    $results = @{
        Removed = @()
        Failed = @()
        SpaceRecovered = 0
    }
    
    foreach ($folder in $backupFolders) {
        if ($folder.CreationTime -lt $cutoffDate) {
            try {
                $size = (Get-ChildItem -Path $folder.FullName -Recurse -Force -ErrorAction SilentlyContinue | 
                        Measure-Object -Property Length -Sum).Sum
                
                Remove-Item -Path $folder.FullName -Recurse -Force -ErrorAction Stop
                $results.Removed += $folder.Name
                $results.SpaceRecovered += $size
                
                Write-Log -Level "INFO" -Category "SafetyNet" -Message "Removed old backup: $($folder.Name)"
            } catch {
                $results.Failed += $folder.Name
                Write-Log -Level "WARNING" -Category "SafetyNet" -Message "Failed to remove backup $($folder.Name): $($_.Exception.Message)"
            }
        }
    }
    
    return $results
}

function global:Get-BackupStatus {
    <#
    .SYNOPSIS
        Returns status of all backups.
    #>
    $backupFolders = Get-ChildItem -Path $script:Paths.Backups -Directory -ErrorAction SilentlyContinue
    
    $status = @{
        TotalBackups = $backupFolders.Count
        TotalSize = 0
        OldestBackup = $null
        NewestBackup = $null
        Backups = @()
    }
    
    foreach ($folder in $backupFolders) {
        $size = (Get-ChildItem -Path $folder.FullName -Recurse -Force -ErrorAction SilentlyContinue | 
                Measure-Object -Property Length -Sum).Sum
        $status.TotalSize += $size
        
        $backupInfo = @{
            Name = $folder.Name
            Path = $folder.FullName
            Size = Format-FileSize $size
            Created = $folder.CreationTime
            Age = (Get-Date) - $folder.CreationTime
        }
        
        $status.Backups += $backupInfo
        
        if (-not $status.OldestBackup -or $folder.CreationTime -lt $status.OldestBackup) {
            $status.OldestBackup = $folder.CreationTime
        }
        if (-not $status.NewestBackup -or $folder.CreationTime -gt $status.NewestBackup) {
            $status.NewestBackup = $folder.CreationTime
        }
    }
    
    $status.TotalSizeFormatted = Format-FileSize $status.TotalSize
    
    return $status
}
