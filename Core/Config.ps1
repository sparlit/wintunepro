#Requires -Version 5.1

$script:ConfigPath = ""
$script:ConfigData = @{}

$script:DefaultConfig = @{
    LogLevel = @{
        Value        = "standard"
        Default      = "standard"
        Category     = "General"
        Description  = "Controls the verbosity of log output. Minimal shows only errors, standard shows key events, verbose shows all operations, debug shows internal details."
        Effect       = "Changing to verbose or debug will produce large log files and may slow down the UI. Minimal hides informational messages that help diagnose issues."
        Advice       = "Use 'standard' for daily use. Switch to 'verbose' only when troubleshooting a specific problem."
    }
    BackupRetentionDays = @{
        Value        = 30
        Default      = 30
        Category     = "Safety"
        Description  = "Number of days to keep rollback backups and restore point data before automatic cleanup."
        Effect       = "Lower values free disk space sooner but reduce the window for recovering from a bad change. Higher values consume more disk space."
        Advice       = "30 days is safe for most users. Reduce to 14 if disk space is tight. Increase to 90 for production servers."
    }
    AutoDeleteBackups = @{
        Value        = $true
        Default      = $true
        Category     = "Safety"
        Description  = "When enabled, old backups older than BackupRetentionDays are automatically deleted during application startup."
        Effect       = "Disabling this means backups accumulate indefinitely and will consume disk space over time."
        Advice       = "Keep enabled unless you have a manual backup rotation policy."
    }
    DefaultPowerPlan = @{
        Value        = "HighPerformance"
        Default      = "HighPerformance"
        Category     = "Optimization"
        Description  = "The power plan to activate when applying performance optimizations. Controls CPU throttling, disk sleep, and display timeout behavior."
        Effect       = "UltraPerformance disables all power saving (higher heat/battery drain). Balanced saves power but may reduce responsiveness."
        Advice       = "Use 'HighPerformance' for desktops. Use 'Balanced' for laptops to preserve battery. Avoid 'UltraPerformance' on laptops."
    }
    CriticalDeviceList = @{
        Value        = @("sqlservr", "store", "Exchange", "dc")
        Default      = @("sqlservr", "store", "Exchange", "dc")
        Category     = "Safety"
        Description  = "List of process/service name patterns that indicate critical infrastructure. If detected, operations are blocked or require confirmation."
        Effect       = "Adding items here prevents WinTunePro from modifying services or processes that match these patterns."
        Advice       = "Add any business-critical application processes. Do not remove SQL or Exchange entries unless you are certain they are not in use."
    }
    ScanExclusions = @{
        Value        = @()
        Default      = @()
        Category     = "Cleaning"
        Description  = "Array of folder paths that the cleaning module will never scan or delete. Useful for mapped drives, shared folders, or application data."
        Effect       = "Excluded folders are completely ignored during all cleaning operations, including deep scans."
        Advice       = "Exclude any mapped network drives and shared data folders to prevent accidental deletion."
    }
    Theme = @{
        Value        = "dark"
        Default      = "dark"
        Category     = "UI"
        Description  = "Controls the visual theme of the application interface."
        Effect       = "Switching themes changes all UI colors and backgrounds immediately. No restart required."
        Advice       = "Use 'dark' for reduced eye strain in low-light environments. Use 'light' for high-contrast readability."
    }
    ShowConfirmations = @{
        Value        = $true
        Default      = $true
        Category     = "UI"
        Description  = "When enabled, the application shows confirmation dialogs before executing potentially destructive operations."
        Effect       = "Disabling this removes all safety prompts. Operations execute immediately when clicked."
        Advice       = "Keep enabled unless you are an experienced user running automated scripts."
    }
    SilentMode = @{
        Value        = $true
        Default      = $false
        Category     = "General"
        Description  = "When enabled, suppresses all UI prompts and uses default values for all decisions. Intended for scheduled/automated runs."
        Effect       = "All operations run without user interaction. Confirmations are auto-accepted. Errors are logged but not displayed."
        Advice       = "Only enable for scheduled task automation. Never enable for interactive sessions."
    }
    AutoApproveFileEdits = @{
        Value        = $false
        Default      = $false
        Category     = "General"
        Description  = "When enabled, file read/write/edit/delete operations initiated by the assistant are auto-approved without additional confirmation."
        Effect       = "Assistant will perform file edits in the application directory immediately when requested. High-risk operations are still subject to SafetyNet blocks."
        Advice       = "Enable only on trusted, non-production machines."
    }
    TestMode = @{
        Value        = $false
        Default      = $false
        Category     = "Safety"
        Description  = "When enabled, operations are simulated but no actual changes are made to the system. Useful for previewing what would happen."
        Effect       = "All operations log what they WOULD do but make no file, registry, or service changes. Logs reflect simulated actions."
        Advice       = "Enable this to safely preview the impact of tuning operations before applying them for real."
    }
    LastSessionState = @{
        Value        = @{}
        Default      = @{}
        Category     = "General"
        Description  = "Stores the state of the last session for resume capability. Managed automatically by the application."
        Effect       = "Clearing this prevents session resume. Modifying it manually may cause unexpected behavior on resume."
        Advice       = "Do not modify manually. Let the application manage this value."
    }
    AutoRestorePoint = @{
        Value        = $true
        Default      = $true
        Category     = "Safety"
        Description  = "Automatically create a system restore point before making changes."
    }
    AutoGenerateReports = @{
        Value        = $false
        Default      = $false
        Category     = "General"
        Description  = "Automatically generate HTML reports after operations."
    }
}

function global:Initialize-Config {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppDataDirectory
    )

    if (-not (Test-Path $AppDataDirectory)) {
        New-Item -ItemType Directory -Path $AppDataDirectory -Force | Out-Null
    }

    $script:ConfigPath = Join-Path $AppDataDirectory "config.json"

    if (Test-Path $script:ConfigPath) {
        try {
            $json = Get-Content -Path $script:ConfigPath -Raw -Encoding UTF8
            if ([string]::IsNullOrWhiteSpace($json)) {
                Write-Log -Level "WARNING" -Category "System" -Message "Config file is empty, using defaults"
                $script:ConfigData = @{}
                foreach ($key in $script:DefaultConfig.Keys) {
                    $script:ConfigData[$key] = $script:DefaultConfig[$key].Clone()
                }
                Save-Config
                return
            }

            $loaded = $json | ConvertFrom-Json
            if ($null -eq $loaded) {
                Write-Log -Level "WARNING" -Category "System" -Message "Config JSON parse failed, using defaults"
                $script:ConfigData = @{}
                foreach ($key in $script:DefaultConfig.Keys) {
                    $script:ConfigData[$key] = $script:DefaultConfig[$key].Clone()
                }
                Save-Config
                return
            }

            $script:ConfigData = @{}
            foreach ($key in $script:DefaultConfig.Keys) {
                $script:ConfigData[$key] = $script:DefaultConfig[$key].Clone()
            }

            $loadedProps = $loaded.PSObject.Properties
            foreach ($prop in $loadedProps) {
                if ($script:ConfigData.ContainsKey($prop.Name)) {
                    $script:ConfigData[$prop.Name].Value = $prop.Value
                }
            }

            Write-Log -Level "INFO" -Category "System" -Message "Configuration loaded from $script:ConfigPath"
        }
        catch {
            Write-Log -Level "WARNING" -Category "System" -Message "Failed to load config, using defaults: $($_.Exception.Message)"
            $script:ConfigData = @{}
            foreach ($key in $script:DefaultConfig.Keys) {
                $script:ConfigData[$key] = $script:DefaultConfig[$key].Clone()
            }
        }
    }
    else {
        $script:ConfigData = @{}
        foreach ($key in $script:DefaultConfig.Keys) {
            $script:ConfigData[$key] = $script:DefaultConfig[$key].Clone()
        }
        Save-Config
        Write-Log -Level "INFO" -Category "System" -Message "Default configuration created at $script:ConfigPath"
    }
}

function global:Get-Config {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Name = ""
    )

    if ($Name -eq "") {
        $result = @{}
        foreach ($key in $script:ConfigData.Keys) {
            $result[$key] = $script:ConfigData[$key].Value
        }
        return $result
    }

    if ($script:ConfigData.ContainsKey($Name)) {
        return $script:ConfigData[$Name].Value
    }

    return $null
}

function global:Set-Config {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [object]$Value
    )

    if (-not $script:ConfigData.ContainsKey($Name)) {
        Write-Log -Level "WARNING" -Category "System" -Message "Unknown configuration key: $Name"
        return $false
    }

    $oldValue = $script:ConfigData[$Name].Value
    $script:ConfigData[$Name].Value = $Value

    Write-Log -Level "INFO" -Category "System" -Message "Config '$Name' changed from '$oldValue' to '$Value'"

    return $true
}

function global:Save-Config {
    [CmdletBinding()]
    param()

    if ($script:ConfigPath -eq "") {
        Write-Log -Level "ERROR" -Category "System" -Message "Config not initialized, cannot save"
        return $false
    }

    $maxRetries = 3
    $retryDelay = 500

    for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
        try {
            $saveData = @{}
            foreach ($key in $script:ConfigData.Keys) {
                $saveData[$key] = $script:ConfigData[$key].Value
            }

            $json = $saveData | ConvertTo-Json -Depth 10
            $json | Out-File -FilePath $script:ConfigPath -Encoding UTF8 -Force

            Write-Log -Level "INFO" -Category "System" -Message "Configuration saved to $script:ConfigPath"
            return $true
        }
        catch {
            if ($attempt -lt $maxRetries) {
                Start-Sleep -Milliseconds $retryDelay
                $retryDelay = $retryDelay * 2
            } else {
                Write-Log -Level "ERROR" -Category "System" -Message "Failed to save config after $maxRetries attempts: $($_.Exception.Message)"
                return $false
            }
        }
    }
    return $false
}

function global:Reset-Config {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Name = ""
    )

    if ($Name -ne "") {
        if ($script:ConfigData.ContainsKey($Name)) {
            $script:ConfigData[$Name].Value = $script:ConfigData[$Name].Default
            Write-Log -Level "INFO" -Category "System" -Message "Config '$Name' reset to default"
        }
    }
    else {
        foreach ($key in $script:ConfigData.Keys) {
            $script:ConfigData[$key].Value = $script:ConfigData[$key].Default
        }
        Write-Log -Level "INFO" -Category "System" -Message "All configuration reset to defaults"
    }

    Save-Config
}

function global:Get-ConfigValue {
    param([string]$Name)
    return Get-Config -Name $Name
}
function global:Set-ConfigValue {
    param([string]$Name, $Value)
    Set-Config -Name $Name -Value $Value
}
function global:Initialize-ConfigPaths {
    param([string]$RootPath)
    Initialize-Config -AppDataDirectory $RootPath
}
function global:Load-Settings {
    try {
        $lastSession = Get-ConfigValue "LastSessionState"
        if ($lastSession -and $lastSession -is [hashtable]) {
            if ($lastSession.ContainsKey("LastRunTime")) {
                Write-Log -Level "INFO" -Category "System" -Message "Last session: $($lastSession.LastRunTime)"
            }
            if ($lastSession.ContainsKey("LastSpaceRecovered")) {
                Write-Log -Level "INFO" -Category "System" -Message "Last session recovered: $(Format-FileSize $lastSession.LastSpaceRecovered)"
            }
        }
    } catch {
        Write-Log -Level "DEBUG" -Category "System" -Message "No previous session state to restore"
    }
}
function global:Save-Settings {
    try {
        $sessionState = @{
            LastRunTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            LastSpaceRecovered = if ($script:State) { $script:State.SpaceRecovered } else { 0 }
            SessionId = if ($script:State) { $script:State.SessionId } else { "" }
        }
        Set-ConfigValue "LastSessionState" $sessionState | Out-Null
    } catch { }
    $null = Save-Config
}
