# Module loading helpers extracted from WinTune.ps1
# Dot-source this file from WinTune.ps1 after scriptRoot initialization.

# Load modules
function global:Load-AppModules {
    $modulesPath = Join-Path $scriptRoot "Modules"
    
    $moduleFiles = @(
        "Cleaning\CleaningCore.ps1"
        "Cleaning\AppCache.ps1"
        "Cleaning\BrowserCache.ps1"
        "Cleaning\BrowserDeep.ps1"
        "Cleaning\BrowsersComplete.ps1"
        "Cleaning\DeepClean.ps1"
        "Cleaning\DeveloperCache.ps1"
        "Cleaning\DeveloperTools.ps1"
        "Cleaning\DriverStore.ps1"
        "Cleaning\GamingPlatforms.ps1"
        "Cleaning\GamingSocialCache.ps1"
        "Cleaning\InstallerCache.ps1"
        "Cleaning\LogCleanup.ps1"
        "Cleaning\MicrosoftOffice.ps1"
        "Cleaning\OfficeAppCache.ps1"
        "Cleaning\PrivacyCleanup.ps1"
        "Cleaning\RegistryCleaner.ps1"
        "Cleaning\SystemCleanup.ps1"
        "Cleaning\SystemFiles.ps1"
        "Cleaning\SystemJunkCleaner.ps1"
        "Cleaning\TempFiles.ps1"
        "Cleaning\WindowsTraceClean.ps1"
        "Cleaning\WindowsUpdateDeep.ps1"
        "BrowserExtended\BrowserExtended.ps1"
        "DefenderCleanup\DefenderCleanup.ps1"
        "WUSourceReset\WUSourceReset.ps1"
        "Optimization\OptimizationCore.ps1"
        "Optimization\Memory.ps1"
        "Optimization\PowerPlan.ps1"
        "Optimization\RestorePoints.ps1"
        "Optimization\SecurityReset.ps1"
        "Optimization\Services.ps1"
        "Optimization\Startup.ps1"
        "NetworkReset\NetworkCore.ps1"
        "NetworkReset\Adapter.ps1"
        "NetworkReset\DNS.ps1"
        "NetworkReset\NetworkAdvanced.ps1"
        "NetworkReset\TCPIP.ps1"
        "NetworkReset\Winsock.ps1"
        "Tuning\TuningCore.ps1"
        "Tuning\UITuning.ps1"
        "Tuning\TCPTuning.ps1"
        "Tuning\BootOptimization.ps1"
        "Tuning\AdapterTuning.ps1"
        "SystemRepair\SystemRepair.ps1"
        "ScheduledTaskMgr\ScheduledTaskMgr.ps1"
        "HostsManager\HostsManager.ps1"
        "StartupEnhanced\StartupEnhanced.ps1"
        "PowerPlanCustom\PowerPlanCustom.ps1"
        "BatteryOptimizer\BatteryOptimizer.ps1"
        "DNSOptimizer\DNSOptimizer.ps1"
        "GamingOptimizer\GamingOptimizer.ps1"
        "PrivacyControl\PrivacyControl.ps1"
        "StorageHealth\StorageHealth.ps1"
        "SophiaScript\SophiaIntegration.ps1"
        "PrinterFix\PrinterFix.ps1"
        "TaskScheduler\TaskScheduler.ps1"
        "RemoteExecution\RemoteExecution.ps1"
        "SystemInfo\SystemInfo.ps1"
        "WindowsUpdateMgr\WindowsUpdateMgr.ps1"
        "DriverMgr\DriverMgr.ps1"
        "WindowsFeatures\WindowsFeatures.ps1"
        "DebloatMgr\DebloatMgr.ps1"
        "TweaksMgr\TweaksMgr.ps1"
        "ProcessMgr\ProcessMgr.ps1"
        "Benchmark\SystemBenchmark.ps1"
        "TronScript\TronScript.ps1"
    )
    
    foreach ($file in $moduleFiles) {
        $fullPath = Join-Path $modulesPath $file
        if (Test-Path $fullPath) {
            try {
                . $fullPath
            } catch {
                Write-Host "[WARNING] Failed to load module: $file - $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }
    
    # Load report generator
    $reportPath = Join-Path $scriptRoot "Reports\ReportGenerator.ps1"
    if (Test-Path $reportPath) {
        . $reportPath
    }
}
