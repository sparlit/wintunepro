<#
.SYNOPSIS
    WinTunePro WindowsUpdateMgr Module - Windows Update management
.DESCRIPTION
    Manages Windows Update operations including checking, installing, repairing,
    caching, blocking/unblocking updates, and configuring update settings.
.NOTES
    File: Modules\WindowsUpdateMgr\WindowsUpdateMgr.ps1
    Version: 1.0.0
    PowerShell: 5.1+
    Compatible: Windows 10, Windows 11
#>

#Requires -Version 5.1

$script:BlockedUpdatesPath = ""
$script:BlockedUpdates = @()

function global:Initialize-WindowsUpdateMgr {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DataPath
    )
    $script:BlockedUpdatesPath = Join-Path $DataPath "BlockedUpdates.json"
    if (Test-Path $script:BlockedUpdatesPath) {
        try {
            $script:BlockedUpdates = Get-Content $script:BlockedUpdatesPath -Raw | ConvertFrom-Json
        } catch {
            $script:BlockedUpdates = @()
        }
    }
    Write-Log -Level "INFO" -Category "System" -Message "WindowsUpdateMgr initialized"
}

function global:Get-WindowsUpdateStatus {
    <#
    .SYNOPSIS
        Returns current update status and pending reboots.
    #>
    $result = @{
        Success  = $true
        Details  = @{}
        Errors   = @()
    }

    Write-Log -Level "INFO" -Category "System" -Message "Checking Windows Update status..."

    try {
        $pendingReboot = $false
        try {
            $rebootKeys = @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
                "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations"
            )
            foreach ($key in $rebootKeys) {
                if (Test-Path $key) {
                    $pendingReboot = $true
                    break
                }
            }
        } catch {
            $result.Errors += "Could not check reboot keys: $($_.Exception.Message)"
        }

        $lastUpdateCheck = "Unknown"
        $lastInstallDate = "Unknown"
        try {
            $session = New-Object -ComObject Microsoft.Update.Session -ErrorAction Stop
            $searcher = $session.CreateUpdateSearcher()
            $historyCount = $searcher.GetTotalHistoryCount()
            if ($historyCount -gt 0) {
                $lastHistory = $searcher.QueryHistory(0, 1)
                if ($lastHistory) {
                    $lastUpdateCheck = $lastHistory[0].Date.ToString("yyyy-MM-dd HH:mm:ss")
                }
            }

            $regUpdate = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" -ErrorAction SilentlyContinue
            if ($regUpdate -and $regUpdate.LastSuccessTime) {
                $lastUpdateCheck = $regUpdate.LastSuccessTime
            }
        } catch {
            $result.Errors += "Could not get update history: $($_.Exception.Message)"
        }

        $auSettings = @{}
        try {
            $auReg = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" -ErrorAction SilentlyContinue
            if ($auReg) {
                $auOptions = switch ($auReg.AUOptions) {
                    1 { "Never check for updates" }
                    2 { "Notify before download" }
                    3 { "Auto download, notify before install" }
                    4 { "Auto download and schedule install" }
                    5 { "Allow local admin to choose" }
                    default { "Unknown ($($auReg.AUOptions))" }
                }
                $auSettings = @{
                    AUOptions        = $auOptions
                    AUOptionsRaw     = $auReg.AUOptions
                    ScheduledInstallDay  = $auReg.ScheduledInstallDay
                    ScheduledInstallTime = $auReg.ScheduledInstallTime
                    NoAutoRebootWithLoggedOnUsers = $auReg.NoAutoRebootWithLoggedOnUsers
                }
            }
        } catch {
            $result.Errors += "Could not read AU settings: $($_.Exception.Message)"
        }

        $pendingUpdates = Get-AvailableUpdates

        $result.Details = @{
            PendingReboot      = $pendingReboot
            PendingUpdateCount = $pendingUpdates.Details.Count
            LastUpdateCheck    = $lastUpdateCheck
            LastInstallDate    = $lastInstallDate
            AutoUpdateSettings = $auSettings
        }

        Write-Log -Level "INFO" -Category "System" -Message "Update status: Pending reboot=$pendingReboot, Updates available=$($pendingUpdates.Details.Count)"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "System" -Message "Failed to get update status: $($_.Exception.Message)"
    }

    return $result
}

function global:Get-AvailableUpdates {
    <#
    .SYNOPSIS
        Returns list of available updates (security, feature, driver).
    #>
    $result = @{
        Success  = $true
        Details  = @()
        Errors   = @()
    }

    Write-Log -Level "INFO" -Category "System" -Message "Searching for available updates..."

    try {
        $session = New-Object -ComObject Microsoft.Update.Session -ErrorAction Stop
        $searcher = $session.CreateUpdateSearcher()
        $searchResult = $searcher.Search("IsInstalled=0 and IsHidden=0")

        foreach ($update in $searchResult.Updates) {
            $category = "Other"
            foreach ($cat in $update.Categories) {
                if ($cat.Name -match "Security|Critical") { $category = "Security"; break }
                elseif ($cat.Name -match "Feature") { $category = "Feature"; break }
                elseif ($cat.Name -match "Driver") { $category = "Driver"; break }
                elseif ($cat.Name -match "Definition") { $category = "Definition"; break }
            }

            $kbNumbers = @()
            foreach ($kb in $update.KBArticleIDs) {
                $kbNumbers += "KB$kb"
            }

            $result.Details += @{
                Title        = $update.Title
                KBNumbers    = $kbNumbers
                Category     = $category
                SizeMB       = [math]::Round($update.MaxDownloadSize / 1MB, 2)
                IsMandatory  = $update.IsMandatory
                IsDownloaded = $update.IsDownloaded
                RebootRequired = $update.RebootRequired
                Description  = $update.Description
            }
        }

        Write-Log -Level "INFO" -Category "System" -Message "Found $($result.Details.Count) available updates"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "System" -Message "Failed to search for updates: $($_.Exception.Message)"
    }

    return $result
}

function global:Install-WindowsUpdates {
    <#
    .SYNOPSIS
        Install updates with progress reporting.
    #>
    param(
        [Parameter()]
        [string[]]$KBNumbers = @(),

        [Parameter()]
        [switch]$IncludeDrivers,

        [Parameter()]
        [switch]$AutoReboot
    )

    $result = @{
        Success  = $true
        Details  = @{
            Installed  = @()
            Failed     = @()
            RebootNeeded = $false
        }
        Errors   = @()
    }

    Write-Log -Level "INFO" -Category "System" -Message "Starting Windows Update installation..."

    try {
        $session = New-Object -ComObject Microsoft.Update.Session -ErrorAction Stop
        $searcher = $session.CreateUpdateSearcher()
        $filter = "IsInstalled=0 and IsHidden=0"
        $searchResult = $searcher.Search($filter)

        $updatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl

        foreach ($update in $searchResult.Updates) {
            $shouldInstall = $false

            if ($KBNumbers.Count -eq 0) {
                if ($update.Categories | Where-Object { $_.Name -match "Driver" }) {
                    if ($IncludeDrivers) { $shouldInstall = $true }
                } else {
                    $shouldInstall = $true
                }
            } else {
                foreach ($kb in $update.KBArticleIDs) {
                    if ($KBNumbers -contains "KB$kb") {
                        $shouldInstall = $true
                        break
                    }
                }
            }

            if (-not $shouldInstall) {
                $isBlocked = $false
                foreach ($kb in $update.KBArticleIDs) {
                    if ($script:BlockedUpdates -contains "KB$kb") {
                        $isBlocked = $true
                        break
                    }
                }
                if ($isBlocked) { continue }
            }

            if ($shouldInstall) {
                [void]$updatesToInstall.Add($update)
            }
        }

        if ($updatesToInstall.Count -eq 0) {
            Write-Log -Level "INFO" -Category "System" -Message "No updates to install"
            $result.Details.Installed = @()
            return $result
        }

        Write-Log -Level "INFO" -Category "System" -Message "Downloading $($updatesToInstall.Count) updates..."

        $downloader = $session.CreateUpdateDownloader()
        $downloader.Updates = $updatesToInstall
        $downloadResult = $downloader.Download()

        if ($downloadResult.ResultCode -eq 2 -or $downloadResult.ResultCode -eq 3) {
            Write-Log -Level "SUCCESS" -Category "System" -Message "Download completed"
        } else {
            $result.Success = $false
            $result.Errors += "Download failed with result code: $($downloadResult.ResultCode)"
            Write-Log -Level "ERROR" -Category "System" -Message "Download failed: result code $($downloadResult.ResultCode)"
            return $result
        }

        $readyToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
        foreach ($update in $updatesToInstall) {
            if ($update.IsDownloaded) {
                [void]$readyToInstall.Add($update)
                $result.Details.Installed += @{
                    Title = $update.Title
                    KB    = ($update.KBArticleIDs | ForEach-Object { "KB$_" }) -join ", "
                    Status = "Installing"
                }
            }
        }

        if ($readyToInstall.Count -eq 0) {
            Write-Log -Level "WARNING" -Category "System" -Message "No updates ready to install after download"
            return $result
        }

        Write-Log -Level "INFO" -Category "System" -Message "Installing $($readyToInstall.Count) updates..."

        $installer = $session.CreateUpdateInstaller()
        $installer.Updates = $readyToInstall
        $installResult = $installer.Install()

        $installedCount = 0
        $failedCount = 0

        for ($i = 0; $i -lt $readyToInstall.Count; $i++) {
            $resultCode = $installResult.GetUpdateResult($i).ResultCode
            if ($resultCode -eq 2 -or $resultCode -eq 3) {
                $installedCount++
                if ($i -lt $result.Details.Installed.Count) {
                    $result.Details.Installed[$i].Status = "Success"
                }
            } else {
                $failedCount++
                if ($i -lt $result.Details.Installed.Count) {
                    $result.Details.Installed[$i].Status = "Failed (code $resultCode)"
                }
                $result.Details.Failed += $readyToInstall.Item($i).Title
            }
        }

        $result.Details.RebootNeeded = $installResult.RebootRequired

        if ($installResult.RebootRequired) {
            Write-Log -Level "WARNING" -Category "System" -Message "Reboot required to complete installation"
            if ($AutoReboot) {
                Write-Log -Level "WARNING" -Category "System" -Message "AutoReboot enabled - initiating restart..."
                try {
                    Restart-Computer -Force
                } catch {
                    $result.Errors += "Failed to initiate reboot: $($_.Exception.Message)"
                }
            }
        }

        Write-Log -Level "SUCCESS" -Category "System" -Message "Installation complete: $installedCount succeeded, $failedCount failed"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "System" -Message "Update installation failed: $($_.Exception.Message)"
    }

    return $result
}

function global:Invoke-WindowsUpdateRepair {
    <#
    .SYNOPSIS
        Fix broken Windows Update (reset components, re-register DLLs).
    #>
    param(
        [Parameter()]
        [switch]$Force
    )

    $result = @{
        Success  = $true
        Details  = @{
            ActionsPerformed = @()
        }
        Errors   = @()
    }

    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Errors += "Administrator privileges required"
        return $result
    }

    Write-Log -Level "INFO" -Category "Repair" -Message "Starting Windows Update repair..."

    $services = @("wuauserv", "bits", "cryptsvc", "msiserver")
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

    foreach ($svc in $services) {
        try {
            Write-Log -Level "INFO" -Category "Repair" -Message "Stopping service: $svc"
            Stop-Service -Name $svc -Force -ErrorAction Stop
            $result.Details.ActionsPerformed += "Stopped service: $svc"
        } catch {
            $result.Errors += "Failed to stop $svc : $($_.Exception.Message)"
        }
    }

    try {
        $catroot2 = "$env:SystemRoot\System32\catroot2"
        $catroot2Bak = "$env:SystemRoot\System32\catroot2.bak"
        if (Test-Path $catroot2) {
            if (Test-Path $catroot2Bak) { Remove-Item $catroot2Bak -Recurse -Force }
            Rename-Item $catroot2 $catroot2Bak -Force
            $result.Details.ActionsPerformed += "Renamed catroot2 folder"
        }
    } catch {
        $result.Errors += "Failed to rename catroot2: $($_.Exception.Message)"
    }

    try {
        $softDist = "$env:SystemRoot\SoftwareDistribution"
        $softDistBak = "$env:SystemRoot\SoftwareDistribution.bak"
        if (Test-Path $softDist) {
            if (Test-Path $softDistBak) { Remove-Item $softDistBak -Recurse -Force }
            Rename-Item $softDist $softDistBak -Force
            $result.Details.ActionsPerformed += "Renamed SoftwareDistribution folder"
        }
    } catch {
        $result.Errors += "Failed to rename SoftwareDistribution: $($_.Exception.Message)"
    }

    foreach ($dll in $dlls) {
        try {
            $dllPath = Join-Path $env:SystemRoot "System32\$dll"
            if (Test-Path $dllPath) {
                $regResult = & regsvr32.exe /s $dllPath 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $result.Details.ActionsPerformed += "Registered: $dll"
                } else {
                    $result.Errors += "Failed to register $dll (exit code $LASTEXITCODE)"
                }
            }
        } catch {
            $result.Errors += "Failed to register $dll : $($_.Exception.Message)"
        }
    }

    try {
        & netsh winsock reset 2>&1 | Out-Null
        $result.Details.ActionsPerformed += "Reset Winsock catalog"
    } catch {
        $result.Errors += "Failed to reset Winsock: $($_.Exception.Message)"
    }

    try {
        & netsh int ip reset 2>&1 | Out-Null
        $result.Details.ActionsPerformed += "Reset IP stack"
    } catch {
        $result.Errors += "Failed to reset IP stack: $($_.Exception.Message)"
    }

    foreach ($svc in $services) {
        try {
            Write-Log -Level "INFO" -Category "Repair" -Message "Starting service: $svc"
            Start-Service -Name $svc -ErrorAction Stop
            $result.Details.ActionsPerformed += "Started service: $svc"
        } catch {
            $result.Errors += "Failed to start $svc : $($_.Exception.Message)"
        }
    }

    try {
        & wuauclt.exe /resetauthorization /detectnow 2>&1 | Out-Null
        $result.Details.ActionsPerformed += "Reset WU authorization"
    } catch {
        $result.Errors += "Failed to reset WU authorization: $($_.Exception.Message)"
    }

    if ($result.Errors.Count -eq 0) {
        Write-Log -Level "SUCCESS" -Category "Repair" -Message "Windows Update repair completed successfully"
    } else {
        Write-Log -Level "WARNING" -Category "Repair" -Message "Windows Update repair completed with $($result.Errors.Count) errors"
    }

    return $result
}

function global:Clear-WindowsUpdateCacheFull {
    <#
    .SYNOPSIS
        Clear download cache, temp files, old logs.
    #>
    $result = @{
        Success  = $true
        Details  = @{
            BytesFreed = [long]0
            PathsCleaned = @()
        }
        Errors   = @()
    }

    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Errors += "Administrator privileges required"
        return $result
    }

    Write-Log -Level "INFO" -Category "Cleaning" -Message "Clearing Windows Update cache..."

    $pathsToClean = @(
        @{ Path = "$env:SystemRoot\SoftwareDistribution\Download"; Description = "Update download cache" }
        @{ Path = "$env:SystemRoot\SoftwareDistribution\DataStore"; Description = "Update data store logs" }
        @{ Path = "$env:SystemRoot\Logs\WindowsUpdate"; Description = "Update logs" }
        @{ Path = "$env:TEMP\*wu*"; Description = "Temp WU files" }
        @{ Path = "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\*"; Description = "Internet cache related to WU" }
    )

    foreach ($item in $pathsToClean) {
        $path = $item.Path
        if (Test-Path $path) {
            try {
                $sizeBefore = (Get-ChildItem $path -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                if (-not $sizeBefore) { $sizeBefore = 0 }

                if ($path -like "*\*") {
                    Remove-Item $path -Recurse -Force -ErrorAction Stop
                } else {
                    Get-ChildItem $path -Recurse -Force -ErrorAction Stop | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                }

                $result.Details.BytesFreed += $sizeBefore
                $result.Details.PathsCleaned += $item.Description
                Write-Log -Level "INFO" -Category "Cleaning" -Message "Cleaned: $($item.Description) ($(Format-FileSize $sizeBefore))"
            } catch {
                $result.Errors += "Failed to clean $($item.Description): $($_.Exception.Message)"
            }
        }
    }

    try {
        Start-Service wuauserv -ErrorAction SilentlyContinue
    } catch {
        $result.Errors += "Failed to restart wuauserv: $($_.Exception.Message)"
    }

    Write-Log -Level "SUCCESS" -Category "Cleaning" -Message "WU cache cleared: $(Format-FileSize $result.Details.BytesFreed) freed"
    return $result
}

function global:Block-WindowsUpdate {
    <#
    .SYNOPSIS
        Block specific updates by KB number.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$KBNumber
    )

    $result = @{
        Success  = $true
        Details  = @{
            Blocked = @()
        }
        Errors   = @()
    }

    Write-Log -Level "INFO" -Category "System" -Message "Blocking updates: $($KBNumber -join ', ')"

    foreach ($kb in $KBNumber) {
        $kbClean = $kb.Trim().ToUpper()
        if (-not $kbClean.StartsWith("KB")) {
            $kbClean = "KB$kbClean"
        }

        try {
            $session = New-Object -ComObject Microsoft.Update.Session -ErrorAction Stop
            $searcher = $session.CreateUpdateSearcher()
            $searchResult = $searcher.Search("IsInstalled=0 and IsHidden=0")

            $found = $false
            foreach ($update in $searchResult.Updates) {
                foreach ($updateKb in $update.KBArticleIDs) {
                    if ("KB$updateKb" -eq $kbClean) {
                        $update.IsHidden = $true
                        $found = $true
                        $result.Details.Blocked += $kbClean
                        Write-Log -Level "SUCCESS" -Category "System" -Message "Blocked update: $kbClean - $($update.Title)"
                        break
                    }
                }
                if ($found) { break }
            }

            if (-not $found) {
                $result.Errors += "Update $kbClean not found in available updates"
            }
        } catch {
            $result.Errors += "Failed to block $kbClean : $($_.Exception.Message)"
        }

        if (-not ($script:BlockedUpdates -contains $kbClean)) {
            $script:BlockedUpdates += $kbClean
        }
    }

    try {
        if ($script:BlockedUpdatesPath) {
            $parentDir = Split-Path $script:BlockedUpdatesPath -Parent
            if ($parentDir -and -not (Test-Path $parentDir)) {
                New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
            }
            $script:BlockedUpdates | ConvertTo-Json | Out-File -FilePath $script:BlockedUpdatesPath -Encoding UTF8
        }
    } catch {
        $result.Errors += "Failed to save blocked updates list: $($_.Exception.Message)"
    }

    return $result
}

function global:Unblock-WindowsUpdate {
    <#
    .SYNOPSIS
        Unblock previously blocked updates.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$KBNumber
    )

    $result = @{
        Success  = $true
        Details  = @{
            Unblocked = @()
        }
        Errors   = @()
    }

    Write-Log -Level "INFO" -Category "System" -Message "Unblocking updates: $($KBNumber -join ', ')"

    foreach ($kb in $KBNumber) {
        $kbClean = $kb.Trim().ToUpper()
        if (-not $kbClean.StartsWith("KB")) {
            $kbClean = "KB$kbClean"
        }

        try {
            $session = New-Object -ComObject Microsoft.Update.Session -ErrorAction Stop
            $searcher = $session.CreateUpdateSearcher()
            $searchResult = $searcher.Search("IsInstalled=0 and IsHidden=1")

            $found = $false
            foreach ($update in $searchResult.Updates) {
                foreach ($updateKb in $update.KBArticleIDs) {
                    if ("KB$updateKb" -eq $kbClean) {
                        $update.IsHidden = $false
                        $found = $true
                        $result.Details.Unblocked += $kbClean
                        Write-Log -Level "SUCCESS" -Category "System" -Message "Unblocked update: $kbClean - $($update.Title)"
                        break
                    }
                }
                if ($found) { break }
            }

            if (-not $found) {
                $result.Errors += "Hidden update $kbClean not found"
            }
        } catch {
            $result.Errors += "Failed to unblock $kbClean : $($_.Exception.Message)"
        }

        $script:BlockedUpdates = @($script:BlockedUpdates | Where-Object { $_ -ne $kbClean })
    }

    try {
        if ($script:BlockedUpdatesPath) {
            $script:BlockedUpdates | ConvertTo-Json | Out-File -FilePath $script:BlockedUpdatesPath -Encoding UTF8
        }
    } catch {
        $result.Errors += "Failed to save blocked updates list: $($_.Exception.Message)"
    }

    return $result
}

function global:Get-UpdateHistory {
    <#
    .SYNOPSIS
        Show update installation history.
    #>
    param(
        [Parameter()]
        [int]$MaxResults = 100
    )

    $result = @{
        Success  = $true
        Details  = @()
        Errors   = @()
    }

    Write-Log -Level "INFO" -Category "System" -Message "Gathering update history (max $MaxResults)..."

    try {
        $session = New-Object -ComObject Microsoft.Update.Session -ErrorAction Stop
        $searcher = $session.CreateUpdateSearcher()
        $historyCount = $searcher.GetTotalHistoryCount()

        if ($historyCount -eq 0) {
            Write-Log -Level "INFO" -Category "System" -Message "No update history found"
            return $result
        }

        $count = [math]::Min($historyCount, $MaxResults)
        $history = $searcher.QueryHistory(0, $count)

        foreach ($entry in $history) {
            $status = switch ($entry.ResultCode) {
                0 { "Not Started" }
                1 { "In Progress" }
                2 { "Succeeded" }
                3 { "Succeeded with Errors" }
                4 { "Failed" }
                5 { "Aborted" }
                default { "Unknown ($($entry.ResultCode))" }
            }

            $result.Details += @{
                Date        = $entry.Date.ToString("yyyy-MM-dd HH:mm:ss")
                Title       = $entry.Title
                Description = $entry.Description
                Status      = $status
                ResultCode  = $entry.ResultCode
                SupportUrl  = $entry.SupportUrl
            }
        }

        Write-Log -Level "INFO" -Category "System" -Message "Retrieved $($result.Details.Count) update history entries"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "System" -Message "Failed to get update history: $($_.Exception.Message)"
    }

    return $result
}

function global:Set-WindowsUpdateSettings {
    <#
    .SYNOPSIS
        Configure update settings (auto/manual/notify).
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("NeverCheck", "NotifyBeforeDownload", "AutoDownloadNotifyInstall", "AutoDownloadScheduleInstall", "AllowLocalAdminChoose")]
        [string]$UpdateMode,

        [Parameter()]
        [int]$ScheduledInstallDay = 0,

        [Parameter()]
        [int]$ScheduledInstallTime = 3
    )

    $result = @{
        Success  = $true
        Details  = @{
            PreviousMode = ""
            NewMode      = $UpdateMode
        }
        Errors   = @()
    }

    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Errors += "Administrator privileges required"
        return $result
    }

    Write-Log -Level "INFO" -Category "System" -Message "Setting Windows Update mode to: $UpdateMode"

    try {
        $auReg = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" -ErrorAction SilentlyContinue
        if ($auReg) {
            $result.Details.PreviousMode = switch ($auReg.AUOptions) {
                1 { "NeverCheck" }
                2 { "NotifyBeforeDownload" }
                3 { "AutoDownloadNotifyInstall" }
                4 { "AutoDownloadScheduleInstall" }
                5 { "AllowLocalAdminChoose" }
                default { "Unknown ($($auReg.AUOptions))" }
            }
        }
    } catch {
        $result.Errors += "Could not read current settings: $($_.Exception.Message)"
    }

    $auOptionValue = switch ($UpdateMode) {
        "NeverCheck"                { 1 }
        "NotifyBeforeDownload"      { 2 }
        "AutoDownloadNotifyInstall" { 3 }
        "AutoDownloadScheduleInstall" { 4 }
        "AllowLocalAdminChoose"     { 5 }
    }

    try {
        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update"
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }
        Set-ItemProperty -Path $regPath -Name "AUOptions" -Value $auOptionValue -Type DWord -ErrorAction Stop
        Set-ItemProperty -Path $regPath -Name "ScheduledInstallDay" -Value $ScheduledInstallDay -Type DWord -ErrorAction Stop
        Set-ItemProperty -Path $regPath -Name "ScheduledInstallTime" -Value $ScheduledInstallTime -Type DWord -ErrorAction Stop

        Write-Log -Level "SUCCESS" -Category "System" -Message "Windows Update settings updated to: $UpdateMode"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "System" -Message "Failed to set update settings: $($_.Exception.Message)"
    }

    return $result
}

function global:Test-WindowsUpdateHealth {
    <#
    .SYNOPSIS
        Run Windows Update diagnostic.
    #>
    $result = @{
        Success  = $true
        Details  = @{
            Tests = @()
            OverallHealth = "Healthy"
        }
        Errors   = @()
    }

    Write-Log -Level "INFO" -Category "System" -Message "Running Windows Update health diagnostic..."

    $tests = @(
        @{
            Name = "WU Service Running"
            Test = { (Get-Service wuauserv -ErrorAction Stop).Status -eq "Running" }
            Fix = { Start-Service wuauserv -ErrorAction Stop }
        },
        @{
            Name = "BITS Service Running"
            Test = { (Get-Service bits -ErrorAction Stop).Status -eq "Running" }
            Fix = { Start-Service bits -ErrorAction Stop }
        },
        @{
            Name = "Cryptographic Service Running"
            Test = { (Get-Service cryptsvc -ErrorAction Stop).Status -eq "Running" }
            Fix = { Start-Service cryptsvc -ErrorAction Stop }
        },
        @{
            Name = "MSI Installer Service Running"
            Test = { (Get-Service msiserver -ErrorAction Stop).Status -eq "Running" }
            Fix = { Start-Service msiserver -ErrorAction Stop }
        },
        @{
            Name = "SoftwareDistribution Exists"
            Test = { Test-Path "$env:SystemRoot\SoftwareDistribution" }
            Fix = { New-Item -ItemType Directory -Path "$env:SystemRoot\SoftwareDistribution" -Force | Out-Null }
        },
        @{
            Name = "Catroot2 Exists"
            Test = { Test-Path "$env:SystemRoot\System32\catroot2" }
            Fix = { New-Item -ItemType Directory -Path "$env:SystemRoot\System32\catroot2" -Force | Out-Null }
        },
        @{
            Name = "WU COM Object Available"
            Test = {
                try { $null = New-Object -ComObject Microsoft.Update.Session; return $true }
                catch { return $false }
            }
            Fix = { & regsvr32.exe /s wuapi.dll }
        }
    )

    foreach ($test in $tests) {
        $testResult = @{
            Name   = $test.Name
            Passed = $false
            Error  = ""
        }

        try {
            $passed = & $test.Test
            $testResult.Passed = [bool]$passed
        } catch {
            $testResult.Error = $_.Exception.Message
        }

        if (-not $testResult.Passed) {
            $result.Details.OverallHealth = "Issues Found"
            Write-Log -Level "WARNING" -Category "System" -Message "Health check failed: $($test.Name)"

            try {
                & $test.Fix
                Write-Log -Level "INFO" -Category "System" -Message "Applied fix for: $($test.Name)"
                $testResult.Passed = $true
            } catch {
                $testResult.Error = "Fix failed: $($_.Exception.Message)"
                $result.Errors += "$($test.Name) : $($_.Exception.Message)"
            }
        }

        $result.Details.Tests += $testResult
    }

    if ($result.Details.OverallHealth -eq "Healthy") {
        Write-Log -Level "SUCCESS" -Category "System" -Message "Windows Update health check passed"
    } else {
        Write-Log -Level "WARNING" -Category "System" -Message "Windows Update health check found issues"
    }

    return $result
}
