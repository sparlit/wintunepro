<#
.SYNOPSIS
    WinTune Pro Remote Execution Module
.DESCRIPTION
    Remote execution capabilities for running WinTune operations on remote computers
    using PowerShell Remoting (WinRM) and WMI fallback methods.
.NOTES
    File: Modules\Remote\RemoteExecution.ps1
    Version: 1.0.1
    PowerShell: 5.1+
    Compatible: Windows 10, Windows 11
#>

$script:RemoteConfig = @{
    DefaultTimeout = 300; MaxConcurrentJobs = 10; RetryAttempts = 3
    RetryDelay = 5; EnableCredSSP = $false; Authentication = "Default"
}

function global:Test-RemoteConnection {
    param(
        [Parameter(Mandatory=$true)][string]$ComputerName,
        [pscredential]$Credential,
        [int]$TimeoutSeconds = 10,
        [ValidateSet("WinRM", "WMI", "Auto")][string]$Method = "Auto"
    )
    $result = @{ ComputerName = $ComputerName; IsReachable = $false; WinRMAvailable = $false; WMIAvailable = $false; OSVersion = ""; Method = ""; ErrorMessage = ""; ResponseTime = 0 }
    $pingResult = Test-Connection -ComputerName $ComputerName -Count 1 -Quiet -ErrorAction SilentlyContinue
    if (-not $pingResult) { $result.ErrorMessage = "Computer is not reachable via network"; return $result }
    $result.IsReachable = $true
    if ($Method -in @("WinRM", "Auto")) {
        try {
            $winRMTest = Test-WSMan -ComputerName $ComputerName -ErrorAction Stop; $result.WinRMAvailable = $true; $result.Method = "WinRM"
            $sessionParams = @{ ComputerName = $ComputerName; ErrorAction = "Stop" }; if ($Credential) { $sessionParams.Credential = $Credential }
            $os = Invoke-Command @sessionParams -ScriptBlock { Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version } -ErrorAction SilentlyContinue
            if ($os) { $result.OSVersion = "$($os.Caption) ($($os.Version))" }
        } catch { $result.WinRMAvailable = $false; Write-Log -Message "WinRM test failed for $ComputerName : $($_.Exception.Message)" -Level 'Debug' -Category 'Remote' }
    }
    if ($Method -eq "WMI" -or ($Method -eq "Auto" -and -not $result.WinRMAvailable)) {
        try {
            $wmiParams = @{ Class = "Win32_OperatingSystem"; ComputerName = $ComputerName; ErrorAction = "Stop" }; if ($Credential) { $wmiParams.Credential = $Credential }
            $os = Get-WmiObject @wmiParams; $result.WMIAvailable = $true; $result.Method = "WMI"; $result.OSVersion = "$($os.Caption) ($($os.Version))"
        } catch { $result.WMIAvailable = $false; Write-Log -Message "WMI test failed for $ComputerName : $($_.Exception.Message)" -Level 'Debug' -Category 'Remote' }
    }
    if ($Method -eq "Auto") { if ($result.WinRMAvailable) { $result.Method = "WinRM" } elseif ($result.WMIAvailable) { $result.Method = "WMI" } else { $result.Method = "None"; $result.ErrorMessage = "Neither WinRM nor WMI is available" } }
    return $result
}

function global:New-RemoteSession {
    param(
        [Parameter(Mandatory=$true)][string]$ComputerName,
        [pscredential]$Credential,
        [ValidateSet("WinRM", "WMI", "Auto")][string]$Method = "Auto",
        [int]$TimeoutSeconds = 60
    )
    $session = @{ ComputerName = $ComputerName; Method = $Method; Session = $null; IsConnected = $false; ErrorMessage = "" }
    $testResult = Test-RemoteConnection -ComputerName $ComputerName -Credential $Credential -Method $Method
    if (-not $testResult.IsReachable) { $session.ErrorMessage = "Computer not reachable: $($testResult.ErrorMessage)"; return $session }
    if ($testResult.Method -eq "None") { $session.ErrorMessage = "No available remote method"; return $session }
    $session.Method = $testResult.Method
    try {
        if ($session.Method -eq "WinRM") {
            $sessionParams = @{ ComputerName = $ComputerName; ErrorAction = "Stop" }; if ($Credential) { $sessionParams.Credential = $Credential }
            $session.Session = New-PSSession @sessionParams; $session.IsConnected = $true
            Write-Log -Message "WinRM session established to $ComputerName" -Level 'Success' -Category 'Remote'
        } else { $session.IsConnected = $true; Write-Log -Message "WMI connection ready for $ComputerName" -Level 'Success' -Category 'Remote' }
    } catch { $session.ErrorMessage = $_.Exception.Message; Write-Log -Message "Failed to create session to $ComputerName : $($_.Exception.Message)" -Level 'Error' -Category 'Remote' }
    return $session
}

function global:Remove-RemoteSession {
    param($Session)
    if ($Session.Session -and $Session.Method -eq "WinRM") {
        try { Remove-PSSession -Session $Session.Session -ErrorAction SilentlyContinue; Write-Log -Message "Remote session to $($Session.ComputerName) closed" -Level 'Debug' -Category 'Remote' } catch { Write-Log $_.Exception.Message -Level 'WARNING' -Category 'System' }
    }
}

function global:Invoke-RemoteCommandWinRM {
    param(
        [Parameter(Mandatory=$true)][string]$ComputerName,
        [Parameter(Mandatory=$true)][scriptblock]$ScriptBlock,
        [pscredential]$Credential,
        [object[]]$ArgumentList,
        [int]$TimeoutSeconds = 300
    )
    $result = @{ ComputerName = $ComputerName; Success = $false; Output = $null; Error = ""; ExecutionTime = 0 }
    $startTime = Get-Date
    try {
        $invokeParams = @{ ComputerName = $ComputerName; ScriptBlock = $ScriptBlock; ErrorAction = "Stop" }
        if ($Credential) { $invokeParams.Credential = $Credential }; if ($ArgumentList) { $invokeParams.ArgumentList = $ArgumentList }
        $output = Invoke-Command @invokeParams; $result.Success = $true; $result.Output = $output
    } catch { $result.Error = $_.Exception.Message; Write-Log -Message "WinRM command failed on $ComputerName : $($_.Exception.Message)" -Level 'Error' -Category 'Remote' }
    $result.ExecutionTime = ((Get-Date) - $startTime).TotalSeconds
    return $result
}

function global:Invoke-RemoteScriptWinRM {
    param(
        [Parameter(Mandatory=$true)][string]$ComputerName,
        [Parameter(Mandatory=$true)][string]$FilePath,
        [pscredential]$Credential,
        [int]$TimeoutSeconds = 300
    )
    $result = @{ ComputerName = $ComputerName; Success = $false; Output = $null; Error = ""; ExecutionTime = 0 }
    if (-not (Test-Path $FilePath)) { $result.Error = "Script file not found: $FilePath"; return $result }
    $startTime = Get-Date
    try {
        $invokeParams = @{ ComputerName = $ComputerName; FilePath = $FilePath; ErrorAction = "Stop" }
        if ($Credential) { $invokeParams.Credential = $Credential }
        $output = Invoke-Command @invokeParams; $result.Success = $true; $result.Output = $output
    } catch { $result.Error = $_.Exception.Message; Write-Log -Message "WinRM script execution failed on $ComputerName : $($_.Exception.Message)" -Level 'Error' -Category 'Remote' }
    $result.ExecutionTime = ((Get-Date) - $startTime).TotalSeconds
    return $result
}

function global:Invoke-RemoteCommandWMI {
    param(
        [Parameter(Mandatory=$true)][string]$ComputerName,
        [Parameter(Mandatory=$true)][string]$Command,
        [pscredential]$Credential,
        [int]$TimeoutSeconds = 300
    )
    $result = @{ ComputerName = $ComputerName; Success = $false; ProcessId = $null; Output = $null; Error = ""; ExecutionTime = 0 }
    $startTime = Get-Date
    try {
        $wmiParams = @{ Class = "Win32_Process"; Name = "Create"; ArgumentList = $Command; ComputerName = $ComputerName; ErrorAction = "Stop" }
        if ($Credential) { $wmiParams.Credential = $Credential }
        $processResult = Invoke-WmiMethod @wmiParams
        if ($processResult.ReturnValue -eq 0) { $result.Success = $true; $result.ProcessId = $processResult.ProcessId; Write-Log -Message "WMI command started on $ComputerName with PID $($processResult.ProcessId)" -Level 'Debug' -Category 'Remote' }
        else { $result.Error = "WMI CreateProcess returned: $($processResult.ReturnValue)" }
    } catch { $result.Error = $_.Exception.Message; Write-Log -Message "WMI command failed on $ComputerName : $($_.Exception.Message)" -Level 'Error' -Category 'Remote' }
    $result.ExecutionTime = ((Get-Date) - $startTime).TotalSeconds
    return $result
}

function global:Invoke-RemoteCommandWMICapture {
    param(
        [Parameter(Mandatory=$true)][string]$ComputerName,
        [Parameter(Mandatory=$true)][string]$Command,
        [pscredential]$Credential,
        [int]$TimeoutSeconds = 300
    )
    $result = @{ ComputerName = $ComputerName; Success = $false; Output = $null; Error = "" }
    $outputFile = "C:\Windows\Temp\WinTune_$([Guid]::NewGuid().ToString()).txt"
    $wrappedCommand = "cmd /c $Command > `"$outputFile`" 2>&1"
    $execResult = Invoke-RemoteCommandWMI -ComputerName $ComputerName -Command $wrappedCommand -Credential $Credential -TimeoutSeconds $TimeoutSeconds
    if (-not $execResult.Success) { $result.Error = "Command execution failed: $($execResult.Error)"; return $result }
    Start-Sleep -Seconds 2
    try {
        $remoteFilePath = "\\$ComputerName\admin$\Temp\$(Split-Path $outputFile -Leaf)"
        if (Test-Path $remoteFilePath) { $result.Output = Get-Content $remoteFilePath -Raw; $result.Success = $true; Remove-Item $remoteFilePath -Force -ErrorAction SilentlyContinue }
    } catch { $result.Error = "Failed to read output: $($_.Exception.Message)" }
    return $result
}

function global:Invoke-RemoteTempCleanup {
    param(
        [Parameter(Mandatory=$true)][string]$ComputerName,
        [pscredential]$Credential,
        [ValidateSet("WinRM", "WMI", "Auto")][string]$Method = "Auto",
        [switch]$Preview
    )
    $result = @{ ComputerName = $ComputerName; Success = $false; BytesRecovered = 0; FilesDeleted = 0; Errors = @(); Method = $Method }
    $testResult = Test-RemoteConnection -ComputerName $ComputerName -Credential $Credential -Method $Method
    if ($testResult.Method -eq "None") { $result.Errors += "Cannot connect to remote computer: $($testResult.ErrorMessage)"; return $result }
    $Method = $testResult.Method; $result.Method = $Method
    Write-Log -Message "Starting remote temp cleanup on $ComputerName via $Method" -Level 'Info' -Category 'Remote'
    if ($Method -eq "WinRM") {
        $scriptBlock = {
            param($IsPreview)
            $results = @{ BytesRecovered = 0; FilesDeleted = 0; Errors = @() }
            $tempPaths = @($env:TEMP, "C:\Windows\Temp")
            foreach ($path in $tempPaths) {
                if (Test-Path $path) {
                    try {
                        $files = Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                        foreach ($file in $files) { try { if (-not $IsPreview) { Remove-Item -Path $file.FullName -Force -Recurse -ErrorAction SilentlyContinue }; $results.BytesRecovered += $file.Length; $results.FilesDeleted++ } catch { Write-Log -Level "WARNING" -Category "System" -Message $_.Exception.Message } }
                    } catch { Write-Log -Level "WARNING" -Category "System" -Message $_.Exception.Message }
                }
            }
            return $results
        }
        $invokeResult = Invoke-RemoteCommandWinRM -ComputerName $ComputerName -ScriptBlock $scriptBlock -ArgumentList $Preview -Credential $Credential
        if ($invokeResult.Success) { $result.Success = $true; $result.BytesRecovered = $invokeResult.Output.BytesRecovered; $result.FilesDeleted = $invokeResult.Output.FilesDeleted; $result.Errors = $invokeResult.Output.Errors } else { $result.Errors += $invokeResult.Error }
    } else {
        $result.Errors += "WMI method provides limited cleanup functionality. WinRM recommended."
        $cleanCommand = "powershell -Command `"Get-ChildItem C:\Windows\Temp -Recurse -Force | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue`""
        if (-not $Preview) { $wmiResult = Invoke-RemoteCommandWMI -ComputerName $ComputerName -Command $cleanCommand -Credential $Credential; $result.Success = $wmiResult.Success } else { $result.Success = $true }
    }
    if ($result.Success) { Write-Log -Message "Remote cleanup completed on $ComputerName : $($result.FilesDeleted) files, $([Math]::Round($result.BytesRecovered / 1MB, 2)) MB" -Level 'Success' -Category 'Remote' }
    return $result
}

function global:Invoke-RemoteNetworkReset {
    param(
        [Parameter(Mandatory=$true)][string]$ComputerName,
        [pscredential]$Credential,
        [ValidateSet("WinRM", "WMI", "Auto")][string]$Method = "Auto",
        [ValidateSet("TCPIP", "Winsock", "DNS", "All")][string]$ResetType = "All",
        [switch]$Preview
    )
    $result = @{ ComputerName = $ComputerName; Success = $false; Operations = @(); Errors = @(); Method = $Method }
    $testResult = Test-RemoteConnection -ComputerName $ComputerName -Credential $Credential -Method $Method
    if ($testResult.Method -eq "None") { $result.Errors += "Cannot connect: $($testResult.ErrorMessage)"; return $result }
    $Method = $testResult.Method; $result.Method = $Method
    Write-Log -Message "Starting remote network reset on $ComputerName ($ResetType)" -Level 'Info' -Category 'Remote'
    $commands = @()
    switch ($ResetType) {
        "TCPIP" { $commands += "netsh int ip reset"; $commands += "netsh int ipv4 reset"; $commands += "netsh int ipv6 reset" }
        "Winsock" { $commands += "netsh winsock reset" }
        "DNS" { $commands += "ipconfig /flushdns"; $commands += "netsh int ip set dns" }
        "All" { $commands += "netsh winsock reset"; $commands += "netsh int ip reset"; $commands += "netsh int ipv4 reset"; $commands += "netsh int ipv6 reset"; $commands += "ipconfig /flushdns"; $commands += "ipconfig /registerdns" }
    }
    if ($Method -eq "WinRM") {
        $scriptBlock = { param($Commands, $IsPreview); $results = @(); foreach ($cmd in $Commands) { try { if (-not $IsPreview) { $output = Invoke-Expression $cmd 2>&1 }; $results += @{ Command = $cmd; Success = $true } } catch { $results += @{ Command = $cmd; Success = $false; Error = $_.Exception.Message } } }; return $results }
        $invokeResult = Invoke-RemoteCommandWinRM -ComputerName $ComputerName -ScriptBlock $scriptBlock -ArgumentList @($commands, $Preview) -Credential $Credential
        if ($invokeResult.Success) { $result.Success = $true; $result.Operations = $invokeResult.Output } else { $result.Errors += $invokeResult.Error }
    } else {
        foreach ($cmd in $commands) { if ($Preview) { $result.Operations += @{ Command = $cmd; Success = $true; Preview = $true } } else { $wmiResult = Invoke-RemoteCommandWMI -ComputerName $ComputerName -Command $cmd -Credential $Credential; $result.Operations += @{ Command = $cmd; Success = $wmiResult.Success; Error = $wmiResult.Error } } }
        $result.Success = $true
    }
    Write-Log -Message "Remote network reset completed on $ComputerName" -Level 'Success' -Category 'Remote'
    return $result
}

function global:Invoke-BulkRemoteOperation {
    param(
        [Parameter(Mandatory=$true)][string[]]$ComputerNames,
        [Parameter(Mandatory=$true)][ValidateSet("TempCleanup", "NetworkReset", "ServiceOptimization", "Custom")][string]$Operation,
        [scriptblock]$CustomScriptBlock,
        [pscredential]$Credential,
        [ValidateSet("WinRM", "WMI", "Auto")][string]$Method = "Auto",
        [int]$MaxConcurrent = 5,
        [switch]$Preview,
        [switch]$ContinueOnError
    )
    $results = @{ TotalComputers = $ComputerNames.Count; Successful = 0; Failed = 0; Results = @(); StartTime = Get-Date; EndTime = $null }
    Write-Log -Message "Starting bulk operation '$Operation' on $($ComputerNames.Count) computers" -Level 'Info' -Category 'Remote'
    foreach ($computer in $ComputerNames) {
        $computerResult = @{ ComputerName = $computer; Success = $false; Data = $null; Error = "" }
        try {
            switch ($Operation) {
                "TempCleanup" { $computerResult.Data = Invoke-RemoteTempCleanup -ComputerName $computer -Credential $Credential -Method $Method -Preview:$Preview }
                "NetworkReset" { $computerResult.Data = Invoke-RemoteNetworkReset -ComputerName $computer -Credential $Credential -Method $Method -Preview:$Preview }
                "Custom" { if ($CustomScriptBlock) { if ($Method -eq "WinRM" -or $Method -eq "Auto") { $computerResult.Data = Invoke-RemoteCommandWinRM -ComputerName $computer -ScriptBlock $CustomScriptBlock -Credential $Credential } else { $computerResult.Error = "Custom scripts require WinRM" } } }
            }
            if ($computerResult.Data -and $computerResult.Data.Success) { $computerResult.Success = $true; $results.Successful++ } else { $computerResult.Error = if ($computerResult.Data) { $computerResult.Data.Errors -join "; " } else { "Unknown error" }; $results.Failed++ }
        } catch { $computerResult.Error = $_.Exception.Message; $results.Failed++; if (-not $ContinueOnError) { Write-Log -Message "Stopping bulk operation due to error on $computer" -Level 'Error' -Category 'Remote'; break } }
        $results.Results += $computerResult
    }
    $results.EndTime = Get-Date
    Write-Log -Message "Bulk operation complete: $($results.Successful) succeeded, $($results.Failed) failed" -Level 'Info' -Category 'Remote'
    return $results
}

function global:Get-RemoteComputerStatus {
    param(
        [Parameter(Mandatory=$true)][string]$ComputerName,
        [pscredential]$Credential,
        [ValidateSet("WinRM", "WMI", "Auto")][string]$Method = "Auto"
    )
    $status = @{ ComputerName = $ComputerName; IsOnline = $false; OSVersion = ""; FreeDiskSpace = 0; FreeMemory = 0; CPUUsage = 0; Uptime = ""; Services = @(); Errors = @() }
    $testResult = Test-RemoteConnection -ComputerName $ComputerName -Credential $Credential -Method $Method
    if ($testResult.Method -eq "None") { $status.Errors += $testResult.ErrorMessage; return $status }
    $status.IsOnline = $true; $status.OSVersion = $testResult.OSVersion; $Method = $testResult.Method
    if ($Method -eq "WinRM") {
        $scriptBlock = { $result = @{}; $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"; $result.FreeDiskSpace = $disk.FreeSpace; $os = Get-CimInstance Win32_OperatingSystem; $result.FreeMemory = $os.FreePhysicalMemory * 1KB; $result.TotalMemory = $os.TotalVisibleMemorySize * 1KB; $result.Uptime = ((Get-Date) - $os.LastBootUpTime).ToString("dd\.hh\:mm\:ss"); $cpu = Get-CimInstance Win32_Processor; $result.CPUUsage = $cpu.LoadPercentage; $result.RunningServices = @(Get-Service | Where-Object { $_.Status -eq 'Running' }).Count; return $result }
        $invokeResult = Invoke-RemoteCommandWinRM -ComputerName $ComputerName -ScriptBlock $scriptBlock -Credential $Credential
        if ($invokeResult.Success) { $status.FreeDiskSpace = $invokeResult.Output.FreeDiskSpace; $status.FreeMemory = $invokeResult.Output.FreeMemory; $status.TotalMemory = $invokeResult.Output.TotalMemory; $status.CPUUsage = $invokeResult.Output.CPUUsage; $status.Uptime = $invokeResult.Output.Uptime; $status.RunningServices = $invokeResult.Output.RunningServices }
    } else {
        try { $wmiParams = @{ ComputerName = $ComputerName; ErrorAction = "Stop" }; if ($Credential) { $wmiParams.Credential = $Credential }; $disk = Get-WmiObject @wmiParams -Class Win32_LogicalDisk -Filter "DeviceID='C:'"; $status.FreeDiskSpace = $disk.FreeSpace; $os = Get-WmiObject @wmiParams -Class Win32_OperatingSystem; $status.FreeMemory = $os.FreePhysicalMemory * 1KB; $status.Uptime = ((Get-Date) - $os.ConvertToDateTime($os.LastBootUpTime)).ToString("dd\.hh\:mm\:ss") } catch { $status.Errors += $_.Exception.Message }
    }
    return $status
}

function global:New-RemoteSessionPool {
    param([Parameter(Mandatory=$true)][string[]]$ComputerNames, [pscredential]$Credential, [int]$MaxSessions = 10)
    $pool = @{ Sessions = @{}; MaxSessions = $MaxSessions; Credential = $Credential }
    foreach ($computer in $ComputerNames) {
        if ($pool.Sessions.Count -ge $MaxSessions) { Write-Log -Message "Session pool limit reached ($MaxSessions)" -Level 'Warning' -Category 'Remote'; break }
        $session = New-RemoteSession -ComputerName $computer -Credential $Credential
        if ($session.IsConnected) { $pool.Sessions[$computer] = $session }
    }
    Write-Log -Message "Session pool created with $($pool.Sessions.Count) connections" -Level 'Info' -Category 'Remote'
    return $pool
}

function global:Remove-RemoteSessionPool {
    param($Pool)
    foreach ($computer in $Pool.Sessions.Keys) { Remove-RemoteSession -Session $Pool.Sessions[$computer] }
    Write-Log -Message "Session pool closed" -Level 'Info' -Category 'Remote'
}

function global:Export-RemoteOperationReport {
    param([Parameter(Mandatory=$true)]$Results, [Parameter(Mandatory=$true)][string]$Path, [ValidateSet('CSV', 'JSON', 'HTML')][string]$Format = 'HTML')
    $reportData = $Results.Results | ForEach-Object { [PSCustomObject]@{ ComputerName = $_.ComputerName; Success = $_.Success; BytesRecovered = if ($_.Data.BytesRecovered) { $_.Data.BytesRecovered } else { 0 }; FilesDeleted = if ($_.Data.FilesDeleted) { $_.Data.FilesDeleted } else { 0 }; Error = $_.Error } }
    switch ($Format) {
        'CSV' { $reportData | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8 }
        'JSON' { $Results | ConvertTo-Json -Depth 5 | Set-Content $Path -Encoding UTF8 }
        'HTML' {
            $html = "<!DOCTYPE html><html><head><title>Remote Operation Report</title><style>body{font-family:Arial;margin:20px}table{border-collapse:collapse;width:100%}th,td{border:1px solid #ddd;padding:8px;text-align:left}th{background-color:#4CAF50;color:white}tr:nth-child(even){background-color:#f2f2f2}.success{color:green}.failure{color:red}</style></head><body><h1>Remote Operation Report</h1><p>Total: $($Results.TotalComputers) | Success: $($Results.Successful) | Failed: $($Results.Failed)</p><table><tr><th>Computer</th><th>Status</th><th>Bytes Recovered</th><th>Files Deleted</th><th>Errors</th></tr>"
            foreach ($item in $reportData) { $statusClass = if ($item.Success) { "success" } else { "failure" }; $statusText = if ($item.Success) { "Success" } else { "Failed" }; $html += "<tr><td>$($item.ComputerName)</td><td class='$statusClass'>$statusText</td><td>$($item.BytesRecovered)</td><td>$($item.FilesDeleted)</td><td>$($item.Error)</td></tr>" }
            $html += "</table></body></html>"; $html | Set-Content $Path -Encoding UTF8
        }
    }
    Write-Log -Message "Remote operation report exported to $Path" -Level 'Success' -Category 'Remote'
    return $Path
}
