# WinTune Pro - Helper Functions
# These are stub/wrapper functions for cross-module compatibility

function global:Cleanup-Image {
    param([switch]$Preview)
    if ($Preview) { return @{ Success = $true; Message = "[Preview] Would run DISM cleanup" } }
    try {
        $proc = Start-Process -FilePath "DISM.exe" -ArgumentList "/Online", "/Cleanup-Image", "/StartComponentCleanup" -Wait -PassThru -NoNewWindow
        return @{ Success = ($proc.ExitCode -eq 0); Message = "DISM cleanup completed" }
    } catch {
        return @{ Success = $false; Message = $_.Exception.Message }
    }
}

function global:Write-OperationLog {
    param([string]$Message, [string]$Category = "System")
    Write-Log -Level "INFO" -Category $Category -Message $Message
}

function global:Register-StartupChange {
    param([string]$Name, [string]$Action, [string]$Path = "")
    Write-Log -Level "INFO" -Category "Startup" -Message "$Action`: $Name"
    return @{ Name = $Name; Action = $Action; Path = $Path }
}

function global:Set-ServiceStartupType {
    param([string]$ServiceName, [string]$StartupType, [switch]$Preview)
    if ($Preview) { return $true }
    try {
        Set-Service -Name $ServiceName -StartupType $StartupType -ErrorAction SilentlyContinue
        return $true
    } catch { return $false }
}

function global:Register-Operation {
    param([string]$Name, [string]$Category = "System", [string]$Details = "")
    Write-Log -Level "INFO" -Category $Category -Message $Name
}

function global:Register-RollbackOperation {
    param([string]$OperationType, [string]$Target, [scriptblock]$RollbackCommand, [hashtable]$Metadata = @{}, [string]$Category = "System")
    Write-Log -Level "DEBUG" -Category $Category -Message "Rollback registered: $OperationType on $Target"
}

function global:Register-ServiceChange {
    param([string]$ServiceName, [string]$PreviousState, [string]$NewState, [string]$Category = "System")
    Write-Log -Level "INFO" -Category $Category -Message "Service $ServiceName`: $PreviousState -> $NewState"
}

function global:Register-NetworkChange {
    param([string]$ChangeType, [string]$Details, [string]$Category = "Network")
    Write-Log -Level "INFO" -Category $Category -Message "Network change: $ChangeType - $Details"
}

# Load-SettingsIntoUI is defined in MainWindow.ps1

function global:Get-StorageRecommendations {
    $recs = @{
        Disks = @()
        TotalUsedGB = 0
        TotalFreeGB = 0
        Recommendations = @()
    }
    try {
        $volumes = Get-Volume | Where-Object { $_.DriveLetter -and $_.Size -gt 0 }
        foreach ($vol in $volumes) {
            $usedGB = [math]::Round(($vol.Size - $vol.SizeRemaining) / 1GB, 1)
            $freeGB = [math]::Round($vol.SizeRemaining / 1GB, 1)
            $usedPercent = [math]::Round(($usedGB / ($usedGB + $freeGB)) * 100, 1)
            $recs.TotalUsedGB += $usedGB
            $recs.TotalFreeGB += $freeGB
            $recs.Disks += @{
                Drive = "$($vol.DriveLetter):"
                UsedGB = $usedGB
                FreeGB = $freeGB
                UsedPercent = $usedPercent
                Status = if ($usedPercent -gt 90) { "Critical" } elseif ($usedPercent -gt 80) { "Warning" } else { "Good" }
            }
            if ($usedPercent -gt 90) {
                $recs.Recommendations += "Drive $($vol.DriveLetter): is $usedPercent% full - clean up immediately"
            } elseif ($usedPercent -gt 80) {
                $recs.Recommendations += "Drive $($vol.DriveLetter): is $usedPercent% full - consider cleaning"
            }
        }
    } catch { }
    return $recs
}

function global:Invoke-StorageOptimization {
    param([bool]$TestMode = $false)
    $results = @{ Actions = @(); SpaceRecovered = 0; Success = $true }
    if ($TestMode) {
        $results.Actions += "[Preview] Would optimize storage"
        return $results
    }
    try {
        $trim = Get-TRIMStatus
        if ($trim.Supported -and -not $trim.Enabled) {
            if (Enable-TRIM) { $results.Actions += "Enabled TRIM" }
        }
        if (Enable-StorageSense -Enable $true) { $results.Actions += "Enabled Storage Sense" }
        $trimResult = Invoke-TRIMOptimization
        if ($trimResult.Success) { $results.Actions += $trimResult.Actions }
        Write-Log -Level "SUCCESS" -Category "Storage" -Message "Storage optimization complete"
    } catch { }
    return $results
}

function global:Write-ProgressBar {
    param(
        [int]$Percent,
        [string]$Activity = "Processing",
        [string]$Status = "",
        [int]$Width = 40
    )
    
    if ($Percent -lt 0) { $Percent = 0 }
    if ($Percent -gt 100) { $Percent = 100 }
    
    $filled = [math]::Floor($Percent / 100 * $Width)
    $empty = $Width - $filled
    $bar = "[" + ("#" * $filled) + ("." * $empty) + "]"
    
    $color = if ($Percent -ge 80) { "Green" } elseif ($Percent -ge 50) { "Yellow" } else { "Cyan" }
    
    Write-Host "`r $Activity $bar $Percent%" -NoNewline -ForegroundColor $color
    
    if ($Status) {
        Write-Host " - $Status" -NoNewline -ForegroundColor DarkGray
    }
    
    if ($Percent -ge 100) {
        Write-Host " [DONE]" -ForegroundColor Green
    }
}

function global:Write-Header {
    param([string]$Text, [string]$Color = "Cyan")
    Write-Host ""
    Write-Host "====================================================" -ForegroundColor DarkGray
    Write-Host "  $Text" -ForegroundColor $Color
    Write-Host "====================================================" -ForegroundColor DarkGray
}

function global:Write-Step {
    param([string]$Text, [string]$Status = "Running")
    $icon = switch ($Status) {
        "Running" { "[...]" }
        "Done"    { "[OK]" }
        "Error"   { "[ERR]" }
        "Skip"    { "[---]" }
        default   { "[   ]" }
    }
    $color = switch ($Status) {
        "Running" { "Yellow" }
        "Done"    { "Green" }
        "Error"   { "Red" }
        "Skip"    { "DarkGray" }
        default   { "White" }
    }
    Write-Host "  $icon $Text" -ForegroundColor $color
}

function global:Write-Summary {
    param([string]$Title, [hashtable]$Stats)
    Write-Host ""
    Write-Host "  === $Title ===" -ForegroundColor Cyan
    foreach ($key in $Stats.Keys) {
        $value = $Stats[$key]
        $color = if ($value -is [bool] -and $value) { "Green" } elseif ($value -is [bool] -and -not $value) { "Red" } else { "White" }
        Write-Host "    $key : $value" -ForegroundColor $color
    }
    Write-Host ""
}

# UI functions are defined in MainWindow.ps1
# Update-DashboardStats, Update-Status, Add-ActivityLog are not duplicated here

function global:Show-CleaningPreview {
    param([string[]]$Categories = @("UserTemp","SystemTemp","WUCache","ThumbnailCache","ChromeCache"))
    
    Write-Host ""
    Write-Host "  === CLEANING PREVIEW ===" -ForegroundColor Cyan
    Write-Host ""
    $total = 0
    foreach ($cat in $Categories) {
        $r = Invoke-Cleaning -Categories @($cat) -TestMode $true
        $freed = if ($r.TotalFreed) { $r.TotalFreed } else { 0 }
        $total += $freed
        $status = if ($freed -gt 0) { "Will free" } else { "Nothing" }
        $color = if ($freed -gt 0) { "Green" } else { "DarkGray" }
        Write-Host "    $($cat.PadRight(20)) $([math]::Round($freed,2)) MB ($status)" -ForegroundColor $color
    }
    Write-Host ""
    Write-Host "    TOTAL: $([math]::Round($total,2)) MB" -ForegroundColor Cyan
    Write-Host ""
    return $total
}

function global:Invoke-SafeCleaning {
    param(
        [string[]]$Categories = @("UserTemp","SystemTemp","WUCache","RecycleBin","ThumbnailCache","ChromeCache","FirefoxCache","WindowsLogs","CBSLogs","RecentDocs"),
        [bool]$TestMode = $false
    )
    
    $results = @{
        Actions = @()
        SpaceRecovered = 0
        BeforeFree = $null
        AfterFree = $null
        Duration = 0
    }
    
    # Get before state
    $disk = Get-CachedCimInstance "Win32_LogicalDisk" "DeviceID='C:'"
    if ($disk) { $results.BeforeFree = $disk.FreeSpace }
    
    # Scan before clean
    Write-Host "  Scanning..." -ForegroundColor DarkGray
    $preview = Show-CleaningPreview -Categories $Categories
    
    # Clean
    $start = Get-Date
    $total = 0
    $i = 0
    foreach ($cat in $Categories) {
        $i++
        Write-Progress -Activity "Cleaning" -Status $cat -PercentComplete ($i * 100 / $Categories.Count)
        try {
            $r = Invoke-Cleaning -Categories @($cat) -TestMode $TestMode
            $freed = if ($r.TotalFreed) { $r.TotalFreed } else { 0 }
            $total += $freed
            $results.Actions += "$cat`: $([math]::Round($freed,2)) MB"
        } catch {
            $results.Actions += "$cat`: error"
        }
    }
    Write-Progress -Activity "Cleaning" -Completed
    $results.SpaceRecovered = $total
    $results.Duration = [math]::Round(((Get-Date) - $start).TotalSeconds, 1)
    
    # Get after state
    $disk = Get-CachedCimInstance "Win32_LogicalDisk" "DeviceID='C:'"
    if ($disk) { $results.AfterFree = $disk.FreeSpace }
    
    # Show comparison
    if ($results.BeforeFree -and $results.AfterFree) {
        $beforeGB = [math]::Round($results.BeforeFree / 1GB, 2)
        $afterGB = [math]::Round($results.AfterFree / 1GB, 2)
        $changeGB = [math]::Round(($results.AfterFree - $results.BeforeFree) / 1GB, 2)
        $results.Actions += "Disk C: $beforeGB GB -> $afterGB GB ($changeGB GB)"
    }
    
    return $results
}

function global:Show-Notification {
    param([string]$Title, [string]$Message)
    
    Write-Host ""
    Write-Host "  === $Title ===" -ForegroundColor Green
    Write-Host "  $Message" -ForegroundColor White
    Write-Host ""
    
    try { [System.Media.SystemSounds]::Asterisk.Play() } catch { }
}

function global:Show-Header([string]$Text) {
    Write-Host ""
    Write-Host "  === $Text ===" -ForegroundColor Cyan
    Write-Host ""
}

function global:Show-Step([string]$Text, [string]$Status = "OK") {
    $icon = switch ($Status) { "OK" {"[OK]"} "RUN" {"[..]"} "ERR" {"[!!]"} "SKIP" {"[--]"} }
    $color = switch ($Status) { "OK" {"Green"} "RUN" {"Yellow"} "ERR" {"Red"} "SKIP" {"DarkGray"} }
    Write-Host "  $icon $Text" -ForegroundColor $color
}

function global:Show-Result([string]$Label, [string]$Value) {
    Write-Host "    $Label : " -NoNewline -ForegroundColor DarkGray
    Write-Host $Value -ForegroundColor Cyan
}

