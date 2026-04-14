# ParallelEngine.ps1 - Runspace-based parallel processing engine for PS5.1
#Requires -Version 5.1

$script:ParallelJobs = [System.Collections.Generic.List[PSObject]]::new()
$script:RunspacePool = $null
$script:ParallelResults = [System.Collections.Generic.List[PSObject]]::new()
$script:MaxRunspaces = [Environment]::ProcessorCount
$script:MaxConcurrentJobs = 50
$script:ActiveJobCount = 0

function global:Initialize-ParallelEngine {
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$MaxRunspaces = [Environment]::ProcessorCount
    )

    try {
        if ($null -ne $script:RunspacePool) {
            Write-Log -Level "WARNING" -Category "System" -Message "ParallelEngine already initialized, stopping previous instance"
            Stop-ParallelEngine
        }

        $script:MaxRunspaces = $MaxRunspaces
        $script:RunspacePool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1, $MaxRunspaces)
        $script:RunspacePool.Open()

        $script:ParallelJobs = [System.Collections.Generic.List[PSObject]]::new()
        $script:ParallelResults = [System.Collections.Generic.List[PSObject]]::new()

        Write-Log -Level "INFO" -Category "System" -Message "ParallelEngine initialized with $MaxRunspaces max runspaces"
        return $true
    }
    catch {
        Write-Log -Level "ERROR" -Category "System" -Message "Failed to initialize ParallelEngine: $($_.Exception.Message)"
        throw
    }
}

function global:Invoke-ParallelOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [scriptblock[]]$ScriptBlocks,

        [Parameter()]
        [hashtable]$Parameters = @{},

        [Parameter()]
        [int]$TimeoutSeconds = 300,

        [Parameter()]
        [switch]$ReturnOrdered
    )

    try {
        if ($null -eq $script:RunspacePool -or $script:RunspacePool.RunspacePoolStateInfo.State -ne 'Opened') {
            Write-Log -Level "WARNING" -Category "System" -Message "RunspacePool not initialized, initializing now"
            Initialize-ParallelEngine
        }

        # Check max concurrent jobs limit
        if ($script:ActiveJobCount -ge $script:MaxConcurrentJobs) {
            Write-Log -Level "WARNING" -Category "System" -Message "Max concurrent jobs ($($script:MaxConcurrentJobs)) reached, waiting..."
            Start-Sleep -Seconds 2
            if ($script:ActiveJobCount -ge $script:MaxConcurrentJobs) {
                Write-Log -Level "ERROR" -Category "System" -Message "Cannot start new parallel operation: max jobs limit reached"
                return @()
            }
        }

        Write-Log -Level "INFO" -Category "System" -Message "Starting parallel operation with $($ScriptBlocks.Count) scriptblocks"

        $jobs = [System.Collections.Generic.List[PSObject]]::new()

        foreach ($sb in $ScriptBlocks) {
            $ps = [System.Management.Automation.PowerShell]::Create()
            $ps.RunspacePool = $script:RunspacePool

            try {
                $ps.Runspace.SessionStateProxy.SetVariable('scriptRoot', $PSScriptRoot)
            }
            catch {
                Write-Log -Level "DEBUG" -Category "System" -Message "Could not set scriptRoot variable: $($_.Exception.Message)"
            }

            $ps.AddScript($sb) | Out-Null

            foreach ($key in $Parameters.Keys) {
                $ps.AddParameter($key, $Parameters[$key]) | Out-Null
            }

            $handle = $ps.BeginInvoke()
            $job = [PSCustomObject]@{
                PowerShell = $ps
                Handle     = $handle
                StartTime  = [DateTime]::Now
                Completed  = $false
                Error      = $null
            }
            $jobs.Add($job)
            $script:ParallelJobs.Add($job)
            $script:ActiveJobCount++
        }

        $deadline = [DateTime]::Now.AddSeconds($TimeoutSeconds)
        $results = [System.Collections.Generic.List[PSObject]]::new()

        while ($jobs.Where({ -not $_.Completed }).Count -gt 0) {
            if ([DateTime]::Now -gt $deadline) {
                Write-Log -Level "WARNING" -Category "System" -Message "Parallel operation timed out after $TimeoutSeconds seconds"
                foreach ($job in $jobs.Where({ -not $_.Completed })) {
                    try {
                        $job.PowerShell.Stop()
                    }
                    catch {
                        Write-Log -Level "WARNING" -Category "System" -Message "Error stopping job: $($_.Exception.Message)"
                    }
                }
                break
            }

            foreach ($job in $jobs.Where({ -not $_.Completed })) {
                if ($job.Handle.IsCompleted) {
                    try {
                        $jobResult = $job.PowerShell.EndInvoke($job.Handle)
                        $results.Add($jobResult)
                        $job.Completed = $true

                        if ($job.PowerShell.HadErrors) {
                            foreach ($err in $job.PowerShell.Streams.Error) {
                                Write-Log -Level "WARNING" -Category "System" -Message "Job error: $($err.ToString())"
                            }
                        }
                    }
                    catch {
                        $job.Error = $_.Exception
                        $job.Completed = $true
                        $results.Add([PSCustomObject]@{ Error = $_.Exception.Message })
                        Write-Log -Level "ERROR" -Category "System" -Message "Error collecting job result: $($_.Exception.Message)"
                    }
                    finally {
                        $script:ActiveJobCount = [Math]::Max(0, $script:ActiveJobCount - 1)
                        try { $job.PowerShell.Dispose() } catch { Write-Log -Level "DEBUG" -Category "System" -Message "Dispose error: $($_.Exception.Message)" }
                    }
                }
            }

            Start-Sleep -Milliseconds 50
        }

        Write-Log -Level "INFO" -Category "System" -Message "Parallel operation completed, $($results.Count) results collected"

        if ($ReturnOrdered) {
            return $results.ToArray()
        }
        return $results.ToArray()
    }
    catch {
        Write-Log -Level "ERROR" -Category "System" -Message "Parallel operation failed: $($_.Exception.Message)"
        throw
    }
}

function global:Start-ParallelJob {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [scriptblock]$ScriptBlock,

        [Parameter()]
        [hashtable]$Parameters = @{}
    )

    try {
        if ($null -eq $script:RunspacePool -or $script:RunspacePool.RunspacePoolStateInfo.State -ne 'Opened') {
            Write-Log -Level "WARNING" -Category "System" -Message "RunspacePool not initialized, initializing now"
            Initialize-ParallelEngine
        }

        $ps = [System.Management.Automation.PowerShell]::Create()
        $ps.RunspacePool = $script:RunspacePool

        try {
            $ps.Runspace.SessionStateProxy.SetVariable('scriptRoot', $PSScriptRoot)
        }
        catch {
            Write-Log -Level "DEBUG" -Category "System" -Message "Could not set scriptRoot variable: $($_.Exception.Message)"
        }

        $ps.AddScript($ScriptBlock) | Out-Null

        foreach ($key in $Parameters.Keys) {
            $ps.AddParameter($key, $Parameters[$key]) | Out-Null
        }

        $handle = $ps.BeginInvoke()
        $job = [PSCustomObject]@{
            PowerShell = $ps
            Handle     = $handle
            StartTime  = [DateTime]::Now
            Completed  = $false
            Error      = $null
        }
        $script:ParallelJobs.Add($job)

        Write-Log -Level "DEBUG" -Category "System" -Message "Parallel job started"
        return $job
    }
    catch {
        Write-Log -Level "ERROR" -Category "System" -Message "Failed to start parallel job: $($_.Exception.Message)"
        throw
    }
}

function global:Wait-ParallelJobs {
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$TimeoutSeconds = 300,

        [Parameter()]
        [switch]$AllJobs
    )

    try {
        if ($AllJobs -or $script:ParallelJobs.Count -eq 0) {
            Write-Log -Level "DEBUG" -Category "System" -Message "No jobs to wait for or waiting for all jobs in pool"
            return $true
        }

        $deadline = [DateTime]::Now.AddSeconds($TimeoutSeconds)
        $pendingJobs = $script:ParallelJobs.Where({ -not $_.Completed })

        if ($pendingJobs.Count -eq 0) {
            Write-Log -Level "DEBUG" -Category "System" -Message "All jobs already completed"
            return $true
        }

        Write-Log -Level "INFO" -Category "System" -Message "Waiting for $($pendingJobs.Count) pending jobs (timeout: ${TimeoutSeconds}s)"

        while ($pendingJobs.Where({ -not $_.Completed }).Count -gt 0) {
            if ([DateTime]::Now -gt $deadline) {
                Write-Log -Level "WARNING" -Category "System" -Message "Wait timed out after $TimeoutSeconds seconds, $($pendingJobs.Where({ -not $_.Completed }).Count) jobs still running"
                return $false
            }

            foreach ($job in $pendingJobs.Where({ -not $_.Completed })) {
                if ($job.Handle.IsCompleted) {
                    $job.Completed = $true
                }
            }

            Start-Sleep -Milliseconds 100
        }

        Write-Log -Level "INFO" -Category "System" -Message "All jobs completed"
        return $true
    }
    catch {
        Write-Log -Level "ERROR" -Category "System" -Message "Error waiting for jobs: $($_.Exception.Message)"
        throw
    }
}

function global:Get-ParallelResults {
    [CmdletBinding()]
    param()

    try {
        $results = [System.Collections.Generic.List[PSObject]]::new()

        foreach ($job in $script:ParallelJobs) {
            if ($job.Handle.IsCompleted -or $job.Completed) {
                try {
                    if (-not $job.Completed) {
                        $result = $job.PowerShell.EndInvoke($job.Handle)
                        $results.Add($result)
                        $job.Completed = $true

                        if ($job.PowerShell.HadErrors) {
                            foreach ($err in $job.PowerShell.Streams.Error) {
                                Write-Log -Level "WARNING" -Category "System" -Message "Job completed with error: $($err.ToString())"
                            }
                        }
                    }
                }
                catch {
                    $results.Add([PSCustomObject]@{ Error = $_.Exception.Message })
                    Write-Log -Level "ERROR" -Category "System" -Message "Error collecting result: $($_.Exception.Message)"
                }
                finally {
                    try { $job.PowerShell.Dispose() } catch { Write-Log -Level "DEBUG" -Category "System" -Message "Dispose error: $($_.Exception.Message)" }
                }
            }
        }

        Write-Log -Level "DEBUG" -Category "System" -Message "Collected $($results.Count) results from completed jobs"
        return $results.ToArray()
    }
    catch {
        Write-Log -Level "ERROR" -Category "System" -Message "Error getting parallel results: $($_.Exception.Message)"
        throw
    }
}

function global:Stop-ParallelEngine {
    [CmdletBinding()]
    param()

    try {
        $activeCount = 0
        foreach ($job in $script:ParallelJobs) {
            if (-not $job.Completed) {
                try {
                    $job.PowerShell.Stop()
                    $activeCount++
                }
                catch {
                    Write-Log -Level "WARNING" -Category "System" -Message "Error stopping job: $($_.Exception.Message)"
                }
            }

            try {
                $job.PowerShell.Dispose()
            }
            catch {
                Write-Log -Level "DEBUG" -Category "System" -Message "Error disposing job PowerShell: $($_.Exception.Message)"
            }
        }

        if ($null -ne $script:RunspacePool) {
            $script:RunspacePool.Close()
            $script:RunspacePool.Dispose()
            $script:RunspacePool = $null
        }

        $script:ParallelJobs = [System.Collections.Generic.List[PSObject]]::new()
        $script:ParallelResults = [System.Collections.Generic.List[PSObject]]::new()

        Write-Log -Level "INFO" -Category "System" -Message "ParallelEngine stopped, $activeCount active jobs cleaned up"
        return $true
    }
    catch {
        Write-Log -Level "ERROR" -Category "System" -Message "Error stopping ParallelEngine: $($_.Exception.Message)"
        throw
    }
}

function global:Get-ParallelStatus {
    [CmdletBinding()]
    param()

    try {
        $running = 0
        $completed = 0
        $failed = 0
        $total = $script:ParallelJobs.Count

        foreach ($job in $script:ParallelJobs) {
            if ($job.Completed) {
                if ($null -ne $job.Error) {
                    $failed++
                }
                else {
                    $completed++
                }
            }
            else {
                $running++
            }
        }

        return @{
            Running   = $running
            Completed = $completed
            Failed    = $failed
            Total     = $total
        }
    }
    catch {
        Write-Log -Level "ERROR" -Category "System" -Message "Error getting parallel status: $($_.Exception.Message)"
        return @{
            Running   = 0
            Completed = 0
            Failed    = 0
            Total     = 0
        }
    }
}
