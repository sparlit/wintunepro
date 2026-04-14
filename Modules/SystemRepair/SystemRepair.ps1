#Requires -Version 5.1
<#
.SYNOPSIS
    WinTune Pro SystemRepair Module - SFC and DISM integration
.DESCRIPTION
    System file repair using SFC and DISM for Windows system integrity
#>

function global:Invoke-SFCScan {
    <#
    .SYNOPSIS
        Runs sfc /scannow with progress monitoring.
    #>
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{
        Success       = $true
        ExitCode      = 0
        IntegrityOK   = $false
        Repaired      = $false
        Error         = $null
    }

    if (-not $script:State.IsElevated) {
        Write-Log -Level "ERROR" -Category "SystemRepair" -Message "Admin privileges required for SFC scan"
        $result.Success = $false
        $result.Error = "Admin privileges required"
        return $result
    }

    if ($Preview) {
        Write-Log -Level "INFO" -Category "SystemRepair" -Message "[Preview] Would run sfc /scannow"
        return $result
    }

    if ($TestMode) {
        Write-Log -Level "INFO" -Category "SystemRepair" -Message "[TestMode] SFC scan flagged for execution"
        return $result
    }

    Write-Log -Level "INFO" -Category "SystemRepair" -Message "Starting SFC scan (this may take several minutes)..."

    try {
        $tempFile = [System.IO.Path]::GetTempFileName()
        $proc = Start-Process -FilePath "sfc.exe" -ArgumentList "/scannow" -Wait -PassThru -NoNewWindow -RedirectStandardOutput $tempFile
        $result.ExitCode = $proc.ExitCode

        $output = Get-Content -Path $tempFile -ErrorAction SilentlyContinue
        Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue

        $outputText = $output -join "`n"

        if ($outputText -match "did not find any integrity violations") {
            $result.IntegrityOK = $true
            Write-Log -Level "SUCCESS" -Category "SystemRepair" -Message "SFC scan complete - no integrity violations found"
        } elseif ($outputText -match "successfully repaired") {
            $result.Repaired = $true
            Write-Log -Level "SUCCESS" -Category "SystemRepair" -Message "SFC scan complete - corrupt files were repaired"
        } elseif ($outputText -match "could not perform the requested operation") {
            $result.Success = $false
            $result.Error = "SFC could not perform the requested operation"
            Write-Log -Level "ERROR" -Category "SystemRepair" -Message "SFC could not perform the requested operation"
        } elseif ($outputText -match "found corrupt files but was unable to fix") {
            $result.Success = $false
            $result.Error = "SFC found corrupt files but could not repair them"
            Write-Log -Level "WARNING" -Category "SystemRepair" -Message "SFC found corrupt files but could not repair - run DISM first"
        } else {
            Write-Log -Level "INFO" -Category "SystemRepair" -Message "SFC scan completed with exit code: $($proc.ExitCode)"
        }
    } catch {
        Write-Log -Level "ERROR" -Category "SystemRepair" -Message "Error running SFC: $($_.Exception.Message)"
        $result.Success = $false
        $result.Error = $_.Exception.Message
    }

    return $result
}

function global:Invoke-DISMRestoreHealth {
    <#
    .SYNOPSIS
        Runs DISM /Online /Cleanup-Image /RestoreHealth.
    #>
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{
        Success       = $true
        ExitCode      = 0
        HealthRestored = $false
        Error         = $null
    }

    if (-not $script:State.IsElevated) {
        Write-Log -Level "ERROR" -Category "SystemRepair" -Message "Admin privileges required for DISM RestoreHealth"
        $result.Success = $false
        $result.Error = "Admin privileges required"
        return $result
    }

    if ($Preview) {
        Write-Log -Level "INFO" -Category "SystemRepair" -Message "[Preview] Would run DISM /Online /Cleanup-Image /RestoreHealth"
        return $result
    }

    if ($TestMode) {
        Write-Log -Level "INFO" -Category "SystemRepair" -Message "[TestMode] DISM RestoreHealth flagged for execution"
        return $result
    }

    Write-Log -Level "INFO" -Category "SystemRepair" -Message "Starting DISM RestoreHealth (this may take 15-30 minutes)..."

    try {
        $tempFile = [System.IO.Path]::GetTempFileName()
        $proc = Start-Process -FilePath "DISM.exe" -ArgumentList "/Online", "/Cleanup-Image", "/RestoreHealth" -Wait -PassThru -NoNewWindow -RedirectStandardOutput $tempFile
        $result.ExitCode = $proc.ExitCode

        $output = Get-Content -Path $tempFile -ErrorAction SilentlyContinue
        Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue

        $outputText = $output -join "`n"

        if ($proc.ExitCode -eq 0) {
            $result.HealthRestored = $true
            Write-Log -Level "SUCCESS" -Category "SystemRepair" -Message "DISM RestoreHealth completed successfully"
        } elseif ($proc.ExitCode -eq 3010) {
            $result.HealthRestored = $true
            Write-Log -Level "SUCCESS" -Category "SystemRepair" -Message "DISM RestoreHealth completed - reboot required"
        } else {
            $result.Success = $false
            $result.Error = "DISM returned exit code: $($proc.ExitCode)"
            Write-Log -Level "ERROR" -Category "SystemRepair" -Message "DISM RestoreHealth failed with exit code: $($proc.ExitCode)"
        }
    } catch {
        Write-Log -Level "ERROR" -Category "SystemRepair" -Message "Error running DISM RestoreHealth: $($_.Exception.Message)"
        $result.Success = $false
        $result.Error = $_.Exception.Message
    }

    return $result
}

function global:Invoke-DISMCleanup {
    <#
    .SYNOPSIS
        Runs DISM /Online /Cleanup-Image /StartComponentCleanup.
    #>
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{
        Success       = $true
        ExitCode      = 0
        SpaceRecovered = 0
        Error         = $null
    }

    if (-not $script:State.IsElevated) {
        Write-Log -Level "ERROR" -Category "SystemRepair" -Message "Admin privileges required for DISM cleanup"
        $result.Success = $false
        $result.Error = "Admin privileges required"
        return $result
    }

    if ($Preview) {
        Write-Log -Level "INFO" -Category "SystemRepair" -Message "[Preview] Would run DISM /Online /Cleanup-Image /StartComponentCleanup"
        return $result
    }

    if ($TestMode) {
        Write-Log -Level "INFO" -Category "SystemRepair" -Message "[TestMode] DISM cleanup flagged for execution"
        return $result
    }

    Write-Log -Level "INFO" -Category "SystemRepair" -Message "Starting DISM component cleanup..."

    try {
        $tempFile = [System.IO.Path]::GetTempFileName()
        $proc = Start-Process -FilePath "DISM.exe" -ArgumentList "/Online", "/Cleanup-Image", "/StartComponentCleanup" -Wait -PassThru -NoNewWindow -RedirectStandardOutput $tempFile
        $result.ExitCode = $proc.ExitCode

        $output = Get-Content -Path $tempFile -ErrorAction SilentlyContinue
        Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue

        if ($proc.ExitCode -eq 0) {
            Write-Log -Level "SUCCESS" -Category "SystemRepair" -Message "DISM component cleanup completed successfully"
        } else {
            $result.Success = $false
            $result.Error = "DISM returned exit code: $($proc.ExitCode)"
            Write-Log -Level "ERROR" -Category "SystemRepair" -Message "DISM cleanup failed with exit code: $($proc.ExitCode)"
        }
    } catch {
        Write-Log -Level "ERROR" -Category "SystemRepair" -Message "Error running DISM cleanup: $($_.Exception.Message)"
        $result.Success = $false
        $result.Error = $_.Exception.Message
    }

    return $result
}

function global:Invoke-DISMCheckHealth {
    <#
    .SYNOPSIS
        Runs DISM /Online /Cleanup-Image /CheckHealth.
    #>
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{
        Success       = $true
        ExitCode      = 0
        Healthy       = $false
        Repairable    = $false
        Error         = $null
    }

    if (-not $script:State.IsElevated) {
        Write-Log -Level "ERROR" -Category "SystemRepair" -Message "Admin privileges required for DISM CheckHealth"
        $result.Success = $false
        $result.Error = "Admin privileges required"
        return $result
    }

    if ($Preview) {
        Write-Log -Level "INFO" -Category "SystemRepair" -Message "[Preview] Would run DISM /Online /Cleanup-Image /CheckHealth"
        return $result
    }

    if ($TestMode) {
        Write-Log -Level "INFO" -Category "SystemRepair" -Message "[TestMode] DISM CheckHealth flagged for execution"
        return $result
    }

    Write-Log -Level "INFO" -Category "SystemRepair" -Message "Running DISM health check..."

    try {
        $tempFile = [System.IO.Path]::GetTempFileName()
        $proc = Start-Process -FilePath "DISM.exe" -ArgumentList "/Online", "/Cleanup-Image", "/CheckHealth" -Wait -PassThru -NoNewWindow -RedirectStandardOutput $tempFile
        $result.ExitCode = $proc.ExitCode

        $output = Get-Content -Path $tempFile -ErrorAction SilentlyContinue
        Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue

        $outputText = $output -join "`n"

        if ($outputText -match "No component store corruption detected") {
            $result.Healthy = $true
            Write-Log -Level "SUCCESS" -Category "SystemRepair" -Message "DISM CheckHealth - system is healthy"
        } elseif ($outputText -match "component store corruption can be repaired") {
            $result.Repairable = $true
            Write-Log -Level "WARNING" -Category "SystemRepair" -Message "DISM CheckHealth - corruption detected but repairable"
        } elseif ($outputText -match "corruption is not repairable") {
            $result.Success = $false
            $result.Error = "Component store corruption is not repairable"
            Write-Log -Level "ERROR" -Category "SystemRepair" -Message "DISM CheckHealth - corruption is not repairable"
        }

        if ($proc.ExitCode -eq 0) {
            Write-Log -Level "SUCCESS" -Category "SystemRepair" -Message "DISM health check completed"
        }
    } catch {
        Write-Log -Level "ERROR" -Category "SystemRepair" -Message "Error running DISM CheckHealth: $($_.Exception.Message)"
        $result.Success = $false
        $result.Error = $_.Exception.Message
    }

    return $result
}

function global:Get-SystemFileIntegrity {
    <#
    .SYNOPSIS
        Combined SFC + DISM health check.
    #>
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{
        Success       = $true
        DISMHealthy   = $false
        SFCHealthy    = $false
        OverallHealthy = $false
        Error         = $null
    }

    Write-Log -Level "INFO" -Category "SystemRepair" -Message "Running comprehensive system file integrity check..."

    $dismResult = Invoke-DISMCheckHealth -Preview:$Preview -TestMode:$TestMode
    $result.DISMHealthy = $dismResult.Healthy

    $sfcResult = Invoke-SFCScan -Preview:$Preview -TestMode:$TestMode
    $result.SFCHealthy = $sfcResult.IntegrityOK

    $result.OverallHealthy = $result.DISMHealthy -and $result.SFCHealthy

    if ($result.OverallHealthy) {
        Write-Log -Level "SUCCESS" -Category "SystemRepair" -Message "System file integrity check: all clear"
    } else {
        Write-Log -Level "WARNING" -Category "SystemRepair" -Message "System file integrity check: issues detected"
    }

    return $result
}

function global:Invoke-FullSystemRepair {
    <#
    .SYNOPSIS
        Full orchestrator: DISM CheckHealth -> RestoreHealth -> SFC.
    #>
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{
        Success       = $true
        Operations    = @{}
        RepairNeeded  = $false
        Error         = $null
    }

    if (-not $script:State.IsElevated) {
        Write-Log -Level "ERROR" -Category "SystemRepair" -Message "Admin privileges required for full system repair"
        $result.Success = $false
        $result.Error = "Admin privileges required"
        return $result
    }

    Write-Log -Level "INFO" -Category "SystemRepair" -Message "Starting full system repair..."

    $result.Operations.CheckHealth = Invoke-DISMCheckHealth -Preview:$Preview -TestMode:$TestMode

    if ($result.Operations.CheckHealth.Repairable -or -not $result.Operations.CheckHealth.Healthy) {
        $result.RepairNeeded = $true
        Write-Log -Level "INFO" -Category "SystemRepair" -Message "Corruption detected - running RestoreHealth..."
        $result.Operations.RestoreHealth = Invoke-DISMRestoreHealth -Preview:$Preview -TestMode:$TestMode
    } else {
        Write-Log -Level "INFO" -Category "SystemRepair" -Message "DISM CheckHealth passed - skipping RestoreHealth"
    }

    $result.Operations.SFCScan = Invoke-SFCScan -Preview:$Preview -TestMode:$TestMode

    if (-not $result.Operations.SFCScan.Success) {
        $result.Success = $false
    }

    Write-Log -Level "SUCCESS" -Category "SystemRepair" -Message "Full system repair complete"
    return $result
}

function global:Get-SystemRepairLog {
    <#
    .SYNOPSIS
        Parses CBS.log and DISM.log for issues.
    #>

    $result = @{
        Success        = $true
        CBSIssues      = @()
        DISMIssues     = @()
        TotalIssues    = 0
        Error          = $null
    }

    $cbsLog = "C:\Windows\Logs\CBS\CBS.log"
    $dismLog = "C:\Windows\Logs\DISM\dism.log"

    Write-Log -Level "INFO" -Category "SystemRepair" -Message "Parsing system repair logs..."

    if (Test-Path $cbsLog) {
        try {
            $cbsContent = Get-Content -Path $cbsLog -Tail 500 -ErrorAction SilentlyContinue
            $cbsIssues = $cbsContent | Where-Object { $_ -match "error|corrupt|cannot repair|failed" }
            $result.CBSIssues = $cbsIssues | Select-Object -Last 20
            Write-Log -Level "INFO" -Category "SystemRepair" -Message "Found $($result.CBSIssues.Count) CBS log issues"
        } catch {
            Write-Log -Level "WARNING" -Category "SystemRepair" -Message "Error reading CBS log: $($_.Exception.Message)"
        }
    } else {
        Write-Log -Level "INFO" -Category "SystemRepair" -Message "CBS log not found at $cbsLog"
    }

    if (Test-Path $dismLog) {
        try {
            $dismContent = Get-Content -Path $dismLog -Tail 500 -ErrorAction SilentlyContinue
            $dismIssues = $dismContent | Where-Object { $_ -match "error|failed|warning" }
            $result.DISMIssues = $dismIssues | Select-Object -Last 20
            Write-Log -Level "INFO" -Category "SystemRepair" -Message "Found $($result.DISMIssues.Count) DISM log issues"
        } catch {
            Write-Log -Level "WARNING" -Category "SystemRepair" -Message "Error reading DISM log: $($_.Exception.Message)"
        }
    } else {
        Write-Log -Level "INFO" -Category "SystemRepair" -Message "DISM log not found at $dismLog"
    }

    $result.TotalIssues = $result.CBSIssues.Count + $result.DISMIssues.Count
    return $result
}

function global:Test-SystemRepairNeeded {
    <#
    .SYNOPSIS
        Quick health assessment to determine if repair is needed.
    #>

    $result = @{
        RepairNeeded  = $false
        DISMStatus    = "Unknown"
        SFCStatus     = "Unknown"
        Issues        = @()
    }

    Write-Log -Level "INFO" -Category "SystemRepair" -Message "Quick system health assessment..."

    if (-not $script:State.IsElevated) {
        Write-Log -Level "WARNING" -Category "SystemRepair" -Message "Admin privileges required for health assessment"
        $result.Issues += "Cannot run full check without admin privileges"
        return $result
    }

    try {
        $dismOutput = & DISM /Online /Cleanup-Image /CheckHealth 2>&1
        $dismText = $dismOutput -join "`n"

        if ($dismText -match "No component store corruption detected") {
            $result.DISMStatus = "Healthy"
        } elseif ($dismText -match "component store corruption can be repaired") {
            $result.DISMStatus = "Repairable"
            $result.RepairNeeded = $true
            $result.Issues += "Component store corruption detected (repairable)"
        } elseif ($dismText -match "corruption is not repairable") {
            $result.DISMStatus = "NotRepairable"
            $result.RepairNeeded = $true
            $result.Issues += "Component store corruption not repairable"
        }
    } catch {
        $result.DISMStatus = "Error"
        $result.Issues += "DISM check failed: $($_.Exception.Message)"
    }

    $cbsLog = "C:\Windows\Logs\CBS\CBS.log"
    if (Test-Path $cbsLog) {
        $recentErrors = Get-Content -Path $cbsLog -Tail 100 -ErrorAction SilentlyContinue |
            Where-Object { $_ -match "cannot repair" }
        if ($recentErrors) {
            $result.SFCStatus = "CorruptionFound"
            $result.RepairNeeded = $true
            $result.Issues += "CBS log shows unrepaired corruption"
        } else {
            $result.SFCStatus = "OK"
        }
    }

    if ($result.RepairNeeded) {
        Write-Log -Level "WARNING" -Category "SystemRepair" -Message "System repair recommended - $($result.Issues.Count) issues found"
    } else {
        Write-Log -Level "SUCCESS" -Category "SystemRepair" -Message "System appears healthy"
    }

    return $result
}
