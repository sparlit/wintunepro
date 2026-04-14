#Requires -Version 5.1
<#
.SYNOPSIS
    WinTune Pro ScheduledTaskMgr Module - Scheduled task management
.DESCRIPTION
    Windows scheduled task management for telemetry and bloatware control
#>

$global:TelemetryTaskPaths = @(
    "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser"
    "\Microsoft\Windows\Application Experience\ProgramDataUpdater"
    "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator"
    "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip"
    "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector"
    "\Microsoft\Windows\Maps\MapsUpdateTask"
    "\Microsoft\Windows\Maps\MapsToastTask"
    "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem"
    "\Microsoft\Windows\Windows Error Reporting\QueueReporting"
)

$global:BloatTaskPaths = @(
    "\Microsoft\Windows\Application Experience\StartupAppTask"
    "\Microsoft\Windows\CloudExperienceHost\CreateObjectTask"
    "\Microsoft\Windows\DiskFootprint\Diagnostics"
    "\Microsoft\Windows\Maintenance\WinSAT"
    "\Microsoft\Windows\Shell\FamilySafetyMonitor"
    "\Microsoft\Windows\Shell\FamilySafetyRefreshTask"
    "\Microsoft\Windows\Windows Filtering Platform\BfeOnServiceStartTypeChange"
)

$global:DisabledTasksHistory = @()

function global:Get-WindowsTelemetryTasks {
    <#
    .SYNOPSIS
        Lists telemetry-related scheduled tasks.
    #>

    $result = @{
        Success = $true
        Tasks   = @()
        Error   = $null
    }

    Write-Log -Level "INFO" -Category "ScheduledTaskMgr" -Message "Scanning for telemetry tasks..."

    foreach ($taskPath in $global:TelemetryTaskPaths) {
        try {
            $task = Get-ScheduledTask -TaskPath (Split-Path $taskPath -Parent) -TaskName (Split-Path $taskPath -Leaf) -ErrorAction SilentlyContinue
            if ($task) {
                $result.Tasks += [PSCustomObject]@{
                    TaskPath  = $taskPath
                    TaskName  = $task.TaskName
                    State     = $task.State
                    Category  = "Telemetry"
                }
                Write-Log -Level "INFO" -Category "ScheduledTaskMgr" -Message "Found telemetry task: $taskPath [$($task.State)]"
            }
        } catch {
            Write-Log -Level "WARNING" -Category "ScheduledTaskMgr" -Message "Error checking task $taskPath : $($_.Exception.Message)"
        }
    }

    Write-Log -Level "INFO" -Category "ScheduledTaskMgr" -Message "Found $($result.Tasks.Count) telemetry tasks"
    return $result
}

function global:Get-WindowsBloatTasks {
    <#
    .SYNOPSIS
        Lists bloatware/background scheduled tasks.
    #>

    $result = @{
        Success = $true
        Tasks   = @()
        Error   = $null
    }

    Write-Log -Level "INFO" -Category "ScheduledTaskMgr" -Message "Scanning for bloatware tasks..."

    foreach ($taskPath in $global:BloatTaskPaths) {
        try {
            $task = Get-ScheduledTask -TaskPath (Split-Path $taskPath -Parent) -TaskName (Split-Path $taskPath -Leaf) -ErrorAction SilentlyContinue
            if ($task) {
                $result.Tasks += [PSCustomObject]@{
                    TaskPath  = $taskPath
                    TaskName  = $task.TaskName
                    State     = $task.State
                    Category  = "Bloatware"
                }
                Write-Log -Level "INFO" -Category "ScheduledTaskMgr" -Message "Found bloat task: $taskPath [$($task.State)]"
            }
        } catch {
            Write-Log -Level "WARNING" -Category "ScheduledTaskMgr" -Message "Error checking task $taskPath : $($_.Exception.Message)"
        }
    }

    Write-Log -Level "INFO" -Category "ScheduledTaskMgr" -Message "Found $($result.Tasks.Count) bloatware tasks"
    return $result
}

function global:Disable-TelemetryTasks {
    <#
    .SYNOPSIS
        Disables known telemetry scheduled tasks.
    #>
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{
        Success       = $true
        TasksDisabled = 0
        TasksSkipped  = 0
        Error         = $null
    }

    if (-not $script:State.IsElevated) {
        Write-Log -Level "ERROR" -Category "ScheduledTaskMgr" -Message "Admin privileges required to disable telemetry tasks"
        $result.Success = $false
        $result.Error = "Admin privileges required"
        return $result
    }

    Write-Log -Level "INFO" -Category "ScheduledTaskMgr" -Message "Disabling telemetry tasks..."

    foreach ($taskPath in $global:TelemetryTaskPaths) {
        try {
            $taskName = Split-Path $taskPath -Leaf
            $taskDir = Split-Path $taskPath -Parent

            $task = Get-ScheduledTask -TaskPath $taskDir -TaskName $taskName -ErrorAction SilentlyContinue
            if (-not $task) {
                Write-Log -Level "INFO" -Category "ScheduledTaskMgr" -Message "Task not found: $taskPath - skipping"
                $result.TasksSkipped++
                continue
            }

            if ($task.State -eq "Disabled") {
                Write-Log -Level "INFO" -Category "ScheduledTaskMgr" -Message "Already disabled: $taskPath"
                $result.TasksSkipped++
                continue
            }

            if ($Preview) {
                Write-Log -Level "INFO" -Category "ScheduledTaskMgr" -Message "[Preview] Would disable: $taskPath"
            } elseif ($TestMode) {
                Write-Log -Level "INFO" -Category "ScheduledTaskMgr" -Message "[TestMode] Task $taskPath flagged for disabling"
            } else {
                Disable-ScheduledTask -TaskPath $taskDir -TaskName $taskName -ErrorAction SilentlyContinue | Out-Null
                Write-Log -Level "SUCCESS" -Category "ScheduledTaskMgr" -Message "Disabled: $taskPath"

                $global:DisabledTasksHistory += [PSCustomObject]@{
                    TaskPath    = $taskPath
                    DisabledAt  = Get-Date
                    Category    = "Telemetry"
                    OriginalState = $task.State
                }
            }

            $result.TasksDisabled++
        } catch {
            Write-Log -Level "WARNING" -Category "ScheduledTaskMgr" -Message "Error disabling $taskPath : $($_.Exception.Message)"
        }
    }

    Write-Log -Level "SUCCESS" -Category "ScheduledTaskMgr" -Message "Telemetry tasks: $($result.TasksDisabled) disabled, $($result.TasksSkipped) skipped"
    return $result
}

function global:Disable-BloatScheduledTasks {
    <#
    .SYNOPSIS
        Disables bloatware scheduled tasks.
    #>
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{
        Success       = $true
        TasksDisabled = 0
        TasksSkipped  = 0
        Error         = $null
    }

    if (-not $script:State.IsElevated) {
        Write-Log -Level "ERROR" -Category "ScheduledTaskMgr" -Message "Admin privileges required to disable bloat tasks"
        $result.Success = $false
        $result.Error = "Admin privileges required"
        return $result
    }

    Write-Log -Level "INFO" -Category "ScheduledTaskMgr" -Message "Disabling bloatware tasks..."

    foreach ($taskPath in $global:BloatTaskPaths) {
        try {
            $taskName = Split-Path $taskPath -Leaf
            $taskDir = Split-Path $taskPath -Parent

            $task = Get-ScheduledTask -TaskPath $taskDir -TaskName $taskName -ErrorAction SilentlyContinue
            if (-not $task) {
                Write-Log -Level "INFO" -Category "ScheduledTaskMgr" -Message "Task not found: $taskPath - skipping"
                $result.TasksSkipped++
                continue
            }

            if ($task.State -eq "Disabled") {
                Write-Log -Level "INFO" -Category "ScheduledTaskMgr" -Message "Already disabled: $taskPath"
                $result.TasksSkipped++
                continue
            }

            if ($Preview) {
                Write-Log -Level "INFO" -Category "ScheduledTaskMgr" -Message "[Preview] Would disable: $taskPath"
            } elseif ($TestMode) {
                Write-Log -Level "INFO" -Category "ScheduledTaskMgr" -Message "[TestMode] Task $taskPath flagged for disabling"
            } else {
                Disable-ScheduledTask -TaskPath $taskDir -TaskName $taskName -ErrorAction SilentlyContinue | Out-Null
                Write-Log -Level "SUCCESS" -Category "ScheduledTaskMgr" -Message "Disabled: $taskPath"

                $global:DisabledTasksHistory += [PSCustomObject]@{
                    TaskPath      = $taskPath
                    DisabledAt    = Get-Date
                    Category      = "Bloatware"
                    OriginalState = $task.State
                }
            }

            $result.TasksDisabled++
        } catch {
            Write-Log -Level "WARNING" -Category "ScheduledTaskMgr" -Message "Error disabling $taskPath : $($_.Exception.Message)"
        }
    }

    Write-Log -Level "SUCCESS" -Category "ScheduledTaskMgr" -Message "Bloatware tasks: $($result.TasksDisabled) disabled, $($result.TasksSkipped) skipped"
    return $result
}

function global:Enable-TaskCategory {
    <#
    .SYNOPSIS
        Re-enables tasks by category.
    #>
    param(
        [ValidateSet("Telemetry", "Bloatware", "All")]
        [string]$Category = "All",
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{
        Success        = $true
        TasksEnabled   = 0
        TasksSkipped   = 0
        Error          = $null
    }

    if (-not $script:State.IsElevated) {
        Write-Log -Level "ERROR" -Category "ScheduledTaskMgr" -Message "Admin privileges required to enable tasks"
        $result.Success = $false
        $result.Error = "Admin privileges required"
        return $result
    }

    $tasksToEnable = @()

    if ($Category -eq "Telemetry" -or $Category -eq "All") {
        $tasksToEnable += $global:TelemetryTaskPaths
    }
    if ($Category -eq "Bloatware" -or $Category -eq "All") {
        $tasksToEnable += $global:BloatTaskPaths
    }

    Write-Log -Level "INFO" -Category "ScheduledTaskMgr" -Message "Re-enabling $Category tasks..."

    foreach ($taskPath in $tasksToEnable) {
        try {
            $taskName = Split-Path $taskPath -Leaf
            $taskDir = Split-Path $taskPath -Parent

            $task = Get-ScheduledTask -TaskPath $taskDir -TaskName $taskName -ErrorAction SilentlyContinue
            if (-not $task) {
                $result.TasksSkipped++
                continue
            }

            if ($task.State -ne "Disabled") {
                $result.TasksSkipped++
                continue
            }

            if ($Preview) {
                Write-Log -Level "INFO" -Category "ScheduledTaskMgr" -Message "[Preview] Would enable: $taskPath"
            } elseif ($TestMode) {
                Write-Log -Level "INFO" -Category "ScheduledTaskMgr" -Message "[TestMode] Task $taskPath flagged for enabling"
            } else {
                Enable-ScheduledTask -TaskPath $taskDir -TaskName $taskName -ErrorAction SilentlyContinue | Out-Null
                Write-Log -Level "SUCCESS" -Category "ScheduledTaskMgr" -Message "Enabled: $taskPath"
            }

            $result.TasksEnabled++
        } catch {
            Write-Log -Level "WARNING" -Category "ScheduledTaskMgr" -Message "Error enabling $taskPath : $($_.Exception.Message)"
        }
    }

    Write-Log -Level "SUCCESS" -Category "ScheduledTaskMgr" -Message "Tasks: $($result.TasksEnabled) enabled, $($result.TasksSkipped) skipped"
    return $result
}

function global:Get-DisabledTaskHistory {
    <#
    .SYNOPSIS
        Returns the history of tasks that were disabled.
    #>

    return $global:DisabledTasksHistory
}

function global:Export-TaskReport {
    <#
    .SYNOPSIS
        Exports a report of task statuses.
    #>
    param(
        [string]$OutputPath = "$env:TEMP\TaskReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    )

    $result = @{
        Success    = $true
        OutputPath = $OutputPath
        Error      = $null
    }

    Write-Log -Level "INFO" -Category "ScheduledTaskMgr" -Message "Generating task report..."

    try {
        $report = @()
        $report += "============================================="
        $report += "Windows Scheduled Task Report"
        $report += "Generated: $(Get-Date)"
        $report += "============================================="
        $report += ""

        $report += "--- TELEMETRY TASKS ---"
        $telemetry = Get-WindowsTelemetryTasks
        foreach ($task in $telemetry.Tasks) {
            $report += "  $($task.TaskPath) [$($task.State)]"
        }
        $report += "Total: $($telemetry.Tasks.Count) found"
        $report += ""

        $report += "--- BLOATWARE TASKS ---"
        $bloat = Get-WindowsBloatTasks
        foreach ($task in $bloat.Tasks) {
            $report += "  $($task.TaskPath) [$($task.State)]"
        }
        $report += "Total: $($bloat.Tasks.Count) found"
        $report += ""

        $report += "--- DISABLED HISTORY ---"
        foreach ($entry in $global:DisabledTasksHistory) {
            $report += "  $($entry.TaskPath) - Disabled at $($entry.DisabledAt) (was $($entry.OriginalState))"
        }
        $report += "Total: $($global:DisabledTasksHistory.Count) tasks disabled by WinTune"

        $report | Out-File -FilePath $OutputPath -Encoding UTF8 -Force
        Write-Log -Level "SUCCESS" -Category "ScheduledTaskMgr" -Message "Task report exported to: $OutputPath"
    } catch {
        Write-Log -Level "ERROR" -Category "ScheduledTaskMgr" -Message "Error exporting task report: $($_.Exception.Message)"
        $result.Success = $false
        $result.Error = $_.Exception.Message
    }

    return $result
}

function global:Reset-AllScheduledTasks {
    <#
    .SYNOPSIS
        Re-enables all previously disabled tasks.
    #>
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{
        Success        = $true
        TasksReEnabled = 0
        Error          = $null
    }

    if (-not $script:State.IsElevated) {
        Write-Log -Level "ERROR" -Category "ScheduledTaskMgr" -Message "Admin privileges required to reset tasks"
        $result.Success = $false
        $result.Error = "Admin privileges required"
        return $result
    }

    Write-Log -Level "INFO" -Category "ScheduledTaskMgr" -Message "Re-enabling all previously disabled tasks..."

    foreach ($entry in $global:DisabledTasksHistory) {
        try {
            $taskName = Split-Path $entry.TaskPath -Leaf
            $taskDir = Split-Path $entry.TaskPath -Parent

            if ($Preview) {
                Write-Log -Level "INFO" -Category "ScheduledTaskMgr" -Message "[Preview] Would re-enable: $($entry.TaskPath)"
            } elseif ($TestMode) {
                Write-Log -Level "INFO" -Category "ScheduledTaskMgr" -Message "[TestMode] Task $($entry.TaskPath) flagged for re-enabling"
            } else {
                Enable-ScheduledTask -TaskPath $taskDir -TaskName $taskName -ErrorAction SilentlyContinue | Out-Null
                Write-Log -Level "SUCCESS" -Category "ScheduledTaskMgr" -Message "Re-enabled: $($entry.TaskPath)"
            }

            $result.TasksReEnabled++
        } catch {
            Write-Log -Level "WARNING" -Category "ScheduledTaskMgr" -Message "Error re-enabling $($entry.TaskPath): $($_.Exception.Message)"
        }
    }

    if (-not $Preview -and -not $TestMode) {
        $global:DisabledTasksHistory = @()
    }

    Write-Log -Level "SUCCESS" -Category "ScheduledTaskMgr" -Message "Re-enabled $($result.TasksReEnabled) tasks"
    return $result
}
