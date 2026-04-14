# WinTune Pro - Execution Flow Diagram

## ┌─────────────────────────────────────────────────────────────────────────────┐
│                        WinTune Pro - Application Flow                         │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                           START: WinTune.bat                                │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Check PowerShell Version                             │
│                        (Requires 5.1+)                                      │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    │                               │
                    ▼                               ▼
            ┌───────────────┐               ┌───────────────┐
            │   Valid PS   │               │  Invalid PS   │
            │   Version?    │               │   Version?    │
            └───────────────┘               └───────────────┘
                    │                               │
                    ▼                               ▼
            ┌───────────────┐               ┌───────────────┐
            │  Continue &   │               │   Show Error  │
            │  Check Admin  │               │   & Exit      │
            └───────────────┘               └───────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Check Administrator Privilege                        │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    │                               │
                    ▼                               ▼
            ┌───────────────┐               ┌───────────────┐
            │    Is Admin?   │               │  Not Admin?   │
            └───────────────┘               └───────────────┘
                    │                               │
         ┌──────────┴──────────┐                  │
         │                     │                  │
         ▼                     ▼                  ▼
┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
│ Show Admin Badge│   │  Show Warning  │   │  Continue with │
│ & Set Flags    │   │  & Continue    │   │  Limited Features│
└─────────────────┘   └─────────────────┘   └─────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                     Initialize Core Components                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │
│  │   Config    │  │   Logger    │  │   State    │  │   AppCore   │      │
│  │  (JSON)     │  │  (Files)   │  │ (Session)  │  │  (Init)     │      │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘      │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Parse Command Line Arguments                          │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
         ┌────────┬────────┬────────┬────────┬────────┬────────┬────────┐
         │        │        │        │        │        │        │        │
         ▼        ▼        ▼        ▼        ▼        ▼        ▼
    ┌────────┐┌────────┐┌────────┐┌────────┐┌────────┐┌────────┐┌────────┐
    │ -NoGUI ││-Status ││-Backup ││-Monitor││-Health ││-Help   ││ Default│
    │        ││        ││        ││        ││Check   ││        ││(GUI)   │
    └────────┘└────────┘└────────┘└────────┘└────────┘└────────┘└────────┘
         │        │        │        │        │        │        │
         └────────┴────────┴────────┴────────┴────────┴────────┴────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Load Application Modules                             │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │  Modules/                                                        │  │
│  │  ├── Cleaning/     (CleaningCore, AppCache, BrowserCache, etc)  │  │
│  │  ├── Optimization/ (OptimizationCore, GamingOptimizer, Privacy)   │  │
│  │  ├── Network/      (NetworkReset, DNSManager, Tuning)            │  │
│  │  ├── Repair/       (SystemRepair, SFC, DISM)                    │  │
│  │  └── ...                                                         │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         EXECUTION BRANCH                                    │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
        ┌───────────────────────────┼───────────────────────────┐
        │                           │                           │
        ▼                           ▼                           ▼
┌───────────────┐          ┌───────────────┐          ┌───────────────┐
│  CLI MODE    │          │  GUI MODE    │          │ SPECIFIC CMD │
│  (-NoGUI)    │          │  (Default)    │          │ (-Status etc)│
└───────────────┘          └───────────────┘          └───────────────┘
        │                           │                           │
        ▼                           ▼                           ▼
┌───────────────┐          ┌───────────────┐          ┌───────────────┐
│  Show Menu:   │          │  Load XAML   │          │  Execute Cmd  │
│  1.Quick     │          │  MainWindow   │          │  & Exit      │
│  2.Scan      │          │               │          │              │
│  3.Report    │          │  ┌─────────┐   │          │              │
│  4.Exit      │          │  │  Tabs  │   │          │              │
│               │          │  ├─────────┤   │          │              │
│               │          │  │Dashboard│   │          │              │
│               │          │  │Cleaning │   │          │              │
│               │          │  │Optimize │   │          │
│               │          │  │Network  │   │          │
│               │          │  │DNS      │   │          │
│               │          │  │Repair   │   │          │
│               │          │  │Reports  │   │          │
│               │          │  │Gaming   │   │          │
│               │          │  │Settings │   │          │
│               │          │  └─────────┘   │          │
│               │          │       │        │          │
│               │          │       ▼        │          │
│               │          │  ┌─────────┐   │          │
│               │          │  │ Bind   │   │          │
│               │          │  │Events  │   │          │
│               │          │  └─────────┘   │          │
│               │          │       │        │          │
│               │          │       ▼        │          │
│               │          │  ┌─────────┐   │          │
│               │          │  │ Show   │   │          │
│               │          │  │Window  │   │          │
│               │          │  └─────────┘   │          │
│               │          │       │        │          │
└───────────────┘          └───────────────┘          └───────────────┘



## ┌─────────────────────────────────────────────────────────────────────────────┐
│                    CLI MODE - Detailed Flow                                  │
└─────────────────────────────────────────────────────────────────────────────┘

                         ┌──────────────────┐
                         │   CLI Main Menu  │
                         └────────┬─────────┘
                                  │
         ┌──────────┬───────────┬──┴───┬───────────┬──────────┐
         │          │           │      │           │          │
         ▼          ▼           ▼      ▼           ▼          ▼
    ┌────────┐┌────────┐┌────────┐┌────────┐┌────────┐┌────────┐
    │ 1.Quick││2.Scan  ││3.Report││4.Status││5.Monitor││6.Exit │
    │Optimize││        ││        ││        ││        ││        │
    └────┬───┘└────┬───┘└────┬───┘└────┬───┘└────┬───┘└────────┘
         │         │         │         │         │
         ▼         ▼         ▼         ▼         ▼
    ┌─────────────────────────────────────────────────────────────┐
    │                    EXECUTION STEPS                          │
    └─────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
    ┌─────────────────────────────────────────────────────────────┐
    │  1. QUICK OPTIMIZE                                         │
    │  ┌───────────────────────────────────────────────────────┐  │
    │  │ • Check Admin → Set High Performance Power Plan        │  │
    │  │ • Disable Telemetry (Registry)                        │  │
    │  │ • Optimize Memory (GC.Collect)                       │  │
    │  │ • Show Results → Save to Config                       │  │
    │  └───────────────────────────────────────────────────────┘  │
    └─────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
    ┌─────────────────────────────────────────────────────────────┐
    │  2. SYSTEM SCAN                                            │
    │  ┌───────────────────────────────────────────────────────┐  │
    │  │ • Scan User Temp Files                                │  │
    │  │ • Scan System Temp Files                             │  │
    │  │ • Scan Browser Caches                               │  │
    │  │ • Scan Windows Update Cache                          │  │
    │  │ • Scan Recycle Bin                                   │  │
    │  │ • Calculate Total Recoverable Space                   │  │
    │  │ • Display Results with Categories                     │  │
    │  └───────────────────────────────────────────────────────┘  │
    └─────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
    ┌─────────────────────────────────────────────────────────────┐
    │  3. CLEAN                                                  │
    │  ┌───────────────────────────────────────────────────────┐  │
    │  │ • Confirm Before Clean (unless -Silent)               │  │
    │  │ • Create Auto-Backup (config, state)                 │  │
    │  │ • Clean Selected Categories:                          │  │
    │  │   - User Temp: Delete $env:TEMP\*                    │  │
    │  │   - System Temp: Delete $env:SystemRoot\Temp\*      │  │
    │  │   - Browser Cache: Delete Chrome/Firefox/Edge cache │  │
    │  │   - Windows Update: Stop Windows Update, Clean       │  │
    │  │   - Recycle Bin: Clear-RecycleBin                   │  │
    │  │   - Prefetch: Delete $env:SystemRoot\Prefetch\*    │  │
    │  │ • Calculate Space Recovered                          │  │
    │  │ • Update Dashboard Stats                             │  │
    │  └───────────────────────────────────────────────────────┘  │
    └─────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
    ┌─────────────────────────────────────────────────────────────┐
    │  4. FULL OPTIMIZATION                                      │
    │  ┌───────────────────────────────────────────────────────┐  │
    │  │ [1/6] System Cleaning → Run cleaning scan             │  │
    │  │ [2/6] Apply Optimizations                            │  │
    │  │   - Disable Telemetry                                 │  │
    │  │   - Set High Performance Power Plan                  │  │
    │  │   - Optimize Services                                │  │
    │  │   - Optimize Startup Items                           │  │
    │  │ [3/6] Network Tuning                                 │  │
    │  │   - Flush DNS                                        │  │
    │  │   - Reset TCP/IP                                     │  │
    │  │   - Set Optimal DNS                                  │  │
    │  │ [4/6] System Tuning                                  │  │
    │  │   - Menu Speed, Visual Effects, NTFS                  │  │
    │  │ [5/6] Startup Optimization                           │  │
    │  │   - Analyze & Disable Non-Essential                  │  │
    │  │ [6/6] Generate Report                                │  │
    │  │   - Create HTML/JSON Report                          │  │
    │  └───────────────────────────────────────────────────────┘  │
    └─────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
    ┌─────────────────────────────────────────────────────────────┐
    │  5. SYSTEM STATUS                                          │
    │  ┌───────────────────────────────────────────────────────┐  │
    │  │ • Display System Info (CPU, RAM, Disk)               │  │
    │  │ • Display Health Score Breakdown                     │  │
    │  │ • Display Disk Usage                                 │  │
    │  │ • Display Network Status                             │  │
    │  │ • Display Recent Backups                             │  │
    │  └───────────────────────────────────────────────────────┘  │
    └─────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
    ┌─────────────────────────────────────────────────────────────┐
    │  6. MONITOR MODE (Real-time)                                │
    │  ┌───────────────────────────────────────────────────────┐  │
    │  │ • Loop every 2 seconds:                              │  │
    │  │   - CPU Usage %                                      │  │
    │  │   - RAM Usage % (Used/Total)                        │  │
    │  │   - Disk I/O                                        │  │
    │  │   - Process Count                                    │  │
    │  │ • Display in console (single line update)            │  │
    │  │ • Press Ctrl+C to exit                               │  │
    │  └───────────────────────────────────────────────────────┘  │
    └─────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
    ┌─────────────────────────────────────────────────────────────┐
    │                    RETURN TO MENU                          │
    └─────────────────────────────────────────────────────────────┘



## ┌─────────────────────────────────────────────────────────────────────────────┐
│                    GUI MODE - Tab Operations Flow                             │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  DASHBOARD TAB                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ QuickOptimizeBtn → Invoke-QuickOptimize → Update-DashboardStats      │   │
│  │ MasterCleanBtn  → Invoke-MasterClean    → Update-DashboardStats     │   │
│  │ RunFullAutomate → Invoke-FullAutomate   → Update-DashboardStats     │   │
│  │ StartWatchdog  → Start-Watchdog        → Update-Status            │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  CLEANING TAB                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ ScanCleaningBtn  → Invoke-CleaningScan → Show Total Size            │   │
│  │ RunCleaningBtn   → Invoke-Cleaning      → Show Freed Space          │   │
│  │ MasterCleanAllBtn → Invoke-MasterClean  → Clean All Categories       │   │
│  │ Categories: UserTemp, SystemTemp, WUCache, RecycleBin, Prefetch    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  OPTIMIZATION TAB                                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ AnalyzeOptBtn    → Invoke-OptimizationAnalysis → Show Recommendations│  │
│  │ RunOptimizeBtn   → Invoke-Optimization        → Apply Changes        │   │
│  │ CreateRestoreBtn → Checkpoint-Computer      → Create Restore Point  │   │
│  │ Options: Privacy Services, Performance Services, Gaming Services   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  NETWORK TAB                                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ RunNetworkBtn      → Invoke-NetworkReset  → Reset TCP/IP, Winsock │   │
│  │ RunNetworkTuneBtn  → Invoke-NetworkTuning → Apply Tuning Settings   │   │
│  │ DNS Buttons: Cloudflare, Google, Quad9, OpenDNS → Set-DNSServer   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  DNS TAB                                                                   │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ DNSCloudflareBtn  → Set-DNSServer 1.1.1.1, 1.0.0.1                 │   │
│  │ DNSGoogleBtn      → Set-DNSServer 8.8.8.8, 8.8.4.4                 │   │
│  │ DNSQuad9Btn       → Set-DNSServer 9.9.9.9, 149.112.112.112         │   │
│  │ DNSOpenDNSBtn     → Set-DNSServer 208.67.222.222, 208.67.220.220   │   │
│  │ DNSDHCPBtn        → Set-DNSServer DHCP                              │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  REPAIR TAB                                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ RunSFCBtn          → Invoke-SFCScan     → Run sfc /scannow        │   │
│  │ RunDISMCheckBtn    → Invoke-DISMCheckHealth → DISM /CheckHealth   │   │
│  │ RunDISMRestoreBtn  → Invoke-DISMRestoreHealth → DISM /RestoreHealth│  │
│  │ RunFullRepairBtn   → Invoke-FullSystemRepair → SFC + DISM         │   │
│  │ RunWURepairBtn     → Invoke-WindowsUpdateRepair → FixWU            │   │
│  │ RunDefenderCleanup → Clear-AllDefenderData → Clean Defender Logs    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  REPORTS TAB                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ GenerateHealthReportBtn → New-SystemReport → Create HTML Report    │   │
│  │ ExportHTMLReportBtn    → New-SystemReport → Export Report           │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  GAMING TAB                                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ ToggleGameModeBtn  → Enable/Disable Game Mode                      │   │
│  │ RunGamingOptimize  → Invoke-GamingOptimization                     │   │
│  │ ClearGameCache     → Clear-GameCache                               │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  SETTINGS TAB                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ SettingTestMode     → Toggle Test Mode                            │   │
│  │ SettingTheme         → Switch-Theme (Dark/Light)                   │   │
│  │ Save Settings        → Save-Settings → Write to config.json        │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘



## ┌─────────────────────────────────────────────────────────────────────────────┐
│                    CLI COMMANDS SUMMARY                                     │
└─────────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────────────────┐
│ COMMAND LINE OPTIONS                                                      │
├────────────────────────────────────────────────────────────────────────────┤
│ WinTune.ps1 [OPTIONS]                                                     │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│ GUI OPTIONS:                                                              │
│   -NoGUI             Launch in CLI mode instead of GUI                   │
│                                                                            │
│ OPERATION MODES:                                                          │
│   -QuickCleanup      Run quick cleanup only                               │
│   -FullOptimization  Run complete optimization suite                      │
│   -Preview          Preview changes without applying                     │
│                                                                            │
│ CLI SPECIFIC:                                                             │
│   -Status            Show detailed system status & health                 │
│   -Backup           Backup all settings to Backups folder                  │
│   -Restore          Restore settings from latest backup                    │
│   -Monitor          Start real-time system monitor (Ctrl+C to exit)       │
│   -MemoryCleanup     Quick memory cleanup (free RAM)                     │
│   -EmergencyRepair   Run SFC + DISM system repair                         │
│   -HealthCheck       Quick system health check                            │
│                                                                            │
│ OTHER:                                                                    │
│   -TestMode          Run in simulation mode (no changes)                  │
│   -Silent            Run without prompts                                  │
│   -Help              Show this help message                               │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘


## ┌─────────────────────────────────────────────────────────────────────────────┐
│                    FILE STRUCTURE                                           │
└─────────────────────────────────────────────────────────────────────────────┘

WinTunePRO/
├── WinTune.ps1              # Main entry point
├── WinTune.bat              # Launcher script
├── config.json              # Configuration file
├── State.json               # Session state
│
├── Core/                    # Core modules
│   ├── Config.ps1          # Configuration management
│   ├── Logger.ps1          # Logging system
│   ├── State.ps1           # Session state
│   ├── AppCore.ps1         # Application core
│   └── HealthScore.ps1     # Health calculation
│
├── Modules/                 # Feature modules
│   ├── Cleaning/           # Cleaning functions
│   │   ├── CleaningCore.ps1
│   │   ├── AppCache.ps1
│   │   ├── BrowserCache.ps1
│   │   └── ...
│   ├── Optimization/       # Optimization functions
│   │   ├── OptimizationCore.ps1
│   │   └── ...
│   ├── Network/           # Network functions
│   │   ├── NetworkReset.ps1
│   │   ├── DNSManager.ps1
│   │   └── ...
│   ├── Repair/           # System repair
│   │   ├── SystemRepair.ps1
│   │   ├── SFCScan.ps1
│   │   └── ...
│   └── ...
│
├── UI/                     # UI components
│   └── MainWindow.ps1     # XAML UI definition
│
├── Backups/               # Auto-backups storage
├── Logs/                  # Log files
└── Reports/              # Generated reports



## ┌─────────────────────────────────────────────────────────────────────────────┐
│                    ERROR HANDLING FLOW                                       │
└─────────────────────────────────────────────────────────────────────────────┘

                         ┌──────────────────┐
                         │   Any Operation  │
                         └────────┬─────────┘
                                  │
                                  ▼
                         ┌──────────────────┐
                         │  TestMode Enabled│
                         └────────┬─────────┘
                                  │
                    ┌─────────────┴─────────────┐
                    │                           │
                    ▼                           ▼
            ┌───────────────┐           ┌───────────────┐
            │     YES       │           │      NO       │
            │ (Simulate)    │           │  (Execute)    │
            └───────────────┘           └───────────────┘
                                              │
                                              ▼
                                     ┌──────────────────┐
                                     │   Is Admin?      │
                                     └────────┬─────────┘
                                              │
                              ┌───────────────┴───────────────┐
                              │                               │
                              ▼                               ▼
                      ┌───────────────┐               ┌───────────────┐
                      │     YES      │               │      NO       │
                      │ (Execute)    │               │(Skip/Warn)    │
                      └───────────────┘               └───────────────┘
                                              │
                                              ▼
                                     ┌──────────────────┐
                                     │  Try-Catch Block │
                                     └────────┬─────────┘
                                              │
                              ┌───────────────┴───────────────┐
                              │                               │
                              ▼                               ▼
                      ┌───────────────┐               ┌───────────────┐
                      │   Success    │               │    Error      │
                      │  Log-Success │               │  Log-Error    │
                      │  Update-UI   │               │  Show-Error   │
                      └───────────────┘               └───────────────┘



## ┌─────────────────────────────────────────────────────────────────────────────┐
│                    AUTO-BACKUP FLOW                                          │
└─────────────────────────────────────────────────────────────────────────────┘

Before any destructive operation:
                                  
                         ┌──────────────────┐
                         │ Auto-Backup      │
                         │ (Invoke-AutoBackup)│
                         └────────┬─────────┘
                                  │
                                  ▼
                         ┌──────────────────┐
                         │ Create Backups/  │
                         │ backup_YYYYMMDD_  │
                         │ HHMMSS/          │
                         └────────┬─────────┘
                                  │
                                  ▼
                         ┌──────────────────┐
                         │ Copy:             │
                         │ - config.json     │
                         │ - State.json      │
                         └────────┬─────────┘
                                  │
                                  ▼
                         ┌──────────────────┐
                         │ Log: "Backup     │
                         │ created: backup_ ││
                         │ YYYYMMDD_HHMMSS" │
                         └──────────────────┘
