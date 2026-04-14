<#
.SYNOPSIS
    WinTunePro DebloatMgr Module - Bloatware detection and removal
.DESCRIPTION
    Detects and removes known bloatware packages, provisioned packages,
    and startup entries. Maintains a database of known bloatware patterns.
.NOTES
    File: Modules\DebloatMgr\DebloatMgr.ps1
    Version: 1.0.0
    PowerShell: 5.1+
    Compatible: Windows 10, Windows 11
#>

#Requires -Version 5.1

$script:BloatwareDatabase = @(
    @{ Pattern = "*CandyCrush*"; Category = "Games"; Description = "Candy Crush Saga" }
    @{ Pattern = "*Facebook*"; Category = "Social"; Description = "Facebook" }
    @{ Pattern = "*Spotify*"; Category = "Music"; Description = "Spotify" }
    @{ Pattern = "*TikTok*"; Category = "Social"; Description = "TikTok" }
    @{ Pattern = "*Disney*"; Category = "Entertainment"; Description = "Disney+" }
    @{ Pattern = "*Netflix*"; Category = "Entertainment"; Description = "Netflix" }
    @{ Pattern = "*Clipchamp*"; Category = "Media"; Description = "Clipchamp Video Editor" }
    @{ Pattern = "*Xbox*"; Category = "Gaming"; Description = "Xbox apps" }
    @{ Pattern = "*Solitaire*"; Category = "Games"; Description = "Microsoft Solitaire Collection" }
    @{ Pattern = "*News*"; Category = "News"; Description = "Microsoft News" }
    @{ Pattern = "*Weather*"; Category = "Weather"; Description = "Weather app" }
    @{ Pattern = "*Sports*"; Category = "Sports"; Description = "Sports app" }
    @{ Pattern = "*Money*"; Category = "Finance"; Description = "Money app" }
    @{ Pattern = "*Food*"; Category = "Food"; Description = "Food & Drink app" }
    @{ Pattern = "*Travel*"; Category = "Travel"; Description = "Travel app" }
    @{ Pattern = "*Health*"; Category = "Health"; Description = "Health & Fitness app" }
    @{ Pattern = "*3DBuilder*"; Category = "Tools"; Description = "3D Builder" }
    @{ Pattern = "*GetHelp*"; Category = "Support"; Description = "Get Help app" }
    @{ Pattern = "*Getstarted*"; Category = "Tips"; Description = "Get Started tips" }
    @{ Pattern = "*People*"; Category = "Social"; Description = "People app" }
    @{ Pattern = "*FeedbackHub*"; Category = "Feedback"; Description = "Feedback Hub" }
    @{ Pattern = "*MixedReality*"; Category = "Mixed Reality"; Description = "Mixed Reality Portal" }
    @{ Pattern = "*ZuneMusic*"; Category = "Music"; Description = "Groove Music" }
    @{ Pattern = "*ZuneVideo*"; Category = "Video"; Description = "Movies & TV" }
    @{ Pattern = "*Office*"; Category = "Productivity"; Description = "Office trial/Hub" }
    @{ Pattern = "*OneNote*"; Category = "Productivity"; Description = "OneNote (Store)" }
    @{ Pattern = "*Skype*"; Category = "Communication"; Description = "Skype" }
    @{ Pattern = "*Teams*"; Category = "Communication"; Description = "Microsoft Teams (personal)" }
    @{ Pattern = "*YourPhone*"; Category = "Phone"; Description = "Phone Link" }
    @{ Pattern = "*king.*"; Category = "Games"; Description = "King games" }
    @{ Pattern = "*BubbleWitch*"; Category = "Games"; Description = "Bubble Witch" }
    @{ Pattern = "*HiddenCity*"; Category = "Games"; Description = "Hidden City" }
    @{ Pattern = "*MarchOfEmpires*"; Category = "Games"; Description = "March of Empires" }
    @{ Pattern = "*FarmVille*"; Category = "Games"; Description = "FarmVille" }
    @{ Pattern = "*Pandora*"; Category = "Music"; Description = "Pandora" }
    @{ Pattern = "*iHeartRadio*"; Category = "Music"; Description = "iHeartRadio" }
    @{ Pattern = "*Minecraft*"; Category = "Games"; Description = "Minecraft trial" }
    @{ Pattern = "*RoyalRevolt*"; Category = "Games"; Description = "Royal Revolt" }
    @{ Pattern = "*Autodesk*"; Category = "Trial"; Description = "Autodesk trial" }
    @{ Pattern = "*Duolingo*"; Category = "Education"; Description = "Duolingo" }
    @{ Pattern = "*Amazon*"; Category = "Shopping"; Description = "Amazon app" }
    @{ Pattern = "*EclipseManager*"; Category = "Tools"; Description = "Eclipse Manager" }
    @{ Pattern = "*NetworkSpeedTest*"; Category = "Tools"; Description = "Network Speed Test" }
    @{ Pattern = "*MicrosoftStickyNotes*"; Category = "Productivity"; Description = "Sticky Notes" }
    @{ Pattern = "*ScreenSketch*"; Category = "Tools"; Description = "Snip & Sketch" }
    @{ Pattern = "*WindowsMaps*"; Category = "Maps"; Description = "Windows Maps" }
    @{ Pattern = "*BingWeather*"; Category = "Weather"; Description = "Bing Weather" }
    @{ Pattern = "*BingNews*"; Category = "News"; Description = "Bing News" }
    @{ Pattern = "*BingFinance*"; Category = "Finance"; Description = "Bing Finance" }
    @{ Pattern = "*BingSports*"; Category = "Sports"; Description = "Bing Sports" }
    @{ Pattern = "*BingFoodAndDrink*"; Category = "Food"; Description = "Bing Food & Drink" }
    @{ Pattern = "*BingTravel*"; Category = "Travel"; Description = "Bing Travel" }
    @{ Pattern = "*BingHealthAndFitness*"; Category = "Health"; Description = "Bing Health & Fitness" }
)

$script:RemovalLog = @()

function global:Get-BloatwareDatabase {
    <#
    .SYNOPSIS
        Return database of known bloatware patterns.
    #>
    $result = @{
        Success  = $true
        Details  = $script:BloatwareDatabase
        Errors   = @()
    }

    Write-Log -Level "INFO" -Category "Optimization" -Message "Bloatware database contains $($script:BloatwareDatabase.Count) patterns"
    return $result
}

function global:Get-InstalledBloatware {
    <#
    .SYNOPSIS
        Scan for known bloatware packages.
    #>
    param(
        [Parameter()]
        [string]$CustomPattern = ""
    )

    $result = @{
        Success  = $true
        Details  = @()
        Errors   = @()
    }

    Write-Log -Level "INFO" -Category "Optimization" -Message "Scanning for installed bloatware..."

    try {
        $packages = Get-AppxPackage -AllUsers -ErrorAction Stop

        foreach ($pkg in $packages) {
            $matchedEntry = $null
            foreach ($entry in $script:BloatwareDatabase) {
                if ($pkg.Name -like $entry.Pattern) {
                    $matchedEntry = $entry
                    break
                }
            }

            if ($CustomPattern -and $pkg.Name -like "*$CustomPattern*") {
                $matchedEntry = @{ Pattern = $CustomPattern; Category = "Custom"; Description = "Custom match" }
            }

            if ($matchedEntry) {
                $result.Details += @{
                    PackageName  = $pkg.Name
                    PackageFullName = $pkg.PackageFullName
                    Version      = $pkg.Version.ToString()
                    Publisher    = $pkg.Publisher
                    InstallDate  = $pkg.InstallDate
                    Category     = $matchedEntry.Category
                    Description  = $matchedEntry.Description
                    Architecture = $pkg.Architecture.ToString()
                    IsFramework  = $pkg.IsFramework
                }
            }
        }

        Write-Log -Level "INFO" -Category "Optimization" -Message "Found $($result.Details.Count) bloatware packages"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "Optimization" -Message "Failed to scan for bloatware: $($_.Exception.Message)"
    }

    return $result
}

function global:Remove-BloatwarePackages {
    <#
    .SYNOPSIS
        Remove identified bloatware.
    #>
    param(
        [Parameter()]
        [string[]]$PackageNames = @(),

        [Parameter()]
        [switch]$WhatIf
    )

    $result = @{
        Success  = $true
        Details  = @{
            Removed  = @()
            Failed   = @()
            Skipped  = @()
        }
        Errors   = @()
    }

    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Errors += "Administrator privileges required"
        return $result
    }

    Write-Log -Level "INFO" -Category "Optimization" -Message "Removing bloatware packages..."

    try {
        if ($PackageNames.Count -eq 0) {
            $bloatware = Get-InstalledBloatware
            if (-not $bloatware.Success) {
                $result.Success = $false
                $result.Errors += $bloatware.Errors
                return $result
            }
            $PackageNames = $bloatware.Details | ForEach-Object { $_.PackageFullName }
        }

        foreach ($pkgName in $PackageNames) {
            if ($WhatIf) {
                $result.Details.Skipped += $pkgName
                Write-Log -Level "INFO" -Category "Optimization" -Message "Preview: Would remove $pkgName"
                continue
            }

            try {
                $pkg = Get-AppxPackage -AllUsers -Name ($pkgName -split "_")[0] -ErrorAction Stop
                if ($pkg) {
                    $pkg | Remove-AppxPackage -AllUsers -ErrorAction Stop
                    $result.Details.Removed += $pkgName
                    $script:RemovalLog += @{
                        PackageName = $pkgName
                        Timestamp   = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                        Action      = "Removed"
                    }
                    Write-Log -Level "SUCCESS" -Category "Optimization" -Message "Removed: $pkgName"
                } else {
                    $result.Details.Skipped += $pkgName
                }
            } catch {
                $result.Details.Failed += $pkgName
                $result.Errors += "Failed to remove $pkgName : $($_.Exception.Message)"
                Write-Log -Level "WARNING" -Category "Optimization" -Message "Failed to remove: $pkgName"
            }
        }

        Write-Log -Level "SUCCESS" -Category "Optimization" -Message "Removal complete: $($result.Details.Removed.Count) removed, $($result.Details.Failed.Count) failed"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "Optimization" -Message "Bloatware removal failed: $($_.Exception.Message)"
    }

    return $result
}

function global:Remove-BloatwareProvisioned {
    <#
    .SYNOPSIS
        Remove provisioned bloatware packages.
    #>
    param(
        [Parameter()]
        [switch]$WhatIf
    )

    $result = @{
        Success  = $true
        Details  = @{
            Removed = @()
            Failed  = @()
            Skipped = @()
        }
        Errors   = @()
    }

    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Errors += "Administrator privileges required"
        return $result
    }

    Write-Log -Level "INFO" -Category "Optimization" -Message "Scanning provisioned packages for bloatware..."

    try {
        $provisioned = Get-AppxProvisionedPackage -Online -ErrorAction Stop

        foreach ($pkg in $provisioned) {
            $isBloatware = $false
            foreach ($entry in $script:BloatwareDatabase) {
                if ($pkg.DisplayName -like $entry.Pattern) {
                    $isBloatware = $true
                    break
                }
            }

            if (-not $isBloatware) { continue }

            if ($WhatIf) {
                $result.Details.Skipped += $pkg.DisplayName
                Write-Log -Level "INFO" -Category "Optimization" -Message "Preview: Would remove provisioned $($pkg.DisplayName)"
                continue
            }

            try {
                Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction Stop
                $result.Details.Removed += $pkg.DisplayName
                $script:RemovalLog += @{
                    PackageName = $pkg.DisplayName
                    Timestamp   = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                    Action      = "ProvisionedRemoved"
                }
                Write-Log -Level "SUCCESS" -Category "Optimization" -Message "Removed provisioned: $($pkg.DisplayName)"
            } catch {
                $result.Details.Failed += $pkg.DisplayName
                $result.Errors += "Failed to remove provisioned $($pkg.DisplayName): $($_.Exception.Message)"
                Write-Log -Level "WARNING" -Category "Optimization" -Message "Failed to remove provisioned: $($pkg.DisplayName)"
            }
        }

        Write-Log -Level "SUCCESS" -Category "Optimization" -Message "Provisioned removal complete: $($result.Details.Removed.Count) removed, $($result.Details.Failed.Count) failed"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "Optimization" -Message "Provisioned package removal failed: $($_.Exception.Message)"
    }

    return $result
}

function global:Disable-BloatwareStartup {
    <#
    .SYNOPSIS
        Disable bloatware startup entries.
    #>
    param(
        [Parameter()]
        [switch]$WhatIf
    )

    $result = @{
        Success  = $true
        Details  = @{
            Disabled = @()
            Failed   = @()
        }
        Errors   = @()
    }

    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Errors += "Administrator privileges required"
        return $result
    }

    Write-Log -Level "INFO" -Category "Startup" -Message "Disabling bloatware startup entries..."

    $startupRegPaths = @(
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
    )

    foreach ($regPath in $startupRegPaths) {
        try {
            if (-not (Test-Path $regPath)) { continue }
            $props = Get-ItemProperty $regPath -ErrorAction SilentlyContinue
            $propNames = $props.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" }

            foreach ($prop in $propNames) {
                $isBloatware = $false
                foreach ($entry in $script:BloatwareDatabase) {
                    $patternBase = $entry.Pattern.Trim("*")
                    if ($prop.Name -like "*$patternBase*" -or $prop.Value -like "*$patternBase*") {
                        $isBloatware = $true
                        break
                    }
                }

                if (-not $isBloatware) { continue }

                if ($WhatIf) {
                    Write-Log -Level "INFO" -Category "Startup" -Message "Preview: Would disable $($prop.Name)"
                    continue
                }

                try {
                    Remove-ItemProperty -Path $regPath -Name $prop.Name -ErrorAction Stop
                    $result.Details.Disabled += @{
                        Name     = $prop.Name
                        Location = $regPath
                        Command  = $prop.Value
                    }
                    Write-Log -Level "SUCCESS" -Category "Startup" -Message "Disabled startup: $($prop.Name)"
                } catch {
                    $result.Details.Failed += $prop.Name
                    $result.Errors += "Failed to disable $($prop.Name): $($_.Exception.Message)"
                }
            }
        } catch {
            $result.Errors += "Failed to read $regPath : $($_.Exception.Message)"
        }
    }

    try {
        $tasks = Get-ScheduledTask -ErrorAction Stop | Where-Object {
            $_.TaskPath -notlike "\Microsoft\Windows\*"
        }
        foreach ($task in $tasks) {
            foreach ($entry in $script:BloatwareDatabase) {
                $patternBase = $entry.Pattern.Trim("*")
                if ($task.TaskName -like "*$patternBase*") {
                    if ($WhatIf) {
                        Write-Log -Level "INFO" -Category "Startup" -Message "Preview: Would disable task $($task.TaskName)"
                        continue
                    }
                    try {
                        Disable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction Stop
                        $result.Details.Disabled += @{
                            Name     = $task.TaskName
                            Location = "ScheduledTask: $($task.TaskPath)"
                            Command  = ($task.Actions | ForEach-Object { $_.Execute }) -join ", "
                        }
                        Write-Log -Level "SUCCESS" -Category "Startup" -Message "Disabled task: $($task.TaskName)"
                    } catch {
                        $result.Errors += "Failed to disable task $($task.TaskName): $($_.Exception.Message)"
                    }
                    break
                }
            }
        }
    } catch {
        $result.Errors += "Failed to check scheduled tasks: $($_.Exception.Message)"
    }

    Write-Log -Level "SUCCESS" -Category "Startup" -Message "Bloatware startup cleanup: $($result.Details.Disabled.Count) disabled"
    return $result
}

function global:Get-DebloatReport {
    <#
    .SYNOPSIS
        Generate report of what was removed.
    #>
    param(
        [Parameter()]
        [string]$OutputPath = ""
    )

    $result = @{
        Success  = $true
        Details  = @{
            TotalRemoved    = $script:RemovalLog.Count
            RemovalHistory  = $script:RemovalLog
            RemainingBloatware = @()
        }
        Errors   = @()
    }

    try {
        $current = Get-InstalledBloatware
        if ($current.Success) {
            $result.Details.RemainingBloatware = $current.Details
        }

        if ($OutputPath) {
            $parentDir = Split-Path $OutputPath -Parent
            if ($parentDir -and -not (Test-Path $parentDir)) {
                New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
            }

            $sb = New-Object System.Text.StringBuilder
            [void]$sb.AppendLine("=" * 80)
            [void]$sb.AppendLine("WinTunePro Debloat Report")
            [void]$sb.AppendLine("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
            [void]$sb.AppendLine("Computer: $env:COMPUTERNAME")
            [void]$sb.AppendLine("=" * 80)

            [void]$sb.AppendLine("`n--- REMOVED PACKAGES ($($result.Details.TotalRemoved)) ---")
            foreach ($item in $result.Details.RemovalHistory) {
                [void]$sb.AppendLine("  [$($item.Timestamp)] $($item.Action): $($item.PackageName)")
            }

            [void]$sb.AppendLine("`n--- REMAINING BLOATWARE ($($result.Details.RemainingBloatware.Count)) ---")
            foreach ($item in $result.Details.RemainingBloatware) {
                [void]$sb.AppendLine("  $($item.PackageName) ($($item.Category)) - $($item.Description)")
            }

            $sb.ToString() | Out-File -FilePath $OutputPath -Encoding UTF8
            Write-Log -Level "SUCCESS" -Category "Report" -Message "Debloat report exported to $OutputPath"
        }

        Write-Log -Level "INFO" -Category "Optimization" -Message "Debloat report: $($result.Details.TotalRemoved) removed, $($result.Details.RemainingBloatware.Count) remaining"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "Optimization" -Message "Failed to generate debloat report: $($_.Exception.Message)"
    }

    return $result
}

function global:Restore-BloatwarePackages {
    <#
    .SYNOPSIS
        Reinstall removed packages from Store.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$PackageNames,

        [Parameter()]
        [switch]$WhatIf
    )

    $result = @{
        Success  = $true
        Details  = @{
            Restored = @()
            Failed   = @()
        }
        Errors   = @()
    }

    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Errors += "Administrator privileges required"
        return $result
    }

    Write-Log -Level "INFO" -Category "Optimization" -Message "Restoring bloatware packages from Store..."

    foreach ($pkgName in $PackageNames) {
        if ($WhatIf) {
            Write-Log -Level "INFO" -Category "Optimization" -Message "Preview: Would reinstall $pkgName"
            continue
        }

        try {
            $storePkg = Get-AppxPackage -AllUsers -Name "*$pkgName*" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($storePkg) {
                Add-AppxPackage -Register "$($storePkg.InstallLocation)\AppxManifest.xml" -DisableDevelopmentMode -ErrorAction Stop
                $result.Details.Restored += $pkgName
                Write-Log -Level "SUCCESS" -Category "Optimization" -Message "Restored: $pkgName"
            } else {
                try {
                    $manifest = Get-ChildItem "$env:SystemRoot\WinStore\Packages\$pkgName*" -ErrorAction Stop | Select-Object -First 1
                    if ($manifest) {
                        Add-AppxPackage -Register "$($manifest.FullName)\AppxManifest.xml" -DisableDevelopmentMode -ErrorAction Stop
                        $result.Details.Restored += $pkgName
                        Write-Log -Level "SUCCESS" -Category "Optimization" -Message "Restored from store: $pkgName"
                    } else {
                        $result.Details.Failed += $pkgName
                        $result.Errors += "Package not found: $pkgName"
                    }
                } catch {
                    $result.Details.Failed += $pkgName
                    $result.Errors += "Failed to restore $pkgName : $($_.Exception.Message)"
                }
            }
        } catch {
            $result.Details.Failed += $pkgName
            $result.Errors += "Failed to restore $pkgName : $($_.Exception.Message)"
            Write-Log -Level "WARNING" -Category "Optimization" -Message "Failed to restore: $pkgName"
        }
    }

    Write-Log -Level "SUCCESS" -Category "Optimization" -Message "Restore complete: $($result.Details.Restored.Count) restored, $($result.Details.Failed.Count) failed"
    return $result
}
