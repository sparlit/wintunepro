#Requires -Version 5.1

$script:StartTime = Get-Date
$script:State = @{
    SessionId             = ""
    IsElevated            = $false
    IsTestMode            = $false
    CurrentOperation      = ""
    OperationsCompleted   = @()
    OperationsPending     = @()
    SpaceRecovered        = [long]0
    ServicesModified      = @()
    StartupItemsModified  = @()
    NetworkChanges        = @()
    RestorePointsCreated  = @()
}

$script:Paths = @{
    AppRoot  = ""
    Data     = ""
    Logs     = ""
    Backups  = ""
    Config   = ""
    Reports  = ""
}

function global:Initialize-State {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AppRoot,

        [Parameter()]
        [string]$SessionIdentifier = "",

        [Parameter()]
        [bool]$TestMode = $false
    )

    $script:Paths.AppRoot = $AppRoot
    $script:Paths.Data    = Join-Path $AppRoot "Data"
    $script:Paths.Logs    = Join-Path $AppRoot "Logs"
    $script:Paths.Backups = Join-Path $AppRoot "Backups"
    $script:Paths.Config  = Join-Path $AppRoot "Config"
    $script:Paths.Reports = Join-Path $AppRoot "Reports"

    $allPaths = @(
        $script:Paths.Data,
        $script:Paths.Logs,
        $script:Paths.Backups,
        $script:Paths.Config,
        $script:Paths.Reports
    )

    foreach ($path in $allPaths) {
        if (-not (Test-Path $path)) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
    }

    if ($SessionIdentifier -eq "") {
        $SessionIdentifier = [guid]::NewGuid().ToString("N").Substring(0, 12)
    }

    $isElevated = $false
    try {
        $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $isElevated = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        $isElevated = $false
    }

    $script:State.SessionId = $SessionIdentifier
    $script:State.IsElevated = $isElevated
    $script:State.IsTestMode = $TestMode
    $script:StartTime = Get-Date

    Write-Log -Level "INFO" -Category "System" -Message "State initialized | Session: $SessionIdentifier | Elevated: $isElevated | TestMode: $TestMode"
}

function global:Get-State {
    [CmdletBinding()]
    param()

    return $script:State.Clone()
}

function global:Set-StateValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key,

        [Parameter(Mandatory = $true)]
        [object]$Value
    )

    if ($script:State.ContainsKey($Key)) {
        $oldValue = $script:State[$Key]
        $script:State[$Key] = $Value
        Write-Log -Level "DEBUG" -Category "System" -Message "State.$Key changed from '$oldValue' to '$Value'"
        return $true
    }

    Write-Log -Level "WARNING" -Category "System" -Message "Attempted to set unknown state key: $Key"
    return $false
}

function global:Get-StateValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key,

        [Parameter()]
        [object]$Default = $null
    )

    if ($script:State.ContainsKey($Key)) {
        return $script:State[$Key]
    }

    return $Default
}

function global:Record-Operation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Cleaning", "Optimization", "Network", "Tuning", "Repair", "System", "UI", "Safety", "Storage", "DNS", "Automation", "ToolManager", "Benchmark", "Power", "Startup", "Privacy", "Task", "Hosts", "Battery", "Gaming", "Sophia", "Printer")]
        [string]$Category,

        [Parameter()]
        [string]$Details = "",

        [Parameter()]
        [bool]$Success = $true,

        [Parameter()]
        [long]$SpaceRecovered = 0
    )

    $entry = [PSCustomObject]@{
        Name           = $Name
        Category       = $Category
        Details        = $Details
        Success        = $Success
        SpaceRecovered = $SpaceRecovered
        Timestamp      = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        SessionId      = $script:State.SessionId
    }

    $script:State.OperationsCompleted += $entry

    if ($SpaceRecovered -gt 0) {
        $script:State.SpaceRecovered = [long]($script:State.SpaceRecovered + $SpaceRecovered)
    }

    $status = if ($Success) { "SUCCESS" } else { "ERROR" }
    Write-Log -Level $status -Category $Category -Message "Operation recorded: $Name | $Details"

    return $entry
}

function global:Get-OperationHistory {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet("Cleaning", "Optimization", "Network", "Tuning", "Repair", "System", "UI", "Safety", "")]
        [string]$Category = "",

        [Parameter()]
        [int]$Last = 0
    )

    $history = $script:State.OperationsCompleted

    if ($Category -ne "") {
        $history = @($history | Where-Object { $_.Category -eq $Category })
    }

    if ($Last -gt 0 -and $history.Count -gt $Last) {
        $history = @($history[($history.Count - $Last)..($history.Count - 1)])
    }

    return $history
}

function global:Get-Paths {
    return $script:Paths
}

function global:Initialize-Directories {
    param([string]$RootPath)
    $dirs = @("Logs","Data","Backups","Config","Reports","Tools")
    foreach ($d in $dirs) {
        $p = Join-Path $RootPath $d
        if (-not (Test-Path $p)) { New-Item -Path $p -ItemType Directory -Force | Out-Null }
    }
}

function global:Get-SessionDuration {
    $elapsed = (Get-Date) - $script:StartTime
    if ($elapsed.TotalHours -ge 1) {
        return "{0}h {1}m {2}s" -f [int]$elapsed.TotalHours, $elapsed.Minutes, $elapsed.Seconds
    } elseif ($elapsed.TotalMinutes -ge 1) {
        return "{0}m {1}s" -f [int]$elapsed.TotalMinutes, $elapsed.Seconds
    } else {
        return "{0:N1}s" -f $elapsed.TotalSeconds
    }
}

function global:Get-SessionSummary {
    return @{
        SessionId = $script:State.SessionId
        Duration = Get-SessionDuration
        OperationsCompleted = $script:State.OperationsCompleted.Count
        SpaceRecovered = $script:State.SpaceRecovered
        SpaceRecoveredFormatted = Format-FileSize $script:State.SpaceRecovered
        IsElevated = $script:State.IsElevated
        IsTestMode = $script:State.IsTestMode
    }
}
