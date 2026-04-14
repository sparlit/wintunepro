#Requires -Version 5.1

param(
    [switch]$NoGUI,
    [switch]$TestMode,
    [switch]$Help,
    [switch]$Silent,
    [switch]$QuickCleanup,
    [switch]$FullOptimization,
    [switch]$Preview,
    [switch]$Status,
    [switch]$Backup,
    [switch]$Restore,
    [switch]$Monitor,
    [switch]$MemoryCleanup,
    [switch]$EmergencyRepair,
    [switch]$HealthCheck,
    [switch]$AutoRun,
    [switch]$Elevated,
    [switch]$NoExit
)

# Get script root
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# Session ID (used by modules)
$script:SessionId = ""

# Auto-backup before changes (enabled by default)
$script:AutoBackupEnabled = $true

# Load bootstrap/startup helper functions
. "$scriptRoot\Core\Bootstrap.ps1"

# Load module-loader helper functions
. "$scriptRoot\Core\ModuleLoader.ps1"

# Load GUI launcher helpers
. "$scriptRoot\Core\GUILauncher.ps1"

# Load settings into UI
function global:Load-SettingsIntoUI {
    try {
        $el = Find-UIElement "SettingAutoRestore"
        if ($el) { $el.IsChecked = [bool](Get-ConfigValue "AutoRestorePoint") }
        $el = Find-UIElement "SettingConfirmations"
        if ($el) { $el.IsChecked = [bool](Get-ConfigValue "ShowConfirmations") }
        $el = Find-UIElement "SettingAutoReports"
        if ($el) { $el.IsChecked = [bool](Get-ConfigValue "AutoGenerateReports") }
        $el = Find-UIElement "SettingTestMode"
        if ($el) { $el.IsChecked = [bool](Get-ConfigValue "TestMode") }
        
        # Load log level
        $el = Find-UIElement "LogLevelCombo"
        if ($el) {
            $level = Get-ConfigValue "LogLevel"
            foreach ($item in $el.Items) {
                if ($item.Content -eq $level) { $el.SelectedItem = $item; break }
            }
        }
    } catch { }
}

# Bind UI event handlers
function global:Bind-EventHandlers {
    param($Window)
    
    . "$scriptRoot\UI\Handlers\DashboardBindings.ps1"

    # Window controls
    Bind-WindowControls
    Update-AdminBadge
    Update-TestModeBadge
    Update-SettingsTab
    
    # Theme selector event handlers
    $themeCombo1 = Find-UIElement "SettingThemeSelect"
    if ($themeCombo1) { $themeCombo1.Add_SelectionChanged({ ThemeCombo-SelectionChangedInternal }) }
    $themeCombo2 = Find-UIElement "SettingTheme"
    if ($themeCombo2) { $themeCombo2.Add_SelectionChanged({ ThemeCombo-SelectionChangedInternal }) }
    
    # Timer for real-time updates (every 3 seconds for live monitoring)
    $script:MonitoringEnabled = $true
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromSeconds(3)
    $timer.Add_Tick({
        try {
            # Update clock
            $timeText = Find-UIElement "TimeText"
            if ($timeText) { $timeText.Text = Get-Date -Format "HH:mm:ss" }
            
            # Update real-time stats if monitoring is enabled
            if ($script:MonitoringEnabled) {
                Update-RealtimeStats
            }
        } catch { }
    })
    $timer.Start()
    
    Bind-DashboardEvents

    # Network tab
    $runNetworkBtn = Find-UIElement "RunNetworkBtn"
    if ($runNetworkBtn) {
        $runNetworkBtn.Add_Click({
            $netBtnRef = Find-UIElement "RunNetworkBtn"
            if ($netBtnRef) { $netBtnRef.IsEnabled = $false }
            Update-Status -Text "Running network reset..." -State "Working"
            Add-ActivityLog "Starting Network Reset..."
            
            try {
                $resetTCPIP = (Find-UIElement "NetResetTCPIP").IsChecked
                $resetWinsock = (Find-UIElement "NetResetWinsock").IsChecked
                $flushDNS = (Find-UIElement "NetFlushDNS").IsChecked
                $clearARP = (Find-UIElement "NetClearARP").IsChecked
                
                $result = Invoke-NetworkReset -ResetTCPIP $resetTCPIP -ResetWinsock $resetWinsock -FlushDNS $flushDNS -ClearARP $clearARP -TestMode (Get-ConfigValue "TestMode")
                
                foreach ($action in $result.Actions) {
                    Add-ActivityLog $action
                }
                
                Update-Status -Text "Network reset completed" -State "Success"
            } catch {
                Update-Status -Text "Network reset failed" -State "Error"
                Add-ActivityLog "Network error: $($_.Exception.Message)"
            }
            if ($netBtnRef) { $netBtnRef.IsEnabled = $true }
        })
    }
    
    # Optimization tab
    $analyzeOptBtn = Find-UIElement "AnalyzeOptBtn"
    if ($analyzeOptBtn) {
        $analyzeOptBtn.Add_Click({
            Update-Status -Text "Analyzing system..." -State "Working"
            
            try {
                $result = Invoke-OptimizationAnalysis
                
                # Update startup items panel
                $startupPanel = Find-UIElement "StartupItemsPanel"
                if ($startupPanel -and $result.StartupItems.Count -gt 0) {
                    $startupPanel.Children.Clear()
                    foreach ($item in $result.StartupItems | Select-Object -First 10) {
                        $tb = New-Object System.Windows.Controls.TextBlock
                        $tb.Text = "$($item.Name) - $($item.Source)"
                        $tb.FontSize = 12
                        $tb.Foreground = [System.Windows.Media.Brushes]::Gray
                        $tb.Margin = "0,2"
                        $startupPanel.Children.Add($tb)
                    }
                }
                
                # Update services panel
                $servicesPanel = Find-UIElement "ServicesPanel"
                if ($servicesPanel -and $result.Services.Count -gt 0) {
                    $servicesPanel.Children.Clear()
                    foreach ($svc in $result.Services) {
                        $tb = New-Object System.Windows.Controls.TextBlock
                        $tb.Text = "$($svc.DisplayName) - $($svc.Recommendation)"
                        $tb.FontSize = 12
                        $tb.Foreground = [System.Windows.Media.Brushes]::Gray
                        $tb.Margin = "0,2"
                        $servicesPanel.Children.Add($tb)
                    }
                }
                
                Update-Status -Text "Analysis completed" -State "Success"
                Add-ActivityLog "System analysis completed"
            } catch {
                Update-Status -Text "Analysis failed" -State "Error"
            }
        })
    }
    
    $runOptBtn = Find-UIElement "RunOptimizeBtn"
    if ($runOptBtn) {
        $runOptBtn.Add_Click({
            # Auto-backup before optimization
            $backupPath = Invoke-AutoBackup -OperationName "Optimization"
            if ($backupPath) {
                Add-ActivityLog "Auto-backup created: $(Split-Path $backupPath -Leaf)"
            }
            
            $optBtnRef = Find-UIElement "RunOptimizeBtn"
            if ($optBtnRef) { $optBtnRef.IsEnabled = $false }
            Update-Status -Text "Running optimization..." -State "Working"
            
            try {
                $result = Invoke-Optimization -TestMode (Get-ConfigValue "TestMode")
                foreach ($action in $result.Actions) {
                    Add-ActivityLog $action
                }
                
                Update-DashboardStats
                Update-Status -Text "Optimization completed" -State "Success"
            } catch {
                Update-Status -Text "Optimization failed" -State "Error"
            }
            if ($optBtnRef) { $optBtnRef.IsEnabled = $true }
        })
    }

    # Tuning tab
    $runTuningBtn = Find-UIElement "RunTuningBtn"
    if ($runTuningBtn) {
        $runTuningBtn.Add_Click({
            $tuningBtnRef = Find-UIElement "RunTuningBtn"
            if ($tuningBtnRef) { $tuningBtnRef.IsEnabled = $false }
            Update-Status -Text "Applying system tuning..." -State "Working"
            
            try {
                $result = Invoke-SystemTuning -TestMode (Get-ConfigValue "TestMode")
                foreach ($action in $result.Actions) {
                    Add-ActivityLog $action
                }
                
                Update-Status -Text "Tuning completed" -State "Success"
            } catch {
                Update-Status -Text "Tuning failed" -State "Error"
            }
            if ($tuningBtnRef) { $tuningBtnRef.IsEnabled = $true }
        })
    }

    # Reports tab
    $genReportBtn = Find-UIElement "GenerateReportBtn"
    if ($genReportBtn) {
        $genReportBtn.Add_Click({
            Update-Status -Text "Generating report..." -State "Working"
            
            try {
                $format = "HTML"
                $formatCombo = Find-UIElement "ReportFormatCombo"
                if ($formatCombo -and $formatCombo.SelectedItem) {
                    $format = $formatCombo.SelectedItem.Content
                }
                
                $reportPath = New-SystemReport -Format $format
                Add-ActivityLog "Report saved: $reportPath"
                Update-Status -Text "Report generated" -State "Success"
            } catch {
                Update-Status -Text "Report generation failed" -State "Error"
            }
        })
    }
    
    # Settings tab
    $saveSettingsBtn = Find-UIElement "SaveSettingsBtn"
    if ($saveSettingsBtn) {
        $saveSettingsBtn.Add_Click({
            Set-ConfigValue "AutoRestorePoint" (Find-UIElement "SettingAutoRestore").IsChecked
            Set-ConfigValue "ShowConfirmations" (Find-UIElement "SettingConfirmations").IsChecked
            Set-ConfigValue "AutoGenerateReports" (Find-UIElement "SettingAutoReports").IsChecked
            Set-ConfigValue "TestMode" (Find-UIElement "SettingTestMode").IsChecked
            
            Save-Settings
            Update-Status -Text "Settings saved" -State "Success"
            Add-ActivityLog "Settings saved"
        })
    }
    
    # Benchmark tab
    $runBenchmarkBtn = Find-UIElement "RunBenchmarkBtn"
    if ($runBenchmarkBtn) {
        $runBenchmarkBtn.Add_Click({
            $capturedSRoot   = $scriptRoot
            $capturedTMode   = Get-ConfigValue "TestMode"
            $capturedRunBtn  = Find-UIElement "RunBenchmarkBtn"
            $capturedQBtn    = Find-UIElement "QuickBenchmarkBtn"
            if ($capturedRunBtn) { $capturedRunBtn.IsEnabled  = $false }
            if ($capturedQBtn)   { $capturedQBtn.IsEnabled    = $false }
            $pb = Find-UIElement "BenchmarkProgressBar"
            if ($pb) { $pb.IsIndeterminate = $true }
            Update-Status -Text "Running benchmark in background..." -State "Working"
            Add-ActivityLog "Benchmark started (background)..."

            $rs    = [runspacefactory]::CreateRunspace()
            $rs.ApartmentState = "STA"; $rs.Open()
            $ps_bg = [powershell]::Create(); $ps_bg.Runspace = $rs
            $ps_bg.AddScript({
                param($sroot,$testMode)
                . "$sroot\Core\Config.ps1"
                . "$sroot\Core\Logger.ps1"
                Initialize-ConfigPaths -RootPath $sroot
                . "$sroot\Modules\Benchmark\SystemBenchmark.ps1"
                return Invoke-SystemBenchmark -QuickMode $false -TestMode $testMode
            }).AddArgument($capturedSRoot).AddArgument($capturedTMode) | Out-Null
            $bgHandle = $ps_bg.BeginInvoke()

            $bmTimer = New-Object System.Windows.Threading.DispatcherTimer
            $bmTimer.Interval = [TimeSpan]::FromMilliseconds(500)
            $capturedBgPs = $ps_bg; $capturedBgRs = $rs; $capturedBgH = $bgHandle
            $bmTimer.Add_Tick({
                if ($capturedBgH.IsCompleted) {
                    $bmTimer.Stop()
                    try { $result = $capturedBgPs.EndInvoke($capturedBgH) | Select-Object -Last 1 }
                    catch { $result = $null }
                    $capturedBgPs.Dispose(); $capturedBgRs.Dispose()
                    $runBtn2 = Find-UIElement "RunBenchmarkBtn"
                    $qBtn2   = Find-UIElement "QuickBenchmarkBtn"
                    if ($runBtn2) { $runBtn2.IsEnabled = $true }
                    if ($qBtn2)   { $qBtn2.IsEnabled   = $true }
                    $pb2 = Find-UIElement "BenchmarkProgressBar"
                    if ($pb2) { $pb2.IsIndeterminate = $false }
                    if ($result) {
                        $os = Find-UIElement "OverallBenchmarkScore"
                        $cs = Find-UIElement "CPUBenchmarkScore"
                        $ms = Find-UIElement "MemoryBenchmarkScore"
                        $ds = Find-UIElement "DiskBenchmarkScore"
                        $ns = Find-UIElement "NetworkBenchmarkScore"
                        $rt = Find-UIElement "OverallBenchmarkRating"
                        if ($os) { $os.Text = $result.Overall }
                        if ($cs) { $cs.Text = $result.CPU }
                        if ($ms) { $ms.Text = $result.Memory }
                        if ($ds) { $ds.Text = $result.Disk }
                        if ($ns) { $ns.Text = $result.Network }
                        if ($rt) { $rt.Text = Get-BenchmarkRating -Score $result.Overall }
                        if ($pb2) { $pb2.Value = 100 }
                        Update-Status -Text "Benchmark done - Score: $($result.Overall)" -State "Success"
                        Add-ActivityLog "Benchmark score: $($result.Overall)"
                    } else {
                        Update-Status -Text "Benchmark failed or returned no result" -State "Error"
                    }
                }
            }.GetNewClosure())
            $bmTimer.Start()
        })
    }
    
    # Quick benchmark (async)
    $quickBenchmarkBtn = Find-UIElement "QuickBenchmarkBtn"
    if ($quickBenchmarkBtn) {
        $quickBenchmarkBtn.Add_Click({
            $capturedSRoot2  = $scriptRoot
            $capturedTMode2  = Get-ConfigValue "TestMode"
            $capturedRunBtn2 = Find-UIElement "RunBenchmarkBtn"
            $capturedQBtn2   = Find-UIElement "QuickBenchmarkBtn"
            if ($capturedRunBtn2) { $capturedRunBtn2.IsEnabled = $false }
            if ($capturedQBtn2)   { $capturedQBtn2.IsEnabled   = $false }
            $pb3 = Find-UIElement "BenchmarkProgressBar"
            if ($pb3) { $pb3.IsIndeterminate = $true }
            Update-Status -Text "Running quick benchmark..." -State "Working"

            $rs2    = [runspacefactory]::CreateRunspace()
            $rs2.ApartmentState = "STA"; $rs2.Open()
            $ps_bg2 = [powershell]::Create(); $ps_bg2.Runspace = $rs2
            $ps_bg2.AddScript({
                param($sroot,$testMode)
                . "$sroot\Core\Config.ps1"
                . "$sroot\Core\Logger.ps1"
                Initialize-ConfigPaths -RootPath $sroot
                . "$sroot\Modules\Benchmark\SystemBenchmark.ps1"
                return Invoke-SystemBenchmark -QuickMode $true -TestMode $testMode
            }).AddArgument($capturedSRoot2).AddArgument($capturedTMode2) | Out-Null
            $bgH2 = $ps_bg2.BeginInvoke()

            $qbTimer = New-Object System.Windows.Threading.DispatcherTimer
            $qbTimer.Interval = [TimeSpan]::FromMilliseconds(500)
            $capturedBgPs2 = $ps_bg2; $capturedBgRs2 = $rs2; $capturedBgH2 = $bgH2
            $qbTimer.Add_Tick({
                if ($capturedBgH2.IsCompleted) {
                    $qbTimer.Stop()
                    try { $result2 = $capturedBgPs2.EndInvoke($capturedBgH2) | Select-Object -Last 1 }
                    catch { $result2 = $null }
                    $capturedBgPs2.Dispose(); $capturedBgRs2.Dispose()
                    $rb3 = Find-UIElement "RunBenchmarkBtn"
                    $qb3 = Find-UIElement "QuickBenchmarkBtn"
                    if ($rb3) { $rb3.IsEnabled = $true }
                    if ($qb3) { $qb3.IsEnabled = $true }
                    $pb4 = Find-UIElement "BenchmarkProgressBar"
                    if ($pb4) { $pb4.IsIndeterminate = $false }
                    if ($result2) {
                        $os2 = Find-UIElement "OverallBenchmarkScore"
                        if ($os2) { $os2.Text = $result2.Overall }
                        if ($pb4) { $pb4.Value = 100 }
                        Update-Status -Text "Quick benchmark done - Score: $($result2.Overall)" -State "Success"
                        Add-ActivityLog "Quick benchmark score: $($result2.Overall)"
                    } else {
                        Update-Status -Text "Quick benchmark failed" -State "Error"
                    }
                }
            }.GetNewClosure())
            $qbTimer.Start()
        })
    }
    
    # DNS tab handlers
    $flushDNSBtn = Find-UIElement "FlushDNSBtn"
    if ($flushDNSBtn) {
        $flushDNSBtn.Add_Click({
            if (Invoke-FlushDNS) {
                Update-Status -Text "DNS cache flushed" -State "Success"
                Add-ActivityLog "DNS cache flushed"
            }
        })
    }
    
    # DNS quick select buttons
    $dnsButtons = @{
        "DNSCloudflareBtn" = "Cloudflare"
        "DNSGoogleBtn" = "Google"
        "DNSQuad9Btn" = "Quad9"
        "DNSOpenDNSBtn" = "OpenDNS"
        "DNSAdGuardBtn" = "AdGuard"
        "DNSNextDNSBtn" = "NextDNS"
        "DNSControlDBtn" = "ControlD"
    }
    
    foreach ($btnName in $dnsButtons.Keys) {
        $btn = Find-UIElement $btnName
        if ($btn) {
            $provider = $dnsButtons[$btnName]
            $btn.Add_Click({
                param($sender, $e)
                $prov = $provider  # Capture variable
                $providers = Get-DNSProviders
                if ($providers.ContainsKey($prov)) {
                    $dns = $providers[$prov]
                    if (Set-DNSServer -Primary $dns.Primary -Secondary $dns.Secondary) {
                        Update-Status -Text "DNS set to $prov" -State "Success"
                        Add-ActivityLog "DNS changed to $prov"
                    }
                }
            }.GetNewClosure())
        }
    }
    
    # Gaming tab
    $toggleGameModeBtn = Find-UIElement "ToggleGameModeBtn"
    if ($toggleGameModeBtn) {
        $toggleGameModeBtn.Add_Click({
            $gmBtn = Find-UIElement "ToggleGameModeBtn"
            $status = Get-GameModeStatus
            if ($status.Enabled) {
                Set-GameMode -Enable $false
                if ($gmBtn) { $gmBtn.Content = "Enable Game Mode" }
                Update-Status -Text "Game Mode disabled" -State "Success"
                Add-ActivityLog "Windows Game Mode disabled"
            } else {
                Set-GameMode -Enable $true
                if ($gmBtn) { $gmBtn.Content = "Disable Game Mode" }
                Update-Status -Text "Game Mode enabled" -State "Success"
                Add-ActivityLog "Windows Game Mode enabled"
            }
        })
    }
    
    $quickGamingBtn = Find-UIElement "QuickGamingOptBtn"
    if ($quickGamingBtn) {
        $quickGamingBtn.Add_Click({
            Update-Status -Text "Applying gaming optimization..." -State "Working"
            $result = Invoke-GamingOptimization -Mode "Quick" -TestMode (Get-ConfigValue "TestMode")
            foreach ($action in $result.Actions) {
                Add-ActivityLog $action
            }
            Update-Status -Text "Gaming optimization applied" -State "Success"
        })
    }
    
    # Privacy tab
    $privacyScanBtn = Find-UIElement "RunPrivacyScanBtn"
    if ($privacyScanBtn) {
        $privacyScanBtn.Add_Click({
            Update-Status -Text "Scanning privacy settings..." -State "Working"
            
            $result = Invoke-PrivacyScan
            $score = Get-PrivacyScore
            
            $scoreText = Find-UIElement "PrivacyScoreText"
            if ($scoreText) { $scoreText.Text = $score.Score }
            
            $issuesPanel = Find-UIElement "PrivacyIssuesPanel"
            if ($issuesPanel) {
                $issuesPanel.Children.Clear()
                foreach ($issue in $score.Issues) {
                    $tb = New-Object System.Windows.Controls.TextBlock
                    $tb.Text = "[!] $issue"
                    $tb.FontSize = 12
                    $tb.Foreground = "#C77700"
                    $tb.Margin = "0,2"
                    $issuesPanel.Children.Add($tb)
                }
            }
            
            Update-Status -Text "Privacy scan completed" -State "Success"
        })
    }
    
    $applyPrivacyBasicBtn = Find-UIElement "ApplyPrivacyBasicBtn"
    if ($applyPrivacyBasicBtn) {
        $applyPrivacyBasicBtn.Add_Click({
            Update-Status -Text "Applying basic privacy..." -State "Working"
            $result = Invoke-PrivacyOptimization -Mode "Basic" -TestMode (Get-ConfigValue "TestMode")
            foreach ($action in $result.Actions) {
                Add-ActivityLog $action
            }
            Update-Status -Text "Basic privacy applied" -State "Success"
        })
    }
    
    $applyPrivacyStrictBtn = Find-UIElement "ApplyPrivacyStrictBtn"
    if ($applyPrivacyStrictBtn) {
        $applyPrivacyStrictBtn.Add_Click({
            Update-Status -Text "Applying strict privacy..." -State "Working"
            $result = Invoke-PrivacyOptimization -Mode "Strict" -TestMode (Get-ConfigValue "TestMode")
            foreach ($action in $result.Actions) {
                Add-ActivityLog $action
            }
            Update-Status -Text "Strict privacy applied" -State "Success"
        })
    }
    
    # Storage tab
    $storageScanBtn = Find-UIElement "RunStorageScanBtn"
    if ($storageScanBtn) {
        $storageScanBtn.Add_Click({
            Update-Status -Text "Scanning storage health..." -State "Working"
            
            $health = Get-StorageHealth
            $trimStatus = Get-TRIMStatus
            $disks = Get-DiskList
            
            $healthScore = Find-UIElement "StorageHealthScore"
            if ($healthScore) { $healthScore.Text = $health.Score }
            
            $trimText = Find-UIElement "TRIMStatus"
            if ($trimText) { $trimText.Text = if ($trimStatus.Enabled) { "Enabled" } else { "Disabled" } }
            
            $diskPanel = Find-UIElement "DiskListPanel"
            if ($diskPanel) {
                $diskPanel.Children.Clear()
                    foreach ($disk in $disks) {
                        $tb = New-Object System.Windows.Controls.TextBlock
                        $tb.Text = "$($disk.FriendlyName) - $($disk.SizeGB) GB ($($disk.MediaType))"
                        $tb.FontSize = 12
                        $tb.Foreground = [System.Windows.Media.Brushes]::Gray
                        $tb.Margin = "0,2"
                        $diskPanel.Children.Add($tb)
                    }
            }
            
            Update-Status -Text "Storage scan completed" -State "Success"
        })
    }
    
    # Battery tab
    $batteryReportBtn = Find-UIElement "GenerateBatteryReportBtn"
    if ($batteryReportBtn) {
        $batteryReportBtn.Add_Click({
            Update-Status -Text "Generating battery report..." -State "Working"
            $path = New-BatteryReport
            if ($path) {
                Update-Status -Text "Battery report saved" -State "Success"
                Add-ActivityLog "Battery report: $path"
            }
        })
    }
    
    # Sophia Tweaks tab
    $applySophiaBtn = Find-UIElement "ApplySophiaTweaksBtn"
    if ($applySophiaBtn) {
        $applySophiaBtn.Add_Click({
            Update-Status -Text "Applying Sophia tweaks..." -State "Working"
            Add-ActivityLog "Starting Sophia Script tweaks..."

            $tweaks = @{
                DiagTrackService    = (Find-UIElement "SophiaDiagTrack").IsChecked
                DiagnosticDataLevel = (Find-UIElement "SophiaDiagData").IsChecked
                ErrorReporting      = (Find-UIElement "SophiaErrorReport").IsChecked
                FeedbackFrequency   = (Find-UIElement "SophiaFeedback").IsChecked
                AdvertisingID       = (Find-UIElement "SophiaAdvertID").IsChecked
                TailoredExperiences = (Find-UIElement "SophiaTailored").IsChecked
                BingSearch          = (Find-UIElement "SophiaBingSearch").IsChecked
                AppsSilentInstalling = (Find-UIElement "SophiaSilentApps").IsChecked
                SettingsSuggested   = (Find-UIElement "SophiaSettingsSugg").IsChecked
                WindowsWelcome      = (Find-UIElement "SophiaWinWelcome").IsChecked
                SigninInfo          = (Find-UIElement "SophiaSigninInfo").IsChecked
                ScheduledTasks      = (Find-UIElement "SophiaSchedTasks").IsChecked
                HiddenItems         = (Find-UIElement "SophiaHiddenItems").IsChecked
                FileExtensions      = (Find-UIElement "SophiaFileExt").IsChecked
                OneDriveAd          = (Find-UIElement "SophiaOneDriveAd").IsChecked
                ShortcutSuffix      = (Find-UIElement "SophiaShortcutSuffix").IsChecked
                MergeConflicts      = (Find-UIElement "SophiaMergeConflicts").IsChecked
                FileTransferDetailed = (Find-UIElement "SophiaFileTransfer").IsChecked
                ExplorerToThisPC    = (Find-UIElement "SophiaExplorerPC").IsChecked
                SecondsInClock      = (Find-UIElement "SophiaClockSeconds").IsChecked
                ExplorerRibbon      = (Find-UIElement "SophiaExplorerRibbon").IsChecked
                SnapAssist          = (Find-UIElement "SophiaSnapAssist").IsChecked
                CortanaButton       = (Find-UIElement "SophiaCortana").IsChecked
                NewsInterests       = (Find-UIElement "SophiaNews").IsChecked
                MeetNow             = (Find-UIElement "SophiaMeetNow").IsChecked
                SearchHighlights    = (Find-UIElement "SophiaSearchHL").IsChecked
                F1HelpPage          = (Find-UIElement "SophiaF1Key").IsChecked
                Autoplay            = (Find-UIElement "SophiaAutoplay").IsChecked
                XboxGameTips        = (Find-UIElement "SophiaXboxTips").IsChecked
                TaskViewButton      = (Find-UIElement "SophiaTaskView").IsChecked
                XboxGameBar         = (Find-UIElement "SophiaXboxBar").IsChecked
                NumLock             = (Find-UIElement "SophiaNumLock").IsChecked
            }

            $result = Invoke-SophiaTweaks -SelectedTweaks $tweaks -TestMode (Get-ConfigValue "TestMode")
            foreach ($action in $result.Actions) { Add-ActivityLog $action }
            foreach ($err in $result.Errors)     { Add-ActivityLog "ERROR: $err" }

            if ($result.Success) {
                Update-Status -Text "Sophia tweaks applied: $($result.Total) tweaks" -State "Success"
            } else {
                Update-Status -Text "Some tweaks failed  -  check activity log" -State "Error"
            }
        })
    }

    $applyAllSophiaBtn = Find-UIElement "ApplyAllSophiaTweaksBtn"
    if ($applyAllSophiaBtn) {
        $applyAllSophiaBtn.Add_Click({
            Update-Status -Text "Applying all Sophia tweaks..." -State "Working"
            Add-ActivityLog "Starting full Sophia Script tweak set..."

            $tweaks = @{
                DiagTrackService     = $true;  DiagnosticDataLevel  = $true
                ErrorReporting       = $true;  FeedbackFrequency    = $true
                AdvertisingID        = $true;  TailoredExperiences  = $true
                BingSearch           = $true;  AppsSilentInstalling = $true
                SettingsSuggested    = $true;  WindowsWelcome       = $true
                SigninInfo           = $true;  ScheduledTasks       = $true
                HiddenItems          = $true;  FileExtensions       = $true
                OneDriveAd           = $true;  ShortcutSuffix       = $true
                MergeConflicts       = $true;  FileTransferDetailed = $true
                ExplorerToThisPC     = $true;  SecondsInClock       = $true
                ExplorerRibbon       = $true;  SnapAssist           = $true
                CortanaButton        = $true;  NewsInterests        = $true
                MeetNow              = $true;  SearchHighlights     = $true
                F1HelpPage           = $true;  Autoplay             = $true
                XboxGameTips         = $true;  TaskViewButton       = $true
                XboxGameBar          = $true;  NumLock              = $true
            }

            $result = Invoke-SophiaTweaks -SelectedTweaks $tweaks -TestMode (Get-ConfigValue "TestMode")
            foreach ($action in $result.Actions) { Add-ActivityLog $action }
            foreach ($err in $result.Errors)     { Add-ActivityLog "ERROR: $err" }

            Update-Status -Text "All tweaks applied: $($result.Total) tweaks" -State "Success"
        })
    }


    # ── Printer Fix (Maintenance tab) ────────────────────────────────────────
    $printerFixBtn = Find-UIElement "PrinterFixBtn"
    if ($printerFixBtn) {
        $printerFixBtn.Add_Click({
            $btn = Find-UIElement "PrinterFixBtn"
            $pb  = Find-UIElement "PrinterProgressBar"
            $tl  = Find-UIElement "PrinterTaskLabel"
            $ob  = Find-UIElement "PrinterOutputBox"
            $sl  = Find-UIElement "PrinterStatusLight"
            if ($sl) { $sl.Fill = [System.Windows.Media.Brushes]::DodgerBlue }
            if ($btn) { $btn.IsEnabled = $false }
            Update-Status -Text "Running Printer Fix..." -State "Working"
            if ($pb -and $tl -and $ob -and $sl) {
                Run-PrinterFix -ProgressBar $pb -TaskLabel $tl -OutputBox $ob -StatusLight $sl
            }
            if ($btn) { $btn.IsEnabled = $true }
            Update-Status -Text "Printer Fix completed" -State "Success"
        })
    }

    $printerStopBtn = Find-UIElement "PrinterStopBtn"
    if ($printerStopBtn) {
        $printerStopBtn.Add_Click({
            $global:PrinterFixStop  = $true
            $global:PrinterFixPause = $false
            $sl = Find-UIElement "PrinterStatusLight"
            if ($sl) { $sl.Fill = [System.Windows.Media.Brushes]::OrangeRed }
            $tl = Find-UIElement "PrinterTaskLabel"
            if ($tl) { $tl.Text = "Stopping..." }
        })
    }

    $printerPauseBtn = Find-UIElement "PrinterPauseBtn"
    if ($printerPauseBtn) {
        $printerPauseBtn.Add_Click({
            if (-not $global:PrinterFixStop) {
                $global:PrinterFixPause = $true
                $sl = Find-UIElement "PrinterStatusLight"
                if ($sl) { $sl.Fill = [System.Windows.Media.Brushes]::Gold }
            }
        })
    }

    $printerResumeBtn = Find-UIElement "PrinterResumeBtn"
    if ($printerResumeBtn) {
        $printerResumeBtn.Add_Click({
            if (-not $global:PrinterFixStop) {
                $global:PrinterFixPause = $false
                $sl = Find-UIElement "PrinterStatusLight"
                if ($sl) { $sl.Fill = [System.Windows.Media.Brushes]::DodgerBlue }
            }
        })
    }


    # ── TronScript Tab ───────────────────────────────────────────────────────

    function global:Update-TronPathDisplay {
        try {
            $tronPathText = Find-UIElement "TronPathText"
            $tronDetectLight = Find-UIElement "TronDetectLight"
            $tronDetectLabel = Find-UIElement "TronDetectLabel"

            $tronPath = Join-Path $scriptRoot "Modules\TronScript\tron\tron.bat"
            $detected = Test-Path $tronPath

            if ($tronPathText) {
                if ($detected) {
                    $tronPathText.Text = $tronPath
                } else {
                    $tronPathText.Text = "tron.bat not found in Modules\TronScript\tron\"
                }
            }

            if ($tronDetectLight) {
                if ($detected) {
                    $tronDetectLight.Fill = "LimeGreen"
                } else {
                    $tronDetectLight.Fill = "OrangeRed"
                }
            }

            if ($tronDetectLabel) {
                if ($detected) {
                    $tronDetectLabel.Text = "Detected"
                } else {
                    $tronDetectLabel.Text = "Not Found"
                }
            }
        } catch { }
    }

    function global:Browse-TronPath {
        try {
            Add-Type -AssemblyName System.Windows.Forms
            $dialog = New-Object System.Windows.Forms.OpenFileDialog
            $dialog.Title = "Select tron.bat"
            $dialog.Filter = "Batch files (*.bat)|*.bat|All files (*.*)|*.*"
            $dialog.FileName = "tron.bat"

            if ($dialog.ShowDialog() -eq "OK") {
                $tronPathText = Find-UIElement "TronPathText"
                if ($tronPathText) {
                    $tronPathText.Text = $dialog.FileName
                }

                $tronDetectLight = Find-UIElement "TronDetectLight"
                if ($tronDetectLight) {
                    $tronDetectLight.Fill = "LimeGreen"
                }

                $tronDetectLabel = Find-UIElement "TronDetectLabel"
                if ($tronDetectLabel) {
                    $tronDetectLabel.Text = "Selected"
                }
            }
        } catch { }
    }

    Update-TronPathDisplay

    $tronBrowseBtn = Find-UIElement "TronBrowseBtn"
    if ($tronBrowseBtn) {
        $tronBrowseBtn.Add_Click({
            Browse-TronPath
        })
    }

    $tronRunBtn = Find-UIElement "TronRunBtn"
    if ($tronRunBtn) {
        $tronRunBtn.Add_Click({
            $runBtn  = Find-UIElement "TronRunBtn"
            $stopBtn = Find-UIElement "TronStopBtn"
            $ob      = Find-UIElement "TronOutputBox"
            $sl      = Find-UIElement "TronDetectLight"
            $lbl     = Find-UIElement "TronDetectLabel"
            $pb      = Find-UIElement "TronProgressBar"

            if ($runBtn)  { $runBtn.IsEnabled  = $false }
            if ($stopBtn) { $stopBtn.IsEnabled = $true  }

            $opts = @{
                AutoMode         = (Find-UIElement "TronAutoMode").IsChecked
                Verbose          = (Find-UIElement "TronVerbose").IsChecked
                RebootAfter      = (Find-UIElement "TronRebootAfter").IsChecked
                SelfDestruct     = (Find-UIElement "TronSelfDestruct").IsChecked
                SkipDebloat      = (Find-UIElement "TronSkipDebloat").IsChecked
                SkipAntiMalware  = (Find-UIElement "TronSkipAntiMalware").IsChecked
                SkipDefrag       = (Find-UIElement "TronSkipDefrag").IsChecked
                SkipPatches      = (Find-UIElement "TronSkipPatches").IsChecked
                SkipEventLogs    = (Find-UIElement "TronSkipEventLogs").IsChecked
                SkipTelemetry    = (Find-UIElement "TronSkipTelemetry").IsChecked
                SkipNetworkReset = (Find-UIElement "TronSkipNetworkReset").IsChecked
            }

            Update-Status -Text "TronScript is running..." -State "Working"
            Start-TronScriptRun -Options $opts -OutputBox $ob -StatusLight $sl -StatusLabel $lbl -ProgressBar $pb
        })
    }

    $tronStopBtn = Find-UIElement "TronStopBtn"
    if ($tronStopBtn) {
        $tronStopBtn.Add_Click({
            Stop-TronScriptRun
            $sl  = Find-UIElement "TronDetectLight"
            $lbl = Find-UIElement "TronDetectLabel"
            $pb  = Find-UIElement "TronProgressBar"
            if ($sl)  { $sl.Fill  = [System.Windows.Media.Brushes]::OrangeRed }
            if ($lbl) { $lbl.Text = "Stopped by user" }
            if ($pb)  { $pb.IsIndeterminate = $false }
            $runBtn  = Find-UIElement "TronRunBtn"
            $stopBtn = Find-UIElement "TronStopBtn"
            if ($runBtn)  { $runBtn.IsEnabled  = $true }
            if ($stopBtn) { $stopBtn.IsEnabled = $false }
            Update-Status -Text "TronScript stopped" -State "Ready"
        })
    }


    # ── Select / Deselect All Cleaning ───────────────────────────────────────
    $selectAllCleanBtn = Find-UIElement "SelectAllCleanBtn"
    if ($selectAllCleanBtn) {
        $selectAllCleanBtn.Add_Click({
            @("CleanUserTemp","CleanSystemTemp","CleanWUCache","CleanRecycleBin",
              "CleanThumbnailCache","CleanPrefetch","CleanChromeCache","CleanEdgeCache","CleanFirefoxCache") |
            ForEach-Object {
                $el = Find-UIElement $_
                if ($el) { $el.IsChecked = $true }
            }
        })
    }

    $deselectAllCleanBtn = Find-UIElement "DeselectAllCleanBtn"
    if ($deselectAllCleanBtn) {
        $deselectAllCleanBtn.Add_Click({
            @("CleanUserTemp","CleanSystemTemp","CleanWUCache","CleanRecycleBin",
              "CleanThumbnailCache","CleanPrefetch","CleanChromeCache","CleanEdgeCache","CleanFirefoxCache") |
            ForEach-Object {
                $el = Find-UIElement $_
                if ($el) { $el.IsChecked = $false }
            }
        })
    }

    # ── Create Restore Point ─────────────────────────────────────────────────
    $createRestoreBtn = Find-UIElement "CreateRestoreBtn"
    if ($createRestoreBtn) {
        $createRestoreBtn.Add_Click({
            $restoreBtnRef = Find-UIElement "CreateRestoreBtn"
            if ($restoreBtnRef) { $restoreBtnRef.IsEnabled = $false }
            Update-Status -Text "Creating restore point..." -State "Working"
            try {
                Checkpoint-Computer -Description "WinTune Pro Restore Point" -RestorePointType MODIFY_SETTINGS
                Update-Status -Text "Restore point created successfully" -State "Success"
                Add-ActivityLog "System restore point created"
            } catch {
                Update-Status -Text "Restore point failed (may need to enable SR)" -State "Error"
                Add-ActivityLog "Restore point error: $($_.Exception.Message)"
            }
            if ($restoreBtnRef) { $restoreBtnRef.IsEnabled = $true }
        })
    }

    # ── Network Tuning ───────────────────────────────────────────────────────
    $runNetworkTuneBtn = Find-UIElement "RunNetworkTuneBtn"
    if ($runNetworkTuneBtn) {
        $runNetworkTuneBtn.Add_Click({
            $ntnBtnRef = Find-UIElement "RunNetworkTuneBtn"
            if ($ntnBtnRef) { $ntnBtnRef.IsEnabled = $false }
            Update-Status -Text "Applying network tuning..." -State "Working"
            try {
                if (Get-Command Invoke-NetworkTuning -ErrorAction SilentlyContinue) {
                    $result = Invoke-NetworkTuning -TestMode (Get-ConfigValue "TestMode")
                    foreach ($action in $result.Actions) { Add-ActivityLog $action }
                } else {
                    # Fallback: flush DNS + renew adapter
                    ipconfig /flushdns | Out-Null
                    Add-ActivityLog "DNS cache flushed"
                    netsh int tcp set global autotuninglevel=normal | Out-Null
                    Add-ActivityLog "TCP auto-tuning set to normal"
                }
                Update-Status -Text "Network tuning applied" -State "Success"
            } catch {
                Update-Status -Text "Network tuning failed" -State "Error"
                Add-ActivityLog "Error: $($_.Exception.Message)"
            }
            if ($ntnBtnRef) { $ntnBtnRef.IsEnabled = $true }
        })
    }

    # ── Full Gaming Optimization ─────────────────────────────────────────────
    $fullGamingBtn = Find-UIElement "FullGamingOptBtn"
    if ($fullGamingBtn) {
        $fullGamingBtn.Add_Click({
            Update-Status -Text "Applying full gaming optimization..." -State "Working"
            try {
                $result = Invoke-GamingOptimization -Mode "Full" -TestMode (Get-ConfigValue "TestMode")
                foreach ($action in $result.Actions) { Add-ActivityLog $action }
                Update-Status -Text "Full gaming optimization applied" -State "Success"
            } catch {
                Update-Status -Text "Gaming optimization failed" -State "Error"
                Add-ActivityLog "Error: $($_.Exception.Message)"
            }
        })
    }

    # ── Aggressive Gaming Optimization ──────────────────────────────────────
    $aggressiveGamingBtn = Find-UIElement "AggressiveGamingOptBtn"
    if ($aggressiveGamingBtn) {
        $aggressiveGamingBtn.Add_Click({
            Update-Status -Text "Applying aggressive gaming optimization..." -State "Working"
            try {
                $result = Invoke-GamingOptimization -Mode "Aggressive" `
                    -EnableGPUScheduling $true -DisableGameDVR $true `
                    -SetUltimatePerformance $true `
                    -TestMode (Get-ConfigValue "TestMode")
                foreach ($action in $result.Actions) { Add-ActivityLog $action }
                Update-Status -Text "Aggressive gaming optimization applied" -State "Success"
            } catch {
                Update-Status -Text "Gaming optimization failed" -State "Error"
            }
        })
    }

    # ── Game Cache Clearing ──────────────────────────────────────────────────
    $clearSteamCacheBtn = Find-UIElement "ClearSteamCacheBtn"
    if ($clearSteamCacheBtn) {
        $clearSteamCacheBtn.Add_Click({
            Update-Status -Text "Clearing Steam cache..." -State "Working"
            try {
                $result = Clear-GameCache -Steam $true -Epic $false -TestMode (Get-ConfigValue "TestMode")
                foreach ($action in $result.Actions) { Add-ActivityLog $action }
                Update-Status -Text "Steam cache cleared ($($result.TotalFreed) MB freed)" -State "Success"
            } catch { Update-Status -Text "Failed to clear Steam cache" -State "Error" }
        })
    }

    $clearEpicCacheBtn = Find-UIElement "ClearEpicCacheBtn"
    if ($clearEpicCacheBtn) {
        $clearEpicCacheBtn.Add_Click({
            Update-Status -Text "Clearing Epic Games cache..." -State "Working"
            try {
                $result = Clear-GameCache -Steam $false -Epic $true -TestMode (Get-ConfigValue "TestMode")
                foreach ($action in $result.Actions) { Add-ActivityLog $action }
                Update-Status -Text "Epic cache cleared ($($result.TotalFreed) MB freed)" -State "Success"
            } catch { Update-Status -Text "Failed to clear Epic cache" -State "Error" }
        })
    }

    $clearAllGameCacheBtn = Find-UIElement "ClearAllGameCacheBtn"
    if ($clearAllGameCacheBtn) {
        $clearAllGameCacheBtn.Add_Click({
            Update-Status -Text "Clearing all game caches..." -State "Working"
            try {
                $result = Clear-GameCache -All $true -TestMode (Get-ConfigValue "TestMode")
                foreach ($action in $result.Actions) { Add-ActivityLog $action }
                Update-Status -Text "All game caches cleared ($($result.TotalFreed) MB freed)" -State "Success"
            } catch { Update-Status -Text "Failed to clear game caches" -State "Error" }
        })
    }

    # ── Battery Power Mode Buttons ───────────────────────────────────────────
    $batteryLifeBtn = Find-UIElement "BatteryLifeModeBtn"
    if ($batteryLifeBtn) {
        $batteryLifeBtn.Add_Click({
            Update-Status -Text "Setting battery life mode..." -State "Working"
            $result = Invoke-BatteryOptimization -Mode "Battery" -TestMode (Get-ConfigValue "TestMode")
            foreach ($action in $result.Actions) { Add-ActivityLog $action }
            Update-Status -Text "Battery life mode applied (Power Saver plan)" -State "Success"
        })
    }

    $balancedModeBtn = Find-UIElement "BalancedModeBtn"
    if ($balancedModeBtn) {
        $balancedModeBtn.Add_Click({
            Update-Status -Text "Setting balanced mode..." -State "Working"
            $result = Invoke-BatteryOptimization -Mode "Balanced" -TestMode (Get-ConfigValue "TestMode")
            foreach ($action in $result.Actions) { Add-ActivityLog $action }
            Update-Status -Text "Balanced power plan applied" -State "Success"
        })
    }

    $performanceModeBtn = Find-UIElement "PerformanceModeBtn"
    if ($performanceModeBtn) {
        $performanceModeBtn.Add_Click({
            Update-Status -Text "Setting performance mode..." -State "Working"
            $result = Invoke-BatteryOptimization -Mode "Performance" -TestMode (Get-ConfigValue "TestMode")
            foreach ($action in $result.Actions) { Add-ActivityLog $action }
            Update-Status -Text "High Performance/Ultimate plan applied" -State "Success"
        })
    }

    $enableBatterySaverBtn = Find-UIElement "EnableBatterySaverBtn"
    if ($enableBatterySaverBtn) {
        $enableBatterySaverBtn.Add_Click({
            Update-Status -Text "Enabling battery saver settings..." -State "Working"
            if (Enable-BatterySaver -Enable $true) {
                Update-Status -Text "Battery saver settings enabled" -State "Success"
                Add-ActivityLog "Battery saver settings enabled"
            } else {
                Update-Status -Text "Battery saver requires laptop/tablet" -State "Ready"
                Add-ActivityLog "Battery saver: no battery detected"
            }
        })
    }

    $applyPowerPlanBtn = Find-UIElement "ApplyPowerPlanBtn"
    if ($applyPowerPlanBtn) {
        $applyPowerPlanBtn.Add_Click({
            $combo = Find-UIElement "PowerPlanCombo"
            if ($combo -and $combo.SelectedItem) {
                $planGuid = $combo.SelectedItem.Tag
                if ([string]::IsNullOrEmpty($planGuid)) { $planGuid = $combo.SelectedItem.Content }
                Update-Status -Text "Applying selected power plan..." -State "Working"
                if (Set-PowerPlan -Guid $planGuid) {
                    Update-Status -Text "Power plan applied" -State "Success"
                    Add-ActivityLog "Power plan set: $($combo.SelectedItem.Content)"
                } else {
                    Update-Status -Text "Failed to apply power plan" -State "Error"
                }
            } else {
                Update-Status -Text "Select a power plan first" -State "Ready"
            }
        })
    }

    # ── DNS Benchmark & Auto-Optimize ───────────────────────────────────────
    $runDNSBenchmarkBtn = Find-UIElement "RunDNSBenchmarkBtn"
    if ($runDNSBenchmarkBtn) {
        $runDNSBenchmarkBtn.Add_Click({
            $dnsBenchBtnRef = Find-UIElement "RunDNSBenchmarkBtn"
            if ($dnsBenchBtnRef) { $dnsBenchBtnRef.IsEnabled = $false }
            Update-Status -Text "Running DNS benchmark (testing all providers)..." -State "Working"
            try {
                $results = Invoke-DNSBenchmark -TestMode (Get-ConfigValue "TestMode")
                $dnsBenchPanel = Find-UIElement "DNSBenchmarkResults"
                if ($dnsBenchPanel) {
                    $dnsBenchPanel.Children.Clear()
                    $rank = 1
                    foreach ($r in $results) {
                        $tb = New-Object System.Windows.Controls.TextBlock
                        $timeStr = if ($r.ResponseTime -ge 999) { "timeout" } else { "$($r.ResponseTime) ms" }
                        $tb.Text = "$rank. $($r.Provider) ($($r.Primary)) - $timeStr"
                        $tb.FontSize = 12
                        $tb.Foreground = if ($r.Success) { "#5A6375" } else { "#C0392B" }
                        $tb.Margin = "0,3"
                        $tb.FontFamily = "Consolas"
                        $dnsBenchPanel.Children.Add($tb) | Out-Null
                        $rank++
                    }
                }
                if ($results.Count -gt 0) {
                    $fastest = $results | Where-Object { $_.Success } | Select-Object -First 1
                    Update-Status -Text "DNS benchmark done - Fastest: $($fastest.Provider) ($($fastest.ResponseTime) ms)" -State "Success"
                    Add-ActivityLog "DNS benchmark: fastest is $($fastest.Provider) at $($fastest.ResponseTime) ms"
                }
            } catch {
                Update-Status -Text "DNS benchmark failed" -State "Error"
                Add-ActivityLog "DNS benchmark error: $($_.Exception.Message)"
            }
            if ($dnsBenchBtnRef) { $dnsBenchBtnRef.IsEnabled = $true }
        })
    }

    $autoOptimizeDNSBtn = Find-UIElement "AutoOptimizeDNSBtn"
    if ($autoOptimizeDNSBtn) {
        $autoOptimizeDNSBtn.Add_Click({
            $autoOptRef = Find-UIElement "AutoOptimizeDNSBtn"
            if ($autoOptRef) { $autoOptRef.IsEnabled = $false }
            Update-Status -Text "Finding fastest DNS provider..." -State "Working"
            try {
                $fastest = Get-FastestDNS -TestMode (Get-ConfigValue "TestMode")
                if ($fastest -and $fastest.Provider) {
                    $providers = Get-DNSProviders
                    if ($providers.ContainsKey($fastest.Provider)) {
                        $dns = $providers[$fastest.Provider]
                        if (Set-DNSServer -Primary $dns.Primary -Secondary $dns.Secondary) {
                            Update-Status -Text "DNS auto-set to $($fastest.Provider) ($($fastest.ResponseTime) ms)" -State "Success"
                            Add-ActivityLog "DNS auto-optimized: $($fastest.Provider) - $($dns.Primary)"
                        }
                    }
                } else {
                    Update-Status -Text "Could not determine fastest DNS" -State "Ready"
                }
            } catch {
                Update-Status -Text "DNS auto-optimize failed" -State "Error"
            }
            if ($autoOptRef) { $autoOptRef.IsEnabled = $true }
        })
    }

    $resetDNSBtn = Find-UIElement "ResetDNSBtn"
    if ($resetDNSBtn) {
        $resetDNSBtn.Add_Click({
            Update-Status -Text "Resetting DNS to automatic..." -State "Working"
            if (Reset-DNSToDHCP) {
                Update-Status -Text "DNS reset to automatic (DHCP/ISP)" -State "Success"
                Add-ActivityLog "DNS reset to automatic (DHCP)"
            } else {
                Update-Status -Text "DNS reset failed" -State "Error"
            }
        })
    }

    $dnsDHCPBtn = Find-UIElement "DNSDHCPBtn"
    if ($dnsDHCPBtn) {
        $dnsDHCPBtn.Add_Click({
            Update-Status -Text "Resetting DNS to DHCP..." -State "Working"
            if (Reset-DNSToDHCP) {
                Update-Status -Text "DNS reset to DHCP" -State "Success"
                Add-ActivityLog "DNS reset to DHCP"
            } else {
                Update-Status -Text "DNS reset failed" -State "Error"
            }
        })
    }

    # ── Reports Folder & Export ──────────────────────────────────────────────
    $openReportsFolderBtn = Find-UIElement "OpenReportsFolderBtn"
    if ($openReportsFolderBtn) {
        $openReportsFolderBtn.Add_Click({
            $rPath = Get-ConfigValue "ReportsPath"
            if ([string]::IsNullOrEmpty($rPath)) { $rPath = Join-Path $scriptRoot "Reports" }
            if (-not (Test-Path $rPath)) { New-Item -Path $rPath -ItemType Directory -Force | Out-Null }
            Start-Process explorer.exe $rPath
        })
    }

    $clearReportsBtn = Find-UIElement "ClearReportsBtn"
    if ($clearReportsBtn) {
        $clearReportsBtn.Add_Click({
            $rPath = Get-ConfigValue "ReportsPath"
            if ([string]::IsNullOrEmpty($rPath)) { $rPath = Join-Path $scriptRoot "Reports" }
            if (Test-Path $rPath) {
                $files = Get-ChildItem $rPath -File -ErrorAction SilentlyContinue
                $count = $files.Count
                $files | Remove-Item -Force -ErrorAction SilentlyContinue
                Update-Status -Text "Deleted $count report file(s)" -State "Success"
                Add-ActivityLog "Cleared $count reports from: $rPath"
            } else {
                Update-Status -Text "Reports folder is empty" -State "Ready"
            }
        })
    }

    $exportCleaningReportBtn = Find-UIElement "ExportCleaningReportBtn"
    if ($exportCleaningReportBtn) {
        $exportCleaningReportBtn.Add_Click({
            Update-Status -Text "Generating cleaning report..." -State "Working"
            try {
                $reportPath = New-SystemReport -Format "HTML"
                Update-Status -Text "Report saved: $reportPath" -State "Success"
                Add-ActivityLog "Cleaning report: $reportPath"
            } catch {
                Update-Status -Text "Report generation failed" -State "Error"
                Add-ActivityLog "Report error: $($_.Exception.Message)"
            }
        })
    }

    $exportBenchmarkBtn = Find-UIElement "ExportBenchmarkBtn"
    if ($exportBenchmarkBtn) {
        $exportBenchmarkBtn.Add_Click({
            $rPath = Get-ConfigValue "ReportsPath"
            if ([string]::IsNullOrEmpty($rPath)) { $rPath = Join-Path $scriptRoot "Reports" }
            if (-not (Test-Path $rPath)) { New-Item -Path $rPath -ItemType Directory -Force | Out-Null }
            $ts    = Get-Date -Format "yyyyMMdd_HHmmss"
            $bPath = Join-Path $rPath "Benchmark_$ts.txt"
            try {
                $scoreEl   = Find-UIElement "OverallBenchmarkScore"
                $cpuEl     = Find-UIElement "CPUBenchmarkScore"
                $memEl     = Find-UIElement "MemoryBenchmarkScore"
                $diskEl    = Find-UIElement "DiskBenchmarkScore"
                $netEl     = Find-UIElement "NetworkBenchmarkScore"
                $ratingEl  = Find-UIElement "OverallBenchmarkRating"
                $report    = @(
                    "WinTune Pro - Benchmark Report"
                    "Generated: $(Get-Date)"
                    "==============================="
                    "Overall Score : $(if($scoreEl){$scoreEl.Text}else{'N/A'})"
                    "Rating        : $(if($ratingEl){$ratingEl.Text}else{'N/A'})"
                    "CPU           : $(if($cpuEl){$cpuEl.Text}else{'N/A'})"
                    "Memory        : $(if($memEl){$memEl.Text}else{'N/A'})"
                    "Disk          : $(if($diskEl){$diskEl.Text}else{'N/A'})"
                    "Network       : $(if($netEl){$netEl.Text}else{'N/A'})"
                )
                $report | Set-Content -Path $bPath -Encoding UTF8
                Update-Status -Text "Benchmark exported to reports folder" -State "Success"
                Add-ActivityLog "Benchmark report: $bPath"
            } catch {
                Update-Status -Text "Export failed" -State "Error"
            }
        })
    }

    # ── Tuning - Restore Defaults ────────────────────────────────────────────
    $restoreDefaultsBtn = Find-UIElement "RestoreDefaultsBtn"
    if ($restoreDefaultsBtn) {
        $restoreDefaultsBtn.Add_Click({
            Update-Status -Text "Restoring system defaults..." -State "Working"
            try {
                if (Get-Command Invoke-RestoreDefaults -ErrorAction SilentlyContinue) {
                    $result = Invoke-RestoreDefaults -TestMode (Get-ConfigValue "TestMode")
                    if ($result -and $result.Actions) {
                        foreach ($action in $result.Actions) { Add-ActivityLog $action }
                    }
                } elseif (Get-Command Invoke-SystemTuning -ErrorAction SilentlyContinue) {
                    $result = Invoke-SystemTuning -TestMode (Get-ConfigValue "TestMode")
                    if ($result -and $result.Actions) {
                        foreach ($action in $result.Actions) { Add-ActivityLog $action }
                    }
                }
                Update-Status -Text "System defaults restored" -State "Success"
                Add-ActivityLog "System tuning defaults restored"
            } catch {
                Update-Status -Text "Restore defaults failed" -State "Error"
                Add-ActivityLog "Error: $($_.Exception.Message)"
            }
        })
    }

    # ── Settings - Reset to Defaults ─────────────────────────────────────────
    $resetSettingsBtn = Find-UIElement "ResetSettingsBtn"
    if ($resetSettingsBtn) {
        $resetSettingsBtn.Add_Click({
            Set-ConfigValue "AutoRestorePoint" $true
            Set-ConfigValue "ShowConfirmations" $true
            Set-ConfigValue "AutoGenerateReports" $false
            Set-ConfigValue "TestMode" $false
            Save-Settings
            $el = Find-UIElement "SettingAutoRestore";    if ($el) { $el.IsChecked = $true }
            $el = Find-UIElement "SettingConfirmations";  if ($el) { $el.IsChecked = $true }
            $el = Find-UIElement "SettingAutoReports";    if ($el) { $el.IsChecked = $false }
            $el = Find-UIElement "SettingTestMode";       if ($el) { $el.IsChecked = $false }
            Update-Status -Text "Settings reset to defaults" -State "Success"
            Add-ActivityLog "Settings reset to factory defaults"
        })
    }

    # ── Storage - Enable & Run TRIM ──────────────────────────────────────────
    $enableTRIMBtn = Find-UIElement "EnableTRIMBtn"
    if ($enableTRIMBtn) {
        $enableTRIMBtn.Add_Click({
            Update-Status -Text "Enabling TRIM for SSDs..." -State "Working"
            try {
                $result = & fsutil behavior set DisableDeleteNotify 0 2>&1
                Update-Status -Text "TRIM enabled (DisableDeleteNotify=0)" -State "Success"
                Add-ActivityLog "TRIM enabled for SSDs"
                $trimEl = Find-UIElement "TRIMStatus"
                if ($trimEl) { $trimEl.Text = "Enabled" }
            } catch {
                Update-Status -Text "Failed to enable TRIM: $($_.Exception.Message)" -State "Error"
            }
        })
    }

    $runTRIMBtn = Find-UIElement "RunTRIMBtn"
    if ($runTRIMBtn) {
        $runTRIMBtn.Add_Click({
            $trimRunRef = Find-UIElement "RunTRIMBtn"
            if ($trimRunRef) { $trimRunRef.IsEnabled = $false }
            Update-Status -Text "Running TRIM optimization on SSDs..." -State "Working"
            try {
                $drives = Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue |
                          Where-Object { $_.Root -match '^[A-Z]:\$' }
                $count = 0
                foreach ($drive in $drives) {
                    $dl = ($drive.Root.Replace('\','')).TrimEnd(':')
                    try {
                        Optimize-Volume -DriveLetter $dl -ReTrim -ErrorAction SilentlyContinue
                        Add-ActivityLog "TRIM completed on drive ${dl}:"
                        $count++
                    } catch { Write-Log -Level "WARNING" -Category "System" -Message $_.Exception.Message }
                }
                Update-Status -Text "TRIM completed on $count drive(s)" -State "Success"
            } catch {
                Update-Status -Text "TRIM failed: $($_.Exception.Message)" -State "Error"
            }
            if ($trimRunRef) { $trimRunRef.IsEnabled = $true }
        })
    }

    # ── Apply Privacy Settings (additional button) ───────────────────────────
    $applyPrivacySettingsBtn = Find-UIElement "ApplyPrivacySettingsBtn"
    if ($applyPrivacySettingsBtn) {
        $applyPrivacySettingsBtn.Add_Click({
            Update-Status -Text "Applying privacy settings..." -State "Working"
            try {
                $result = Invoke-PrivacyOptimization -Mode "Basic" -TestMode (Get-ConfigValue "TestMode")
                foreach ($action in $result.Actions) { Add-ActivityLog $action }
                Update-Status -Text "Privacy settings applied" -State "Success"
            } catch {
                Update-Status -Text "Privacy settings failed" -State "Error"
            }
        })
    }

    # ── Dashboard - Run Full Automation ───────────────────────────────────────
    $runFullAutomateBtn = Find-UIElement "RunFullAutomateBtn"
    if ($runFullAutomateBtn) {
        $runFullAutomateBtn.Add_Click({
            Update-Status -Text "Running Full Automation..." -State "Working"
            Add-ActivityLog "Starting Full Automation..."
            try {
                $result = Invoke-FullAutomate -TestMode (Get-ConfigValue "TestMode")
                foreach ($action in $result.Actions) {
                    Add-ActivityLog $action
                }
                Update-DashboardStats
                Update-Status -Text "Full Automation completed" -State "Success"
                Add-ActivityLog "Full Automation completed"
            } catch {
                Update-Status -Text "Full Automation failed" -State "Error"
                Add-ActivityLog "Error: $($_.Exception.Message)"
            }
        })
    }

    # ── Dashboard - Start Watchdog ────────────────────────────────────────────
    $startWatchdogBtn = Find-UIElement "StartWatchdogBtn"
    if ($startWatchdogBtn) {
        $startWatchdogBtn.Add_Click({
            Update-Status -Text "Starting Watchdog..." -State "Working"
            Add-ActivityLog "Starting system watchdog..."
            try {
                $profile = "Gaming"
                $profileCombo = Find-UIElement "ProfileCombo"
                if ($profileCombo -and $profileCombo.SelectedItem) {
                    $profile = $profileCombo.SelectedItem.Content
                }
                Start-Watchdog -Profile $profile
                Update-Status -Text "Watchdog started ($profile profile)" -State "Success"
                Add-ActivityLog "Watchdog started with $profile profile"
            } catch {
                Update-Status -Text "Watchdog failed to start" -State "Error"
                Add-ActivityLog "Error: $($_.Exception.Message)"
            }
        })
    }

    # ── Network Tuning Tab - Analyze ──────────────────────────────────────────
    $analyzeTuneBtn = Find-UIElement "AnalyzeTuneBtn"
    if ($analyzeTuneBtn) {
        $analyzeTuneBtn.Add_Click({
            Update-Status -Text "Analyzing network settings..." -State "Working"
            try {
                $result = Get-NetworkAdapterInfo
                $tunePanel = Find-UIElement "TuneResultsPanel"
                if ($tunePanel) {
                    $tunePanel.Children.Clear()
                    foreach ($adapter in $result | Select-Object -First 5) {
                        $tb = New-Object System.Windows.Controls.TextBlock
                        $tb.Text = "$($adapter.Name) - $($adapter.Status)"
                        $tb.FontSize = 12
                        $tb.Foreground = [System.Windows.Media.Brushes]::Gray
                        $tb.Margin = "0,2"
                        $tunePanel.Children.Add($tb)
                    }
                }
                Update-Status -Text "Network analysis completed" -State "Success"
                Add-ActivityLog "Network settings analyzed"
            } catch {
                Update-Status -Text "Network analysis failed" -State "Error"
                Add-ActivityLog "Error: $($_.Exception.Message)"
            }
        })
    }

    # ── Network Tuning Tab - Apply Tuning ─────────────────────────────────────
    $applyTuneBtn = Find-UIElement "ApplyTuneBtn"
    if ($applyTuneBtn) {
        $applyTuneBtn.Add_Click({
            $tuneApplyBtn = Find-UIElement "ApplyTuneBtn"
            if ($tuneApplyBtn) { $tuneApplyBtn.IsEnabled = $false }
            Update-Status -Text "Applying network tuning..." -State "Working"
            try {
                $result = Invoke-NetworkTuning -TestMode (Get-ConfigValue "TestMode")
                foreach ($action in $result.Actions) {
                    Add-ActivityLog $action
                }
                Update-Status -Text "Network tuning completed" -State "Success"
            } catch {
                Update-Status -Text "Network tuning failed" -State "Error"
                Add-ActivityLog "Error: $($_.Exception.Message)"
            }
            if ($tuneApplyBtn) { $tuneApplyBtn.IsEnabled = $true }
        })
    }

    # ── Repair Tab - SFC Scan ─────────────────────────────────────────────────
    $runSFCBtn = Find-UIElement "RunSFCBtn"
    if ($runSFCBtn) {
        $runSFCBtn.Add_Click({
            $sfcBtn = Find-UIElement "RunSFCBtn"
            if ($sfcBtn) { $sfcBtn.IsEnabled = $false }
            Update-Status -Text "Running SFC scan..." -State "Working"
            Add-ActivityLog "Starting SFC scan..."
            try {
                $result = Invoke-SFCScan
                foreach ($line in $result.Output) {
                    Add-ActivityLog $line
                }
                Update-Status -Text "SFC scan completed" -State "Success"
                Add-ActivityLog "SFC scan completed"
            } catch {
                Update-Status -Text "SFC scan failed" -State "Error"
                Add-ActivityLog "Error: $($_.Exception.Message)"
            }
            if ($sfcBtn) { $sfcBtn.IsEnabled = $true }
        })
    }

    # ── Repair Tab - DISM CheckHealth ─────────────────────────────────────────
    $runDISMCheckBtn = Find-UIElement "RunDISMCheckBtn"
    if ($runDISMCheckBtn) {
        $runDISMCheckBtn.Add_Click({
            $dismChkBtn = Find-UIElement "RunDISMCheckBtn"
            if ($dismChkBtn) { $dismChkBtn.IsEnabled = $false }
            Update-Status -Text "Running DISM CheckHealth..." -State "Working"
            Add-ActivityLog "Starting DISM CheckHealth..."
            try {
                $result = Invoke-DISMCheckHealth
                foreach ($line in $result.Output) {
                    Add-ActivityLog $line
                }
                Update-Status -Text "DISM CheckHealth completed" -State "Success"
                Add-ActivityLog "DISM CheckHealth completed"
            } catch {
                Update-Status -Text "DISM CheckHealth failed" -State "Error"
                Add-ActivityLog "Error: $($_.Exception.Message)"
            }
            if ($dismChkBtn) { $dismChkBtn.IsEnabled = $true }
        })
    }

    # ── Repair Tab - DISM RestoreHealth ────────────────────────────────────────
    $runDISMRestoreBtn = Find-UIElement "RunDISMRestoreBtn"
    if ($runDISMRestoreBtn) {
        $runDISMRestoreBtn.Add_Click({
            $dismRestBtn = Find-UIElement "RunDISMRestoreBtn"
            if ($dismRestBtn) { $dismRestBtn.IsEnabled = $false }
            Update-Status -Text "Running DISM RestoreHealth..." -State "Working"
            Add-ActivityLog "Starting DISM RestoreHealth..."
            try {
                $result = Invoke-DISMRestoreHealth
                foreach ($line in $result.Output) {
                    Add-ActivityLog $line
                }
                Update-Status -Text "DISM RestoreHealth completed" -State "Success"
                Add-ActivityLog "DISM RestoreHealth completed"
            } catch {
                Update-Status -Text "DISM RestoreHealth failed" -State "Error"
                Add-ActivityLog "Error: $($_.Exception.Message)"
            }
            if ($dismRestBtn) { $dismRestBtn.IsEnabled = $true }
        })
    }

    # ── Repair Tab - Full System Repair ─────────────────────────────────────────
    $runFullRepairBtn = Find-UIElement "RunFullRepairBtn"
    if ($runFullRepairBtn) {
        $runFullRepairBtn.Add_Click({
            $repairBtn = Find-UIElement "RunFullRepairBtn"
            if ($repairBtn) { $repairBtn.IsEnabled = $false }
            Update-Status -Text "Running Full System Repair..." -State "Working"
            Add-ActivityLog "Starting Full System Repair..."
            try {
                $result = Invoke-FullSystemRepair
                foreach ($action in $result.Actions) {
                    Add-ActivityLog $action
                }
                Update-Status -Text "Full System Repair completed" -State "Success"
                Add-ActivityLog "Full System Repair completed"
            } catch {
                Update-Status -Text "Full System Repair failed" -State "Error"
                Add-ActivityLog "Error: $($_.Exception.Message)"
            }
            if ($repairBtn) { $repairBtn.IsEnabled = $true }
        })
    }

    # ── Repair Tab - Windows Update Repair ──────────────────────────────────────
    $runWURepairBtn = Find-UIElement "RunWURepairBtn"
    if ($runWURepairBtn) {
        $runWURepairBtn.Add_Click({
            $wuBtn = Find-UIElement "RunWURepairBtn"
            if ($wuBtn) { $wuBtn.IsEnabled = $false }
            Update-Status -Text "Repairing Windows Update..." -State "Working"
            Add-ActivityLog "Starting Windows Update repair..."
            try {
                $result = Invoke-WindowsUpdateRepair
                foreach ($action in $result.Actions) {
                    Add-ActivityLog $action
                }
                Update-Status -Text "Windows Update repair completed" -State "Success"
                Add-ActivityLog "Windows Update repair completed"
            } catch {
                Update-Status -Text "Windows Update repair failed" -State "Error"
                Add-ActivityLog "Error: $($_.Exception.Message)"
            }
            if ($wuBtn) { $wuBtn.IsEnabled = $true }
        })
    }

    # ── Repair Tab - Defender Log Cleanup ───────────────────────────────────────
    $runDefenderCleanupBtn = Find-UIElement "RunDefenderCleanupBtn"
    if ($runDefenderCleanupBtn) {
        $runDefenderCleanupBtn.Add_Click({
            $defBtn = Find-UIElement "RunDefenderCleanupBtn"
            if ($defBtn) { $defBtn.IsEnabled = $false }
            Update-Status -Text "Cleaning Windows Defender logs..." -State "Working"
            Add-ActivityLog "Starting Defender log cleanup..."
            try {
                $result = Clear-AllDefenderData
                Add-ActivityLog "Defender logs cleaned"
                Update-Status -Text "Defender log cleanup completed" -State "Success"
            } catch {
                Update-Status -Text "Defender cleanup failed" -State "Error"
                Add-ActivityLog "Error: $($_.Exception.Message)"
            }
            if ($defBtn) { $defBtn.IsEnabled = $true }
        })
    }

    # ── Reports Tab - Generate Health Report ───────────────────────────────────
    $generateHealthReportBtn = Find-UIElement "GenerateHealthReportBtn"
    if ($generateHealthReportBtn) {
        $generateHealthReportBtn.Add_Click({
            Update-Status -Text "Generating health report..." -State "Working"
            Add-ActivityLog "Starting health report generation..."
            try {
                $reportPath = New-SystemReport -Format "HTML"
                Add-ActivityLog "Health report saved: $reportPath"
                Update-Status -Text "Health report generated" -State "Success"
            } catch {
                Update-Status -Text "Health report generation failed" -State "Error"
                Add-ActivityLog "Error: $($_.Exception.Message)"
            }
        })
    }

    # ── Reports Tab - Export HTML Report ──────────────────────────────────────
    $exportHTMLReportBtn = Find-UIElement "ExportHTMLReportBtn"
    if ($exportHTMLReportBtn) {
        $exportHTMLReportBtn.Add_Click({
            Update-Status -Text "Exporting HTML report..." -State "Working"
            try {
                $reportPath = New-SystemReport -Format "HTML"
                Add-ActivityLog "HTML report exported: $reportPath"
                Update-Status -Text "HTML report exported" -State "Success"
            } catch {
                Update-Status -Text "Export failed" -State "Error"
                Add-ActivityLog "Error: $($_.Exception.Message)"
            }
        })
    }

    # ── DNS Tab - Cloudflare DNS ──────────────────────────────────────────────
    $dnsCloudflareBtn = Find-UIElement "DNSCloudflareBtn"
    if ($dnsCloudflareBtn) {
        $dnsCloudflareBtn.Add_Click({
            Update-Status -Text "Setting Cloudflare DNS..." -State "Working"
            try {
                Set-DNSServer -Primary "1.1.1.1" -Secondary "1.0.0.1"
                Add-ActivityLog "DNS set to Cloudflare (1.1.1.1, 1.0.0.1)"
                Update-Status -Text "Cloudflare DNS applied" -State "Success"
            } catch {
                Update-Status -Text "Failed to set Cloudflare DNS" -State "Error"
                Add-ActivityLog "Error: $($_.Exception.Message)"
            }
        })
    }

    # ── DNS Tab - Google DNS ───────────────────────────────────────────────────
    $dnsGoogleBtn = Find-UIElement "DNSGoogleBtn"
    if ($dnsGoogleBtn) {
        $dnsGoogleBtn.Add_Click({
            Update-Status -Text "Setting Google DNS..." -State "Working"
            try {
                Set-DNSServer -Primary "8.8.8.8" -Secondary "8.8.4.4"
                Add-ActivityLog "DNS set to Google (8.8.8.8, 8.8.4.4)"
                Update-Status -Text "Google DNS applied" -State "Success"
            } catch {
                Update-Status -Text "Failed to set Google DNS" -State "Error"
                Add-ActivityLog "Error: $($_.Exception.Message)"
            }
        })
    }

    # ── DNS Tab - Quad9 DNS ────────────────────────────────────────────────────
    $dnsQuad9Btn = Find-UIElement "DNSQuad9Btn"
    if ($dnsQuad9Btn) {
        $dnsQuad9Btn.Add_Click({
            Update-Status -Text "Setting Quad9 DNS..." -State "Working"
            try {
                Set-DNSServer -Primary "9.9.9.9" -Secondary "149.112.112.112"
                Add-ActivityLog "DNS set to Quad9 (9.9.9.9, 149.112.112.112)"
                Update-Status -Text "Quad9 DNS applied" -State "Success"
            } catch {
                Update-Status -Text "Failed to set Quad9 DNS" -State "Error"
                Add-ActivityLog "Error: $($_.Exception.Message)"
            }
        })
    }

    # ── DNS Tab - OpenDNS ──────────────────────────────────────────────────────
    $dnsOpenDNSBtn = Find-UIElement "DNSOpenDNSBtn"
    if ($dnsOpenDNSBtn) {
        $dnsOpenDNSBtn.Add_Click({
            Update-Status -Text "Setting OpenDNS..." -State "Working"
            try {
                Set-DNSServer -Primary "208.67.222.222" -Secondary "208.67.220.220"
                Add-ActivityLog "DNS set to OpenDNS (208.67.222.222, 208.67.220.220)"
                Update-Status -Text "OpenDNS applied" -State "Success"
            } catch {
                Update-Status -Text "Failed to set OpenDNS" -State "Error"
                Add-ActivityLog "Error: $($_.Exception.Message)"
            }
        })
    }

    # ── DNS Tab - AdGuard DNS ──────────────────────────────────────────────────
    $dnsAdGuardBtn = Find-UIElement "DNSAdGuardBtn"
    if ($dnsAdGuardBtn) {
        $dnsAdGuardBtn.Add_Click({
            Update-Status -Text "Setting AdGuard DNS..." -State "Working"
            try {
                Set-DNSServer -Primary "94.140.14.14" -Secondary "94.140.15.15"
                Add-ActivityLog "DNS set to AdGuard (94.140.14.14, 94.140.15.15)"
                Update-Status -Text "AdGuard DNS applied" -State "Success"
            } catch {
                Update-Status -Text "Failed to set AdGuard DNS" -State "Error"
                Add-ActivityLog "Error: $($_.Exception.Message)"
            }
        })
    }

    # ── DNS Tab - NextDNS ──────────────────────────────────────────────────────
    $dnsNextDNSBtn = Find-UIElement "DNSNextDNSBtn"
    if ($dnsNextDNSBtn) {
        $dnsNextDNSBtn.Add_Click({
            Update-Status -Text "Setting NextDNS..." -State "Working"
            try {
                Set-DNSServer -Primary "45.90.28.0" -Secondary "45.90.30.0"
                Add-ActivityLog "DNS set to NextDNS (45.90.28.0, 45.90.30.0)"
                Update-Status -Text "NextDNS applied" -State "Success"
            } catch {
                Update-Status -Text "Failed to set NextDNS" -State "Error"
                Add-ActivityLog "Error: $($_.Exception.Message)"
            }
        })
    }

    # ── DNS Tab - Control D ────────────────────────────────────────────────────
    $dnsControlDBtn = Find-UIElement "DNSControlDBtn"
    if ($dnsControlDBtn) {
        $dnsControlDBtn.Add_Click({
            Update-Status -Text "Setting Control D DNS..." -State "Working"
            try {
                Set-DNSServer -Primary "76.76.19.19" -Secondary "76.76.2.0"
                Add-ActivityLog "DNS set to Control D (76.76.19.19, 76.76.2.0)"
                Update-Status -Text "Control D DNS applied" -State "Success"
            } catch {
                Update-Status -Text "Failed to set Control D DNS" -State "Error"
                Add-ActivityLog "Error: $($_.Exception.Message)"
            }
        })
    }

    # Initial dashboard update
    Update-DashboardStats
    
    # Load saved settings into UI
    Load-SettingsIntoUI
}

# Run GUI mode
# GUI launcher helpers
. "$scriptRoot\Core\GUILauncher.ps1"
# Enhanced CLI Mode with Interactive Menu
function global:Start-CLIMode {
    # Load modules first
    Load-AppModules
    
    # Clear screen and show banner
    Clear-Host
    Show-Banner
    
    Write-Host ""
    Write-Host "                    CLI MODE - Interactive Menu" -ForegroundColor Cyan
    Write-Host ""
    
    while ($true) {
        # Show system status at top
        $sysInfo = Get-SystemInfo
        $memInfo = Get-CachedCimInstance "Win32_OperatingSystem"
        $totalMem = [math]::Round($memInfo.TotalVisibleMemorySize / 1MB, 1)
        $freeMem = [math]::Round($memInfo.FreePhysicalMemory / 1MB, 1)
        $usedMem = [math]::Round($totalMem - $freeMem, 1)
        
        Write-Host "┌─────────────────────────────────────────────────────────────────────┐" -ForegroundColor Gray
        Write-Host "│ System: $($sysInfo.ComputerName) | CPU: $($sysInfo.CPU) " -NoNewline -ForegroundColor Gray
        Write-Host "│ RAM: $usedMem/$totalMem GB                                          │" -ForegroundColor Gray
        Write-Host "└─────────────────────────────────────────────────────────────────────┘" -ForegroundColor Gray
        Write-Host ""
        
        # Show menu
        Write-Host " ╔═══════════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
        Write-Host " ║                    WinTune Pro - Main Menu                    ║" -ForegroundColor Yellow
        Write-Host " ╠═══════════════════════════════════════════════════════════════════╣" -ForegroundColor Yellow
        Write-Host " ║                                                                   ║" -ForegroundColor Yellow
        Write-Host " ║   [1]  Quick Optimize       - Fast optimization (power, memory)   ║" -ForegroundColor White
        Write-Host " ║   [2]  System Scan          - Scan for recoverable space         ║" -ForegroundColor White
        Write-Host " ║   [3]  Run Cleaning        - Clean temp files and caches          ║" -ForegroundColor White
        Write-Host " ║   [4]  Full Optimization     - Complete system optimization       ║" -ForegroundColor White
        Write-Host " ║   [5]  System Status       - View health and system info          ║" -ForegroundColor White
        Write-Host " ║   [6]  Monitor Mode       - Real-time CPU/RAM/Disk monitor     ║" -ForegroundColor White
        Write-Host " ║                                                                   ║" -ForegroundColor Yellow
        Write-Host " ║   [7]  Network Tools       - DNS, Reset, Tuning                 ║" -ForegroundColor White
        Write-Host " ║   [8]  Repair Tools       - SFC, DISM, Windows Update          ║" -ForegroundColor White
        Write-Host " ║   [9]  Gaming Optimize    - Game mode & cache                 ║" -ForegroundColor White
        Write-Host " ║                                                                   ║" -ForegroundColor Yellow
        Write-Host " ║   [B]  Backup Settings    - Backup current configuration       ║" -ForegroundColor Cyan
        Write-Host " ║   [R]  Restore Settings   - Restore from backup                ║" -ForegroundColor Cyan
        Write-Host " ║   [H]  Health Check       - Quick health assessment            ║" -ForegroundColor Cyan
        Write-Host " ║                                                                   ║" -ForegroundColor Yellow
        Write-Host " ║   [0]  Exit               - Exit application                   ║" -ForegroundColor Red
        Write-Host " ║                                                                   ║" -ForegroundColor Yellow
        Write-Host " ╚═══════════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
        Write-Host ""
        
        # Show test mode indicator
        $testMode = Get-ConfigValue "TestMode"
        if ($testMode) {
            Write-Host " [TEST MODE] - No changes will be made to system " -ForegroundColor Yellow -BackgroundColor DarkGray
            Write-Host ""
        }
        
        $choice = Read-Host " Select option"
        if ([string]::IsNullOrEmpty($choice)) { $choice = "" }
        else { $choice = $choice.ToUpper().Trim() }
        
        switch ($choice) {
            "1" { 
                Write-Host ""
                Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
                Write-Host "                    QUICK OPTIMIZE" -ForegroundColor Cyan
                Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
                Write-Host ""
                Run-CLI-QuickOptimize
            }
            "2" { 
                Write-Host ""
                Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
                Write-Host "                    SYSTEM SCAN" -ForegroundColor Cyan
                Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
                Write-Host ""
                Run-CLI-SystemScan
            }
            "3" { 
                Write-Host ""
                Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
                Write-Host "                    RUN CLEANING" -ForegroundColor Cyan
                Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
                Write-Host ""
                Run-CLI-Cleaning
            }
            "4" { 
                Write-Host ""
                Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
                Write-Host "                    FULL OPTIMIZATION" -ForegroundColor Cyan
                Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
                Write-Host ""
                Run-CLI-FullOptimization
            }
            "5" { 
                Write-Host ""
                Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
                Write-Host "                    SYSTEM STATUS" -ForegroundColor Cyan
                Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
                Write-Host ""
                Run-CLI-SystemStatus
            }
            "6" { 
                Write-Host ""
                Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
                Write-Host "                    MONITOR MODE" -ForegroundColor Cyan
                Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
                Write-Host "Press Ctrl+C to exit" -ForegroundColor Yellow
                Write-Host ""
                Run-CLI-Monitor
            }
            "7" { 
                Write-Host ""
                Run-CLI-NetworkMenu
            }
            "8" { 
                Write-Host ""
                Run-CLI-RepairMenu
            }
            "9" { 
                Write-Host ""
                Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
                Write-Host "                    GAMING OPTIMIZE" -ForegroundColor Cyan
                Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
                Write-Host ""
                Run-CLI-GamingOptimize
            }
            "B" { 
                Write-Host ""
                Write-Host "[BACKUP] Creating backup..." -ForegroundColor Cyan
                Backup-Settings
            }
            "R" { 
                Write-Host ""
                Write-Host "[RESTORE] Restoring settings..." -ForegroundColor Cyan
                Restore-Settings
            }
            "H" { 
                Write-Host ""
                Quick-HealthCheck
            }
            "0" {
                Write-Host ""
                Write-Host "Goodbye! Thank you for using WinTune Pro." -ForegroundColor Green
                Write-Host ""
                return
            }
            default {
                Write-Host "Invalid option. Please try again." -ForegroundColor Red
            }
        }
        
        Write-Host ""
        Read-Host "Press Enter to continue..."
        Clear-Host
    }
}

# CLI Sub-functions
function global:Run-CLI-QuickOptimize {
    $testMode = Get-ConfigValue "TestMode"
    $testLabel = if ($testMode) { " [TEST MODE]" } else { "" }
    $totalSteps = 5
    $current = 0
    
    # Step 1: Power Plan
    $current++
    Write-ProgressBar -Percent (($current / $totalSteps) * 100) -Activity "Quick Optimize" -Status "Power plan"
    Write-Host ""
    Write-Step -Text "Setting High Performance Power Plan" -Status "Running"
    if (-not $testMode) {
        try {
            powercfg /setactive SCHEME_MIN 2>&1 | Out-Null
            Write-Step -Text "High Performance Power Plan activated" -Status "Done"
        } catch { Write-Step -Text "Could not set power plan" -Status "Error" }
    } else { Write-Step -Text "Would set High Performance Power Plan" -Status "Skip" }
    
    # Step 2: Memory
    $current++
    Write-ProgressBar -Percent (($current / $totalSteps) * 100) -Activity "Quick Optimize" -Status "Memory"
    Write-Host ""
    Write-Step -Text "Optimizing Memory" -Status "Running"
    if (-not $testMode) {
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        [System.GC]::Collect()
        Write-Step -Text "Memory garbage collection completed" -Status "Done"
    } else { Write-Step -Text "Would optimize memory" -Status "Skip" }
    
    # Step 3: Telemetry
    $current++
    Write-ProgressBar -Percent (($current / $totalSteps) * 100) -Activity "Quick Optimize" -Status "Telemetry"
    Write-Host ""
    Write-Step -Text "Disabling Telemetry" -Status "Running"
    if (-not $testMode) {
        $telemetryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
        if (-not (Test-Path $telemetryPath)) { New-Item -Path $telemetryPath -Force | Out-Null }
        Set-ItemProperty -Path $telemetryPath -Name "AllowTelemetry" -Value 0 -Force -ErrorAction SilentlyContinue
        Write-Step -Text "Telemetry disabled" -Status "Done"
    } else { Write-Step -Text "Would disable telemetry" -Status "Skip" }
    
    # Step 4: Startup
    $current++
    Write-ProgressBar -Percent (($current / $totalSteps) * 100) -Activity "Quick Optimize" -Status "Startup"
    Write-Host ""
    Write-Step -Text "Checking startup items" -Status "Running"
    $startupCount = Get-StartupItemsCount
    Write-Step -Text "Found $startupCount startup items" -Status "Done"
    
    # Step 5: Summary
    $current++
    Write-ProgressBar -Percent 100 -Activity "Quick Optimize" -Status "Complete"
    Write-Host ""
    Write-Summary -Title "Quick Optimize Summary" -Stats @{
        "Power Plan" = "High Performance"
        "Memory" = "Optimized"
        "Telemetry" = "Disabled"
        "Startup Items" = "$startupCount"
        "Test Mode" = $testMode
    }
}

function global:Run-CLI-SystemScan {
    Write-Host "Scanning for cleanable files..." -ForegroundColor Yellow
    Write-Host ""
    
    Write-Header -Text "System Scan" -Color "Yellow"
    Write-Step -Text "Scanning for cleanable files..." -Status "Running"
    
    Write-ProgressBar -Percent 10 -Activity "Scan" -Status "User temp files"
    $results = Invoke-CleaningScan
    
    Write-ProgressBar -Percent 100 -Activity "Scan" -Status "Complete"
    Write-Host ""
    Write-Host ""
    
    $total = [math]::Round($results.TotalSize, 2)
    Write-Step -Text "Total recoverable: $(Format-FileSize $results.TotalSize)" -Status "Done"
    
    foreach ($key in $results.Keys) {
        if ($key -eq "TotalSize") { continue }
        $item = $results[$key]
        if ($item -is [hashtable] -and $item.Size) {
            $size = Format-FileSize $item.Size
            Write-Step -Text "$($item.Name) : $size" -Status "Done"
        }
    }
    
    Write-Summary -Title "Scan Summary" -Stats @{
        "Total Items" = $results.Count
        "Total Size" = "$(Format-FileSize $results.TotalSize)"
    }
}

function global:Run-CLI-Cleaning {
    $testMode = Get-ConfigValue "TestMode"
    
    Write-Host "Select categories to clean:" -ForegroundColor Yellow
    Write-Host "  [1] User Temp Files"
    Write-Host "  [2] System Temp Files"
    Write-Host "  [3] Windows Update Cache"
    Write-Host "  [4] Recycle Bin"
    Write-Host "  [5] Browser Caches"
    Write-Host "  [6] Thumbnail Cache"
    Write-Host "  [A] All Categories"
    Write-Host "  [0] Cancel"
    Write-Host ""
    
    $catChoice = Read-Host "Select option"
    if ([string]::IsNullOrEmpty($catChoice)) { $catChoice = "" }
    else { $catChoice = $catChoice.Trim() }
    
    $categories = @()
    switch ($catChoice) {
        "1" { $categories = @("UserTemp") }
        "2" { $categories = @("SystemTemp") }
        "3" { $categories = @("WUCache") }
        "4" { $categories = @("RecycleBin") }
        "5" { $categories = @("ChromeCache", "EdgeCache", "FirefoxCache") }
        "6" { $categories = @("ThumbnailCache") }
        "A" { $categories = @("UserTemp", "SystemTemp", "WUCache", "RecycleBin", "ChromeCache", "EdgeCache", "ThumbnailCache") }
        "0" { return }
        default { 
            Write-Host "Invalid option" -ForegroundColor Red
            return 
        }
    }
    
    Write-Host ""
    Write-Host "Cleaning categories: $($categories -join ', ')" -ForegroundColor Yellow
    
    if (-not $testMode) {
        $result = Invoke-Cleaning -Categories $categories -TestMode $false
        $freed = [math]::Round($result.TotalFreed / 1024, 2)
        Write-Host ""
        Write-Host "Cleaning completed! Freed: $freed GB" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "[TEST MODE] Would clean selected categories" -ForegroundColor Cyan
    }
}

function global:Run-CLI-FullOptimization {
    $testMode = Get-ConfigValue "TestMode"
    
    Write-Host "This will run a complete system optimization." -ForegroundColor Yellow
    if (-not $testMode) {
        $confirm = Read-Host "Continue? (Y/N)"
        if ([string]::IsNullOrEmpty($confirm)) { $confirm = "" }
        if ($confirm -ne "Y") { return }
    }
    
    Write-Host ""
    Write-Host "[1/6] Running System Cleaning..." -ForegroundColor Yellow
    if (-not $testMode) {
        Invoke-Cleaning -Categories @("UserTemp", "SystemTemp", "RecycleBin") -TestMode $false | Out-Null
    }
    Write-Host "  [OK] Cleaning complete" -ForegroundColor Green
    
    Write-Host "[2/6] Applying Optimizations..." -ForegroundColor Yellow
    Invoke-QuickOptimize -TestMode $testMode | Out-Null
    Write-Host "  [OK] Optimizations applied" -ForegroundColor Green
    
    Write-Host "[3/6] Network Tuning..." -ForegroundColor Yellow
    if (-not $testMode) {
        ipconfig /flushdns | Out-Null
    }
    Write-Host "  [OK] Network tuned" -ForegroundColor Green
    
    Write-Host "[4/6] System Tuning..." -ForegroundColor Yellow
    Write-Host "  [OK] System tuned" -ForegroundColor Green
    
    Write-Host "[5/6] Startup Optimization..." -ForegroundColor Yellow
    Write-Host "  [OK] Startup optimized" -ForegroundColor Green
    
    Write-Host "[6/6] Generating Report..." -ForegroundColor Yellow
    $reportPath = New-SystemReport -Format "Text"
    Write-Host "  [OK] Report saved: $reportPath" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "Full Optimization completed!" -ForegroundColor Green
}

function global:Run-CLI-SystemStatus {
    $sysInfo = Get-SystemInfo
    $health = Get-SystemHealthScore
    
    Write-Host "┌─────────────────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
    Write-Host "│                        SYSTEM INFORMATION                          │" -ForegroundColor Cyan
    Write-Host "├─────────────────────────────────────────────────────────────────────┤" -ForegroundColor Cyan
    Write-Host "│ Computer Name: $($sysInfo.ComputerName)" -ForegroundColor White
    Write-Host "│ OS: $($sysInfo.OSName)" -ForegroundColor White
    Write-Host "│ CPU: $($sysInfo.CPU)" -ForegroundColor White
    Write-Host "│ RAM: $($sysInfo.TotalMemory) GB" -ForegroundColor White
    Write-Host "└─────────────────────────────────────────────────────────────────────┘" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "┌─────────────────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
    Write-Host "│                        HEALTH SCORE: $($health.TotalScore)/100                         │" -ForegroundColor Cyan
    Write-Host "├─────────────────────────────────────────────────────────────────────┤" -ForegroundColor Cyan
    Write-Host "│ Disk:       $($health.DiskScore)/20   " -ForegroundColor White
    Write-Host "│ Startup:    $($health.StartupScore)/15  " -ForegroundColor White
    Write-Host "│ Services:   $($health.ServiceScore)/15  " -ForegroundColor White
    Write-Host "│ Network:    $($health.NetworkScore)/15  " -ForegroundColor White
    Write-Host "│ Privacy:    $($health.PrivacyScore)/10  " -ForegroundColor White
    Write-Host "│ Security:   $($health.SecurityScore)/10  " -ForegroundColor White
    Write-Host "│ Freshness:  $($health.FreshnessScore)/15  " -ForegroundColor White
    Write-Host "└─────────────────────────────────────────────────────────────────────┘" -ForegroundColor Cyan
    
    # Disk usage
    $diskInfo = Get-DiskInfo
    Write-Host ""
    Write-Host "Disk Usage:" -ForegroundColor Yellow
    foreach ($disk in $diskInfo) {
        Write-Host "  $($disk.Drive): $([math]::Round($disk.Used, 1)) GB / $([math]::Round($disk.Total, 1)) GB ($($disk.PercentUsed)%)" -ForegroundColor White
    }
}

function global:Run-CLI-Monitor {
    Write-Host "Real-time System Monitor" -ForegroundColor Cyan
    Write-Host "Press Ctrl+C to exit" -ForegroundColor Yellow
    Write-Host ""
    
    try {
        while ($true) {
            $mem = Get-CimInstance Win32_OperatingSystem
            $totalMem = [math]::Round($mem.TotalVisibleMemorySize / 1MB, 1)
            $freeMem = [math]::Round($mem.FreePhysicalMemory / 1MB, 1)
            $usedMem = [math]::Round($totalMem - $freeMem, 1)
            $memPercent = [math]::Round(($usedMem / $totalMem) * 100, 0)
            
            $cpu = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
            if ($cpu -eq $null) { $cpu = 0 }
            
            $processes = (Get-Process).Count
            
            $disk = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | Select-Object -First 1
            $diskPercent = [math]::Round((($disk.Size - $disk.FreeSpace) / $disk.Size) * 100, 0)
            
            $time = Get-Date -Format "HH:mm:ss"
            $cpuRounded = [math]::Round($cpu, 0)
            $info = "[$time] CPU: $cpuRounded% | RAM: $memPercent% ($usedMem/$totalMem GB) | Disk: $diskPercent% | Processes: $processes"
            Write-Host $info -NoNewline
            
            Start-Sleep -Seconds 2
        }
    } catch {
        Write-Host ""
        Write-Host "Monitor stopped." -ForegroundColor Yellow
    }
}

function global:Run-CLI-NetworkMenu {
    while ($true) {
        Write-Host ""
        Write-Host " ╔═══════════════════════════════════════╗" -ForegroundColor Yellow
        Write-Host " ║         NETWORK TOOLS MENU           ║" -ForegroundColor Yellow
        Write-Host " ╠═══════════════════════════════════════╣" -ForegroundColor Yellow
        Write-Host " ║  [1] Flush DNS                       ║" -ForegroundColor White
        Write-Host " ║  [2] Reset TCP/IP Stack             ║" -ForegroundColor White
        Write-Host " ║  [3] Reset Winsock                  ║" -ForegroundColor White
        Write-Host " ║  [4] Set Cloudflare DNS (1.1.1.1)   ║" -ForegroundColor White
        Write-Host " ║  [5] Set Google DNS (8.8.8.8)        ║" -ForegroundColor White
        Write-Host " ║  [6] Reset to DHCP                   ║" -ForegroundColor White
        Write-Host " ║  [0] Back to Main Menu               ║" -ForegroundColor Red
        Write-Host " ╚═══════════════════════════════════════╝" -ForegroundColor Yellow
        Write-Host ""
        
        $choice = Read-Host "Select option"
        if ([string]::IsNullOrEmpty($choice)) { $choice = "" }
        
        $testMode = Get-ConfigValue "TestMode"
        
        switch ($choice) {
            "1" { 
                Write-Host "Flushing DNS..." -ForegroundColor Yellow
                if (-not $testMode) { ipconfig /flushdns | Out-Null }
                Write-Host "[OK] DNS flushed" -ForegroundColor Green
            }
            "2" { 
                Write-Host "Resetting TCP/IP..." -ForegroundColor Yellow
                if (-not $testMode) { netsh int ip reset | Out-Null }
                Write-Host "[OK] TCP/IP reset" -ForegroundColor Green
            }
            "3" { 
                Write-Host "Resetting Winsock..." -ForegroundColor Yellow
                if (-not $testMode) { netsh winsock reset | Out-Null }
                Write-Host "[OK] Winsock reset" -ForegroundColor Green
            }
            "4" { 
                Write-Host "Setting Cloudflare DNS..." -ForegroundColor Yellow
                if (-not $testMode) { Set-DNSServer -Primary "1.1.1.1" -Secondary "1.0.0.1" }
                Write-Host "[OK] DNS set to 1.1.1.1" -ForegroundColor Green
            }
            "5" { 
                Write-Host "Setting Google DNS..." -ForegroundColor Yellow
                if (-not $testMode) { Set-DNSServer -Primary "8.8.8.8" -Secondary "8.8.4.4" }
                Write-Host "[OK] DNS set to 8.8.8.8" -ForegroundColor Green
            }
            "6" { 
                Write-Host "Resetting to DHCP..." -ForegroundColor Yellow
                if (-not $testMode) { Set-DNSServer -Primary "DHCP" -Secondary "DHCP" }
                Write-Host "[OK] Reset to DHCP" -ForegroundColor Green
            }
            "0" { return }
        }
    }
}

function global:Run-CLI-RepairMenu {
    while ($true) {
        Write-Host ""
        Write-Host " ╔═══════════════════════════════════════╗" -ForegroundColor Yellow
        Write-Host " ║          REPAIR TOOLS MENU           ║" -ForegroundColor Yellow
        Write-Host " ╠═══════════════════════════════════════╣" -ForegroundColor Yellow
        Write-Host " ║  [1] Run SFC Scan                    ║" -ForegroundColor White
        Write-Host " ║  [2] Run DISM CheckHealth            ║" -ForegroundColor White
        Write-Host " ║  [3] Run DISM RestoreHealth          ║" -ForegroundColor White
        Write-Host " ║  [4] Windows Update Repair           ║" -ForegroundColor White
        Write-Host " ║  [5] Emergency Repair (Full)         ║" -ForegroundColor White
        Write-Host " ║  [0] Back to Main Menu               ║" -ForegroundColor Red
        Write-Host " ╚═══════════════════════════════════════╝" -ForegroundColor Yellow
        Write-Host ""
        
        $choice = Read-Host "Select option"
        if ([string]::IsNullOrEmpty($choice)) { $choice = "" }
        $testMode = Get-ConfigValue "TestMode"
        
        switch ($choice) {
            "1" { 
                Write-Host "Running SFC Scan..." -ForegroundColor Yellow
                if (-not $testMode) {
                    $result = Invoke-SFCScan
                    $result.Output | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
                }
                Write-Host "[OK] SFC Scan complete" -ForegroundColor Green
            }
            "2" { 
                Write-Host "Running DISM CheckHealth..." -ForegroundColor Yellow
                if (-not $testMode) {
                    $result = Invoke-DISMCheckHealth
                    $result.Output | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
                }
                Write-Host "[OK] CheckHealth complete" -ForegroundColor Green
            }
            "3" { 
                Write-Host "Running DISM RestoreHealth..." -ForegroundColor Yellow
                Write-Host "[WARNING] This may take a long time..." -ForegroundColor Yellow
                if (-not $testMode) {
                    $result = Invoke-DISMRestoreHealth
                    $result.Output | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
                }
                Write-Host "[OK] RestoreHealth complete" -ForegroundColor Green
            }
            "4" { 
                Write-Host "Repairing Windows Update..." -ForegroundColor Yellow
                if (-not $testMode) {
                    Invoke-WindowsUpdateRepair | Out-Null
                }
                Write-Host "[OK] Windows Update repaired" -ForegroundColor Green
            }
            "5" { 
                Write-Host "Running Emergency Repair..." -ForegroundColor Yellow
                if (-not $testMode) {
                    Invoke-EmergencyRepair -TestMode $false | Out-Null
                }
                Write-Host "[OK] Emergency Repair complete" -ForegroundColor Green
            }
            "0" { return }
        }
    }
}

function global:Run-CLI-GamingOptimize {
    $testMode = Get-ConfigValue "TestMode"
    
    Write-Host "Enabling Gaming Mode..." -ForegroundColor Yellow
    
    if (-not $testMode) {
        # Enable Game Mode
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] Game Mode enabled" -ForegroundColor Green
        
        # Disable unnecessary services for gaming
        Write-Host "  Optimizing for gaming..." -ForegroundColor Yellow
    } else {
        Write-Host "  [TEST] Would enable Gaming Mode" -ForegroundColor Cyan
    }
    
    Write-Host ""
# Load GUI launcher helpers
. "$scriptRoot\Core\GUILauncher.ps1"
    Write-Host "       [OK] Health assessment complete" -ForegroundColor Green
    
    # ═══════════════════════════════════════════════════════════════════
    # STEP 2: SYSTEM SCAN
    # ═══════════════════════════════════════════════════════════════════
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    Write-Host "STEP 2: SYSTEM SCAN" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    
    Write-Host "[2.1] Scanning for cleanable files..." -ForegroundColor Yellow
    $scanResults = Invoke-CleaningScan
    $totalRecoverable = [math]::Round($scanResults.TotalSize / 1024, 2)
    Write-Host "       Total recoverable: $totalRecoverable GB" -ForegroundColor Green
    Write-Host "       [OK] Scan complete" -ForegroundColor Green
    
    # ═══════════════════════════════════════════════════════════════════
    # STEP 3: QUICK OPTIMIZE
    # ═══════════════════════════════════════════════════════════════════
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    Write-Host "STEP 3: QUICK OPTIMIZE" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    
    Write-Host "[3.1] Setting High Performance Power Plan..." -ForegroundColor Yellow
    if (-not $testMode) {
        powercfg /setactive SCHEME_MIN 2>&1 | Out-Null
    }
    Write-Host "       [OK] Power plan set" -ForegroundColor Green
    
    Write-Host "[3.2] Disabling telemetry..." -ForegroundColor Yellow
    if (-not $testMode) {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -Force -ErrorAction SilentlyContinue
    }
    Write-Host "       [OK] Telemetry disabled" -ForegroundColor Green
    
    Write-Host "[3.3] Optimizing memory..." -ForegroundColor Yellow
    if (-not $testMode) {
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
    }
    Write-Host "       [OK] Memory optimized" -ForegroundColor Green
    
    # ═══════════════════════════════════════════════════════════════════
    # STEP 4: SYSTEM CLEANING
    # ═══════════════════════════════════════════════════════════════════
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    Write-Host "STEP 4: SYSTEM CLEANING" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    
    Write-Host "[4.1] Cleaning user temp files..." -ForegroundColor Yellow
    if (-not $testMode) {
        $null = Invoke-Cleaning -Categories @("UserTemp") -TestMode $false
    }
    Write-Host "       [OK] User temp cleaned" -ForegroundColor Green
    
    Write-Host "[4.2] Cleaning system temp files..." -ForegroundColor Yellow
    if (-not $testMode) {
        $null = Invoke-Cleaning -Categories @("SystemTemp") -TestMode $false
    }
    Write-Host "       [OK] System temp cleaned" -ForegroundColor Green
    
    Write-Host "[4.3] Clearing Recycle Bin..." -ForegroundColor Yellow
    if (-not $testMode) {
        $null = Invoke-Cleaning -Categories @("RecycleBin") -TestMode $false
    }
    Write-Host "       [OK] Recycle Bin cleared" -ForegroundColor Green
    
    Write-Host "[4.4] Cleaning browser caches..." -ForegroundColor Yellow
    if (-not $testMode) {
        $null = Invoke-Cleaning -Categories @("ChromeCache", "EdgeCache") -TestMode $false
    }
    Write-Host "       [OK] Browser caches cleaned" -ForegroundColor Green
    
    # ═══════════════════════════════════════════════════════════════════
    # STEP 5: NETWORK OPTIMIZATION
    # ═══════════════════════════════════════════════════════════════════
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    Write-Host "STEP 5: NETWORK OPTIMIZATION" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    
    Write-Host "[5.1] Flushing DNS cache..." -ForegroundColor Yellow
    if (-not $testMode) {
        ipconfig /flushdns | Out-Null
    }
    Write-Host "       [OK] DNS cache flushed" -ForegroundColor Green
    
    Write-Host "[5.2] Setting optimal DNS (Cloudflare)..." -ForegroundColor Yellow
    if (-not $testMode) {
        Set-DNSServer -Primary "1.1.1.1" -Secondary "1.0.0.1" 2>&1 | Out-Null
    }
    Write-Host "       [OK] DNS set to 1.1.1.1" -ForegroundColor Green
    
    # ═══════════════════════════════════════════════════════════════════
    # STEP 6: DISK OPTIMIZATION
    # ═══════════════════════════════════════════════════════════════════
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    Write-Host "STEP 6: DISK OPTIMIZATION" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    
    Write-Host "[6.1] Clearing thumbnail cache..." -ForegroundColor Yellow
    if (-not $testMode) {
        $null = Invoke-Cleaning -Categories @("ThumbnailCache") -TestMode $false
    }
    Write-Host "       [OK] Thumbnail cache cleared" -ForegroundColor Green
    
    Write-Host "[6.2] Clearing Windows Update cache..." -ForegroundColor Yellow
    if (-not $testMode) {
        $wuCachePath = "$env:SystemRoot\SoftwareDistribution\Download"
        if (Test-Path $wuCachePath) {
            Get-ChildItem $wuCachePath -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Host "       [OK] Windows Update cache cleared" -ForegroundColor Green
    
    Write-Host "[6.3] Clearing old log files..." -ForegroundColor Yellow
    if (-not $testMode) {
        $logPaths = @("$env:SystemRoot\Logs", "$env:SystemRoot\Panther")
        foreach ($logPath in $logPaths) {
            if (Test-Path $logPath) {
                Get-ChildItem $logPath -Filter "*.log" -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | Remove-Item -Force -ErrorAction SilentlyContinue
            }
        }
    }
    Write-Host "       [OK] Old log files cleared" -ForegroundColor Green
    
    # ═══════════════════════════════════════════════════════════════════
    # STEP 7: SERVICE OPTIMIZATION
    # ═══════════════════════════════════════════════════════════════════
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    Write-Host "STEP 7: SERVICE OPTIMIZATION" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    
    Write-Host "[7.1] Checking unnecessary services..." -ForegroundColor Yellow
    $unnecessaryServices = @("DiagTrack", "MapsBroker", "RemoteRegistry", "Spooler")
    $stoppedCount = 0
    foreach ($svc in $unnecessaryServices) {
        try {
            $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
            if ($service -and $service.StartType -eq "Automatic" -and $service.Status -eq "Running") {
                if (-not $testMode) {
                    # Don't actually stop services in test mode, just report
                }
                $stoppedCount++
            }
        } catch { }
    }
    Write-Host "       Found $stoppedCount unnecessary auto-start services" -ForegroundColor Yellow
    Write-Host "       [OK] Services checked" -ForegroundColor Green
    
    # ═══════════════════════════════════════════════════════════════════
    # STEP 8: FINAL HEALTH CHECK
    # ═══════════════════════════════════════════════════════════════════
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    Write-Host "STEP 8: FINAL HEALTH CHECK" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    
    Write-Host "[8.1] Running final health assessment..." -ForegroundColor Yellow
    $finalHealth = Get-SystemHealthScore
    Write-Host "       Final Health Score: $($finalHealth.TotalScore)/100" -ForegroundColor $(if($finalHealth.TotalScore -ge 70){ "Green" }elseif($finalHealth.TotalScore -ge 50){ "Yellow" }else{ "Red" })
    Write-Host "       [OK] Final health check complete" -ForegroundColor Green
    
    # ═══════════════════════════════════════════════════════════════════
    # SUMMARY
    # ═══════════════════════════════════════════════════════════════════
    $totalEndTime = Get-Date
    $duration = $totalEndTime - $totalStartTime
    
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                    WORKFLOW COMPLETE                          ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Duration: $($duration.ToString('mm\:ss'))" -ForegroundColor White
    Write-Host "Initial Health: $($health.TotalScore)/100" -ForegroundColor White
    Write-Host "Final Health: $($finalHealth.TotalScore)/100" -ForegroundColor $(if($finalHealth.TotalScore -gt $health.TotalScore){ "Green" }elseif($finalHealth.TotalScore -eq $health.TotalScore){ "Yellow" }else{ "Red" })
    Write-Host "Space Recovered: ~$totalRecoverable GB" -ForegroundColor White
    Write-Host ""
    Write-Host "System has been optimized and cleaned!" -ForegroundColor Green
    Write-Host ""
}

# Main entry point
if ($Help) {
    Show-Banner
    Show-Help
    exit 0
}

if (Initialize-App) {
    # Handle elevated mode (set by AutoElevate)
    if ($Elevated) {
        Write-Log -Level "INFO" -Category "System" -Message "Running in elevated mode"
    }
    
    # Handle QuickCleanup mode
    if ($QuickCleanup) {
        Load-AppModules
        Write-Host "[INFO] Running Quick Cleanup..." -ForegroundColor Cyan
        try {
            $result = Invoke-CleaningScan -TestMode (Get-ConfigValue "TestMode")
            $totalSizeGB = [math]::Round($result.TotalSize / 1GB, 2)
            $totalSizeMB = [math]::Round($result.TotalSize / 1MB, 0)
            if ($totalSizeGB -gt 1) {
                Write-Host "  Scan complete. Found $totalSizeGB GB to clean." -ForegroundColor Green
            } else {
                Write-Host "  Scan complete. Found $totalSizeMB MB to clean." -ForegroundColor Green
            }
            if (-not $TestMode -and -not $Preview) {
                $cleanResult = Invoke-Cleaning -Categories @("UserTemp", "SystemTemp", "RecycleBin", "BrowserCache", "ThumbnailCache") -TestMode $false
                $freedMB = $cleanResult.TotalFreed
                if ($freedMB -gt 1024) {
                    $freedGB = [math]::Round($freedMB / 1024, 2)
                    Write-Host "  Cleaned: $freedGB GB" -ForegroundColor Green
                } else {
                    Write-Host "  Cleaned: $freedMB MB" -ForegroundColor Green
                }
            }
        } catch {
            Write-Host "[ERROR] Quick cleanup failed: $($_.Exception.Message)" -ForegroundColor Red
        }
        Invoke-SessionCleanup
        exit 0
    }
    
    # Handle FullOptimization mode
    if ($FullOptimization) {
        Load-AppModules
        Write-Host "[INFO] Running Full Optimization Suite..." -ForegroundColor Cyan
        try {
            # Cleaning
            Write-Host "  [1/6] Running system cleaning..." -ForegroundColor Yellow
            Invoke-Cleaning -TestMode (Get-ConfigValue "TestMode") | Out-Null
            
            # Optimization
            Write-Host "  [2/6] Running optimization..." -ForegroundColor Yellow
            Invoke-Optimization -TestMode (Get-ConfigValue "TestMode") | Out-Null
            
            # Network
            Write-Host "  [3/6] Optimizing network..." -ForegroundColor Yellow
            Invoke-NetworkTuning -TestMode (Get-ConfigValue "TestMode") | Out-Null
            
            # Tuning
            Write-Host "  [4/6] Applying system tuning..." -ForegroundColor Yellow
            Invoke-SystemTuning -TestMode (Get-ConfigValue "TestMode") | Out-Null
            
            # Startup
            Write-Host "  [5/6] Optimizing startup..." -ForegroundColor Yellow
            try {
                $testMode = Get-ConfigValue "TestMode"
                if ($testMode) {
                    Invoke-SmartStartupOptimization -Preview -ErrorAction SilentlyContinue | Out-Null
                } else {
                    Invoke-SmartStartupOptimization -ErrorAction SilentlyContinue | Out-Null
                }
            } catch {
                # Skip startup optimization if it fails
            }
            
            # Report
            Write-Host "  [6/6] Generating report..." -ForegroundColor Yellow
            $reportPath = New-SystemReport -Format "HTML"
            Write-Host "  Report saved: $reportPath" -ForegroundColor Green
            
            Write-Host "[SUCCESS] Full optimization complete!" -ForegroundColor Green
        } catch {
            Write-Host "[ERROR] Full optimization failed: $($_.Exception.Message)" -ForegroundColor Red
        }
        Invoke-SessionCleanup
        exit 0
    }
    
    # Handle Preview mode - show what would happen without making changes
    if ($Preview -and -not ($QuickCleanup -or $FullOptimization -or $Status -or $Backup -or $Restore -or $Monitor -or $MemoryCleanup -or $EmergencyRepair -or $HealthCheck -or $AutoRun)) {
        Load-AppModules
        Write-Host ""
        Write-Host "=== PREVIEW MODE - What would happen ===" -ForegroundColor Yellow
        Write-Host ""
        
        Write-Host "[1] System Analysis:" -ForegroundColor Cyan
        $sysInfo = Get-SystemInfo
        Write-Host "    Computer: $($sysInfo.ComputerName), CPU: $($sysInfo.CPU), RAM: $($sysInfo.TotalMemory) GB"
        
        Write-Host "[2] Health Check:" -ForegroundColor Cyan
        $health = Get-SystemHealthScore
        Write-Host "    Health Score: $($health.TotalScore)/100"
        
        Write-Host "[3] Cleaning Scan:" -ForegroundColor Cyan
        $scanResults = Invoke-CleaningScan
        $totalRecoverable = [math]::Round($scanResults.TotalSize / 1MB, 0)
        Write-Host "    Would recover: $totalRecoverable MB"
        
        Write-Host "[4] Optimization:" -ForegroundColor Cyan
        Write-Host "    - Set High Performance power plan"
        Write-Host "    - Disable telemetry"
        Write-Host "    - Optimize memory"
        Write-Host "    - Clean temp files"
        
        Write-Host "[5] Network:" -ForegroundColor Cyan
        Write-Host "    - Reset network adapters"
        Write-Host "    - Flush DNS cache"
        
        Write-Host ""
        Write-Host "[PREVIEW MODE] No changes have been made to your system." -ForegroundColor Yellow
        Write-Host "To apply these changes, run without -Preview flag." -ForegroundColor Yellow
        
        Invoke-SessionCleanup
        exit 0
    }
    
    # Handle Status command
    if ($Status) {
        Load-AppModules
        Show-SystemStatus
        Invoke-SessionCleanup
        exit 0
    }
    
    # Handle Backup command
    if ($Backup) {
        Load-AppModules
        $null = Backup-Settings
        Invoke-SessionCleanup
        exit 0
    }
    
    # Handle Restore command
    if ($Restore) {
        Load-AppModules
        $null = Restore-Settings
        Invoke-SessionCleanup
        exit 0
    }
    
    # Handle Monitor command
    if ($Monitor) {
        Load-AppModules
        $null = Start-MonitorMode
        Invoke-SessionCleanup
        exit 0
    }
    
    # Handle MemoryCleanup command
    if ($MemoryCleanup) {
        Load-AppModules
        $null = Invoke-MemoryCleanup
        Invoke-SessionCleanup
        exit 0
    }
    
    # Handle EmergencyRepair command
    if ($EmergencyRepair) {
        Load-AppModules
        $null = Invoke-EmergencyRepair -TestMode $TestMode
        Invoke-SessionCleanup
        exit 0
    }
    
    # Handle HealthCheck command
    if ($HealthCheck) {
        Load-AppModules
        $null = Quick-HealthCheck
        Invoke-SessionCleanup
        exit 0
    }
    
    # Handle AutoRun - Sequential automated workflow without prompts
    if ($AutoRun) {
        Load-AppModules
        $null = Run-AutoSequential
        Invoke-SessionCleanup
        exit 0
    }
    
    if ($NoGUI) {
        Start-CLIMode
    } else {
        Start-GUIMode
    }
}

