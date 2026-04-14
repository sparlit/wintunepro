#Requires -Version 5.1
<#
.SYNOPSIS
    WinTune Pro WUSourceReset Module - Windows Update source reset
.DESCRIPTION
    Windows Update component reset, cache management, and source configuration
#>

function global:Reset-WindowsUpdateComponents {
    <#
    .SYNOPSIS
        Performs a full Windows Update component reset.
    #>
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{
        Success       = $true
        SpaceRecovered = 0
        ItemsCleaned  = 0
        Error         = $null
    }

    if (-not $script:State.IsElevated) {
        Write-Log -Level "ERROR" -Category "WUSourceReset" -Message "Admin privileges required for WU component reset"
        $result.Success = $false
        $result.Error = "Admin privileges required"
        return $result
    }

    $services = @("wuauserv", "bits", "cryptsvc", "msiserver")
    $sdPath = "C:\Windows\SoftwareDistribution"
    $catRoot2 = "C:\Windows\System32\catroot2"

    Write-Log -Level "INFO" -Category "WUSourceReset" -Message "Starting Windows Update component reset..."

    if ($Preview) {
        Write-Log -Level "INFO" -Category "WUSourceReset" -Message "[Preview] Would stop services: $($services -join ', ')"
        Write-Log -Level "INFO" -Category "WUSourceReset" -Message "[Preview] Would rename $sdPath to SoftwareDistribution.bak"
        Write-Log -Level "INFO" -Category "WUSourceReset" -Message "[Preview] Would rename $catRoot2 to catroot2.bak"
        Write-Log -Level "INFO" -Category "WUSourceReset" -Message "[Preview] Would restart services"
        return $result
    }

    if ($TestMode) {
        Write-Log -Level "INFO" -Category "WUSourceReset" -Message "[TestMode] WU component reset flagged for execution"
        return $result
    }

    try {
        Write-Log -Level "INFO" -Category "WUSourceReset" -Message "Stopping Windows Update services..."
        foreach ($svc in $services) {
            try {
                Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
                Write-Log -Level "SUCCESS" -Category "WUSourceReset" -Message "Stopped service: $svc"
            } catch {
                Write-Log -Level "WARNING" -Category "WUSourceReset" -Message "Could not stop service $svc : $($_.Exception.Message)"
            }
        }

        Start-Sleep -Seconds 2

        $timestamp = Get-Date -Format "yyyyMMddHHmmss"

        if (Test-Path $sdPath) {
            $newName = "$sdPath.bak.$timestamp"
            Rename-Item -Path $sdPath -NewName $newName -Force -ErrorAction SilentlyContinue
            Write-Log -Level "SUCCESS" -Category "WUSourceReset" -Message "Renamed SoftwareDistribution to $($newName)"
        }

        if (Test-Path $catRoot2) {
            $newName = "$catRoot2.bak.$timestamp"
            Rename-Item -Path $catRoot2 -NewName $newName -Force -ErrorAction SilentlyContinue
            Write-Log -Level "SUCCESS" -Category "WUSourceReset" -Message "Renamed catroot2 to $($newName)"
        }

        Write-Log -Level "INFO" -Category "WUSourceReset" -Message "Restarting Windows Update services..."
        foreach ($svc in $services) {
            try {
                Start-Service -Name $svc -ErrorAction SilentlyContinue
                Write-Log -Level "SUCCESS" -Category "WUSourceReset" -Message "Started service: $svc"
            } catch {
                Write-Log -Level "WARNING" -Category "WUSourceReset" -Message "Could not start service $svc : $($_.Exception.Message)"
            }
        }

        $result.ItemsCleaned = 2
        Write-Log -Level "SUCCESS" -Category "WUSourceReset" -Message "Windows Update component reset complete"
    } catch {
        Write-Log -Level "ERROR" -Category "WUSourceReset" -Message "Error during component reset: $($_.Exception.Message)"
        $result.Success = $false
        $result.Error = $_.Exception.Message
    }

    return $result
}

function global:Clear-WindowsUpdateDownloadCache {
    <#
    .SYNOPSIS
        Clears the Windows Update download cache.
    #>
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{
        Success       = $true
        SpaceRecovered = 0
        ItemsCleaned  = 0
        Error         = $null
    }

    $downloadPath = "C:\Windows\SoftwareDistribution\Download"

    if (-not (Test-Path $downloadPath)) {
        Write-Log -Level "INFO" -Category "WUSourceReset" -Message "Download cache folder not found - skipping"
        return $result
    }

    Write-Log -Level "INFO" -Category "WUSourceReset" -Message "Clearing Windows Update download cache..."

    try {
        $items = Get-ChildItem -Path $downloadPath -Recurse -Force -ErrorAction SilentlyContinue
        $size = ($items | Measure-Object -Property Length -Sum).Sum
        if (-not $size) { $size = 0 }

        if ($Preview) {
            Write-Log -Level "INFO" -Category "WUSourceReset" -Message "[Preview] Would clear download cache - $(Format-FileSize $size)"
        } elseif ($TestMode) {
            Write-Log -Level "INFO" -Category "WUSourceReset" -Message "[TestMode] Download cache flagged for clearing"
        } else {
            if ($script:State.IsElevated) {
                Write-Log -Level "INFO" -Category "WUSourceReset" -Message "Stopping wuauserv for cache cleanup..."
                Stop-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue
            }

            Remove-Item -Path "$downloadPath\*" -Recurse -Force -ErrorAction SilentlyContinue

            if ($script:State.IsElevated) {
                Start-Service -Name "wuauserv" -ErrorAction SilentlyContinue
            }

            Write-Log -Level "SUCCESS" -Category "WUSourceReset" -Message "Cleared download cache"
        }

        $result.SpaceRecovered = $size
        $result.ItemsCleaned = ($items | Measure-Object).Count
    } catch {
        Write-Log -Level "ERROR" -Category "WUSourceReset" -Message "Error clearing download cache: $($_.Exception.Message)"
        $result.Success = $false
        $result.Error = $_.Exception.Message
    }

    Write-Log -Level "SUCCESS" -Category "WUSourceReset" -Message "Download cache cleanup complete: $(Format-FileSize $result.SpaceRecovered) recovered"
    return $result
}

function global:Reset-WindowsUpdateAgent {
    <#
    .SYNOPSIS
        Re-registers Windows Update DLLs.
    #>
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{
        Success       = $true
        SpaceRecovered = 0
        ItemsCleaned  = 0
        Error         = $null
        DllsRegistered = 0
    }

    if (-not $script:State.IsElevated) {
        Write-Log -Level "ERROR" -Category "WUSourceReset" -Message "Admin privileges required for WU agent reset"
        $result.Success = $false
        $result.Error = "Admin privileges required"
        return $result
    }

    $dlls = @(
        "atl.dll", "urlmon.dll", "mshtml.dll", "shdocvw.dll", "browseui.dll",
        "jscript.dll", "vbscript.dll", "scrrun.dll", "msxml.dll", "msxml3.dll",
        "msxml6.dll", "actxprxy.dll", "softpub.dll", "wintrust.dll", "dssenh.dll",
        "rsaenh.dll", "gpkcsp.dll", "sccbase.dll", "slbcsp.dll", "cryptdlg.dll",
        "oleaut32.dll", "ole32.dll", "shell32.dll", "initpki.dll", "wuapi.dll",
        "wuaueng.dll", "wuaueng1.dll", "wucltui.dll", "wups.dll", "wups2.dll",
        "wuweb.dll", "qmgr.dll", "qmgrprxy.dll", "wucltux.dll", "muweb.dll",
        "wuwebv.dll"
    )

    Write-Log -Level "INFO" -Category "WUSourceReset" -Message "Re-registering Windows Update DLLs..."

    if ($Preview) {
        Write-Log -Level "INFO" -Category "WUSourceReset" -Message "[Preview] Would re-register $($dlls.Count) DLLs"
        return $result
    }

    if ($TestMode) {
        Write-Log -Level "INFO" -Category "WUSourceReset" -Message "[TestMode] WU DLL re-registration flagged"
        return $result
    }

    foreach ($dll in $dlls) {
        $dllPath = Join-Path $env:SystemRoot "System32\$dll"
        if (Test-Path $dllPath) {
            try {
                $proc = Start-Process -FilePath "regsvr32.exe" -ArgumentList "/s `"$dllPath`"" -Wait -PassThru -NoNewWindow
                if ($proc.ExitCode -eq 0) {
                    $result.DllsRegistered++
                }
            } catch {
                Write-Log -Level "WARNING" -Category "WUSourceReset" -Message "Error registering $dll : $($_.Exception.Message)"
            }
        }
    }

    $result.ItemsCleaned = $result.DllsRegistered
    Write-Log -Level "SUCCESS" -Category "WUSourceReset" -Message "Re-registered $($result.DllsRegistered) DLLs"
    return $result
}

function global:Clear-WindowsUpdateLogs {
    <#
    .SYNOPSIS
        Clears Windows Update log files.
    #>
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{
        Success       = $true
        SpaceRecovered = 0
        ItemsCleaned  = 0
        Error         = $null
    }

    $logPaths = @(
        "C:\Windows\WindowsUpdate.log"
        "C:\Windows\Logs\WindowsUpdate"
        "$env:ProgramData\USOShared\Logs"
    )

    Write-Log -Level "INFO" -Category "WUSourceReset" -Message "Clearing Windows Update logs..."

    foreach ($path in $logPaths) {
        if (-not (Test-Path $path)) { continue }

        try {
            if (Test-Path $path -PathType Container) {
                $items = Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                $size = ($items | Measure-Object -Property Length -Sum).Sum
                if (-not $size) { $size = 0 }

                if ($Preview) {
                    Write-Log -Level "INFO" -Category "WUSourceReset" -Message "[Preview] Would clear logs at $path - $(Format-FileSize $size)"
                } elseif ($TestMode) {
                    Write-Log -Level "INFO" -Category "WUSourceReset" -Message "[TestMode] Logs at $path flagged"
                } else {
                    Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Log -Level "SUCCESS" -Category "WUSourceReset" -Message "Cleared logs at $path"
                }

                $result.SpaceRecovered += $size
                $result.ItemsCleaned += ($items | Measure-Object).Count
            } else {
                $size = (Get-Item -Path $path -Force -ErrorAction SilentlyContinue).Length
                if (-not $size) { $size = 0 }

                if ($Preview) {
                    Write-Log -Level "INFO" -Category "WUSourceReset" -Message "[Preview] Would remove $path - $(Format-FileSize $size)"
                } elseif ($TestMode) {
                    Write-Log -Level "INFO" -Category "WUSourceReset" -Message "[TestMode] File $path flagged"
                } else {
                    Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
                    Write-Log -Level "SUCCESS" -Category "WUSourceReset" -Message "Removed $path"
                }

                $result.SpaceRecovered += $size
                $result.ItemsCleaned++
            }
        } catch {
            Write-Log -Level "WARNING" -Category "WUSourceReset" -Message "Error clearing logs at $path : $($_.Exception.Message)"
        }
    }

    Write-Log -Level "SUCCESS" -Category "WUSourceReset" -Message "Log cleanup complete: $(Format-FileSize $result.SpaceRecovered) recovered"
    return $result
}

function global:Set-WindowsUpdateSource {
    <#
    .SYNOPSIS
        Sets the Windows Update source.
    #>
    param(
        [ValidateSet("Microsoft", "WSUS", "Default")]
        [string]$Source = "Default",
        [switch]$Preview
    )

    $result = @{
        Success = $true
        Error   = $null
        Source  = $Source
    }

    if (-not $script:State.IsElevated) {
        Write-Log -Level "ERROR" -Category "WUSourceReset" -Message "Admin privileges required to change WU source"
        $result.Success = $false
        $result.Error = "Admin privileges required"
        return $result
    }

    Write-Log -Level "INFO" -Category "WUSourceReset" -Message "Setting Windows Update source to: $Source"

    $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"

    if ($Preview) {
        Write-Log -Level "INFO" -Category "WUSourceReset" -Message "[Preview] Would set WU source to $Source"
        return $result
    }

    try {
        switch ($Source) {
            "Microsoft" {
                if (-not (Test-Path $regPath)) {
                    New-Item -Path $regPath -Force | Out-Null
                }
                Set-ItemProperty -Path $regPath -Name "DoNotConnectToWindowsUpdateInternetLocations" -Value 0 -Type DWord -Force
                Set-ItemProperty -Path $regPath -Name "WUServer" -Value "" -Force
                Set-ItemProperty -Path $regPath -Name "WUStatusServer" -Value "" -Force
                Write-Log -Level "SUCCESS" -Category "WUSourceReset" -Message "Set source to Microsoft Update"
            }
            "WSUS" {
                Write-Log -Level "WARNING" -Category "WUSourceReset" -Message "WSUS source requires a server URL - use registry manually"
            }
            "Default" {
                if (Test-Path $regPath) {
                    Remove-ItemProperty -Path $regPath -Name "DoNotConnectToWindowsUpdateInternetLocations" -ErrorAction SilentlyContinue
                    Remove-ItemProperty -Path $regPath -Name "WUServer" -ErrorAction SilentlyContinue
                    Remove-ItemProperty -Path $regPath -Name "WUStatusServer" -ErrorAction SilentlyContinue
                }
                Write-Log -Level "SUCCESS" -Category "WUSourceReset" -Message "Reset to default Windows Update source"
            }
        }
    } catch {
        Write-Log -Level "ERROR" -Category "WUSourceReset" -Message "Error setting WU source: $($_.Exception.Message)"
        $result.Success = $false
        $result.Error = $_.Exception.Message
    }

    return $result
}

function global:Get-WindowsUpdateCacheSize {
    <#
    .SYNOPSIS
        Calculates the size of Windows Update caches.
    #>

    $result = @{
        TotalSize          = 0
        SoftwareDistribution = 0
        DownloadCache      = 0
        CatRoot            = 0
        LogFiles           = 0
    }

    $paths = @{
        SoftwareDistribution = "C:\Windows\SoftwareDistribution"
        DownloadCache        = "C:\Windows\SoftwareDistribution\Download"
        CatRoot              = "C:\Windows\System32\catroot2"
        LogFiles             = "C:\Windows\WindowsUpdate.log"
    }

    foreach ($key in $paths.Keys) {
        $path = $paths[$key]
        if (Test-Path $path) {
            if (Test-Path $path -PathType Container) {
                $size = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                    Measure-Object -Property Length -Sum).Sum
                if ($size) { $result.$key = $size }
            } else {
                $size = (Get-Item -Path $path -Force -ErrorAction SilentlyContinue).Length
                if ($size) { $result.$key = $size }
            }
        }
    }

    $result.TotalSize = $result.SoftwareDistribution + $result.CatRoot + $result.LogFiles
    return $result
}
