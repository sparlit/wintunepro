<#
.SYNOPSIS
    WinTune Pro UI Tuning Module
.DESCRIPTION
    Windows UI optimization and responsiveness tuning including visual effects,
    animation settings, and interface performance enhancements.
#>

# ============================================================================
# UI DIAGNOSTICS
# ============================================================================

function global:Get-UIPerformanceStatus {
    $uiStatus = @{
        VisualEffectsSetting = 0; AnimationsEnabled = $false; TransparencyEnabled = $false
        PeekEnabled = $false; ComboBoxAnimation = $false; ListBoxAnimation = $false
        MenuAnimation = $false; TooltipAnimation = $false; DragFullWindows = $false
        FontSmoothing = $false; ShowThumbnails = $false; DesktopComposition = $false
        OverallScore = 100; Recommendations = @()
    }
    try {
        $visualPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
        $visualSetting = Get-ItemProperty -Path $visualPath -Name "VisualFXSetting" -ErrorAction SilentlyContinue
        if ($visualSetting) { $uiStatus.VisualEffectsSetting = $visualSetting.VisualFXSetting }
        $sysPath = "HKCU:\Control Panel\Desktop"
        $desktopSettings = Get-ItemProperty -Path $sysPath -ErrorAction SilentlyContinue
        if ($desktopSettings) {
            $uiSettings = $desktopSettings.UserPreferencesMask
            if ($uiSettings -and $uiSettings.Count -gt 0) {
                try { $maskBytes = [Convert]::ToString($uiSettings[0], 2).PadLeft(8, '0'); $uiStatus.AnimationsEnabled = $desktopSettings.MenuShowDelay -lt 400 } catch { $uiStatus.AnimationsEnabled = $true }
                $uiStatus.DragFullWindows = $desktopSettings.DragFullWindows -eq "1"
                $uiStatus.FontSmoothing = $desktopSettings.FontSmoothing -eq "2"
            }
        }
        $advSettings = Get-ItemProperty -Path $sysPath -ErrorAction SilentlyContinue
        if ($advSettings) { $uiStatus.MenuShowDelay = [int]$advSettings.MenuShowDelay; $uiStatus.WaitToKillAppTimeout = $advSettings.WaitToKillAppTimeout }
        $win10Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
        $win10Settings = Get-ItemProperty -Path $win10Path -ErrorAction SilentlyContinue
        if ($win10Settings) { $uiStatus.TransparencyEnabled = $win10Settings.EnableTransparency -eq 1 }
        $peekPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        $peekSettings = Get-ItemProperty -Path $peekPath -ErrorAction SilentlyContinue
        if ($peekSettings) { $uiStatus.PeekEnabled = $peekSettings.DisablePreviewDesktop -eq 0; $uiStatus.ShowThumbnails = $peekSettings.ShowTypeOverlayText -eq 1; $uiStatus.ThumbnailPreview = $peekSettings.ThumbnailPreview -ne 0 }
        $uiStatus.OverallScore = Calculate-UIScore $uiStatus
        $uiStatus.Recommendations = Get-UIRecommendations $uiStatus
    } catch { Write-Log -Message "Error getting UI status: $($_.Exception.Message)" -Level 'Error' -Category 'UITuning' }
    return $uiStatus
}

function global:Calculate-UIScore {
    param($Status)
    $score = 100
    if ($Status.AnimationsEnabled) { $score -= 10 }; if ($Status.TransparencyEnabled) { $score -= 15 }
    if ($Status.PeekEnabled) { $score -= 5 }; if ($Status.DragFullWindows) { $score -= 5 }
    if ($Status.MenuShowDelay -gt 200) { $score -= 5 }
    if ($Status.VisualEffectsSetting -eq 1) { $score -= 20 }; if ($Status.VisualEffectsSetting -eq 3) { $score -= 10 }
    return [Math]::Max(0, [Math]::Min(100, $score))
}

function global:Get-UIRecommendations {
    param($Status)
    $recommendations = @()
    if ($Status.VisualEffectsSetting -eq 1) { $recommendations += "Change visual effects to 'Best performance' or custom" }
    if ($Status.AnimationsEnabled) { $recommendations += "Disable animations for faster UI response" }
    if ($Status.TransparencyEnabled) { $recommendations += "Disable transparency effects to reduce GPU load" }
    if ($Status.MenuShowDelay -gt 100) { $recommendations += "Reduce menu show delay for faster menu response" }
    if ($recommendations.Count -eq 0) { $recommendations += "UI settings are already optimized" }
    return $recommendations
}

# ============================================================================
# VISUAL EFFECTS OPTIMIZATION
# ============================================================================

function global:Set-VisualEffectsPerformance {
    param(
        [ValidateSet("BestAppearance","BestPerformance","Custom","LetWindowsChoose")]
        [string]$Mode = "BestPerformance",
        [switch]$Preview, [switch]$KeepFontSmoothing, [switch]$KeepThumbnails, [switch]$KeepBasicAnimations
    )
    $result = @{ Success = $true; Message = ""; Changes = @(); PreviousSettings = @{}; Errors = @() }
    if ($Preview) { $result.Message = "[PREVIEW] Would set visual effects to: $Mode"; return $result }
    Write-Log -Message "Setting visual effects to: $Mode" -Level 'Info' -Category 'UITuning'
    try {
        $visualPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
        $current = Get-ItemProperty -Path $visualPath -ErrorAction SilentlyContinue
        $result.PreviousSettings = @{ VisualFXSetting = $current.VisualFXSetting }
        $modeValue = switch ($Mode) { "BestAppearance" { 1 }; "BestPerformance" { 2 }; "Custom" { 0 }; "LetWindowsChoose" { 3 } }
        Set-ItemProperty -Path $visualPath -Name "VisualFXSetting" -Value $modeValue -Force
        $result.Changes += "Visual effects mode set to: $Mode"
        if ($Mode -eq "BestPerformance") {
            $desktopPath = "HKCU:\Control Panel\Desktop"; $advPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
            $perfMask = @(0x90, 0x12, 0x03, 0x80, 0x10, 0x00, 0x00, 0x00)
            if ($KeepFontSmoothing) { $perfMask[0] = $perfMask[0] -bor 0x40 }
            if ($KeepThumbnails) { $perfMask[3] = $perfMask[3] -bor 0x20 }
            Set-ItemProperty -Path $desktopPath -Name "UserPreferencesMask" -Value $perfMask -Force
            $result.Changes += "Performance-optimized UserPreferencesMask applied"
            Set-ItemProperty -Path $desktopPath -Name "DragFullWindows" -Value "0" -Force
            Set-ItemProperty -Path $desktopPath -Name "FontSmoothing" -Value "2" -Force
            Set-ItemProperty -Path $desktopPath -Name "MenuShowDelay" -Value "0" -Force
            $personalizePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
            Set-ItemProperty -Path $personalizePath -Name "EnableTransparency" -Value 0 -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $advPath -Name "TaskbarAnimations" -Value 0 -Force -ErrorAction SilentlyContinue
            $result.Changes += "Transparency effects disabled"; $result.Changes += "Taskbar animations disabled"
        }
        if ($Mode -eq "Custom") {
            $desktopPath = "HKCU:\Control Panel\Desktop"
            if ($KeepFontSmoothing) { Set-ItemProperty -Path $desktopPath -Name "FontSmoothing" -Value "2" -Force }
            if ($KeepThumbnails) { $advPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Set-ItemProperty -Path $advPath -Name "IconsOnly" -Value 0 -Force }
            if (-not $KeepBasicAnimations) { Set-ItemProperty -Path $desktopPath -Name "MenuShowDelay" -Value "0" -Force }
        }
        $result.Message = "Visual effects configured successfully"
        Write-Log -Message $result.Message -Level 'Success' -Category 'UITuning'
    } catch {
        $result.Success = $false; $result.Errors += $_.Exception.Message
        $result.Message = "Failed to configure visual effects"
        Write-Log -Message $result.Message -Level 'Error' -Category 'UITuning'
    }
    return $result
}

function global:Disable-UIAnimations {
    param([switch]$Preview, [switch]$IncludeTransitions, [switch]$IncludeTaskbar)
    $result = @{ Success = $true; Message = ""; Changes = @(); Errors = @() }
    if ($Preview) { $result.Message = "[PREVIEW] Would disable UI animations"; return $result }
    Write-Log -Message "Disabling UI animations..." -Level 'Info' -Category 'UITuning'
    try {
        $desktopPath = "HKCU:\Control Panel\Desktop"; $advPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        Set-ItemProperty -Path $desktopPath -Name "MenuShowDelay" -Value "0" -Force; $result.Changes += "Menu show delay set to 0ms"
        $prefMask = Get-ItemProperty -Path $desktopPath -Name "UserPreferencesMask" -ErrorAction SilentlyContinue
        if ($prefMask) { $bytes = $prefMask.UserPreferencesMask; $bytes[0] = $bytes[0] -band 0xDF; Set-ItemProperty -Path $desktopPath -Name "UserPreferencesMask" -Value $bytes -Force; $result.Changes += "Window animations disabled" }
        Set-ItemProperty -Path $desktopPath -Name "ComboBoxAnimation" -Value "0" -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $desktopPath -Name "ListBoxAnimation" -Value "0" -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $desktopPath -Name "MenuAnimation" -Value "0" -Force -ErrorAction SilentlyContinue
        if ($IncludeTaskbar) { Set-ItemProperty -Path $advPath -Name "TaskbarAnimations" -Value 0 -Force -ErrorAction SilentlyContinue; $result.Changes += "Taskbar animations disabled" }
        if ($IncludeTransitions) { Set-ItemProperty -Path $advPath -Name "EnableXamlAnimations" -Value 0 -Force -ErrorAction SilentlyContinue; Set-ItemProperty -Path $advPath -Name "EnableTransparency" -Value 0 -Force -ErrorAction SilentlyContinue; $result.Changes += "Transition effects disabled" }
        $result.Message = "UI animations disabled: $($result.Changes.Count) changes"
        Write-Log -Message $result.Message -Level 'Success' -Category 'UITuning'
    } catch { $result.Success = $false; $result.Errors += $_.Exception.Message }
    return $result
}

function global:Optimize-UIResponsiveness {
    param([switch]$Preview, [switch]$Aggressive)
    $result = @{ Success = $true; Message = ""; Changes = @(); Errors = @() }
    if ($Preview) { $result.Message = "[PREVIEW] Would optimize UI responsiveness"; return $result }
    Write-Log -Message "Optimizing UI responsiveness..." -Level 'Info' -Category 'UITuning'
    try {
        $desktopPath = "HKCU:\Control Panel\Desktop"
        Set-ItemProperty -Path $desktopPath -Name "ForegroundLockTimeout" -Value "0" -Force; $result.Changes += "Foreground lock timeout minimized"
        Set-ItemProperty -Path $desktopPath -Name "MenuShowDelay" -Value "0" -Force; $result.Changes += "Menu delay set to 0ms"
        Set-ItemProperty -Path $desktopPath -Name "WaitToKillAppTimeout" -Value "2000" -Force
        Set-ItemProperty -Path $desktopPath -Name "HungAppTimeout" -Value "1000" -Force; $result.Changes += "Application timeout optimized"
        Set-ItemProperty -Path $desktopPath -Name "AutoEndTasks" -Value "1" -Force; $result.Changes += "Auto-end tasks enabled"
        Set-ItemProperty -Path $desktopPath -Name "LowLevelHooksTimeout" -Value "1000" -Force -ErrorAction SilentlyContinue
        if ($Aggressive) { Set-ItemProperty -Path $desktopPath -Name "WaitToKillServiceTimeout" -Value "2000" -Force -ErrorAction SilentlyContinue; $result.Changes += "Service kill timeout reduced" }
        $result.Message = "UI responsiveness optimized: $($result.Changes.Count) changes"
        Write-Log -Message $result.Message -Level 'Success' -Category 'UITuning'
    } catch { $result.Success = $false; $result.Errors += $_.Exception.Message }
    return $result
}

function global:Optimize-ExplorerPerformance {
    param([switch]$Preview, [switch]$DisableThumbnails, [switch]$DisableSearchIndexing)
    $result = @{ Success = $true; Message = ""; Changes = @(); Errors = @() }
    if ($Preview) { $result.Message = "[PREVIEW] Would optimize Explorer performance"; return $result }
    Write-Log -Message "Optimizing Explorer performance..." -Level 'Info' -Category 'UITuning'
    try {
        $advPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        if ($DisableThumbnails) { Set-ItemProperty -Path $advPath -Name "IconsOnly" -Value 1 -Force; $result.Changes += "Thumbnail previews disabled" }
        Set-ItemProperty -Path $advPath -Name "ShowTypeOverlay" -Value 1 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $advPath -Name "ShowStatusBar" -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $advPath -Name "ShowInfoTip" -Value 0 -Force -ErrorAction SilentlyContinue; $result.Changes += "Info tips disabled"
        Set-ItemProperty -Path $advPath -Name "DisablePreviewDesktop" -Value 1 -Force -ErrorAction SilentlyContinue; $result.Changes += "Aero Peek disabled"
        $folderPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"
        Set-ItemProperty -Path $folderPath -Name "Max Cached Icons" -Value 4096 -Force -ErrorAction SilentlyContinue
        $searchPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Search"
        Set-ItemProperty -Path $searchPath -Name "SearchboxSuggestions" -Value 0 -Force -ErrorAction SilentlyContinue
        $result.Message = "Explorer performance optimized: $($result.Changes.Count) changes"
        Write-Log -Message $result.Message -Level 'Success' -Category 'UITuning'
    } catch { $result.Success = $false; $result.Errors += $_.Exception.Message }
    return $result
}

function global:Optimize-TaskbarPerformance {
    param([switch]$Preview, [switch]$DisableAnimations, [switch]$DisableTransparency, [switch]$DisableSearchBox)
    $result = @{ Success = $true; Message = ""; Changes = @(); Errors = @() }
    if ($Preview) { $result.Message = "[PREVIEW] Would optimize taskbar performance"; return $result }
    Write-Log -Message "Optimizing taskbar..." -Level 'Info' -Category 'UITuning'
    try {
        $advPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        if ($DisableAnimations) { Set-ItemProperty -Path $advPath -Name "TaskbarAnimations" -Value 0 -Force; $result.Changes += "Taskbar animations disabled" }
        if ($DisableTransparency) { $personalizePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"; Set-ItemProperty -Path $personalizePath -Name "EnableTransparency" -Value 0 -Force; $result.Changes += "Taskbar transparency disabled" }
        if ($DisableSearchBox) { $searchPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"; Set-ItemProperty -Path $searchPath -Name "SearchboxTaskbarMode" -Value 0 -Force -ErrorAction SilentlyContinue; $result.Changes += "Search box hidden" }
        Set-ItemProperty -Path $advPath -Name "ExtendedUIHoverTime" -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $advPath -Name "TaskbarDa" -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $advPath -Name "TaskbarMn" -Value 0 -Force -ErrorAction SilentlyContinue; $result.Changes += "Widgets disabled"
        $result.Message = "Taskbar optimized: $($result.Changes.Count) changes"
        Write-Log -Message $result.Message -Level 'Success' -Category 'UITuning'
    } catch { $result.Success = $false; $result.Errors += $_.Exception.Message }
    return $result
}

function global:Optimize-StartMenuPerformance {
    param([switch]$Preview, [switch]$DisableSuggestions, [switch]$DisableRecentFiles)
    $result = @{ Success = $true; Message = ""; Changes = @(); Errors = @() }
    if ($Preview) { $result.Message = "[PREVIEW] Would optimize Start Menu performance"; return $result }
    Write-Log -Message "Optimizing Start Menu..." -Level 'Info' -Category 'UITuning'
    try {
        $advPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        if ($DisableSuggestions) {
            Set-ItemProperty -Path $advPath -Name "Start_TrackProgs" -Value 0 -Force
            Set-ItemProperty -Path $advPath -Name "Start_TrackDocs" -Value 0 -Force; $result.Changes += "Start Menu tracking disabled"
            $suggPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
            Set-ItemProperty -Path $suggPath -Name "SubscribedContent-338388Enabled" -Value 0 -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $suggPath -Name "SubscribedContent-338389Enabled" -Value 0 -Force -ErrorAction SilentlyContinue
        }
        if ($DisableRecentFiles) { Set-ItemProperty -Path $advPath -Name "Start_ShowRecentPins" -Value 0 -Force -ErrorAction SilentlyContinue }
        $startPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize"
        if (-not (Test-Path $startPath)) { New-Item -Path $startPath -Force | Out-Null }
        Set-ItemProperty -Path $startPath -Name "StartupDelayInMSec" -Value 0 -Force -ErrorAction SilentlyContinue
        $result.Message = "Start Menu optimized: $($result.Changes.Count) changes"
        Write-Log -Message $result.Message -Level 'Success' -Category 'UITuning'
    } catch { $result.Success = $false; $result.Errors += $_.Exception.Message }
    return $result
}

# ============================================================================
# COMPREHENSIVE UI OPTIMIZATION
# ============================================================================

function global:Invoke-CompleteUIOptimization {
    param([switch]$Preview, [switch]$Aggressive, [switch]$KeepFontSmoothing, [switch]$KeepThumbnails)
    $result = @{ Success = $true; Message = ""; TotalChanges = 0; VisualEffects = $null; Responsiveness = $null; Explorer = $null; Taskbar = $null; StartMenu = $null; Errors = @() }
    Write-Log -Message "Starting complete UI optimization..." -Level 'Info' -Category 'UITuning'
    $result.VisualEffects = Set-VisualEffectsPerformance -Mode "BestPerformance" -Preview:$Preview -KeepFontSmoothing:$KeepFontSmoothing -KeepThumbnails:$KeepThumbnails
    $result.TotalChanges += $result.VisualEffects.Changes.Count
    $result.Responsiveness = Optimize-UIResponsiveness -Preview:$Preview -Aggressive:$Aggressive
    $result.TotalChanges += $result.Responsiveness.Changes.Count
    $result.Explorer = Optimize-ExplorerPerformance -Preview:$Preview -DisableThumbnails:(-not $KeepThumbnails)
    $result.TotalChanges += $result.Explorer.Changes.Count
    $result.Taskbar = Optimize-TaskbarPerformance -Preview:$Preview -DisableAnimations -DisableTransparency
    $result.TotalChanges += $result.Taskbar.Changes.Count
    $result.StartMenu = Optimize-StartMenuPerformance -Preview:$Preview -DisableSuggestions
    $result.TotalChanges += $result.StartMenu.Changes.Count
    if ($result.VisualEffects.Errors) { $result.Errors += $result.VisualEffects.Errors }
    if ($result.Responsiveness.Errors) { $result.Errors += $result.Responsiveness.Errors }
    if ($result.Explorer.Errors) { $result.Errors += $result.Explorer.Errors }
    if ($result.Taskbar.Errors) { $result.Errors += $result.Taskbar.Errors }
    if ($result.StartMenu.Errors) { $result.Errors += $result.StartMenu.Errors }
    $result.Message = "Complete UI optimization finished: $([Math]::Max(0, $result.TotalChanges)) total changes"
    Write-Log -Message $result.Message -Level 'Success' -Category 'UITuning'
    $script:State.OperationsExecuted += "CompleteUIOptimization"
    return $result
}

function global:Restore-UISettings {
    param([switch]$Preview)
    $result = @{ Success = $true; Message = ""; Changes = @(); Errors = @() }
    if ($Preview) { $result.Message = "[PREVIEW] Would restore UI settings to default"; return $result }
    Write-Log -Message "Restoring UI settings to default..." -Level 'Info' -Category 'UITuning'
    try {
        $visualPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
        Set-ItemProperty -Path $visualPath -Name "VisualFXSetting" -Value 3 -Force; $result.Changes += "Visual effects: Let Windows choose"
        $desktopPath = "HKCU:\Control Panel\Desktop"
        Set-ItemProperty -Path $desktopPath -Name "MenuShowDelay" -Value "400" -Force; $result.Changes += "Menu delay restored to 400ms"
        Set-ItemProperty -Path $desktopPath -Name "DragFullWindows" -Value "1" -Force -ErrorAction SilentlyContinue
        $personalizePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
        Set-ItemProperty -Path $personalizePath -Name "EnableTransparency" -Value 1 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $desktopPath -Name "ForegroundLockTimeout" -Value "200000" -Force
        Set-ItemProperty -Path $desktopPath -Name "WaitToKillAppTimeout" -Value "20000" -Force
        Set-ItemProperty -Path $desktopPath -Name "HungAppTimeout" -Value "5000" -Force
        Set-ItemProperty -Path $desktopPath -Name "AutoEndTasks" -Value "0" -Force; $result.Changes += "Shutdown timeouts restored"
        $result.Message = "UI settings restored to default: $($result.Changes.Count) changes"
        Write-Log -Message $result.Message -Level 'Success' -Category 'UITuning'
    } catch { $result.Success = $false; $result.Errors += $_.Exception.Message }
    return $result
}
