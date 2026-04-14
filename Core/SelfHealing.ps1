# SelfHealing.ps1 - Self-healing and error recovery system
#Requires -Version 5.1

$script:HealingState = @{
    Initialized       = $false
    HealingActions    = [System.Collections.Generic.List[PSObject]]::new()
    LastKnownGood     = $null
    RecoveryAttempts  = [System.Collections.Generic.List[PSObject]]::new()
    CriticalServices  = @('wuauserv','bits','WinDefend','mpssvc','Dnscache','Dhcp','NlaSvc','EventLog','CryptSvc')
    CriticalFiles     = @(
        "$env:SystemDrive\Windows\System32\drivers\etc\hosts"
        "$env:SystemDrive\Windows\System32\config\SYSTEM"
        "$env:SystemDrive\Windows\System32\config\SOFTWARE"
    )
}

function global:Initialize-SelfHealing {
    [CmdletBinding()]
    param()

    try {
        $script:HealingState.Initialized = $true
        $script:HealingState.HealingActions = [System.Collections.Generic.List[PSObject]]::new()
        $script:HealingState.RecoveryAttempts = [System.Collections.Generic.List[PSObject]]::new()

        $script:HealingState.LastKnownGood = @{
            Timestamp = [DateTime]::Now
            Services  = @{}
            Registry  = @{}
            Network   = @{}
            Files     = @{}
        }

        try {
            $currentState = Get-Service -Name $script:HealingState.CriticalServices -ErrorAction SilentlyContinue
            foreach ($svc in $currentState) {
                $script:HealingState.LastKnownGood.Services[$svc.Name] = $svc.Status
            }
        }
        catch {
            Write-Log -Level "WARNING" -Category "System" -Message "Could not capture service state: $($_.Exception.Message)"
        }

        Write-Log -Level "INFO" -Category "System" -Message "SelfHealing initialized"
        return $true
    }
    catch {
        Write-Log -Level "ERROR" -Category "System" -Message "Failed to initialize SelfHealing: $($_.Exception.Message)"
        throw
    }
}

function global:Test-SystemIntegrity {
    [CmdletBinding()]
    param()

    try {
        if (-not $script:HealingState.Initialized) {
            Write-Log -Level "WARNING" -Category "System" -Message "SelfHealing not initialized, initializing now"
            Initialize-SelfHealing
        }

        $issues = [System.Collections.Generic.List[PSObject]]::new()

        $serviceIssues = Test-ServicesIntegrity
        foreach ($issue in $serviceIssues) { $issues.Add($issue) }

        $registryIssues = Test-RegistryIntegrity
        foreach ($issue in $registryIssues) { $issues.Add($issue) }

        $networkIssues = Test-NetworkIntegrity
        foreach ($issue in $networkIssues) { $issues.Add($issue) }

        $fileIssues = Test-FileIntegrity
        foreach ($issue in $fileIssues) { $issues.Add($issue) }

        Write-Log -Level "INFO" -Category "System" -Message "System integrity check completed: $($issues.Count) issues found"
        return $issues.ToArray()
    }
    catch {
        Write-Log -Level "ERROR" -Category "System" -Message "System integrity check failed: $($_.Exception.Message)"
        throw
    }
}

function global:Invoke-SelfHeal {
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$DryRun,

        [Parameter()]
        [switch]$Force
    )

    try {
        if (-not $script:HealingState.Initialized) {
            Write-Log -Level "WARNING" -Category "System" -Message "SelfHealing not initialized, initializing now"
            Initialize-SelfHealing
        }

        $issues = Test-SystemIntegrity
        $healed = [System.Collections.Generic.List[PSObject]]::new()
        $skipped = [System.Collections.Generic.List[PSObject]]::new()

        foreach ($issue in $issues) {
            if ($DryRun) {
                Write-Log -Level "INFO" -Category "System" -Message "[DRY RUN] Would heal: $($issue.Type) - $($issue.Description)"
                $healed.Add([PSCustomObject]@{
                    Issue     = $issue
                    Action    = "DryRun"
                    Timestamp = [DateTime]::Now
                    Success   = $false
                })
                continue
            }

            try {
                $result = Invoke-AutoFix -Issue $issue -Force:$Force
                if ($result.Success) {
                    $healed.Add($result)
                    Write-Log -Level "INFO" -Category "System" -Message "Healed: $($issue.Type) - $($issue.Description)"
                }
                else {
                    $skipped.Add($result)
                    Write-Log -Level "WARNING" -Category "System" -Message "Could not heal: $($issue.Type) - $($issue.Description)"
                }
            }
            catch {
                Write-Log -Level "ERROR" -Category "System" -Message "Error healing $($issue.Type): $($_.Exception.Message)"
                $skipped.Add([PSCustomObject]@{
                    Issue   = $issue
                    Error   = $_.Exception.Message
                    Success = $false
                })
            }
        }

        $script:HealingState.LastKnownGood.Timestamp = [DateTime]::Now

        Write-Log -Level "INFO" -Category "System" -Message "Self-healing completed: $($healed.Count) healed, $($skipped.Count) skipped"
        return @{
            Healed  = $healed.ToArray()
            Skipped = $skipped.ToArray()
        }
    }
    catch {
        Write-Log -Level "ERROR" -Category "System" -Message "Self-healing failed: $($_.Exception.Message)"
        throw
    }
}

function global:Invoke-ErrorRecovery {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OperationName,

        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,

        [Parameter()]
        [scriptblock]$Fallback,

        [Parameter()]
        [int]$MaxRetries = 3,

        [Parameter()]
        [int]$RetryDelaySeconds = 5
    )

    try {
        if (-not $script:HealingState.Initialized) {
            Initialize-SelfHealing
        }

        $attempt = 0
        $lastError = $null

        while ($attempt -le $MaxRetries) {
            $attempt++

            try {
                $result = & $ScriptBlock
                Write-Log -Level "INFO" -Category "System" -Message "Operation '$OperationName' succeeded on attempt $attempt"

                $script:HealingState.RecoveryAttempts.Add([PSCustomObject]@{
                    Operation = $OperationName
                    Attempt   = $attempt
                    Success   = $true
                    Timestamp = [DateTime]::Now
                })

                return $result
            }
            catch {
                $lastError = $_
                Write-Log -Level "WARNING" -Category "System" -Message "Operation '$OperationName' failed on attempt $attempt/$($MaxRetries+1): $($_.Exception.Message)"

                if ($attempt -le $MaxRetries) {
                    Start-Sleep -Seconds $RetryDelaySeconds
                }
            }
        }

        if ($null -ne $Fallback) {
            Write-Log -Level "WARNING" -Category "System" -Message "All retries exhausted for '$OperationName', executing fallback"

            try {
                $fallbackResult = & $Fallback

                $script:HealingState.RecoveryAttempts.Add([PSCustomObject]@{
                    Operation = $OperationName
                    Attempt   = $attempt
                    Success   = $true
                    Fallback  = $true
                    Timestamp = [DateTime]::Now
                })

                return $fallbackResult
            }
            catch {
                Write-Log -Level "ERROR" -Category "System" -Message "Fallback also failed for '$OperationName': $($_.Exception.Message)"
                $script:HealingState.RecoveryAttempts.Add([PSCustomObject]@{
                    Operation = $OperationName
                    Attempt   = $attempt
                    Success   = $false
                    Fallback  = $true
                    Error     = $_.Exception.Message
                    Timestamp = [DateTime]::Now
                })
                throw
            }
        }

        $script:HealingState.RecoveryAttempts.Add([PSCustomObject]@{
            Operation = $OperationName
            Attempt   = $attempt
            Success   = $false
            Error     = $lastError.Exception.Message
            Timestamp = [DateTime]::Now
        })

        throw $lastError
    }
    catch {
        if ($null -ne $lastError -and $lastError -ne $_) {
            Write-Log -Level "ERROR" -Category "System" -Message "Recovery failed for '$OperationName': $($_.Exception.Message)"
        }
        throw
    }
}

function global:Invoke-StateRestoration {
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$Force
    )

    try {
        if (-not $script:HealingState.Initialized) {
            Write-Log -Level "WARNING" -Category "System" -Message "SelfHealing not initialized"
            return $false
        }

        if ($null -eq $script:HealingState.LastKnownGood -and -not $Force) {
            Write-Log -Level "WARNING" -Category "System" -Message "No known-good state available for restoration"
            return $false
        }

        Write-Log -Level "INFO" -Category "System" -Message "Restoring to last known-good state from $($script:HealingState.LastKnownGood.Timestamp)"

        $restored = [System.Collections.Generic.List[string]]::new()

        foreach ($svcName in $script:HealingState.LastKnownGood.Services.Keys) {
            $expectedStatus = $script:HealingState.LastKnownGood.Services[$svcName]
            try {
                $currentService = Get-Service -Name $svcName -ErrorAction SilentlyContinue
                if ($null -eq $currentService) {
                    Write-Log -Level "WARNING" -Category "System" -Message "Service '$svcName' not found during restoration"
                    continue
                }

                if ($currentService.Status -ne $expectedStatus -and $expectedStatus -eq 'Running') {
                    Start-Service -Name $svcName -ErrorAction Stop
                    Write-Log -Level "INFO" -Category "System" -Message "Restored service '$svcName' to $expectedStatus"
                    $restored.Add("Service:$svcName")
                }
            }
            catch {
                Write-Log -Level "WARNING" -Category "System" -Message "Failed to restore service '$svcName': $($_.Exception.Message)"
            }
        }

        Write-Log -Level "INFO" -Category "System" -Message "State restoration completed: $($restored.Count) items restored"
        return @{
            RestoredCount = $restored.Count
            Items         = $restored.ToArray()
            Timestamp     = [DateTime]::Now
        }
    }
    catch {
        Write-Log -Level "ERROR" -Category "System" -Message "State restoration failed: $($_.Exception.Message)"
        throw
    }
}

function global:Test-ServicesIntegrity {
    [CmdletBinding()]
    param()

    try {
        $issues = [System.Collections.Generic.List[PSObject]]::new()

        foreach ($svcName in $script:HealingState.CriticalServices) {
            try {
                $svc = Get-Service -Name $svcName -ErrorAction Stop

                if ($svc.Status -ne 'Running') {
                    $issues.Add([PSCustomObject]@{
                        Type        = 'ServiceStopped'
                        Service     = $svcName
                        Description = "Service '$svcName' is $($svc.Status), expected Running"
                        Severity    = if ($svcName -in @('EventLog','WinDefend','CryptSvc')) { 'Critical' } else { 'High' }
                    })
                }

                if ($svc.StartType -eq 'Disabled' -and $svcName -in @('EventLog','WinDefend','CryptSvc','Dnscache','Dhcp','NlaSvc')) {
                    $issues.Add([PSCustomObject]@{
                        Type        = 'ServiceDisabled'
                        Service     = $svcName
                        Description = "Critical service '$svcName' is disabled"
                        Severity    = 'Critical'
                    })
                }
            }
            catch [System.ServiceProcess.ServiceNotFoundException], [System.InvalidOperationException] {
                $issues.Add([PSCustomObject]@{
                    Type        = 'ServiceNotFound'
                    Service     = $svcName
                    Description = "Critical service '$svcName' not found"
                    Severity    = 'Critical'
                })
            }
            catch {
                Write-Log -Level "WARNING" -Category "System" -Message "Error checking service '$svcName': $($_.Exception.Message)"
                $issues.Add([PSCustomObject]@{
                    Type        = 'ServiceError'
                    Service     = $svcName
                    Description = "Error checking service '$svcName': $($_.Exception.Message)"
                    Severity    = 'Medium'
                })
            }
        }

        return $issues.ToArray()
    }
    catch {
        Write-Log -Level "ERROR" -Category "System" -Message "Services integrity check failed: $($_.Exception.Message)"
        throw
    }
}

function global:Test-RegistryIntegrity {
    [CmdletBinding()]
    param()

    try {
        $issues = [System.Collections.Generic.List[PSObject]]::new()

        $criticalKeys = @(
            @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'; Property = 'EnableLUA' }
            @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'; Property = 'LimitBlankPasswordUse' }
            @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate'; Property = $null }
        )

        foreach ($key in $criticalKeys) {
            try {
                if (-not (Test-Path -Path $key.Path)) {
                    $issues.Add([PSCustomObject]@{
                        Type        = 'RegistryKeyMissing'
                        Path        = $key.Path
                        Description = "Critical registry key missing: $($key.Path)"
                        Severity    = 'Critical'
                    })
                    continue
                }

                if ($null -ne $key.Property) {
                    $regKey = Get-ItemProperty -Path $key.Path -Name $key.Property -ErrorAction Stop
                }
            }
            catch [System.Management.Automation.ItemNotFoundException] {
                $issues.Add([PSCustomObject]@{
                    Type        = 'RegistryKeyMissing'
                    Path        = $key.Path
                    Description = "Critical registry key missing: $($key.Path)"
                    Severity    = 'Critical'
                })
            }
            catch [System.Management.Automation.PSArgumentException] {
                $issues.Add([PSCustomObject]@{
                    Type        = 'RegistryPropertyMissing'
                    Path        = $key.Path
                    Property    = $key.Property
                    Description = "Registry property '$($key.Property)' missing in $($key.Path)"
                    Severity    = 'High'
                })
            }
            catch {
                Write-Log -Level "WARNING" -Category "System" -Message "Error checking registry key '$($key.Path)': $($_.Exception.Message)"
                $issues.Add([PSCustomObject]@{
                    Type        = 'RegistryError'
                    Path        = $key.Path
                    Description = "Error checking registry key: $($_.Exception.Message)"
                    Severity    = 'Medium'
                })
            }
        }

        return $issues.ToArray()
    }
    catch {
        Write-Log -Level "ERROR" -Category "System" -Message "Registry integrity check failed: $($_.Exception.Message)"
        throw
    }
}

function global:Test-NetworkIntegrity {
    [CmdletBinding()]
    param()

    try {
        $issues = [System.Collections.Generic.List[PSObject]]::new()

        $adapters = Get-NetAdapter -ErrorAction SilentlyContinue
        if ($null -eq $adapters -or ($adapters | Where-Object { $_.Status -eq 'Up' }).Count -eq 0) {
            $issues.Add([PSCustomObject]@{
                Type        = 'NetworkAdapterDown'
                Description = 'No active network adapters found'
                Severity    = 'Critical'
            })
        }
        else {
            $disabledAdapters = $adapters | Where-Object { $_.Status -eq 'Disabled' -and $_.InterfaceDescription -notmatch 'Virtual|Hyper-V|Loopback' }
            foreach ($adapter in $disabledAdapters) {
                $issues.Add([PSCustomObject]@{
                    Type        = 'NetworkAdapterDisabled'
                    Adapter     = $adapter.Name
                    Description = "Network adapter '$($adapter.Name)' is disabled"
                    Severity    = 'Medium'
                })
            }
        }

        try {
            $dnsResult = Resolve-DnsName -Name 'www.microsoft.com' -ErrorAction Stop | Select-Object -First 1
            if ($null -eq $dnsResult) {
                $issues.Add([PSCustomObject]@{
                    Type        = 'DnsResolutionFailed'
                    Description = 'DNS resolution not functioning'
                    Severity    = 'High'
                })
            }
        }
        catch {
            $issues.Add([PSCustomObject]@{
                Type        = 'DnsResolutionFailed'
                Description = "DNS resolution failed: $($_.Exception.Message)"
                Severity    = 'High'
            })
        }

        try {
            $ping = Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction Stop
            if (-not $ping) {
                $issues.Add([PSCustomObject]@{
                    Type        = 'InternetConnectivityLost'
                    Description = 'No internet connectivity detected'
                    Severity    = 'Critical'
                })
            }
        }
        catch {
            $issues.Add([PSCustomObject]@{
                Type        = 'InternetConnectivityError'
                Description = "Connectivity test failed: $($_.Exception.Message)"
                Severity    = 'High'
            })
        }

        return $issues.ToArray()
    }
    catch {
        Write-Log -Level "ERROR" -Category "System" -Message "Network integrity check failed: $($_.Exception.Message)"
        throw
    }
}

function global:Test-FileIntegrity {
    [CmdletBinding()]
    param()

    try {
        $issues = [System.Collections.Generic.List[PSObject]]::new()

        foreach ($file in $script:HealingState.CriticalFiles) {
            try {
                if (-not (Test-Path -Path $file)) {
                    $issues.Add([PSCustomObject]@{
                        Type        = 'CriticalFileMissing'
                        File        = $file
                        Description = "Critical file missing: $file"
                        Severity    = 'Critical'
                    })
                    continue
                }

                $fileInfo = Get-Item -Path $file -ErrorAction Stop
                if ($fileInfo.Length -eq 0 -and $file -match 'hosts') {
                    $issues.Add([PSCustomObject]@{
                        Type        = 'CriticalFileEmpty'
                        File        = $file
                        Description = "Critical file is empty: $file"
                        Severity    = 'High'
                    })
                }
            }
            catch {
                Write-Log -Level "WARNING" -Category "System" -Message "Error checking file '$file': $($_.Exception.Message)"
                $issues.Add([PSCustomObject]@{
                    Type        = 'FileCheckError'
                    File        = $file
                    Description = "Error checking file '$file': $($_.Exception.Message)"
                    Severity    = 'Medium'
                })
            }
        }

        return $issues.ToArray()
    }
    catch {
        Write-Log -Level "ERROR" -Category "System" -Message "File integrity check failed: $($_.Exception.Message)"
        throw
    }
}

function global:Invoke-AutoFix {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSObject]$Issue,

        [Parameter()]
        [switch]$Force
    )

    try {
        $fix = [PSCustomObject]@{
            Issue     = $Issue
            Action    = $null
            Success   = $false
            Error     = $null
            Timestamp = [DateTime]::Now
        }

        switch ($Issue.Type) {
            'ServiceStopped' {
                try {
                    $svc = Get-Service -Name $Issue.Service -ErrorAction Stop
                    if ($svc.StartType -eq 'Disabled') {
                        Set-Service -Name $Issue.Service -StartupType Automatic -ErrorAction Stop
                        Write-Log -Level "INFO" -Category "System" -Message "Set service '$($Issue.Service)' to Automatic startup"
                    }
                    Start-Service -Name $Issue.Service -ErrorAction Stop
                    $fix.Action = "Started service '$($Issue.Service)'"
                    $fix.Success = $true
                    Write-Log -Level "INFO" -Category "System" -Message "Started service '$($Issue.Service)'"
                }
                catch {
                    $fix.Error = $_.Exception.Message
                    Write-Log -Level "WARNING" -Category "System" -Message "Failed to start service '$($Issue.Service)': $($_.Exception.Message)"
                }
            }

            'ServiceDisabled' {
                try {
                    Set-Service -Name $Issue.Service -StartupType Automatic -ErrorAction Stop
                    Start-Service -Name $Issue.Service -ErrorAction Stop
                    $fix.Action = "Enabled and started service '$($Issue.Service)'"
                    $fix.Success = $true
                    Write-Log -Level "INFO" -Category "System" -Message "Enabled and started service '$($Issue.Service)'"
                }
                catch {
                    $fix.Error = $_.Exception.Message
                    Write-Log -Level "WARNING" -Category "System" -Message "Failed to enable service '$($Issue.Service)': $($_.Exception.Message)"
                }
            }

            'NetworkAdapterDisabled' {
                try {
                    if ($Force) {
                        Enable-NetAdapter -Name $Issue.Adapter -ErrorAction Stop
                        $fix.Action = "Enabled network adapter '$($Issue.Adapter)'"
                        $fix.Success = $true
                        Write-Log -Level "INFO" -Category "System" -Message "Enabled network adapter '$($Issue.Adapter)'"
                    }
                    else {
                        $fix.Action = "Skipped (use -Force to enable adapter)"
                        Write-Log -Level "INFO" -Category "System" -Message "Skipping adapter enable, use -Force to enable '$($Issue.Adapter)'"
                    }
                }
                catch {
                    $fix.Error = $_.Exception.Message
                    Write-Log -Level "WARNING" -Category "System" -Message "Failed to enable adapter '$($Issue.Adapter)': $($_.Exception.Message)"
                }
            }

            'CriticalFileMissing' {
                if ($Issue.File -match 'hosts') {
                    try {
                        $defaultHosts = @"
# Copyright (c) 1993-2009 Microsoft Corp.
#
# This is a sample HOSTS file used by Microsoft TCP/IP for Windows.
#
127.0.0.1       localhost
::1             localhost
"@
                        Set-Content -Path $Issue.File -Value $defaultHosts -Force -ErrorAction Stop
                        $fix.Action = "Restored default hosts file"
                        $fix.Success = $true
                        Write-Log -Level "INFO" -Category "System" -Message "Restored default hosts file"
                    }
                    catch {
                        $fix.Error = $_.Exception.Message
                        Write-Log -Level "WARNING" -Category "System" -Message "Failed to restore hosts file: $($_.Exception.Message)"
                    }
                }
                else {
                    $fix.Action = "Cannot auto-fix registry hive files"
                    Write-Log -Level "WARNING" -Category "System" -Message "Cannot auto-fix critical file '$($Issue.File)', manual intervention required"
                }
            }

            'DnsResolutionFailed' {
                try {
                    ipconfig /flushdns | Out-Null
                    $fix.Action = "Flushed DNS cache"
                    $fix.Success = $true
                    Write-Log -Level "INFO" -Category "System" -Message "Flushed DNS cache"
                }
                catch {
                    $fix.Error = $_.Exception.Message
                    Write-Log -Level "WARNING" -Category "System" -Message "Failed to flush DNS: $($_.Exception.Message)"
                }
            }

            default {
                $fix.Action = "No auto-fix available for type '$($Issue.Type)'"
                Write-Log -Level "INFO" -Category "System" -Message "No auto-fix available for issue type '$($Issue.Type)'"
            }
        }

        $script:HealingState.HealingActions.Add($fix)
        return $fix
    }
    catch {
        Write-Log -Level "ERROR" -Category "System" -Message "AutoFix failed: $($_.Exception.Message)"
        $fix.Error = $_.Exception.Message
        $script:HealingState.HealingActions.Add($fix)
        return $fix
    }
}

function global:Get-HealingReport {
    [CmdletBinding()]
    param()

    try {
        $actions = $script:HealingState.HealingActions
        $successful = ($actions | Where-Object { $_.Success -eq $true }).Count
        $failed = ($actions | Where-Object { $_.Success -eq $false }).Count

        return @{
            TotalActions   = $actions.Count
            Successful     = $successful
            Failed         = $failed
            LastRun        = if ($actions.Count -gt 0) { ($actions | Select-Object -Last 1).Timestamp } else { $null }
            RecoveryAttempts = $script:HealingState.RecoveryAttempts.Count
            Actions        = $actions.ToArray()
        }
    }
    catch {
        Write-Log -Level "ERROR" -Category "System" -Message "Error generating healing report: $($_.Exception.Message)"
        return @{
            TotalActions   = 0
            Successful     = 0
            Failed         = 0
            LastRun        = $null
            RecoveryAttempts = 0
            Actions        = @()
        }
    }
}
