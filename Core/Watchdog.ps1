#Requires -Version 5.1

$script:WatchdogTimer = $null
$script:WatchdogStatePath = ""
$script:WatchdogInterval = 60
$script:WatchdogRunning = $false
$script:DriftHistory = @()
$script:WatchedSettings = @{
    Services   = @()
    Registry   = @()
    Startup    = @()
    Network    = @()
    Privacy    = @()
    PowerPlan  = ""
    DNS        = @()
}

function global:Initialize-Watchdog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DataDirectory
    )

    $script:WatchdogStatePath = Join-Path $DataDirectory "watchdog_state.json"

    if (Test-Path $script:WatchdogStatePath) {
        try {
            $json = Get-Content -Path $script:WatchdogStatePath -Raw -Encoding UTF8
            $loaded = $json | ConvertFrom-Json

            if ($loaded.PSObject.Properties["WatchedSettings"]) {
                $script:WatchedSettings = @{}
                $ws = $loaded.WatchedSettings
                $script:WatchedSettings.Services   = @($ws.Services)
                $script:WatchedSettings.Registry   = @($ws.Registry)
                $script:WatchedSettings.Startup    = @($ws.Startup)
                $script:WatchedSettings.Network    = @($ws.Network)
                $script:WatchedSettings.Privacy    = @($ws.Privacy)
                $script:WatchedSettings.PowerPlan  = if ($ws.PowerPlan) { $ws.PowerPlan } else { "" }
                $script:WatchedSettings.DNS        = @($ws.DNS)
            }

            if ($loaded.PSObject.Properties["WatchdogInterval"]) {
                $script:WatchdogInterval = [int]$loaded.WatchdogInterval
            }

            if ($loaded.PSObject.Properties["DriftHistory"]) {
                $script:DriftHistory = @($loaded.DriftHistory)
            }

            Write-Log -Level "INFO" -Category "System" -Message "Watchdog state loaded from $script:WatchdogStatePath"
        }
        catch {
            Write-Log -Level "WARNING" -Category "System" -Message "Failed to load watchdog state: $($_.Exception.Message)"
        }
    }
    else {
        Write-Log -Level "INFO" -Category "System" -Message "No existing watchdog state found, starting fresh"
    }
}

function global:Start-Watchdog {
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$IntervalSeconds = 0
    )

    if ($script:WatchdogRunning) {
        Write-Log -Level "WARNING" -Category "System" -Message "Watchdog is already running"
        return $false
    }

    if (-not (Test-IsAdmin)) {
        Write-Log -Level "ERROR" -Category "System" -Message "Administrator privileges required to start watchdog"
        return $false
    }

    if ($IntervalSeconds -gt 0) {
        $script:WatchdogInterval = $IntervalSeconds
    }

    try {
        $script:WatchdogTimer = New-Object System.Timers.Timer
        $script:WatchdogTimer.Interval = ($script:WatchdogInterval * 1000)
        $script:WatchdogTimer.AutoReset = $true

        $action = {
            try {
                $drifts = Test-SettingsDrift
                if ($drifts.Count -gt 0) {
                    Invoke-SettingsReapply -Drifts $drifts
                }
            }
            catch {
                Write-Log -Level "ERROR" -Category "System" -Message "Watchdog tick error: $($_.Exception.Message)"
            }
        }

        Register-ObjectEvent -InputObject $script:WatchdogTimer -EventName "Elapsed" -Action $action | Out-Null
        $script:WatchdogTimer.Start()
        $script:WatchdogRunning = $true

        Write-Log -Level "SUCCESS" -Category "System" -Message "Watchdog started with $($script:WatchdogInterval)s interval"
        return $true
    }
    catch {
        Write-Log -Level "ERROR" -Category "System" -Message "Failed to start watchdog: $($_.Exception.Message)"
        return $false
    }
}

function global:Stop-Watchdog {
    [CmdletBinding()]
    param()

    if (-not $script:WatchdogRunning) {
        Write-Log -Level "WARNING" -Category "System" -Message "Watchdog is not running"
        return $false
    }

    try {
        if ($null -ne $script:WatchdogTimer) {
            $script:WatchdogTimer.Stop()
            $script:WatchdogTimer.Dispose()
            $script:WatchdogTimer = $null
        }

        Get-EventSubscriber | Where-Object { $_.SourceObject -is [System.Timers.Timer] } | Unregister-Event -ErrorAction SilentlyContinue

        $script:WatchdogRunning = $false

        Save-WatchdogState

        Write-Log -Level "SUCCESS" -Category "System" -Message "Watchdog stopped"
        return $true
    }
    catch {
        Write-Log -Level "ERROR" -Category "System" -Message "Failed to stop watchdog: $($_.Exception.Message)"
        return $false
    }
}

function global:Test-SettingsDrift {
    [CmdletBinding()]
    param()

    $drifts = @()

    foreach ($svcEntry in $script:WatchedSettings.Services) {
        try {
            $parts = $svcEntry -split ":"
            $svcName = $parts[0]
            $expectedStartup = $parts[1]

            $service = Get-Service -Name $svcName -ErrorAction SilentlyContinue
            if ($null -ne $service) {
                if ($service.StartType.ToString() -ne $expectedStartup) {
                    $drifts += [PSCustomObject]@{
                        Type     = "Service"
                        Target   = $svcName
                        Expected = $expectedStartup
                        Actual   = $service.StartType.ToString()
                        Time     = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                    }
                }
            }
        }
        catch {
            Write-Log -Level "WARNING" -Category "System" -Message "Error checking service drift for $svcEntry : $($_.Exception.Message)"
        }
    }

    foreach ($regEntry in $script:WatchedSettings.Registry) {
        try {
            $parts = $regEntry -split "\|"
            $regPath = $parts[0]
            $regName = $parts[1]
            $expectedValue = $parts[2]

            if (Test-Path $regPath) {
                $prop = Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue
                if ($null -ne $prop) {
                    $actualValue = $prop.$regName
                    if ($actualValue.ToString() -ne $expectedValue) {
                        $drifts += [PSCustomObject]@{
                            Type     = "Registry"
                            Target   = "$regPath\$regName"
                            Expected = $expectedValue
                            Actual   = $actualValue.ToString()
                            Time     = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                        }
                    }
                }
            }
        }
        catch {
            Write-Log -Level "WARNING" -Category "System" -Message "Error checking registry drift for $regEntry : $($_.Exception.Message)"
        }
    }

    foreach ($startupEntry in $script:WatchedSettings.Startup) {
        try {
            $parts = $startupEntry -split ":"
            $itemName = $parts[0]
            $expectedState = $parts[1]

            $regRunPaths = @(
                "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
                "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
            )

            $found = $false
            foreach ($runPath in $regRunPaths) {
                if (Test-Path $runPath) {
                    $prop = Get-ItemProperty -Path $runPath -Name $itemName -ErrorAction SilentlyContinue
                    if ($null -ne $prop) {
                        $found = $true
                        break
                    }
                }
            }

            if ($expectedState -eq "Disabled" -and $found) {
                $drifts += [PSCustomObject]@{
                    Type     = "Startup"
                    Target   = $itemName
                    Expected = $expectedState
                    Actual   = "Enabled"
                    Time     = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                }
            }
        }
        catch {
            Write-Log -Level "WARNING" -Category "System" -Message "Error checking startup drift for $itemName : $($_.Exception.Message)"
        }
    }

    foreach ($netEntry in $script:WatchedSettings.Network) {
        try {
            $parts = $netEntry -split "\|"
            $settingName = $parts[0]
            $expectedValue = $parts[1]

            if ($settingName -eq "TCP_AutoTuning") {
                $actual = netsh interface tcp show global 2>&1 | Select-String "Receive Window Auto-Tuning Level"
                if ($actual -and $actual.ToString() -notmatch $expectedValue) {
                    $drifts += [PSCustomObject]@{
                        Type     = "Network"
                        Target   = $settingName
                        Expected = $expectedValue
                        Actual   = $actual.ToString().Trim()
                        Time     = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                    }
                }
            }
            elseif ($settingName -eq "Nagle_Algorithm") {
                $interfaces = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" -ErrorAction SilentlyContinue
                foreach ($iface in $interfaces) {
                    $actual = Get-ItemProperty -Path $iface.PSPath -Name "TcpAckFrequency" -ErrorAction SilentlyContinue
                    if ($null -ne $actual -and $actual.TcpAckFrequency.ToString() -ne $expectedValue) {
                        $drifts += [PSCustomObject]@{
                            Type     = "Network"
                            Target   = "$settingName\$($iface.PSChildName)"
                            Expected = $expectedValue
                            Actual   = $actual.TcpAckFrequency.ToString()
                            Time     = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                        }
                    }
                }
            }
        }
        catch {
            Write-Log -Level "WARNING" -Category "System" -Message "Error checking network drift for $netEntry : $($_.Exception.Message)"
        }
    }

    foreach ($privEntry in $script:WatchedSettings.Privacy) {
        try {
            $parts = $privEntry -split "\|"
            $regPath = $parts[0]
            $regName = $parts[1]
            $expectedValue = $parts[2]

            if (Test-Path $regPath) {
                $prop = Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue
                if ($null -ne $prop) {
                    if ($prop.$regName.ToString() -ne $expectedValue) {
                        $drifts += [PSCustomObject]@{
                            Type     = "Privacy"
                            Target   = "$regPath\$regName"
                            Expected = $expectedValue
                            Actual   = $prop.$regName.ToString()
                            Time     = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                        }
                    }
                }
            }
        }
        catch {
            Write-Log -Level "WARNING" -Category "System" -Message "Error checking privacy drift for $privEntry : $($_.Exception.Message)"
        }
    }

    if ($script:WatchedSettings.PowerPlan -ne "") {
        try {
            $activePlan = powercfg /getactivescheme 2>&1
            if ($activePlan -match '\(([^\)]+)\)') {
                $actualPlan = $Matches[1]
                if ($actualPlan -ne $script:WatchedSettings.PowerPlan) {
                    $drifts += [PSCustomObject]@{
                        Type     = "PowerPlan"
                        Target   = "ActivePowerPlan"
                        Expected = $script:WatchedSettings.PowerPlan
                        Actual   = $actualPlan
                        Time     = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                    }
                }
            }
        }
        catch {
            Write-Log -Level "WARNING" -Category "System" -Message "Error checking power plan drift: $($_.Exception.Message)"
        }
    }

    foreach ($dnsEntry in $script:WatchedSettings.DNS) {
        try {
            $parts = $dnsEntry -split ":"
            $adapterName = $parts[0]
            $expectedDNS = $parts[1]

            $adapters = Get-DnsClientServerAddress -InterfaceAlias $adapterName -ErrorAction SilentlyContinue
            if ($null -ne $adapters) {
                $actualDNS = ($adapters.ServerAddresses -join ",")
                if ($actualDNS -ne $expectedDNS) {
                    $drifts += [PSCustomObject]@{
                        Type     = "DNS"
                        Target   = $adapterName
                        Expected = $expectedDNS
                        Actual   = $actualDNS
                        Time     = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                    }
                }
            }
        }
        catch {
            Write-Log -Level "WARNING" -Category "System" -Message "Error checking DNS drift for $adapterName : $($_.Exception.Message)"
        }
    }

    if ($drifts.Count -gt 0) {
        Write-Log -Level "WARNING" -Category "System" -Message "Settings drift detected: $($drifts.Count) item(s)"
    }

    return $drifts
}

function global:Invoke-SettingsReapply {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$Drifts
    )

    $results = @{
        Total   = $Drifts.Count
        Fixed   = 0
        Failed  = 0
        Details = @()
    }

    foreach ($drift in $Drifts) {
        $fixed = $false
        $errorMsg = ""

        try {
            switch ($drift.Type) {
                "Service" {
                    $targetStartup = $drift.Expected
                    if ($targetStartup -in @("Automatic", "Manual", "Disabled")) {
                        Set-Service -Name $drift.Target -StartupType $targetStartup -ErrorAction Stop
                        $fixed = $true
                    }
                }
                "Registry" {
                    $regParts = $drift.Target -split "\\"
                    $regName = $regParts[-1]
                    $regPath = $drift.Target.Substring(0, $drift.Target.LastIndexOf("\"))
                    $regPath = $regPath -replace "HKEY_LOCAL_MACHINE\\", "HKLM:\" -replace "HKEY_CURRENT_USER\\", "HKCU:"

                    $valueType = "DWord"
                    $setValue = $drift.Expected
                    if ($drift.Expected -match "^[a-fA-F0-9-]{36}$") {
                        $valueType = "String"
                    }

                    Set-ItemProperty -Path $regPath -Name $regName -Value $setValue -Type $valueType -Force -ErrorAction Stop
                    $fixed = $true
                }
                "Startup" {
                    $regRunPaths = @(
                        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
                        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
                    )
                    foreach ($runPath in $regRunPaths) {
                        if (Test-Path $runPath) {
                            $prop = Get-ItemProperty -Path $runPath -Name $drift.Target -ErrorAction SilentlyContinue
                            if ($null -ne $prop) {
                                Remove-ItemProperty -Path $runPath -Name $drift.Target -Force -ErrorAction Stop
                                $fixed = $true
                                break
                            }
                        }
                    }
                }
                "Network" {
                    if ($drift.Target -match "TCP_AutoTuning") {
                        netsh interface tcp set global autotuninglevel=normal 2>&1 | Out-Null
                        $fixed = $true
                    }
                }
                "Privacy" {
                    $regParts = $drift.Target -split "\\"
                    $regName = $regParts[-1]
                    $regPath = $drift.Target.Substring(0, $drift.Target.LastIndexOf("\"))
                    $regPath = $regPath -replace "HKEY_LOCAL_MACHINE\\", "HKLM:\" -replace "HKEY_CURRENT_USER\\", "HKCU:"

                    Set-ItemProperty -Path $regPath -Name $regName -Value $drift.Expected -Type DWord -Force -ErrorAction Stop
                    $fixed = $true
                }
                "PowerPlan" {
                    $plans = powercfg /list 2>&1
                    $matchLines = $plans | Select-String "\($([regex]::Escape($drift.Expected))\)"
                    if ($matchLines -and $matchLines.ToString() -match '([a-f0-9-]{36})') {
                        powercfg /setactive $Matches[1] 2>&1 | Out-Null
                        $fixed = $true
                    }
                }
                "DNS" {
                    Set-DnsClientServerAddress -InterfaceAlias $drift.Target -ServerAddresses ($drift.Expected -split ",") -ErrorAction Stop
                    $fixed = $true
                }
            }
        }
        catch {
            $errorMsg = $_.Exception.Message
            Write-Log -Level "ERROR" -Category "System" -Message "Failed to reapply $($drift.Type) setting $($drift.Target): $errorMsg"
        }

        $historyEntry = [PSCustomObject]@{
            Type      = $drift.Type
            Target    = $drift.Target
            Expected  = $drift.Expected
            Actual    = $drift.Actual
            Fixed     = $fixed
            Error     = $errorMsg
            Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }

        $script:DriftHistory += $historyEntry

        if ($fixed) {
            $results.Fixed++
            Write-Log -Level "SUCCESS" -Category "System" -Message "Reapplied $($drift.Type) setting: $($drift.Target)"
        }
        else {
            $results.Failed++
        }

        $results.Details += $historyEntry
    }

    Save-WatchdogState

    Write-Log -Level "INFO" -Category "System" -Message "Settings reapply complete: $($results.Fixed) fixed, $($results.Failed) failed out of $($results.Total)"

    return $results
}

function global:Get-WatchdogStatus {
    [CmdletBinding()]
    param()

    $status = [PSCustomObject]@{
        Running          = $script:WatchdogRunning
        IntervalSeconds  = $script:WatchdogInterval
        TimerEnabled     = if ($null -ne $script:WatchdogTimer) { $script:WatchdogTimer.Enabled } else { $false }
        WatchedServices  = $script:WatchedSettings.Services.Count
        WatchedRegistry  = $script:WatchedSettings.Registry.Count
        WatchedStartup   = $script:WatchedSettings.Startup.Count
        WatchedNetwork   = $script:WatchedSettings.Network.Count
        WatchedPrivacy   = $script:WatchedSettings.Privacy.Count
        WatchedPowerPlan = if ($script:WatchedSettings.PowerPlan -ne "") { $true } else { $false }
        WatchedDNS       = $script:WatchedSettings.DNS.Count
        DriftsDetected   = $script:DriftHistory.Count
        StateFilePath    = $script:WatchdogStatePath
    }

    return $status
}

function global:Set-WatchdogInterval {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateRange(10, 3600)]
        [int]$Seconds
    )

    $script:WatchdogInterval = $Seconds

    if ($null -ne $script:WatchdogTimer) {
        $script:WatchdogTimer.Interval = ($Seconds * 1000)
    }

    Save-WatchdogState

    Write-Log -Level "SUCCESS" -Category "System" -Message "Watchdog interval set to $Seconds seconds"
    return $true
}

function global:Get-DriftHistory {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet("Service", "Registry", "Startup", "Network", "Privacy", "PowerPlan", "DNS", "")]
        [string]$Type = "",

        [Parameter()]
        [int]$Last = 0
    )

    $history = $script:DriftHistory

    if ($Type -ne "") {
        $history = @($history | Where-Object { $_.Type -eq $Type })
    }

    if ($Last -gt 0 -and $history.Count -gt $Last) {
        $history = @($history[($history.Count - $Last)..($history.Count - 1)])
    }

    return $history
}

function global:Watch-Service {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServiceName,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Automatic", "Manual", "Disabled")]
        [string]$ExpectedStartup
    )

    $entry = "${ServiceName}:${ExpectedStartup}"
    if ($entry -notin $script:WatchedSettings.Services) {
        $script:WatchedSettings.Services += $entry
        Save-WatchdogState
        Write-Log -Level "SUCCESS" -Category "System" -Message "Now watching service $ServiceName (expected: $ExpectedStartup)"
    }
}

function global:Watch-RegistryValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedValue
    )

    $entry = "${Path}|${Name}|${ExpectedValue}"
    if ($entry -notin $script:WatchedSettings.Registry) {
        $script:WatchedSettings.Registry += $entry
        Save-WatchdogState
        Write-Log -Level "SUCCESS" -Category "System" -Message "Now watching registry $Path\$Name (expected: $ExpectedValue)"
    }
}

function global:Watch-StartupItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ItemName,

        [Parameter()]
        [string]$ExpectedState = "Disabled"
    )

    $entry = "${ItemName}:${ExpectedState}"
    if ($entry -notin $script:WatchedSettings.Startup) {
        $script:WatchedSettings.Startup += $entry
        Save-WatchdogState
        Write-Log -Level "SUCCESS" -Category "System" -Message "Now watching startup item $ItemName (expected: $ExpectedState)"
    }
}

function global:Watch-DNSSetting {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AdapterName,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedDNS
    )

    $entry = "${AdapterName}:${ExpectedDNS}"
    if ($entry -notin $script:WatchedSettings.DNS) {
        $script:WatchedSettings.DNS += $entry
        Save-WatchdogState
        Write-Log -Level "SUCCESS" -Category "System" -Message "Now watching DNS on $AdapterName (expected: $ExpectedDNS)"
    }
}

function global:Watch-PowerPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExpectedPlanName
    )

    $script:WatchedSettings.PowerPlan = $ExpectedPlanName
    Save-WatchdogState
    Write-Log -Level "SUCCESS" -Category "System" -Message "Now watching power plan (expected: $ExpectedPlanName)"
}

function global:Watch-PrivacySetting {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RegistryPath,

        [Parameter(Mandatory = $true)]
        [string]$RegistryName,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedValue
    )

    $entry = "${RegistryPath}|${RegistryName}|${ExpectedValue}"
    if ($entry -notin $script:WatchedSettings.Privacy) {
        $script:WatchedSettings.Privacy += $entry
        Save-WatchdogState
        Write-Log -Level "SUCCESS" -Category "System" -Message "Now watching privacy setting $RegistryPath\$RegistryName (expected: $ExpectedValue)"
    }
}

function global:Watch-NetworkSetting {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SettingName,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedValue
    )

    $entry = "${SettingName}|${ExpectedValue}"
    if ($entry -notin $script:WatchedSettings.Network) {
        $script:WatchedSettings.Network += $entry
        Save-WatchdogState
        Write-Log -Level "SUCCESS" -Category "System" -Message "Now watching network setting $SettingName (expected: $ExpectedValue)"
    }
}

function global:Remove-WatchedItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Service", "Registry", "Startup", "Network", "Privacy", "DNS", "PowerPlan")]
        [string]$Type,

        [Parameter()]
        [string]$Target = ""
    )

    switch ($Type) {
        "Service" {
            $script:WatchedSettings.Services = @($script:WatchedSettings.Services | Where-Object { $_ -notlike "$Target*" })
        }
        "Registry" {
            if ($Target -eq "") {
                $script:WatchedSettings.Registry = @()
            }
            else {
                $script:WatchedSettings.Registry = @($script:WatchedSettings.Registry | Where-Object { $_ -notlike "$Target*" })
            }
        }
        "Startup" {
            $script:WatchedSettings.Startup = @($script:WatchedSettings.Startup | Where-Object { $_ -notlike "$Target*" })
        }
        "Network" {
            $script:WatchedSettings.Network = @($script:WatchedSettings.Network | Where-Object { $_ -notlike "$Target*" })
        }
        "Privacy" {
            if ($Target -eq "") {
                $script:WatchedSettings.Privacy = @()
            }
            else {
                $script:WatchedSettings.Privacy = @($script:WatchedSettings.Privacy | Where-Object { $_ -notlike "$Target*" })
            }
        }
        "DNS" {
            $script:WatchedSettings.DNS = @($script:WatchedSettings.DNS | Where-Object { $_ -notlike "$Target*" })
        }
        "PowerPlan" {
            $script:WatchedSettings.PowerPlan = ""
        }
    }

    Save-WatchdogState
    Write-Log -Level "INFO" -Category "System" -Message "Removed watched item: $Type $Target"
}

function global:Clear-WatchdogState {
    [CmdletBinding()]
    param()

    $script:WatchedSettings = @{
        Services   = @()
        Registry   = @()
        Startup    = @()
        Network    = @()
        Privacy    = @()
        PowerPlan  = ""
        DNS        = @()
    }

    $script:DriftHistory = @()

    Save-WatchdogState
    Write-Log -Level "INFO" -Category "System" -Message "All watchdog state cleared"
}

function global:Save-WatchdogState {
    [CmdletBinding()]
    param()

    if ($script:WatchdogStatePath -eq "") {
        Write-Log -Level "WARNING" -Category "System" -Message "Watchdog state path not set, cannot save"
        return $false
    }

    try {
        $parentDir = Split-Path $script:WatchdogStatePath -Parent
        if (-not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }

        $state = [PSCustomObject]@{
            WatchedSettings = $script:WatchedSettings
            WatchdogInterval = $script:WatchdogInterval
            DriftHistory = $script:DriftHistory
            LastSaved = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }

        $json = $state | ConvertTo-Json -Depth 10
        $json | Out-File -FilePath $script:WatchdogStatePath -Encoding UTF8 -Force

        return $true
    }
    catch {
        Write-Log -Level "ERROR" -Category "System" -Message "Failed to save watchdog state: $($_.Exception.Message)"
        return $false
    }
}
