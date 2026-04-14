# SophiaIntegration.ps1
# Sophia Script for Windows 10 v6.1.4 - WinTune Pro integration wrapper
# Powered by https://github.com/farag2/Sophia-Script-for-Windows

function global:Initialize-SophiaIntegration {
    $sophiaRoot = Join-Path $PSScriptRoot "Sophia"
    $manifestPath = Join-Path $sophiaRoot "Manifest\SophiaScript.psd1"

    if (-not (Test-Path $manifestPath)) {
        Log-Warning "Sophia Script not found at: $sophiaRoot" -Category "Sophia"
        return $false
    }

    try {
        # Unload any previously loaded instance
        Get-ChildItem function: | Where-Object { $_.ScriptBlock.File -match "SophiaScript" } | Remove-Item -Force -ErrorAction Ignore
        Remove-Module -Name SophiaScript -Force -ErrorAction Ignore

        # Import the Sophia module manifest
        Import-Module -Name $manifestPath -PassThru -Force -ErrorAction Stop | Out-Null

        # Load private helper functions required by Sophia
        $privatePath = Join-Path $sophiaRoot "Module\Private"
        if (Test-Path $privatePath) {
            Get-ChildItem -Path $privatePath -Filter "*.ps1" | ForEach-Object {
                . $_.FullName
            }
        }

        Log-Info "Sophia Script v6.1.4 loaded successfully" -Category "Sophia"
        return $true
    } catch {
        Log-Warning "Failed to load Sophia Script: $($_.Exception.Message)" -Category "Sophia"
        return $false
    }
}

function global:Invoke-SophiaTweaks {
    param(
        [hashtable]$SelectedTweaks,
        [bool]$TestMode = $false
    )

    if (-not (Initialize-SophiaIntegration)) {
        return @{
            Success = $false
            Actions = @("Sophia Script module not available - check Modules\SophiaScript\Sophia\ folder")
            Errors  = @()
            Total   = 0
        }
    }

    $actions = [System.Collections.Generic.List[string]]::new()
    $errors  = [System.Collections.Generic.List[string]]::new()

    # Helper: run one tweak safely
    function Run-Tweak {
        param([string]$Label, [scriptblock]$Code)
        if ($TestMode) {
            $actions.Add("[Test Mode] Would apply: $Label")
            return
        }
        try {
            & $Code
            $actions.Add("Applied: $Label")
            Log-Info "Sophia tweak applied: $Label" -Category "Sophia"
        } catch {
            $errors.Add("Failed - ${Label}: $($_.Exception.Message)")
            Log-Warning "Sophia tweak failed: ${Label} - $($_.Exception.Message)" -Category "Sophia"
        }
    }

    # ── Privacy & Telemetry ────────────────────────────────────────────────
    if ($SelectedTweaks.DiagTrackService)     { Run-Tweak "Disable Telemetry Service (DiagTrack)"        { DiagTrackService -Disable } }
    if ($SelectedTweaks.DiagnosticDataLevel)  { Run-Tweak "Minimal Diagnostic Data Collection"           { DiagnosticDataLevel -Minimal } }
    if ($SelectedTweaks.ErrorReporting)       { Run-Tweak "Disable Windows Error Reporting"               { ErrorReporting -Disable } }
    if ($SelectedTweaks.FeedbackFrequency)    { Run-Tweak "Set Feedback Frequency to Never"               { FeedbackFrequency -Never } }
    if ($SelectedTweaks.AdvertisingID)        { Run-Tweak "Disable Advertising ID"                        { AdvertisingID -Disable } }
    if ($SelectedTweaks.TailoredExperiences)  { Run-Tweak "Disable Tailored Experiences"                  { TailoredExperiences -Disable } }
    if ($SelectedTweaks.BingSearch)           { Run-Tweak "Disable Bing Search in Start Menu"             { BingSearch -Disable } }
    if ($SelectedTweaks.AppsSilentInstalling) { Run-Tweak "Disable Silent App Suggestions Install"        { AppsSilentInstalling -Disable } }
    if ($SelectedTweaks.SigninInfo)           { Run-Tweak "Disable Sign-in Info Reuse After Update"       { SigninInfo -Disable } }
    if ($SelectedTweaks.ScheduledTasks)       { Run-Tweak "Disable Diagnostic Scheduled Tasks"            { ScheduledTasks -Disable } }
    if ($SelectedTweaks.WindowsWelcome)       { Run-Tweak "Hide Windows Welcome Experience Screen"        { WindowsWelcomeExperience -Hide } }
    if ($SelectedTweaks.SettingsSuggested)    { Run-Tweak "Hide Suggested Content in Settings"            { SettingsSuggestedContent -Hide } }

    # ── UI & File Explorer ─────────────────────────────────────────────────
    if ($SelectedTweaks.HiddenItems)          { Run-Tweak "Show Hidden Files and Folders"                 { HiddenItems -Enable } }
    if ($SelectedTweaks.FileExtensions)       { Run-Tweak "Show File Name Extensions"                     { FileExtensions -Show } }
    if ($SelectedTweaks.OneDriveAd)           { Run-Tweak "Hide OneDrive Sync Ad in Explorer"             { OneDriveFileExplorerAd -Hide } }
    if ($SelectedTweaks.ShortcutSuffix)       { Run-Tweak "Remove Shortcut Text Suffix"                   { ShortcutsSuffix -Disable } }
    if ($SelectedTweaks.ExplorerToThisPC)     { Run-Tweak "Open File Explorer to This PC"                 { OpenFileExplorerTo -ThisPC } }
    if ($SelectedTweaks.SecondsInClock)       { Run-Tweak "Show Seconds in System Clock"                  { SecondsInSystemClock -Enable } }
    if ($SelectedTweaks.ExplorerRibbon)       { Run-Tweak "Expand File Explorer Ribbon"                   { FileExplorerRibbon -Expanded } }
    if ($SelectedTweaks.SnapAssist)           { Run-Tweak "Disable Snap Assist"                           { SnapAssist -Disable } }
    if ($SelectedTweaks.MergeConflicts)       { Run-Tweak "Show Folder Merge Conflicts"                   { MergeConflicts -Show } }
    if ($SelectedTweaks.FileTransferDetailed) { Run-Tweak "Detailed File Transfer Dialog"                 { FileTransferDialog -Detailed } }

    # ── Taskbar & System ───────────────────────────────────────────────────
    if ($SelectedTweaks.CortanaButton)        { Run-Tweak "Hide Cortana Button from Taskbar"              { CortanaButton -Hide } }
    if ($SelectedTweaks.TaskViewButton)       { Run-Tweak "Hide Task View Button from Taskbar"            { TaskViewButton -Hide } }
    if ($SelectedTweaks.NewsInterests)        { Run-Tweak "Disable News and Interests on Taskbar"         { NewsInterests -Disable } }
    if ($SelectedTweaks.XboxGameBar)          { Run-Tweak "Disable Xbox Game Bar"                         { XboxGameBar -Disable } }
    if ($SelectedTweaks.XboxGameTips)         { Run-Tweak "Disable Xbox Game Tips"                        { XboxGameTips -Disable } }
    if ($SelectedTweaks.F1HelpPage)           { Run-Tweak "Disable F1 Help Key"                           { F1HelpPage -Disable } }
    if ($SelectedTweaks.Autoplay)             { Run-Tweak "Disable Autoplay for Removable Drives"         { Autoplay -Disable } }
    if ($SelectedTweaks.NumLock)              { Run-Tweak "Enable NumLock at Startup"                     { NumLock -Enable } }
    if ($SelectedTweaks.MeetNow)              { Run-Tweak "Hide Meet Now Button from Taskbar"             { MeetNow -Hide } }
    if ($SelectedTweaks.SearchHighlights)     { Run-Tweak "Hide Search Highlights"                        { SearchHighlights -Hide } }

    return @{
        Success = ($errors.Count -eq 0)
        Actions = $actions
        Errors  = $errors
        Total   = ($actions.Count + $errors.Count)
    }
}
