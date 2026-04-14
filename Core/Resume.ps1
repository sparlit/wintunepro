#Requires -Version 5.1

$script:StateFilePath = ""
$script:CurrentSessionState = @{
    SessionId           = ""
    IsComplete          = $false
    ResumeFlag          = $false
    PendingOperations  = @()
    CompletedOperations = @()
    StartTime           = ""
    LastUpdateTime      = ""
    SessionData         = @{}
}

function global:Initialize-Resume {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DataDirectory,

        [Parameter(Mandatory = $true)]
        [string]$SessionId
    )

    if (-not (Test-Path $DataDirectory)) {
        New-Item -ItemType Directory -Path $DataDirectory -Force | Out-Null
    }

    $script:StateFilePath = Join-Path $DataDirectory "state.json"
    $script:CurrentSessionState.SessionId = $SessionId
    $script:CurrentSessionState.StartTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $script:CurrentSessionState.LastUpdateTime = $script:CurrentSessionState.StartTime

    Write-Log -Level "INFO" -Category "System" -Message "Resume system initialized | State file: $script:StateFilePath"
}

function global:Save-SessionState {
    [CmdletBinding()]
    param()

    if ($script:StateFilePath -eq "") {
        Write-Log -Level "ERROR" -Category "System" -Message "Resume not initialized, cannot save state"
        return $false
    }

    try {
        $script:CurrentSessionState.LastUpdateTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        $json = $script:CurrentSessionState | ConvertTo-Json -Depth 10
        $json | Out-File -FilePath $script:StateFilePath -Encoding UTF8 -Force

        Write-Log -Level "DEBUG" -Category "System" -Message "Session state saved"
        return $true
    }
    catch {
        Write-Log -Level "ERROR" -Category "System" -Message "Failed to save session state: $($_.Exception.Message)"
        return $false
    }
}

function global:Test-ResumableSession {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$DataDirectory = ""
    )

    if ($DataDirectory -eq "") {
        if ($script:Paths -and $script:Paths.Data) {
            $DataDirectory = $script:Paths.Data
        }
        else {
            return $false
        }
    }

    $stateFile = Join-Path $DataDirectory "state.json"

    if (-not (Test-Path $stateFile)) {
        return $false
    }

    try {
        $json = Get-Content -Path $stateFile -Raw -Encoding UTF8
        $savedState = $json | ConvertFrom-Json

        if ($savedState.IsComplete -eq $true) {
            return $false
        }

        if ($savedState.ResumeFlag -eq $true) {
            Write-Log -Level "INFO" -Category "System" -Message "Resumable session found: $($savedState.SessionId)"
            return $true
        }

        return $false
    }
    catch {
        Write-Log -Level "WARNING" -Category "System" -Message "Corrupted state file, cannot resume"
        return $false
    }
}

function global:Get-PendingOperations {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$DataDirectory = ""
    )

    if ($DataDirectory -eq "") {
        if ($script:Paths -and $script:Paths.Data) {
            $DataDirectory = $script:Paths.Data
        }
        else {
            return @()
        }
    }

    $stateFile = Join-Path $DataDirectory "state.json"

    if (-not (Test-Path $stateFile)) {
        return @()
    }

    try {
        $json = Get-Content -Path $stateFile -Raw -Encoding UTF8
        $savedState = $json | ConvertFrom-Json

        if ($savedState.PendingOperations -and $savedState.PendingOperations.Count -gt 0) {
            return @($savedState.PendingOperations)
        }

        return @()
    }
    catch {
        Write-Log -Level "WARNING" -Category "System" -Message "Failed to read pending operations: $($_.Exception.Message)"
        return @()
    }
}

function global:Invoke-Resume {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$DataDirectory = "",

        [Parameter()]
        [switch]$AutoContinue
    )

    if ($DataDirectory -eq "") {
        if ($script:Paths -and $script:Paths.Data) {
            $DataDirectory = $script:Paths.Data
        }
        else {
            Write-Log -Level "ERROR" -Category "System" -Message "No data directory available for resume"
            return $false
        }
    }

    $stateFile = Join-Path $DataDirectory "state.json"

    if (-not (Test-Path $stateFile)) {
        Write-Log -Level "INFO" -Category "System" -Message "No previous session to resume"
        return $false
    }

    try {
        $json = Get-Content -Path $stateFile -Raw -Encoding UTF8
        $savedState = $json | ConvertFrom-Json

        if ($savedState.IsComplete -eq $true) {
            Write-Log -Level "INFO" -Category "System" -Message "Previous session completed normally, no resume needed"
            return $false
        }

        $sessionId = $savedState.SessionId
        $pendingOps = @()
        if ($savedState.PendingOperations) {
            $pendingOps = @($savedState.PendingOperations)
        }

        Write-Log -Level "INFO" -Category "System" -Message "Resuming session: $sessionId | Pending operations: $($pendingOps.Count)"

        $script:CurrentSessionState.SessionId = $sessionId
        $script:CurrentSessionState.ResumeFlag = $true
        $script:CurrentSessionState.PendingOperations = $pendingOps

        if ($savedState.CompletedOperations) {
            $script:CurrentSessionState.CompletedOperations = @($savedState.CompletedOperations)
        }

        if ($savedState.SessionData) {
            $dataHash = @{}
            $savedState.SessionData.PSObject.Properties | ForEach-Object {
                $dataHash[$_.Name] = $_.Value
            }
            $script:CurrentSessionState.SessionData = $dataHash
        }

        Save-SessionState

        return @{
            SessionId          = $sessionId
            PendingOperations  = $pendingOps
            CompletedOperations = $script:CurrentSessionState.CompletedOperations
            SessionData        = $script:CurrentSessionState.SessionData
        }
    }
    catch {
        Write-Log -Level "ERROR" -Category "System" -Message "Failed to resume session: $($_.Exception.Message)"
        return $false
    }
}

function global:Add-PendingOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OperationName,

        [Parameter()]
        [string]$Category = "General",

        [Parameter()]
        [hashtable]$Parameters = @{},

        [Parameter()]
        [int]$Priority = 5
    )

    $op = @{
        Name       = $OperationName
        Category   = $Category
        Parameters = $Parameters
        Priority   = $Priority
        AddedTime  = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
    }

    $script:CurrentSessionState.PendingOperations += $op
    $script:CurrentSessionState.ResumeFlag = $true

    Save-SessionState

    Write-Log -Level "DEBUG" -Category "System" -Message "Pending operation added: $OperationName (priority: $Priority)"
}

function global:Complete-Operation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OperationName,

        [Parameter()]
        [bool]$Success = $true,

        [Parameter()]
        [string]$Result = ""
    )

    $completed = @{
        Name      = $OperationName
        Success   = $Success
        Result    = $Result
        Completed = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
    }

    $script:CurrentSessionState.CompletedOperations += $completed
    $script:CurrentSessionState.PendingOperations = @(
        $script:CurrentSessionState.PendingOperations | Where-Object { $_.Name -ne $OperationName }
    )

    if ($script:CurrentSessionState.PendingOperations.Count -eq 0) {
        $script:CurrentSessionState.IsComplete = $true
        $script:CurrentSessionState.ResumeFlag = $false
        Write-Log -Level "SUCCESS" -Category "System" -Message "Session complete: all operations finished"
    }

    Save-SessionState

    $status = if ($Success) { "SUCCESS" } else { "ERROR" }
    Write-Log -Level $status -Category "System" -Message "Operation completed: $OperationName | $Result"
}

function global:Reset-SessionState {
    [CmdletBinding()]
    param()

    $script:CurrentSessionState = @{
        SessionId           = $script:CurrentSessionState.SessionId
        IsComplete          = $false
        ResumeFlag          = $false
        PendingOperations  = @()
        CompletedOperations = @()
        StartTime           = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        LastUpdateTime      = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        SessionData         = @{}
    }

    Save-SessionState

    Write-Log -Level "INFO" -Category "System" -Message "Session state reset"
}

function global:Set-SessionData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key,

        [Parameter(Mandatory = $true)]
        [object]$Value
    )

    $script:CurrentSessionState.SessionData[$Key] = $Value
    Save-SessionState
}

function global:Get-SessionData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key,

        [Parameter()]
        [object]$Default = $null
    )

    if ($script:CurrentSessionState.SessionData.ContainsKey($Key)) {
        return $script:CurrentSessionState.SessionData[$Key]
    }

    return $Default
}
