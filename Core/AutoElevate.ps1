#Requires -Version 5.1

$script:ElevationHistory = @()
$script:ElevatedInstance = $false
$script:OriginalArguments = $null

function global:Test-IsAdmin {
    [CmdletBinding()]
    param()

    try {
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        Write-Log -Level "WARNING" -Category "System" -Message "Failed to check admin status: $($_.Exception.Message)"
        return $false
    }
}

function global:Test-IsSystem {
    [CmdletBinding()]
    param()

    try {
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        return ($currentUser.Name -match "NT AUTHORITY\\SYSTEM")
    }
    catch {
        Write-Log -Level "WARNING" -Category "System" -Message "Failed to check SYSTEM status: $($_.Exception.Message)"
        return $false
    }
}

function global:Get-PrivilegeLevel {
    [CmdletBinding()]
    param()

    if (Test-IsSystem) {
        return "System"
    }

    if (Test-IsAdmin) {
        return "Admin"
    }

    return "User"
}

function global:Invoke-AutoElevate {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ScriptPath = "",

        [Parameter()]
        [string]$Arguments = "",

        [Parameter()]
        [switch]$NoExit
    )

    if (Test-IsAdmin) {
        Write-Log -Level "INFO" -Category "System" -Message "Already running with admin privileges, no elevation needed"
        return $true
    }

    if ($script:ElevatedInstance) {
        Write-Log -Level "WARNING" -Category "System" -Message "Already in elevated instance, preventing elevation loop"
        return $false
    }

    try {
        $currentScript = if ($ScriptPath -ne "") { $ScriptPath } else { $MyInvocation.ScriptName }

        if ($currentScript -eq "") {
            $currentScript = $PSCommandPath
        }

        if ($currentScript -eq "" -or $null -eq $currentScript) {
            Write-Log -Level "ERROR" -Category "System" -Message "Cannot determine script path for elevation"
            return $false
        }

        $elevateArgs = "-ExecutionPolicy Bypass -File `"$currentScript`""

        if ($Arguments -ne "") {
            $elevateArgs += " $Arguments"
        }

        $elevateArgs += " -Elevated"

        if ($NoExit) {
            $elevateArgs += " -NoExit"
        }

        Write-Log -Level "INFO" -Category "System" -Message "Requesting elevation: powershell.exe $elevateArgs"

        $process = Start-Process -FilePath "powershell.exe" -ArgumentList $elevateArgs -Verb RunAs -PassThru -ErrorAction Stop

        $historyEntry = [PSCustomObject]@{
            Timestamp   = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            ScriptPath  = $currentScript
            Arguments   = $Arguments
            ProcessId   = $process.Id
            Result      = "Initiated"
            FromUser    = $env:USERNAME
        }

        $script:ElevationHistory += $historyEntry

        Write-Log -Level "SUCCESS" -Category "System" -Message "Elevation requested, new process PID: $($process.Id)"
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message

        if ($errorMsg -match "canceled by the user") {
            Write-Log -Level "WARNING" -Category "System" -Message "User cancelled UAC elevation prompt"

            $historyEntry = [PSCustomObject]@{
                Timestamp   = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                ScriptPath  = $currentScript
                Arguments   = $Arguments
                ProcessId   = 0
                Result      = "CancelledByUser"
                FromUser    = $env:USERNAME
            }

            $script:ElevationHistory += $historyEntry
        }
        else {
            Write-Log -Level "ERROR" -Category "System" -Message "Failed to elevate: $errorMsg"

            $historyEntry = [PSCustomObject]@{
                Timestamp   = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                ScriptPath  = $currentScript
                Arguments   = $Arguments
                ProcessId   = 0
                Result      = "Failed"
                Error       = $errorMsg
                FromUser    = $env:USERNAME
            }

            $script:ElevationHistory += $historyEntry
        }

        return $false
    }
}

function global:Test-OperationRequiresAdmin {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("ServiceModify", "RegistryHKLM", "RegistryHKCU", "FileSystem", "NetworkConfig", "PowerPlan", "ScheduledTask", "FirewallRule", "DriverInstall", "UserAccount", "SystemRestore", "WindowsUpdate")]
        [string]$Operation
    )

    $adminRequired = @{
        "ServiceModify"   = $true
        "RegistryHKLM"    = $true
        "RegistryHKCU"    = $false
        "FileSystem"      = $false
        "NetworkConfig"   = $true
        "PowerPlan"       = $true
        "ScheduledTask"   = $true
        "FirewallRule"    = $true
        "DriverInstall"   = $true
        "UserAccount"     = $true
        "SystemRestore"   = $true
        "WindowsUpdate"   = $true
    }

    $requires = $false
    if ($adminRequired.ContainsKey($Operation)) {
        $requires = $adminRequired[$Operation]
    }

    if ($requires) {
        $isAdmin = Test-IsAdmin
        if (-not $isAdmin) {
            Write-Log -Level "WARNING" -Category "System" -Message "Operation '$Operation' requires administrator privileges"
        }
        return [PSCustomObject]@{
            Operation       = $Operation
            RequiresAdmin   = $true
            CurrentlyAdmin  = $isAdmin
            CanProceed      = $isAdmin
        }
    }

    return [PSCustomObject]@{
        Operation       = $Operation
        RequiresAdmin   = $false
        CurrentlyAdmin  = (Test-IsAdmin)
        CanProceed      = $true
    }
}

function global:Request-Elevation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Reason,

        [Parameter()]
        [string]$ScriptPath = "",

        [Parameter()]
        [string]$Arguments = ""
    )

    if (Test-IsAdmin) {
        Write-Log -Level "INFO" -Category "System" -Message "Already elevated, no action needed for: $Reason"
        return $true
    }

    Write-Log -Level "INFO" -Category "System" -Message "Elevation requested: $Reason"

    $confirmMsg = "The following operation requires administrator privileges:`n`n$Reason`n`nRestart with elevated privileges?"

    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        $result = [System.Windows.Forms.MessageBox]::Show(
            $confirmMsg,
            "Administrator Required",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )

        if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
            return Invoke-AutoElevate -ScriptPath $ScriptPath -Arguments $Arguments
        }
        else {
            Write-Log -Level "WARNING" -Category "System" -Message "User declined elevation for: $Reason"

            $historyEntry = [PSCustomObject]@{
                Timestamp   = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                ScriptPath  = $ScriptPath
                Arguments   = $Arguments
                ProcessId   = 0
                Result      = "DeclinedByUser"
                Reason      = $Reason
                FromUser    = $env:USERNAME
            }

            $script:ElevationHistory += $historyEntry

            return $false
        }
    }
    catch {
        Write-Log -Level "WARNING" -Category "System" -Message "Failed to show elevation dialog, attempting direct elevation: $($_.Exception.Message)"
        return Invoke-AutoElevate -ScriptPath $ScriptPath -Arguments $Arguments
    }
}

function global:Get-ElevationHistory {
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$Last = 0
    )

    $history = $script:ElevationHistory

    if ($Last -gt 0 -and $history.Count -gt $Last) {
        $history = @($history[($history.Count - $Last)..($history.Count - 1)])
    }

    return $history
}

function global:Set-ElevatedFlag {
    [CmdletBinding()]
    param()

    $script:ElevatedInstance = $true
    Write-Log -Level "INFO" -Category "System" -Message "Running as elevated instance"

    $historyEntry = [PSCustomObject]@{
        Timestamp   = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        ScriptPath  = $PSCommandPath
        Arguments   = ($MyInvocation.UnboundArguments -join " ")
        ProcessId   = $PID
        Result      = "ElevatedInstance"
        FromUser    = $env:USERNAME
    }

    $script:ElevationHistory += $historyEntry
}

function global:Ensure-Elevation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Reason,

        [Parameter()]
        [switch]$Force
    )

    if (Test-IsAdmin) {
        return $true
    }

    if (-not $Force) {
        Write-Log -Level "WARNING" -Category "System" -Message "Admin required for: $Reason. Call Request-Elevation or use -Force to auto-elevate."
        return $false
    }

    return Request-Elevation -Reason $Reason
}

function global:Invoke-AsAdmin {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,

        [Parameter()]
        [string]$WorkingDirectory = "",

        [Parameter()]
        [switch]$Wait
    )

    if (Test-IsAdmin) {
        try {
            return (& $ScriptBlock)
        }
        catch {
            Write-Log -Level "ERROR" -Category "System" -Message "Script block execution failed: $($_.Exception.Message)"
            return $null
        }
    }

    try {
        $tempScript = [System.IO.Path]::GetTempFileName() + ".ps1"
        $scriptContent = $ScriptBlock.ToString()

        if ($WorkingDirectory -ne "") {
            $scriptContent = "Set-Location -Path '$WorkingDirectory'`n" + $scriptContent
        }

        $scriptContent | Out-File -FilePath $tempScript -Encoding UTF8 -Force

        $procArgs = "-ExecutionPolicy Bypass -File `"$tempScript`" -Elevated"

        $processParams = @{
            FilePath     = "powershell.exe"
            ArgumentList = $procArgs
            Verb         = "RunAs"
            PassThru     = $true
        }

        if ($WorkingDirectory -ne "") {
            $processParams.WorkingDirectory = $WorkingDirectory
        }

        $process = Start-Process @processParams -ErrorAction Stop

        if ($Wait) {
            $process.WaitForExit()
            $exitCode = $process.ExitCode
            Remove-Item -Path $tempScript -Force -ErrorAction SilentlyContinue

            $historyEntry = [PSCustomObject]@{
                Timestamp   = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                ScriptPath  = $tempScript
                Arguments   = "ScriptBlock"
                ProcessId   = $process.Id
                Result      = "Completed (Exit: $exitCode)"
                FromUser    = $env:USERNAME
            }

            $script:ElevationHistory += $historyEntry

            return $exitCode
        }
        else {
            $historyEntry = [PSCustomObject]@{
                Timestamp   = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                ScriptPath  = $tempScript
                Arguments   = "ScriptBlock"
                ProcessId   = $process.Id
                Result      = "Running"
                FromUser    = $env:USERNAME
            }

            $script:ElevationHistory += $historyEntry

            return $process.Id
        }
    }
    catch {
        $errorMsg = $_.Exception.Message

        if ($errorMsg -match "canceled by the user") {
            Write-Log -Level "WARNING" -Category "System" -Message "User cancelled UAC for script block execution"
        }
        else {
            Write-Log -Level "ERROR" -Category "System" -Message "Failed to run script block as admin: $errorMsg"
        }

        return $null
    }
}

function global:Get-CurrentSecurityContext {
    [CmdletBinding()]
    param()

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)

    $groups = @()
    foreach ($group in $identity.Groups) {
        try {
            $groupName = $group.Translate([Security.Principal.NTAccount]).Value
            $groups += $groupName
        }
        catch {
            $groups += $group.Value
        }
    }

    $context = [PSCustomObject]@{
        UserName       = $identity.Name
        IsAuthenticated = $identity.IsAuthenticated
        IsAdmin        = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        IsSystem       = ($identity.Name -match "NT AUTHORITY\\SYSTEM")
        PrivilegeLevel = Get-PrivilegeLevel
        AuthenticationType = $identity.AuthenticationType
        Groups         = $groups
        ProcessId      = $PID
    }

    return $context
}
