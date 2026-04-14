<#
.SYNOPSIS
    WinTune Pro Scheduling Module
.DESCRIPTION
    Windows Task Scheduler integration for scheduling WinTune operations
    including creation, management, and monitoring of scheduled tasks.
.NOTES
    File: Modules\Scheduling\TaskScheduler.ps1
    Version: 1.0.1
    PowerShell: 5.1+
    Compatible: Windows 10, Windows 11
#>

# ============================================================================
# SCHEDULED TASK CONSTANTS
# ============================================================================

$script:TaskSchedulerConfig = @{
    TaskFolder = "\WinTunePro\"
    Author = "WinTune Pro"
    Description = "WinTune Pro Scheduled Optimization Tasks"
    DefaultWorkingDir = $PSScriptRoot
    ScriptsDir = Join-Path $PSScriptRoot "..\..\Scripts"
}

# ============================================================================
# TASK CREATION HELPERS
# ============================================================================

function global:New-WinTuneScheduledTask {
    <#
    .SYNOPSIS
        Creates a new scheduled task for WinTune operations.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TaskName,
        
        [Parameter(Mandatory=$true)]
        [string]$ScriptPath,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet("Daily", "Weekly", "Monthly", "Once", "OnLogon", "OnStartup", "OnIdle")]
        [string]$ScheduleType,
        
        [string]$StartTime = "03:00",
        
        [int]$IntervalDays = 1,
        
        [int]$IntervalWeeks = 1,
        
        [DayOfWeek[]]$DaysOfWeek = @("Sunday"),
        
        [int]$DayOfMonth = 1,
        
        [string]$Arguments = "",
        
        [ValidateSet("SYSTEM", "CurrentUser")]
        [string]$RunAs = "SYSTEM",
        
        [switch]$RunWithHighestPrivileges,
        
        [switch]$StartWhenAvailable,
        
        [switch]$RunWhetherUserIsLoggedOn,
        
        [string]$Description = "",
        
        [int]$ExecutionTimeLimitMinutes = 120,
        
        [switch]$Preview
    )
    
    $result = @{
        Success = $false
        TaskName = $TaskName
        TaskPath = "$($script:TaskSchedulerConfig.TaskFolder)$TaskName"
        Message = ""
        Preview = $Preview
    }
    
    if ($Preview) {
        $result.Message = "[PREVIEW] Would create scheduled task: $TaskName"
        $result.Success = $true
        return $result
    }
    
    Write-Log -Level "INFO" -Category "Scheduling" -Message "Creating scheduled task: $TaskName"
    
    try {
        # Ensure task folder exists
        $taskFolder = $script:TaskSchedulerConfig.TaskFolder
        
        # Create task action
        $actionParams = @{
            Execute = "powershell.exe"
            Argument = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" $Arguments"
        }
        
        $action = New-ScheduledTaskAction @actionParams
        
        # Create task trigger based on schedule type
        $triggerParams = @{}
        
        switch ($ScheduleType) {
            "Daily" {
                $triggerParams.Daily = $true
                $triggerParams.DaysInterval = $IntervalDays
            }
            "Weekly" {
                $triggerParams.Weekly = $true
                $triggerParams.WeeksInterval = $IntervalWeeks
                $triggerParams.DaysOfWeek = $DaysOfWeek
            }
            "Monthly" {
                $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date
                # Monthly triggers need special handling
                $trigger.StartBoundary = [DateTime]::Today.AddDays($DayOfMonth - [DateTime]::Today.Day).ToString("yyyy-MM-dd'T'HH:mm:ss")
                $trigger.EndBoundary = $null
                $trigger.DaysOfMonth = @($DayOfMonth)
                $trigger.MonthsOfYear = @(1..12)
            }
            "Once" {
                $triggerParams.Once = $true
            }
            "OnLogon" {
                $triggerParams.AtLogon = $true
            }
            "OnStartup" {
                $triggerParams.AtStartup = $true
            }
            "OnIdle" {
                $triggerParams.AtIdle = $true
            }
        }
        
        $triggerParams.At = [DateTime]::Parse($StartTime)
        
        if ($ScheduleType -ne "Monthly") {
            $trigger = New-ScheduledTaskTrigger @triggerParams
        }
        
        # Create task settings
        $settingsParams = @{
            StartWhenAvailable = $StartWhenAvailable
            DontStopOnIdleEnd = $true
            AllowStartIfOnBatteries = $true
            DontStopIfGoingOnBatteries = $true
            ExecutionTimeLimit = (New-TimeSpan -Minutes $ExecutionTimeLimitMinutes)
        }
        
        $settings = New-ScheduledTaskSettingsSet @settingsParams
        
        # Create task principal
        $principalParams = @{
            UserId = if ($RunAs -eq "SYSTEM") { "S-1-5-18" } else { $env:USERNAME }
            LogonType = if ($RunAs -eq "SYSTEM") { "ServiceAccount" } else { "Interactive" }
            RunLevel = if ($RunWithHighestPrivileges) { "Highest" } else { "Limited" }
        }
        
        $principal = New-ScheduledTaskPrincipal @principalParams
        
        # Register the task
        $registerParams = @{
            TaskName = $TaskName
            TaskPath = $taskFolder.TrimEnd('\')
            Action = $action
            Trigger = $trigger
            Settings = $settings
            Principal = $principal
            Description = if ($Description) { $Description } else { "WinTune Pro: $TaskName" }
            Force = $true
        }
        
        Register-ScheduledTask @registerParams | Out-Null
        
        $result.Success = $true
        $result.Message = "Scheduled task '$TaskName' created successfully"
        Write-Log -Level "SUCCESS" -Category "Scheduling" -Message $result.Message
        
    } catch {
        $result.Message = "Failed to create scheduled task: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "Scheduling" -Message $result.Message
    }
    
    return $result
}

function global:New-OptimizationScheduledTask {
    <#
    .SYNOPSIS
        Creates a scheduled task for WinTune optimization operations.
    #>
    param(
        [ValidateSet("FullOptimization", "QuickCleanup", "NetworkReset", "TempCleanup", "BootOptimization")]
        [string]$OptimizationType = "QuickCleanup",
        
        [ValidateSet("Daily", "Weekly", "Monthly")]
        [string]$Schedule = "Weekly",
        
        [string]$StartTime = "03:00",
        
        [DayOfWeek]$DayOfWeek = "Sunday",
        
        [switch]$Preview
    )
    
    # Get the main WinTune.ps1 script path
    $winTunePath = Join-Path $PSScriptRoot "..\..\WinTune.ps1"
    $winTunePath = (Resolve-Path $winTunePath -ErrorAction SilentlyContinue).Path
    if (-not $winTunePath) {
        $winTunePath = Join-Path $PSScriptRoot "..\..\WinTune.ps1"
    }
    
    $taskConfig = @{
        FullOptimization = @{
            Name = "WinTune Full Optimization"
            Args = "-Silent -FullOptimization"
            Description = "Full system optimization including cleaning, tuning, and network reset"
        }
        QuickCleanup = @{
            Name = "WinTune Quick Cleanup"
            Args = "-Silent -QuickCleanup"
            Description = "Quick system cleanup - temp files and cache cleanup"
        }
        NetworkReset = @{
            Name = "WinTune Network Reset"
            Args = "-Silent -NetworkReset"
            Description = "Network stack reset and optimization"
        }
        TempCleanup = @{
            Name = "WinTune Temp Cleanup"
            Args = "-Silent -TempCleanup"
            Description = "Temporary file cleanup operation"
        }
        BootOptimization = @{
            Name = "WinTune Boot Optimization"
            Args = "-Silent -BootOptimization"
            Description = "Boot optimization and startup cleanup"
        }
    }
    
    $config = $taskConfig[$OptimizationType]
    
    # Determine schedule parameters
    $scheduleParams = @{
        TaskName = $config.Name
        ScriptPath = $winTunePath
        Arguments = $config.Args
        StartTime = $StartTime
        Description = $config.Description
        RunAs = "SYSTEM"
        RunWithHighestPrivileges = $true
        StartWhenAvailable = $true
        Preview = $Preview
    }
    
    switch ($Schedule) {
        "Daily" {
            $scheduleParams.ScheduleType = "Daily"
            $scheduleParams.IntervalDays = 1
        }
        "Weekly" {
            $scheduleParams.ScheduleType = "Weekly"
            $scheduleParams.DaysOfWeek = @($DayOfWeek)
            $scheduleParams.IntervalWeeks = 1
        }
        "Monthly" {
            $scheduleParams.ScheduleType = "Monthly"
            $scheduleParams.DayOfMonth = 1
        }
    }
    
    return New-WinTuneScheduledTask @scheduleParams
}

# ============================================================================
# TASK MANAGEMENT
# ============================================================================

function global:Get-WinTuneScheduledTasks {
    <#
    .SYNOPSIS
        Gets all WinTune scheduled tasks.
    #>
    param(
        [switch]$IncludeDisabled
    )
    
    $tasks = @()
    $taskFolder = $script:TaskSchedulerConfig.TaskFolder.TrimEnd('\')
    
    try {
        $scheduledTasks = Get-ScheduledTask -TaskPath $taskFolder -ErrorAction SilentlyContinue
        
        foreach ($task in $scheduledTasks) {
            if (-not $IncludeDisabled -and $task.State -eq "Disabled") {
                continue
            }
            
            $taskInfo = [PSCustomObject]@{
                Name = $task.TaskName
                Path = $task.TaskPath
                State = $task.State
                LastRunTime = $task.LastRunTime
                NextRunTime = $task.NextRunTime
                LastTaskResult = $task.LastTaskResult
                Actions = @($task.Actions | ForEach-Object {
                    @{
                        Execute = $_.Execute
                        Arguments = $_.Arguments
                    }
                })
                Triggers = @($task.Triggers | ForEach-Object {
                    @{
                        Type = $_.CimClass.CimClassName
                        StartBoundary = $_.StartBoundary
                        Enabled = $_.Enabled
                    }
                })
            }
            
            $tasks += $taskInfo
        }
        
    } catch {
        Write-Log -Level "ERROR" -Category "Scheduling" -Message "Error getting scheduled tasks: $($_.Exception.Message)"
    }
    
    return $tasks
}

function global:Enable-WinTuneScheduledTask {
    <#
    .SYNOPSIS
        Enables a WinTune scheduled task.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TaskName
    )
    
    $result = @{
        Success = $false
        TaskName = $TaskName
        Message = ""
    }
    
    try {
        $taskPath = $script:TaskSchedulerConfig.TaskFolder.TrimEnd('\')
        $task = Get-ScheduledTask -TaskName $TaskName -TaskPath $taskPath -ErrorAction Stop
        
        Enable-ScheduledTask -TaskName $TaskName -TaskPath $taskPath | Out-Null
        
        $result.Success = $true
        $result.Message = "Task '$TaskName' enabled successfully"
        Write-Log -Level "SUCCESS" -Category "Scheduling" -Message $result.Message
        
    } catch {
        $result.Message = "Failed to enable task: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "Scheduling" -Message $result.Message
    }
    
    return $result
}

function global:Disable-WinTuneScheduledTask {
    <#
    .SYNOPSIS
        Disables a WinTune scheduled task.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TaskName
    )
    
    $result = @{
        Success = $false
        TaskName = $TaskName
        Message = ""
    }
    
    try {
        $taskPath = $script:TaskSchedulerConfig.TaskFolder.TrimEnd('\')
        $task = Get-ScheduledTask -TaskName $TaskName -TaskPath $taskPath -ErrorAction Stop
        
        Disable-ScheduledTask -TaskName $TaskName -TaskPath $taskPath | Out-Null
        
        $result.Success = $true
        $result.Message = "Task '$TaskName' disabled successfully"
        Write-Log -Level "SUCCESS" -Category "Scheduling" -Message $result.Message
        
    } catch {
        $result.Message = "Failed to disable task: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "Scheduling" -Message $result.Message
    }
    
    return $result
}

function global:Remove-WinTuneScheduledTask {
    <#
    .SYNOPSIS
        Removes a WinTune scheduled task.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TaskName
    )
    
    $result = @{
        Success = $false
        TaskName = $TaskName
        Message = ""
    }
    
    try {
        $taskPath = $script:TaskSchedulerConfig.TaskFolder.TrimEnd('\')
        
        Unregister-ScheduledTask -TaskName $TaskName -TaskPath $taskPath -Confirm:$false -ErrorAction Stop
        
        $result.Success = $true
        $result.Message = "Task '$TaskName' removed successfully"
        Write-Log -Level "SUCCESS" -Category "Scheduling" -Message $result.Message
        
    } catch {
        $result.Message = "Failed to remove task: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "Scheduling" -Message $result.Message
    }
    
    return $result
}

function global:Start-WinTuneScheduledTask {
    <#
    .SYNOPSIS
        Runs a WinTune scheduled task immediately.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TaskName
    )
    
    $result = @{
        Success = $false
        TaskName = $TaskName
        Message = ""
        InstanceId = $null
    }
    
    try {
        $taskPath = $script:TaskSchedulerConfig.TaskFolder.TrimEnd('\')
        
        $taskInstance = Start-ScheduledTask -TaskName $TaskName -TaskPath $taskPath -ErrorAction Stop
        
        $result.Success = $true
        $result.InstanceId = $taskInstance.InstanceId
        $result.Message = "Task '$TaskName' started successfully"
        Write-Log -Level "SUCCESS" -Category "Scheduling" -Message $result.Message
        
    } catch {
        $result.Message = "Failed to start task: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "Scheduling" -Message $result.Message
    }
    
    return $result
}

function global:Stop-WinTuneScheduledTask {
    <#
    .SYNOPSIS
        Stops a running WinTune scheduled task.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TaskName
    )
    
    $result = @{
        Success = $false
        TaskName = $TaskName
        Message = ""
    }
    
    try {
        $taskPath = $script:TaskSchedulerConfig.TaskFolder.TrimEnd('\')
        
        Stop-ScheduledTask -TaskName $TaskName -TaskPath $taskPath -ErrorAction Stop
        
        $result.Success = $true
        $result.Message = "Task '$TaskName' stopped successfully"
        Write-Log -Level "SUCCESS" -Category "Scheduling" -Message $result.Message
        
    } catch {
        $result.Message = "Failed to stop task: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "Scheduling" -Message $result.Message
    }
    
    return $result
}

# ============================================================================
# TASK TEMPLATES
# ============================================================================

function global:New-ScheduledTaskFromTemplate {
    <#
    .SYNOPSIS
        Creates scheduled tasks from predefined templates.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("WeeklyMaintenance", "DailyCleanup", "MonthlyDeepClean", "BootOptimization", "NetworkMaintenance", "FullSuite")]
        [string]$Template,
        
        [string]$StartTime = "03:00",
        
        [switch]$Preview
    )
    
    $result = @{
        Success = $true
        Template = $Template
        TasksCreated = 0
        Tasks = @()
        Errors = @()
    }
    
    $templates = @{
        WeeklyMaintenance = @(
            @{ Name = "WinTune Weekly Cleanup"; Type = "QuickCleanup"; Schedule = "Weekly"; Day = "Sunday" }
        )
        DailyCleanup = @(
            @{ Name = "WinTune Daily Temp Cleanup"; Type = "TempCleanup"; Schedule = "Daily" }
        )
        MonthlyDeepClean = @(
            @{ Name = "WinTune Monthly Optimization"; Type = "FullOptimization"; Schedule = "Monthly" }
        )
        BootOptimization = @(
            @{ Name = "WinTune Boot Optimization"; Type = "BootOptimization"; Schedule = "Weekly"; Day = "Sunday" }
        )
        NetworkMaintenance = @(
            @{ Name = "WinTune Network Reset"; Type = "NetworkReset"; Schedule = "Weekly"; Day = "Saturday" }
        )
        FullSuite = @(
            @{ Name = "WinTune Daily Cleanup"; Type = "TempCleanup"; Schedule = "Daily" }
            @{ Name = "WinTune Weekly Maintenance"; Type = "QuickCleanup"; Schedule = "Weekly"; Day = "Wednesday" }
            @{ Name = "WinTune Monthly Optimization"; Type = "FullOptimization"; Schedule = "Monthly" }
        )
    }
    
    $selectedTemplate = $templates[$Template]
    
    foreach ($taskDef in $selectedTemplate) {
        $taskParams = @{
            OptimizationType = $taskDef.Type
            Schedule = $taskDef.Schedule
            StartTime = $StartTime
            Preview = $Preview
        }
        
        if ($taskDef.Day) {
            $taskParams.DayOfWeek = $taskDef.Day
        }
        
        $taskResult = New-OptimizationScheduledTask @taskParams
        
        $result.Tasks += $taskResult
        
        if ($taskResult.Success) {
            $result.TasksCreated++
        } else {
            $result.Errors += $taskResult.Message
        }
    }
    
    $result.Message = "Template '$Template' processed: $($result.TasksCreated) tasks created"
    Write-Log -Level "INFO" -Category "Scheduling" -Message $result.Message
    
    return $result
}

# ============================================================================
# TASK SCHEDULING CONFIGURATION
# ============================================================================

function global:Set-WinTuneScheduleConfiguration {
    <#
    .SYNOPSIS
        Configures schedule settings for WinTune operations.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TaskName,
        
        [DateTime]$NewStartTime,
        
        [int]$NewIntervalDays,
        
        [int]$NewIntervalWeeks,
        
        [DayOfWeek[]]$NewDaysOfWeek,
        
        [switch]$Preview
    )
    
    $result = @{
        Success = $false
        TaskName = $TaskName
        Message = ""
        Changes = @()
    }
    
    if ($Preview) {
        $result.Message = "[PREVIEW] Would update schedule for: $TaskName"
        $result.Success = $true
        return $result
    }
    
    try {
        $taskPath = $script:TaskSchedulerConfig.TaskFolder.TrimEnd('\')
        $task = Get-ScheduledTask -TaskName $TaskName -TaskPath $taskPath -ErrorAction Stop
        
        $triggers = @()
        
        foreach ($trigger in $task.Triggers) {
            $updatedTrigger = $trigger
            
            if ($NewStartTime) {
                $updatedTrigger.StartBoundary = $NewStartTime.ToString("yyyy-MM-dd'T'HH:mm:ss")
                $result.Changes += "Start time updated to $NewStartTime"
            }
            
            if ($trigger.CimClass.CimClassName -eq "MSFT_TaskWeeklyTrigger") {
                if ($NewDaysOfWeek) {
                    $updatedTrigger.DaysOfWeek = $NewDaysOfWeek
                    $result.Changes += "Days of week updated"
                }
                if ($NewIntervalWeeks) {
                    $updatedTrigger.WeeksInterval = $NewIntervalWeeks
                    $result.Changes += "Weeks interval updated to $NewIntervalWeeks"
                }
            }
            
            if ($trigger.CimClass.CimClassName -eq "MSFT_TaskDailyTrigger") {
                if ($NewIntervalDays) {
                    $updatedTrigger.DaysInterval = $NewIntervalDays
                    $result.Changes += "Days interval updated to $NewIntervalDays"
                }
            }
            
            $triggers += $updatedTrigger
        }
        
        Set-ScheduledTask -TaskName $TaskName -TaskPath $taskPath -Trigger $triggers | Out-Null
        
        $result.Success = $true
        $result.Message = "Schedule configuration updated"
        Write-Log -Level "SUCCESS" -Category "Scheduling" -Message "Schedule updated for task: $TaskName"
        
    } catch {
        $result.Message = "Failed to update schedule: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "Scheduling" -Message $result.Message
    }
    
    return $result
}

# ============================================================================
# TASK HISTORY AND MONITORING
# ============================================================================

function global:Get-WinTuneTaskHistory {
    <#
    .SYNOPSIS
        Gets execution history for WinTune scheduled tasks.
    #>
    param(
        [string]$TaskName,
        
        [int]$LastDays = 7,
        
        [int]$MaxResults = 100
    )
    
    $history = @()
    
    try {
        $startTime = (Get-Date).AddDays(-$LastDays)
        
        $filterHashTable = @{
            LogName = 'Microsoft-Windows-TaskScheduler/Operational'
            StartTime = $startTime
            ID = @(129, 140, 141, 142, 143, 200, 201)  # Task start, complete, failure events
        }
        
        $events = Get-WinEvent -FilterHashtable $filterHashTable -MaxEvents $MaxResults -ErrorAction SilentlyContinue
        
        foreach ($event in $events) {
            $eventXml = [xml]$event.ToXml()
            $taskPath = $eventXml.Event.EventData.Data | Where-Object { $_.Name -eq 'TaskName' } | Select-Object -ExpandProperty '#text'
            
            # Filter to WinTune tasks
            if ($taskPath -notlike "*WinTune*") { continue }
            if ($TaskName -and $taskPath -notlike "*$TaskName*") { continue }
            
            $history += [PSCustomObject]@{
                TimeCreated = $event.TimeCreated
                TaskPath = $taskPath
                EventId = $event.Id
                Level = $event.LevelDisplayName
                Message = $event.Message
                Action = switch ($event.Id) {
                    129 { "Task Started" }
                    140 { "Task Registration" }
                    141 { "Task Deletion" }
                    142 { "Task Enabled" }
                    143 { "Task Disabled" }
                    200 { "Action Started" }
                    201 { "Action Completed" }
                    default { "Unknown" }
                }
            }
        }
        
    } catch {
        Write-Log -Level "ERROR" -Category "Scheduling" -Message "Error getting task history: $($_.Exception.Message)"
    }
    
    return $history | Sort-Object TimeCreated -Descending
}

function global:Get-WinTuneTaskStatus {
    <#
    .SYNOPSIS
        Gets current status of WinTune scheduled tasks.
    #>
    
    $status = @{
        TotalTasks = 0
        RunningTasks = 0
        ReadyTasks = 0
        DisabledTasks = 0
        QueuedTasks = 0
        LastRun = $null
        NextRun = $null
        Tasks = @()
    }
    
    $tasks = Get-WinTuneScheduledTasks -IncludeDisabled
    
    $status.TotalTasks = $tasks.Count
    
    foreach ($task in $tasks) {
        switch ($task.State) {
            "Running" { $status.RunningTasks++ }
            "Ready" { $status.ReadyTasks++ }
            "Disabled" { $status.DisabledTasks++ }
            "Queued" { $status.QueuedTasks++ }
        }
        
        if ($task.LastRunTime -and (-not $status.LastRun -or $task.LastRunTime -gt $status.LastRun)) {
            $status.LastRun = $task.LastRunTime
        }
        
        if ($task.NextRunTime -and (-not $status.NextRun -or $task.NextRunTime -lt $status.NextRun)) {
            $status.NextRun = $task.NextRunTime
        }
    }
    
    $status.Tasks = $tasks
    
    return $status
}

# ============================================================================
# TASK EXPORT/IMPORT
# ============================================================================

function global:Export-WinTuneScheduledTasks {
    <#
    .SYNOPSIS
        Exports WinTune scheduled tasks to XML files.
    #>
    param(
        [string]$ExportPath,
        
        [string[]]$TaskNames
    )
    
    $result = @{
        Success = $true
        ExportPath = $ExportPath
        TasksExported = 0
        Files = @()
        Errors = @()
    }
    
    if (-not $ExportPath) {
        $ExportPath = Join-Path $script:TaskSchedulerConfig.DefaultWorkingDir "ScheduledTasks"
    }
    
    # Create export directory
    if (-not (Test-Path $ExportPath)) {
        New-Item -ItemType Directory -Path $ExportPath -Force | Out-Null
    }
    
    $taskPath = $script:TaskSchedulerConfig.TaskFolder.TrimEnd('\')
    
    if ($TaskNames) {
        $tasks = $TaskNames | ForEach-Object {
            Get-ScheduledTask -TaskName $_ -TaskPath $taskPath -ErrorAction SilentlyContinue
        }
    } else {
        $tasks = Get-WinTuneScheduledTasks -IncludeDisabled
    }
    
    foreach ($task in $tasks) {
        try {
            $fileName = "$($task.Name -replace '[^a-zA-Z0-9]', '_').xml"
            $filePath = Join-Path $ExportPath $fileName
            
            Export-ScheduledTask -TaskName $task.Name -TaskPath $taskPath | Out-File $filePath -Encoding UTF8
            
            $result.Files += $filePath
            $result.TasksExported++
            
        } catch {
            $result.Errors += "Failed to export '$($task.Name)': $($_.Exception.Message)"
        }
    }
    
    Write-Log -Level "SUCCESS" -Category "Scheduling" -Message "Exported $($result.TasksExported) scheduled tasks to $ExportPath"
    
    return $result
}

function global:Import-WinTuneScheduledTasks {
    <#
    .SYNOPSIS
        Imports WinTune scheduled tasks from XML files.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ImportPath,
        
        [switch]$Preview
    )
    
    $result = @{
        Success = $true
        ImportPath = $ImportPath
        TasksImported = 0
        Tasks = @()
        Errors = @()
    }
    
    if ($Preview) {
        $result.Message = "[PREVIEW] Would import tasks from $ImportPath"
        return $result
    }
    
    $xmlFiles = Get-ChildItem -Path $ImportPath -Filter "*.xml" -ErrorAction SilentlyContinue
    
    foreach ($file in $xmlFiles) {
        try {
            $taskPath = $script:TaskSchedulerConfig.TaskFolder.TrimEnd('\')
            
            # Read and register the task
            $taskXml = Get-Content $file.FullName -Raw
            Register-ScheduledTask -Xml $taskXml -TaskPath $taskPath -Force | Out-Null
            
            $result.Tasks += $file.Name
            $result.TasksImported++
            
        } catch {
            $result.Errors += "Failed to import '$($file.Name)': $($_.Exception.Message)"
        }
    }
    
    Write-Log -Level "SUCCESS" -Category "Scheduling" -Message "Imported $($result.TasksImported) scheduled tasks from $ImportPath"
    
    return $result
}

# ============================================================================
# QUICK SCHEDULE SETUP
# ============================================================================

function global:Initialize-WinTuneScheduling {
    <#
    .SYNOPSIS
        Initializes default WinTune scheduled tasks.
    #>
    param(
        [ValidateSet("Minimal", "Standard", "Aggressive")]
        [string]$Profile = "Standard",
        
        [string]$StartTime = "03:00",
        
        [switch]$Preview
    )
    
    $result = @{
        Success = $true
        Profile = $Profile
        TasksCreated = 0
        Tasks = @()
        Errors = @()
    }
    
    $profiles = @{
        Minimal = @(
            @{ Type = "QuickCleanup"; Schedule = "Weekly"; Day = "Sunday" }
        )
        Standard = @(
            @{ Type = "TempCleanup"; Schedule = "Daily" }
            @{ Type = "QuickCleanup"; Schedule = "Weekly"; Day = "Sunday" }
            @{ Type = "FullOptimization"; Schedule = "Monthly" }
        )
        Aggressive = @(
            @{ Type = "TempCleanup"; Schedule = "Daily" }
            @{ Type = "QuickCleanup"; Schedule = "Weekly"; Day = "Wednesday" }
            @{ Type = "BootOptimization"; Schedule = "Weekly"; Day = "Sunday" }
            @{ Type = "NetworkReset"; Schedule = "Weekly"; Day = "Saturday" }
            @{ Type = "FullOptimization"; Schedule = "Monthly" }
        )
    }
    
    $selectedProfile = $profiles[$Profile]
    
    Write-Log -Level "INFO" -Category "Scheduling" -Message "Initializing WinTune scheduling with '$Profile' profile"
    
    foreach ($taskDef in $selectedProfile) {
        $taskParams = @{
            OptimizationType = $taskDef.Type
            Schedule = $taskDef.Schedule
            StartTime = $StartTime
            Preview = $Preview
        }
        
        if ($taskDef.Day) {
            $taskParams.DayOfWeek = $taskDef.Day
        }
        
        $taskResult = New-OptimizationScheduledTask @taskParams
        
        $result.Tasks += $taskResult
        
        if ($taskResult.Success) {
            $result.TasksCreated++
        } else {
            $result.Errors += $taskResult.Message
        }
    }
    
    $result.Message = "Scheduling initialized: $($result.TasksCreated) tasks created"
    Write-Log -Level "SUCCESS" -Category "Scheduling" -Message $result.Message
    
    return $result
}

function global:Remove-AllWinTuneScheduledTasks {
    <#
    .SYNOPSIS
        Removes all WinTune scheduled tasks.
    #>
    param(
        [switch]$Preview
    )
    
    $result = @{
        Success = $true
        TasksRemoved = 0
        Tasks = @()
        Errors = @()
    }
    
    $tasks = Get-WinTuneScheduledTasks -IncludeDisabled
    
    foreach ($task in $tasks) {
        if ($Preview) {
            $result.Tasks += "[PREVIEW] Would remove: $($task.Name)"
            $result.TasksRemoved++
        } else {
            $removeResult = Remove-WinTuneScheduledTask -TaskName $task.Name
            
            if ($removeResult.Success) {
                $result.TasksRemoved++
                $result.Tasks += "Removed: $($task.Name)"
            } else {
                $result.Errors += "Failed to remove $($task.Name): $($removeResult.Message)"
            }
        }
    }
    
    Write-Log -Level "INFO" -Category "Scheduling" -Message "Removed $($result.TasksRemoved) scheduled tasks"
    
    return $result
}
