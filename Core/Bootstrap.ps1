# WinTune Pro - bootstrap and launch helpers

function global:Show-Banner {
    Write-Host ""
    Write-Host " ============================================================" -ForegroundColor Cyan
    Write-Host "           WinTune Pro - Enterprise System Optimizer" -ForegroundColor Magenta
    Write-Host " ============================================================" -ForegroundColor Cyan
    Write-Host ""
}

function global:Test-Requirements {
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Host "[ERROR] PowerShell 5.1 or higher is required." -ForegroundColor Red
        return $false
    }

    Write-Host "[OK] PowerShell $($PSVersionTable.PSVersion) detected" -ForegroundColor Green

    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if ($isAdmin) {
        Write-Host "[OK] Running with Administrator privileges" -ForegroundColor Green
    } else {
        Write-Host "[WARNING] Not running as Administrator. Some features may be limited." -ForegroundColor Yellow
    }

    return $true
}

function global:Show-Help {
    Write-Host ""
    Write-Host "WinTune Pro - Windows System Optimizer" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage: WinTune.ps1 [-NoGUI] [-TestMode] [-Silent] [-QuickCleanup] [-FullOptimization] [-Preview] [-Status] [-Backup] [-Restore] [-Monitor] [-MemoryCleanup] [-EmergencyRepair] [-HealthCheck] [-AutoRun] [-Diagnostics] [-Recommendations] [-SystemReport] [-ListProfiles] [-ApplyProfile <Name>] [-ExportProfile <Name>] [-ImportProfile <Path>] [-CompareProfiles <A,B>] [-ReportFormat <HTML|TXT>] [-Help]" -ForegroundColor White
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  -NoGUI             Run in command-line mode (no GUI)"
    Write-Host "  -TestMode          Simulate operations without making changes"
    Write-Host "  -Silent            Run silently without prompts"
    Write-Host "  -QuickCleanup      Run quick cleanup only"
    Write-Host "  -FullOptimization  Run full optimization suite"
    Write-Host "  -Preview           Preview changes without applying"
    Write-Host "  -Status            Show detailed system status and health"
    Write-Host "  -Backup            Backup all settings"
    Write-Host "  -Restore           Restore settings from latest backup"
    Write-Host "  -Monitor           Start real-time system monitor"
    Write-Host "  -MemoryCleanup     Quick memory cleanup (free RAM)"
    Write-Host "  -EmergencyRepair   Run SFC/DISM system repair"
    Write-Host "  -HealthCheck       Quick system health check"
    Write-Host "  -AutoRun           Run full sequential workflow (analyze -> optimize -> clean)"
    Write-Host "  -Diagnostics       Show report/system snapshot, automation state, and health summary"
    Write-Host "  -Recommendations   Show health-based recommendations"
    Write-Host "  -SystemReport      Generate a system health report using -ReportFormat"
    Write-Host "  -ListProfiles      List built-in and custom profiles"
    Write-Host "  -ApplyProfile      Apply a named profile (supports -Preview)"
    Write-Host "  -ExportProfile     Export a named profile to the Reports folder as JSON"
    Write-Host "  -ImportProfile     Import a profile JSON file as a custom profile"
    Write-Host "  -CompareProfiles   Compare two profiles using 'ProfileA,ProfileB'"
    Write-Host "  -ReportFormat      Preferred report format for report-oriented commands (HTML or TXT)"
    Write-Host "  -Help              Show this help message"
    Write-Host ""
    Write-Host "New Features:" -ForegroundColor Cyan
    Write-Host "  - Real-time monitoring (CPU, RAM, Disk) - 3 second refresh"
    Write-Host "  - Auto-backup before any system changes"
    Write-Host "  - Dark/Light theme toggle in Settings"
    Write-Host "  - One-click backup/restore"
    Write-Host "  - Live CLI monitoring mode"
    Write-Host "  - Memory cleanup function"
    Write-Host "  - Emergency system repair (SFC + DISM)"
    Write-Host "  - Diagnostics and recommendation views from health/report engines"
    Write-Host "  - Profile listing, apply, import/export, and partial comparison commands"
    Write-Host "  - SIMULATION badge when Test Mode is active"
    Write-Host ""
    Write-Host "Features:" -ForegroundColor Yellow
    Write-Host "  - System cleaning (temp files, cache, recycle bin)"
    Write-Host "  - Extended browser support (Opera, Brave, Vivaldi, Safari)"
    Write-Host "  - Windows Defender log cleanup"
    Write-Host "  - Service optimization"
    Write-Host "  - Network reset and DNS optimization"
    Write-Host "  - TCP/IP and adapter tuning"
    Write-Host "  - System tuning and performance tweaks"
    Write-Host "  - SFC/DISM system repair integration"
    Write-Host "  - Scheduled task management"
    Write-Host "  - Hosts file management"
    Write-Host "  - Enhanced startup optimizer with risk assessment"
    Write-Host "  - Power plan customization"
    Write-Host "  - Benchmark system performance"
    Write-Host "  - Battery optimization"
    Write-Host "  - Privacy control"
    Write-Host "  - Storage health monitoring"
    Write-Host "  - Gaming optimization"
    Write-Host "  - Windows Update repair"
    Write-Host ""
}

function global:Initialize-App {
    Show-Banner

    if (-not (Test-Requirements)) {
        return $false
    }

    Write-Host "Starting WinTune Pro..." -ForegroundColor Cyan

    try {
        . "$scriptRoot\Core\Config.ps1"
        . "$scriptRoot\Core\Logger.ps1"
        . "$scriptRoot\Core\State.ps1"
        . "$scriptRoot\Core\AppCore.ps1"
        . "$scriptRoot\Core\Helpers.ps1"
        . "$scriptRoot\Core\SafetyNet.ps1"
        . "$scriptRoot\Core\Safety.ps1"
        . "$scriptRoot\Core\Rollback.ps1"
        . "$scriptRoot\Core\Resume.ps1"
        . "$scriptRoot\Core\HealthScore.ps1"
        . "$scriptRoot\Core\ReportGenerator.ps1"
        . "$scriptRoot\Core\AutoElevate.ps1"
        . "$scriptRoot\Core\ParallelEngine.ps1"
        . "$scriptRoot\Core\SelfHealing.ps1"
        . "$scriptRoot\Core\ToolManager.ps1"
        . "$scriptRoot\Core\Watchdog.ps1"
        . "$scriptRoot\Core\ProfileManager.ps1"
        . "$scriptRoot\Core\AutomationEngine.ps1"

        Initialize-State -AppRoot $scriptRoot
        Initialize-ConfigPaths -RootPath $scriptRoot
        Initialize-Logger -LogDirectory (Join-Path $scriptRoot "Logs") -SessionIdentifier (Get-StateValue -Key "SessionId")
        Initialize-Application -RootPath $scriptRoot

        if ($TestMode) {
            Set-ConfigValue "TestMode" $true
            Set-StateValue -Key "IsTestMode" -Value $true
            Write-Host "[INFO] Test mode enabled - no changes will be made" -ForegroundColor Yellow
        }

        if ($Preview) {
            Set-ConfigValue "TestMode" $true
            Set-StateValue -Key "IsTestMode" -Value $true
            Write-Host "[INFO] Preview mode enabled - no changes will be made" -ForegroundColor Yellow
        }

        if ($Silent) {
            Set-ConfigValue "ShowConfirmations" $false
            Set-ConfigValue "SilentMode" $true
            Write-Host "[INFO] Silent mode enabled" -ForegroundColor Yellow
        }

        return $true
    } catch {
        Write-Host "[ERROR] Failed to initialize: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function global:Invoke-SessionCleanup {
    try {
        Save-Settings
        $elapsed = Get-SessionDuration
        Write-Host "`nSession ended. Duration: $elapsed" -ForegroundColor DarkGray
    } catch { }
}
