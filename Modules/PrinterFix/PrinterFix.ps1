# WinTune Pro - Printer Fix Module
# PowerShell 5.1+ Compatible
# Fixes common printer errors including error 0x00000709
# Extracted and adapted from PrinterFix v4.4 by Simon Peter

$global:PrinterFixStop    = $false
$global:PrinterFixPause   = $false
$global:PrinterFixLogFile = "$env:SystemRoot\Temp\PrinterFix.log"

$global:PrinterFixTasks = @(
    @{ Name = "Stopping Print Spooler and dependent services"; Action = {
        Stop-Service "PrintNotify" -Force -ErrorAction SilentlyContinue
        Stop-Service "Fax"         -Force -ErrorAction SilentlyContinue
        Stop-Service "LPDSVC"      -Force -ErrorAction SilentlyContinue
        Stop-Service spooler       -Force -ErrorAction SilentlyContinue
        return $true
    }},
    @{ Name = "Clearing all print job queues and driver caches"; Action = { global:Clear-PrinterCache }},
    @{ Name = "Fixing error 0x00000709 registry settings";       Action = { global:Fix-PrinterRegistry }},
    @{ Name = "Starting Print Spooler service";                  Action = { global:Restart-PrintSpooler }},
    @{ Name = "Restarting Line Printer Daemon (LPDSVC)";         Action = { global:Restart-PrinterServiceSafe "LPDSVC" }},
    @{ Name = "Restarting Fax service";                         Action = { global:Restart-PrinterServiceSafe "Fax" }},
    @{ Name = "Restarting Print Notification service";           Action = { global:Restart-PrinterServiceSafe "PrintNotify" }},
    @{ Name = "Refreshing printer driver cache";                 Action = { rundll32 printui.dll,PrintUIEntry /Xg | Out-Null; return $true }},
    @{ Name = "Refreshing network printer connections";          Action = { rundll32 printui.dll,PrintUIEntry /in /q | Out-Null; return $true }},
    @{ Name = "Restarting Print Spooler (final confirmation)";   Action = {
        Restart-Service spooler -Force -ErrorAction SilentlyContinue
        return $true
    }}
)

function global:Restart-PrinterServiceSafe {
    param([string]$ServiceName)
    try {
        if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
            Stop-Service  -Name $ServiceName -Force -ErrorAction SilentlyContinue
            Start-Service -Name $ServiceName        -ErrorAction SilentlyContinue
            Add-Content $global:PrinterFixLogFile "$ServiceName restarted successfully."
            return $true
        } else {
            Add-Content $global:PrinterFixLogFile "$ServiceName not found - skipped."
            return $false
        }
    } catch {
        Add-Content $global:PrinterFixLogFile ("Error restarting {0}: {1}" -f $ServiceName, $_.Exception.Message)
        return $false
    }
}

function global:Fix-PrinterRegistry {
    try {
        $regPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Windows"
        if (Test-Path $regPath) {
            $dev = Get-ItemProperty -Path $regPath -Name "Device" -ErrorAction SilentlyContinue
            if ($dev) {
                Add-Content $global:PrinterFixLogFile "Current default printer device: $($dev.Device)"
            }
            Set-ItemProperty -Path $regPath -Name "LegacyDefaultPrinterMode" -Value 1 -ErrorAction SilentlyContinue
            Add-Content $global:PrinterFixLogFile "Set LegacyDefaultPrinterMode to 1"
        }
        Add-Content $global:PrinterFixLogFile "Registry fix completed"
        return $true
    } catch {
        Add-Content $global:PrinterFixLogFile "Registry fix error: $($_.Exception.Message)"
        return $false
    }
}

function global:Clear-PrinterCache {
    try {
        $paths = @(
            "$env:SystemRoot\System32\spool\PRINTERS",
            "$env:SystemRoot\System32\spool\SERVERS"
        )
        $cleared = 0
        foreach ($path in $paths) {
            if (Test-Path $path) {
                Get-ChildItem $path -Force -ErrorAction SilentlyContinue |
                    Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                $cleared++
                Add-Content $global:PrinterFixLogFile "Cleared: $path"
            }
        }
        return ($cleared -gt 0)
    } catch {
        Add-Content $global:PrinterFixLogFile "Cache clear error: $($_.Exception.Message)"
        return $false
    }
}

function global:Restart-PrintSpooler {
    try {
        $deps = @("PrintNotify", "Fax", "LPDSVC")
        foreach ($svc in $deps) {
            Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
        }
        Stop-Service spooler -Force -ErrorAction SilentlyContinue

        $timeout = 30; $elapsed = 0
        while ((Get-Service spooler).Status -ne "Stopped" -and $elapsed -lt $timeout) {
            Start-Sleep -Seconds 1; $elapsed++
        }

        Start-Service spooler -ErrorAction SilentlyContinue

        $elapsed = 0
        while ((Get-Service spooler).Status -ne "Running" -and $elapsed -lt $timeout) {
            Start-Sleep -Seconds 1; $elapsed++
        }

        foreach ($svc in $deps) {
            Start-Service -Name $svc -ErrorAction SilentlyContinue
        }
        Add-Content $global:PrinterFixLogFile "Print Spooler restarted successfully"
        return $true
    } catch {
        Add-Content $global:PrinterFixLogFile "Spooler restart error: $($_.Exception.Message)"
        return $false
    }
}

function global:Run-PrinterFix {
    param(
        $ProgressBar,
        $TaskLabel,
        $OutputBox,
        $StatusLight
    )

    $global:PrinterFixStop  = $false
    $global:PrinterFixPause = $false

    $ProgressBar.Value   = 0
    $ProgressBar.Maximum = $global:PrinterFixTasks.Count
    $OutputBox.Text      = ""

    $successCount = 0
    $failCount    = 0

    Add-Content $global:PrinterFixLogFile "`n============================================================"
    Add-Content $global:PrinterFixLogFile "PrinterFix started at $(Get-Date)"
    Add-Content $global:PrinterFixLogFile "------------------------------------------------------------"

    $OutputBox.AppendText("========================================`r`n")
    $OutputBox.AppendText("  PrinterFix - Error 0x00000709 Fix`r`n")
    $OutputBox.AppendText("  Author: Simon Peter | Version 4.4`r`n")
    $OutputBox.AppendText("========================================`r`n`r`n")

    $dispatcher = $ProgressBar.Dispatcher

    for ($i = 0; $i -lt $global:PrinterFixTasks.Count; $i++) {

        if ($global:PrinterFixStop) {
            $TaskLabel.Text   = "Stopped by user."
            $StatusLight.Fill = [System.Windows.Media.Brushes]::OrangeRed
            $OutputBox.AppendText("`r`n[STOPPED] Operation cancelled by user.`r`n")
            $OutputBox.ScrollToEnd()
            Add-Content $global:PrinterFixLogFile "Operation stopped by user."
            break
        }

        # Pause loop - keeps UI alive while waiting
        while ($global:PrinterFixPause -and -not $global:PrinterFixStop) {
            $TaskLabel.Text   = "Paused - click Resume to continue..."
            $StatusLight.Fill = [System.Windows.Media.Brushes]::Gold
            $dispatcher.Invoke([System.Action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
            Start-Sleep -Milliseconds 150
        }

        if ($global:PrinterFixStop) { break }

        $task = $global:PrinterFixTasks[$i]
        $TaskLabel.Text   = "[$($i+1)/$($global:PrinterFixTasks.Count)] $($task.Name)..."
        $StatusLight.Fill = [System.Windows.Media.Brushes]::DodgerBlue
        $OutputBox.AppendText("[$($i+1)/$($global:PrinterFixTasks.Count)] $($task.Name)...`r`n")
        $OutputBox.ScrollToEnd()
        $dispatcher.Invoke([System.Action]{}, [System.Windows.Threading.DispatcherPriority]::Background)

        try {
            $result = & $task.Action
            if ($result -ne $false) {
                $OutputBox.AppendText("   [SUCCESS] Completed`r`n")
                $successCount++
                Add-Content $global:PrinterFixLogFile "SUCCESS: $($task.Name)"
            } else {
                $OutputBox.AppendText("   [WARNING] Completed with warnings`r`n")
                $failCount++
                Add-Content $global:PrinterFixLogFile "WARNING: $($task.Name)"
            }
        } catch {
            $OutputBox.AppendText("   [ERROR] $($_.Exception.Message)`r`n")
            $failCount++
            Add-Content $global:PrinterFixLogFile "ERROR: $($task.Name) - $($_.Exception.Message)"
        }

        $ProgressBar.Value = $i + 1
        $OutputBox.ScrollToEnd()
        $dispatcher.Invoke([System.Action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
    }

    if (-not $global:PrinterFixStop) {
        $TaskLabel.Text = "Completed: $successCount succeeded, $failCount failed"
        if ($successCount -ge 8) {
            $StatusLight.Fill = [System.Windows.Media.Brushes]::LimeGreen
        } else {
            $StatusLight.Fill = [System.Windows.Media.Brushes]::OrangeRed
        }

        $OutputBox.AppendText("`r`n========================================`r`n")
        $OutputBox.AppendText("  SUMMARY`r`n")
        $OutputBox.AppendText("========================================`r`n")
        $OutputBox.AppendText("  Success: $successCount`r`n")
        $OutputBox.AppendText("  Failed:  $failCount`r`n")
        $OutputBox.AppendText("========================================`r`n`r`n")

        if ($successCount -ge 8) {
            $OutputBox.AppendText("[OK] Printer fix completed successfully!`r`n")
            $OutputBox.AppendText("Please try your printer again.`r`n")
        } else {
            $OutputBox.AppendText("[WARNING] Some tasks failed. Check the log for details.`r`n")
        }
        $OutputBox.AppendText("`r`nLog: $global:PrinterFixLogFile`r`n")
        $OutputBox.ScrollToEnd()

        Add-Content $global:PrinterFixLogFile "COMPLETED - Success: $successCount, Failed: $failCount"
    }
}
