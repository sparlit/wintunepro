# TronScript Integration Module for WinTune Pro
# Provides detection, configuration and launch of TronScript
# Path is relative to $scriptRoot - works on any drive

$global:TronScriptProcess = $null
$global:TronScriptStop    = $false
$global:TronLogTimer      = $null
$global:TronLastLogPos    = 0
$global:TronLogPath       = $null
$global:TronCustomPath    = $null

if (-not (Test-Path variable:scriptRoot)) {
    $scriptRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}

function global:Get-TronScriptPath {
    if ($global:TronCustomPath -and (Test-Path $global:TronCustomPath)) {
        return $global:TronCustomPath
    }
    $cfgFile = Join-Path $scriptRoot "Core\tronpath.cfg"
    if (Test-Path $cfgFile) {
        $saved = (Get-Content $cfgFile -Raw -ErrorAction SilentlyContinue).Trim()
        if ($saved -and (Test-Path $saved)) {
            $global:TronCustomPath = $saved
            return $saved
        }
    }
    $default = Join-Path $scriptRoot "Modules\TronScript\tron\tron.bat"
    if (Test-Path $default) { return $default }
    return $null
}

function global:Test-TronScriptPresent {
    return ($null -ne (Get-TronScriptPath))
}

# Function Update-TronPathDisplay removed (duplicate of E:\WinTunePro\WinTune.ps1)
# Function Update-TronPathDisplay removed (duplicate of E:\WinTunePro\WinTune.ps1)
# Function Update-TronPathDisplay removed (duplicate of E:\WinTunePro\WinTune.ps1)
# Function Update-TronPathDisplay removed (duplicate of E:\WinTunePro\WinTune.ps1)
# Function Update-TronPathDisplay removed (duplicate of E:\WinTunePro\WinTune.ps1)
# Function Update-TronPathDisplay removed (duplicate of E:\WinTunePro\WinTune.ps1)
# Function Update-TronPathDisplay removed (duplicate of E:\WinTunePro\WinTune.ps1)
# Function Update-TronPathDisplay removed (duplicate of E:\WinTunePro\WinTune.ps1)
# Function Update-TronPathDisplay removed (duplicate of E:\WinTunePro\WinTune.ps1)
# Function Update-TronPathDisplay removed (duplicate of E:\WinTunePro\WinTune.ps1)
# Function Update-TronPathDisplay removed (duplicate of E:\WinTunePro\WinTune.ps1)
# Function Update-TronPathDisplay removed (duplicate of E:\WinTunePro\WinTune.ps1)
# Function Update-TronPathDisplay removed (duplicate of E:\WinTunePro\WinTune.ps1)
# Function Update-TronPathDisplay removed (duplicate of E:\WinTunePro\WinTune.ps1)
# Function Update-TronPathDisplay removed (duplicate of E:\WinTunePro\WinTune.ps1)
# Function Update-TronPathDisplay removed (duplicate of E:\WinTunePro\WinTune.ps1)
# Function Update-TronPathDisplay removed (duplicate of E:\WinTunePro\WinTune.ps1)
# Function Update-TronPathDisplay removed (duplicate of E:\WinTunePro\WinTune.ps1)
# Function Update-TronPathDisplay removed (duplicate of E:\WinTunePro\WinTune.ps1)

# Function Browse-TronPath removed (duplicate of E:\WinTunePro\WinTune.ps1)
# Function Browse-TronPath removed (duplicate of E:\WinTunePro\WinTune.ps1)
# Function Browse-TronPath removed (duplicate of E:\WinTunePro\WinTune.ps1)
# Function Browse-TronPath removed (duplicate of E:\WinTunePro\WinTune.ps1)
# Function Browse-TronPath removed (duplicate of E:\WinTunePro\WinTune.ps1)
# Function Browse-TronPath removed (duplicate of E:\WinTunePro\WinTune.ps1)
# Function Browse-TronPath removed (duplicate of E:\WinTunePro\WinTune.ps1)
# Function Browse-TronPath removed (duplicate of E:\WinTunePro\WinTune.ps1)
# Function Browse-TronPath removed (duplicate of E:\WinTunePro\WinTune.ps1)
# Function Browse-TronPath removed (duplicate of E:\WinTunePro\WinTune.ps1)
# Function Browse-TronPath removed (duplicate of E:\WinTunePro\WinTune.ps1)
# Function Browse-TronPath removed (duplicate of E:\WinTunePro\WinTune.ps1)
# Function Browse-TronPath removed (duplicate of E:\WinTunePro\WinTune.ps1)

function global:Build-TronArguments {
    param([hashtable]$Options)
    $argList = [System.Collections.Generic.List[string]]::new()
    if ($Options.AutoMode)         { $argList.Add("-a")   }
    if ($Options.Verbose)          { $argList.Add("-v")   }
    if ($Options.RebootAfter)      { $argList.Add("-r")   }
    if ($Options.SelfDestruct)     { $argList.Add("-x")   }
    if ($Options.SkipDebloat)      { $argList.Add("-sdb") }
    if ($Options.SkipAntiMalware)  { $argList.Add("-sa")  }
    if ($Options.SkipDefrag)       { $argList.Add("-sd")  }
    if ($Options.SkipPatches)      { $argList.Add("-sp")  }
    if ($Options.SkipEventLogs)    { $argList.Add("-se")  }
    if ($Options.SkipTelemetry)    { $argList.Add("-str") }
    if ($Options.SkipNetworkReset) { $argList.Add("-snr") }
    return ($argList -join " ")
}

function global:Get-TronLatestLog {
    $logDir = "$env:SystemDrive\logs\tron"
    if (-not (Test-Path $logDir)) { return $null }
    $latest = Get-ChildItem $logDir -Filter "tron_*.log" -ErrorAction SilentlyContinue |
              Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latest) { return $latest.FullName }
    return $null
}

function global:Append-TronOutput {
    param([System.Windows.Controls.TextBox]$Box, [string]$Text)
    if (-not $Box -or -not $Text) { return }
    $Box.AppendText($Text)
    $Box.ScrollToEnd()
}

function global:Start-TronScriptRun {
    param(
        [hashtable]$Options,
        [System.Windows.Controls.TextBox]$OutputBox,
        [System.Windows.Shapes.Ellipse]$StatusLight,
        [System.Windows.Controls.TextBlock]$StatusLabel,
        [System.Windows.Controls.ProgressBar]$ProgressBar
    )

    $tronPath = Get-TronScriptPath
    if (-not $tronPath) {
        Append-TronOutput -Box $OutputBox -Text "[ERROR] tron.bat not found. Use Browse to locate it.`r`n"
        return $false
    }

    $tronDir = Split-Path $tronPath -Parent
    $argStr  = Build-TronArguments -Options $Options

    $global:TronScriptStop = $false
    $global:TronLastLogPos = 0
    $global:TronLogPath    = $null

    if ($OutputBox) {
        $OutputBox.Clear()
        $ts = Get-Date -Format "HH:mm:ss"
        $OutputBox.AppendText("[$ts] Launching TronScript...`r`n")
        $OutputBox.AppendText("[$ts] Path: $tronPath`r`n")
        $OutputBox.AppendText("[$ts] Flags: $argStr`r`n")
        $OutputBox.AppendText("[$ts] Log will be tailed from: $env:SystemDrive\logs\tron\`r`n")
        $OutputBox.AppendText("[$ts] TronScript runs in its own elevated console window.`r`n")
        $OutputBox.AppendText(("--------------------------------------------------`r`n"))
        $OutputBox.ScrollToEnd()
    }
    if ($StatusLight) { $StatusLight.Fill = [System.Windows.Media.Brushes]::DodgerBlue }
    if ($StatusLabel) { $StatusLabel.Text = "TronScript is running..." }
    if ($ProgressBar) { $ProgressBar.IsIndeterminate = $true }

    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName         = "cmd.exe"
        $psi.Arguments        = "/c `"$tronPath`" $argStr"
        $psi.WorkingDirectory = $tronDir
        $psi.Verb             = "runas"
        $psi.UseShellExecute  = $true
        $global:TronScriptProcess = [System.Diagnostics.Process]::Start($psi)
    } catch {
        Write-Log -Level "ERROR" -Category "System" -Message "Failed to launch TronScript: $($_.Exception.Message)" -Category System
        Append-TronOutput -Box $OutputBox -Text "[ERROR] Failed to launch: $($_.Exception.Message)`r`n"
        if ($StatusLight) { $StatusLight.Fill = [System.Windows.Media.Brushes]::OrangeRed }
        if ($StatusLabel) { $StatusLabel.Text = "Launch failed" }
        if ($ProgressBar) { $ProgressBar.IsIndeterminate = $false }
        return $false
    }

    $dispatcherBox   = $OutputBox
    $dispatcherLight = $StatusLight
    $dispatcherLabel = $StatusLabel
    $dispatcherBar   = $ProgressBar

    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromSeconds(3)
    $timer.Add_Tick({
        if ($global:TronScriptStop) {
            $timer.Stop()
            if ($dispatcherBar) { $dispatcherBar.IsIndeterminate = $false }
            return
        }

        if (-not $global:TronLogPath) {
            $global:TronLogPath = Get-TronLatestLog
            if ($global:TronLogPath) {
                $ts = Get-Date -Format "HH:mm:ss"
                Append-TronOutput -Box $dispatcherBox -Text "[$ts] Tailing log: $($global:TronLogPath)`r`n"
            }
        }

        if ($global:TronLogPath -and (Test-Path $global:TronLogPath)) {
            try {
                $fs = [System.IO.File]::Open($global:TronLogPath,
                    [System.IO.FileMode]::Open,
                    [System.IO.FileAccess]::Read,
                    [System.IO.FileShare]::ReadWrite)
                $reader = New-Object System.IO.StreamReader($fs, [System.Text.Encoding]::UTF8)
                if ($global:TronLastLogPos -gt 0) {
                    $reader.BaseStream.Seek($global:TronLastLogPos, [System.IO.SeekOrigin]::Begin) | Out-Null
                }
                $newText = $reader.ReadToEnd()
                $global:TronLastLogPos = $reader.BaseStream.Position
                $reader.Close()
                $fs.Close()
                if ($newText) {
                    Append-TronOutput -Box $dispatcherBox -Text $newText
                    if ($dispatcherBar -and -not $dispatcherBar.IsIndeterminate) {
                        $stageMatch = [regex]::Matches($newText, "Stage (\d):")
                        if ($stageMatch.Count -gt 0) {
                            $stageNum = [int]$stageMatch[$stageMatch.Count - 1].Groups[1].Value
                            $dispatcherBar.IsIndeterminate = $false
                            $dispatcherBar.Value = $stageNum + 1
                        }
                    }
                }
            } catch {
                Write-Log -Level "WARNING" -Category "System" -Message "Error reading TronScript log: $($_.Exception.Message)" -Category System
            }
        }

        if ($global:TronScriptProcess -and $global:TronScriptProcess.HasExited) {
            $timer.Stop()
            if ($dispatcherBar) {
                $dispatcherBar.IsIndeterminate = $false
                $dispatcherBar.Value = 8
            }
            $exitCode = $global:TronScriptProcess.ExitCode
            if ($dispatcherLight) {
                if ($exitCode -eq 0) { $dispatcherLight.Fill = [System.Windows.Media.Brushes]::LimeGreen }
                else                 { $dispatcherLight.Fill = [System.Windows.Media.Brushes]::OrangeRed }
            }
            if ($dispatcherLabel) {
                if ($exitCode -eq 0) { $dispatcherLabel.Text = "TronScript completed successfully" }
                else                 { $dispatcherLabel.Text = "TronScript finished (exit code: $exitCode)" }
            }
            $ts = Get-Date -Format "HH:mm:ss"
            Append-TronOutput -Box $dispatcherBox -Text "`r`n--------------------------------------------------`r`n"
            Append-TronOutput -Box $dispatcherBox -Text "[$ts] TronScript process ended. Exit code: $exitCode`r`n"

            $runBtn  = Find-UIElement "TronRunBtn"
            $stopBtn = Find-UIElement "TronStopBtn"
            if ($runBtn)  { $runBtn.IsEnabled  = $true }
            if ($stopBtn) { $stopBtn.IsEnabled = $false }
        }
    })
    $global:TronLogTimer = $timer
    $timer.Start()
    return $true
}

function global:Stop-TronScriptRun {
    $global:TronScriptStop = $true
    if ($global:TronLogTimer) { $global:TronLogTimer.Stop() }
    if ($global:TronScriptProcess -and -not $global:TronScriptProcess.HasExited) {
        try {
            $processId = $global:TronScriptProcess.Id
            Get-WmiObject Win32_Process | Where-Object { $_.ParentProcessId -eq $processId } |
                ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
            $global:TronScriptProcess.Kill()
        } catch {
            Write-Log -Level "ERROR" -Category "System" -Message "Failed to stop TronScript process: $($_.Exception.Message)" -Category System
        }
    }
}
