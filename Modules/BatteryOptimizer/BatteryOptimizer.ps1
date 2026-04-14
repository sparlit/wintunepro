# WinTune Pro - Battery Optimizer Module
# PowerShell 5.1+ Compatible

function global:Get-BatteryStatus {
    $status = @{
        HasBattery = $false
        Percent = 0
        Charging = $false
        Health = 100
        Cycles = 0
        TimeRemaining = ""
    }

    try {
        $battery = Get-WmiObject -Class Win32_Battery -ErrorAction SilentlyContinue
        if ($battery) {
            $status.HasBattery = $true
            $status.Percent = $battery.EstimatedChargeRemaining
            $status.Charging = ($battery.BatteryStatus -in @(2, 6, 7, 8, 9))
            if ($battery.EstimatedChargeRemaining -gt 0) {
                $status.TimeRemaining = "$($battery.EstimatedChargeRemaining)%"
            }
        }
    } catch {
        Write-Log -Level "WARNING" -Category "Battery" -Message "Error getting battery status: $($_.Exception.Message)"
    }

    return $status
}

function global:Get-PowerPlans {
    $plans = @()

    try {
        $output = powercfg /list
        $output | Select-String -Pattern "([a-f0-9-]{36})\s+(.+)" | ForEach-Object {
            $guid = $_.Matches.Groups[1].Value
            $name = $_.Matches.Groups[2].Value.Trim()
            $isActive = $_.Line -match "\*"
            $plans += @{
                GUID = $guid
                Name = $name
                IsActive = $isActive
            }
        }
    } catch {
        Write-Log -Level "WARNING" -Category "Battery" -Message "Error getting power plans: $($_.Exception.Message)"
    }

    return $plans
}

function global:Invoke-BatteryOptimization {
    param(
        [string]$Mode = "Balanced",
        [bool]$TestMode = $false
    )

    $results = @{
        Actions = @()
        Success = $true
    }

    if ($TestMode) {
        $results.Actions += "Test Mode: Would optimize battery"
        return $results
    }

    switch ($Mode) {
        "Battery" {
            $guid = "a1841308-3541-4fab-bc81-f71556f20b4a"
            $results.Actions += "Set Power Saver plan"
        }
        "Performance" {
            $guid = "e9a42b02-d5df-448d-aa00-03f14749eb61"
            $plans = Get-PowerPlans
            if ($plans | Where-Object { $_.GUID -eq $guid }) {
                $results.Actions += "Set Ultimate Performance plan"
            } else {
                $guid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8486b7"
                $results.Actions += "Set High Performance plan"
            }
        }
        default {
            $guid = "381b4222-f694-41f0-9685-ff5bb260df2e"
            $results.Actions += "Set Balanced plan"
        }
    }

    try {
        powercfg /setactive $guid
        Log-Success "Applied $Mode power optimization" -Category "Battery"
    } catch {
        $results.Actions += "Failed to set power plan"
    }

    if ($Mode -eq "Battery") {
        try {
            powercfg /change monitor-timeout-ac 5
            powercfg /change monitor-timeout-dc 2
            $results.Actions += "Reduced display timeout"
            powercfg /change standby-timeout-dc 10
            $results.Actions += "Reduced sleep timeout"
        } catch {
            Write-Log -Level "WARNING" -Category "Battery" -Message "Error setting timeouts: $($_.Exception.Message)"
        }
    }

    return $results
}

function global:New-BatteryReport {
    param([string]$OutputPath = "")

    if ([string]::IsNullOrEmpty($OutputPath)) {
        $OutputPath = Join-Path (Get-ConfigValue "ReportsPath") "battery-report.html"
    }

    try {
        powercfg /batteryreport /output $OutputPath
        Log-Success "Generated battery report at $OutputPath" -Category "Battery"
        return $OutputPath
    } catch {
        Log-Error "Failed to generate battery report: $($_.Exception.Message)" -Category "Battery"
        return $null
    }
}

function global:Enable-BatterySaver {
    param([bool]$Enable = $true)

    try {
        if ($Enable) {
            powercfg /setdcvalueindex SCHEME_CURRENT SUB_VIDEO VIDEOADAPT 1
            powercfg /setactive SCHEME_CURRENT
            Log-Success "Enabled battery saver settings" -Category "Battery"
            return $true
        }
    } catch {
        Log-Error "Failed to enable battery saver: $($_.Exception.Message)" -Category "Battery"
    }

    return $false
}

