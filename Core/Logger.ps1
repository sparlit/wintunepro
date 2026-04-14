#Requires -Version 5.1

$script:LogLevel = "standard"
$script:LogPath = ""
$script:SessionId = ""
$script:LogHistory = [System.Collections.Generic.List[PSObject]]::new()
$script:MaxLogHistory = 1000
$script:MaxLogFiles = 10
$script:LogWriteLock = [System.Object]::new()
$script:LogLevelValues = @{
    "minimal" = 1
    "standard" = 2
    "verbose" = 3
    "debug" = 4
}

function global:Initialize-Logger {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogDirectory,
        [Parameter()]
        [string]$Level = "standard",
        [Parameter()]
        [string]$SessionIdentifier = ""
    )

    $script:LogLevel = $Level.ToLower()

    if ($SessionIdentifier -eq "") {
        $SessionIdentifier = [guid]::NewGuid().ToString("N").Substring(0, 12)
    }
    $script:SessionId = $SessionIdentifier

    if (-not (Test-Path $LogDirectory)) {
        New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
    }

    # Rotate old log files - keep only MaxLogFiles
    try {
        $oldLogs = Get-ChildItem -Path $LogDirectory -Filter "WinTunePro_*.log" -ErrorAction SilentlyContinue |
            Sort-Object CreationTime -Descending
        if ($oldLogs.Count -gt $script:MaxLogFiles) {
            $oldLogs | Select-Object -Skip $script:MaxLogFiles | Remove-Item -Force -ErrorAction SilentlyContinue
        }
    } catch { }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $script:LogPath = Join-Path $LogDirectory "WinTunePro_${timestamp}_${SessionIdentifier}.log"

    Write-Log -Level "INFO" -Category "System" -Message "Logger initialized"
    Write-Log -Level "INFO" -Category "System" -Message "Session ID: $SessionIdentifier"
    Write-Log -Level "INFO" -Category "System" -Message "Log level: $($script:LogLevel)"
}

function global:Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG")]
        [string]$Level,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Cleaning", "Optimization", "Network", "Tuning", "Repair", "System", "UI", "Safety", "Storage", "DNS", "Report", "HealthScore", "Automation", "SafetyNet", "Parallel", "Watchdog", "Profile", "ToolManager", "Benchmark", "Power", "Startup", "Privacy", "Task", "Hosts", "Battery", "Gaming", "Sophia", "Printer", "PowerPlan", "WUSourceReset", "Core", "Rollback", "SelfHealing", "Config", "SystemRepair", "Backup", "Maintenance", "NetworkTune", "BootOptimization", "Winsock", "NetworkReset", "CleaningCore", "WindowsFeatures", "Debloat", "Features", "StartupEnhanced", "Memory", "Services", "PowerPlanCustom", "Tweaks", "Tro", "RemoteExecution", "Adapter", "HostsManager", "ScheduledTaskMgr", "ProcessMgr", "DefenderCleanup", "Storage", "DNSOptimizer", "GamingOptimizer", "BatteryOptimizer", "DriverMgr", "PrinterFix", "Privacy", "SophiaScript", "TaskScheduler", "SystemInfo")]
        [string]$Category,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter()]
        [object]$Data = $null
    )

    $levelOrder = @{
        "INFO" = 2
        "SUCCESS" = 2
        "WARNING" = 2
        "ERROR" = 1
        "DEBUG" = 4
    }

    $configLevelValue = 2
    if ($script:LogLevelValues.ContainsKey($script:LogLevel)) {
        $configLevelValue = $script:LogLevelValues[$script:LogLevel]
    }

    $msgLevelValue = 4
    if ($levelOrder.ContainsKey($Level)) {
        $msgLevelValue = $levelOrder[$Level]
    }

    if ($msgLevelValue -gt $configLevelValue) {
        return
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logEntry = "[$timestamp] [$Level] [$Category] [$Message]"

    $logObject = [PSCustomObject]@{
        Timestamp = $timestamp
        Level     = $Level
        Category  = $Category
        Message   = $Message
        Data      = $Data
        SessionId = $script:SessionId
        Formatted = $logEntry
    }

    [System.Threading.Monitor]::Enter($script:LogWriteLock)
    try {
        $script:LogHistory.Add($logObject)
        if ($script:LogHistory.Count -gt $script:MaxLogHistory) {
            $script:LogHistory.RemoveAt(0)
        }
    }
    finally {
        [System.Threading.Monitor]::Exit($script:LogWriteLock)
    }

    if ($script:LogPath -ne "") {
        $parentDir = Split-Path $script:LogPath -Parent
        if ($parentDir -and (Test-Path $parentDir)) {
            [System.Threading.Monitor]::Enter($script:LogWriteLock)
            try {
                $logEntry | Out-File -FilePath $script:LogPath -Append -Encoding UTF8
            }
            catch { }
            finally {
                [System.Threading.Monitor]::Exit($script:LogWriteLock)
            }
        }
    }

    $colors = @{
        "INFO"    = "Cyan"
        "SUCCESS" = "Green"
        "WARNING" = "Yellow"
        "ERROR"   = "Red"
        "DEBUG"   = "Gray"
    }

    $color = "White"
    if ($colors.ContainsKey($Level)) {
        $color = $colors[$Level]
    }

    Write-Host $logEntry -ForegroundColor $color
}

function global:Get-LogHistory {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG", "")]
        [string]$Level = "",

        [Parameter()]
        [ValidateSet("Cleaning", "Optimization", "Network", "Tuning", "Repair", "System", "UI", "Safety", "Storage", "DNS", "Report", "HealthScore", "Automation", "SafetyNet", "Parallel", "Watchdog", "Profile", "ToolManager", "Benchmark", "Power", "Startup", "Privacy", "Task", "Hosts", "Battery", "Gaming", "Sophia", "Printer", "PowerPlan", "WUSourceReset", "Core", "Rollback", "SelfHealing", "Config", "")]
        [string]$Category = "",

        [Parameter()]
        [int]$Last = 0
    )

    $history = @($script:LogHistory)

    if ($Level -ne "") {
        $history = @($history | Where-Object { $_.Level -eq $Level })
    }

    if ($Category -ne "") {
        $history = @($history | Where-Object { $_.Category -eq $Category })
    }

    if ($Last -gt 0 -and $history.Count -gt $Last) {
        $history = @($history[($history.Count - $Last)..($history.Count - 1)])
    }

    return $history
}

function global:Export-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,

        [Parameter()]
        [ValidateSet("TXT", "HTML")]
        [string]$Format = "TXT",

        [Parameter()]
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG", "")]
        [string]$Level = "",

        [Parameter()]
        [ValidateSet("Cleaning", "Optimization", "Network", "Tuning", "Repair", "System", "UI", "Safety", "Storage", "DNS", "Report", "HealthScore", "Automation", "SafetyNet", "Parallel", "Watchdog", "Profile", "ToolManager", "Benchmark", "Power", "Startup", "Privacy", "Task", "Hosts", "Battery", "Gaming", "Sophia", "Printer", "PowerPlan", "WUSourceReset", "Core", "Rollback", "SelfHealing", "Config", "")]
        [string]$Category = ""
    )

    $history = Get-LogHistory -Level $Level -Category $Category

    $parentDir = Split-Path $OutputPath -Parent
    if ($parentDir -ne "" -and -not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    if ($Format -eq "TXT") {
        $sb = New-Object System.Text.StringBuilder
        foreach ($entry in $history) {
            [void]$sb.AppendLine($entry.Formatted)
        }
        $sb.ToString() | Out-File -FilePath $OutputPath -Encoding UTF8
    }
    else {
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.AppendLine("<!DOCTYPE html>")
        [void]$sb.AppendLine("<html><head>")
        [void]$sb.AppendLine("<style>")
        [void]$sb.AppendLine("body { font-family: Consolas, monospace; background: #1e1e1e; color: #d4d4d4; padding: 20px; }")
        [void]$sb.AppendLine("h1 { color: #569cd6; }")
        [void]$sb.AppendLine("table { border-collapse: collapse; width: 100%; }")
        [void]$sb.AppendLine("th { background: #264f78; color: white; padding: 8px; text-align: left; }")
        [void]$sb.AppendLine("td { border: 1px solid #444; padding: 6px 8px; }")
        [void]$sb.AppendLine("tr:nth-child(even) { background: #2d2d2d; }")
        [void]$sb.AppendLine(".INFO { color: #569cd6; }")
        [void]$sb.AppendLine(".SUCCESS { color: #4ec9b0; }")
        [void]$sb.AppendLine(".WARNING { color: #dcdcaa; }")
        [void]$sb.AppendLine(".ERROR { color: #f44747; }")
        [void]$sb.AppendLine(".DEBUG { color: #808080; }")
        [void]$sb.AppendLine("</style></head><body>")
        [void]$sb.AppendLine("<h1>WinTunePro Log Export</h1>")

        $genTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        [void]$sb.AppendLine("<p>Session: $($script:SessionId) | Generated: $genTime</p>")
        [void]$sb.AppendLine("<table><tr><th>Timestamp</th><th>Level</th><th>Category</th><th>Message</th></tr>")

        foreach ($entry in $history) {
            $cssClass = $entry.Level
            $msgHtml = $entry.Message -replace "&", "&amp;" -replace "<", "&lt;" -replace ">", "&gt;"
            [void]$sb.AppendLine("<tr>")
            [void]$sb.AppendLine("<td>$($entry.Timestamp)</td>")
            [void]$sb.AppendLine("<td class='$cssClass'>$($entry.Level)</td>")
            [void]$sb.AppendLine("<td>$($entry.Category)</td>")
            [void]$sb.AppendLine("<td>$msgHtml</td>")
            [void]$sb.AppendLine("</tr>")
        }

        [void]$sb.AppendLine("</table></body></html>")
        $sb.ToString() | Out-File -FilePath $OutputPath -Encoding UTF8
    }

    Write-Log -Level "INFO" -Category "System" -Message "Log exported to $OutputPath ($Format format, $($history.Count) entries)"
}

function global:Format-FileSize {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { return "$([math]::Round($Bytes/1GB,2)) GB" }
    elseif ($Bytes -ge 1MB) { return "$([math]::Round($Bytes/1MB,2)) MB" }
    elseif ($Bytes -ge 1KB) { return "$([math]::Round($Bytes/1KB,2)) KB" }
    else { return "$Bytes B" }
}

function global:Log-Info { param([string]$Message,[string]$Category="System") Write-Log -Level "INFO" -Category $Category -Message $Message }
function global:Log-Success { param([string]$Message,[string]$Category="System") Write-Log -Level "SUCCESS" -Category $Category -Message $Message }
function global:Log-Error { param([string]$Message,[string]$Category="System") Write-Log -Level "ERROR" -Category $Category -Message $Message }
function global:Log-Warning { param([string]$Message,[string]$Category="System") Write-Log -Level "WARNING" -Category $Category -Message $Message }
