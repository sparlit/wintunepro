================================================================================
                     WinTune Pro - ASCII Flowchart
================================================================================

                            ┌─────────────────┐
                            │   WinTune.ps1   │
                            └────────┬────────┘
                                     │
                    ┌────────────────┼────────────────┐
                    │                │                │
                    ▼                ▼                ▼
             ┌──────────┐    ┌──────────┐    ┌──────────┐
             │ -NoGUI    │    │ -Status   │    │ -Backup   │
             │ CLI Mode  │    │ Status    │    │ Backup    │
             └─────┬─────┘    └─────┬─────┘    └─────┬─────┘
                   │                │                │
                   └────────┬───────┴────────┬───────┘
                            │
                            ▼
              ┌─────────────────────────┐
              │  Load Modules            │
              │  - Core/                 │
              │  - Modules/Cleaning/      │
              │  - Modules/Optimization/  │
              │  - Modules/Network/       │
              │  - Modules/Repair/        │
              └────────────┬────────────┘
                           │
           ┌───────────────┼───────────────┐
           │               │               │
           ▼               ▼               ▼
    ┌────────────┐  ┌────────────┐  ┌────────────┐
    │  CLI MENU  │  │ GUI MODE   │  │  COMMANDS  │
    │            │  │ (XAML UI)  │  │            │
    │ 1.Quick   │  │            │  │ -Monitor   │
    │ 2.Scan     │  │ Dashboard  │  │ -Health    │
    │ 3.Clean    │  │ Cleaning   │  │ -Emergency │
    │ 4.FullOpt  │  │ Optimize   │  │ -Restore   │
    │ 5.Status   │  │ Network    │  │            │
    │ 6.Monitor   │  │ DNS        │  │            │
    │ 7.Exit     │  │ Repair     │  │            │
    └────────────┘  └────────────┘  └────────────┘


================================================================================
                         CLI MAIN MENU FLOW
================================================================================

    ╔═══════════════════════════════════════════════════════════════════════╗
    ║                     WinTune Pro - CLI Mode                            ║
    ╠═══════════════════════════════════════════════════════════════════════╣
    ║                                                                       ║
    ║   [1] Quick Optimize      → Quick optimization (power, memory)        ║
    ║   [2] System Scan        → Scan for cleanable files                  ║
    ║   [3] Run Cleaning       → Clean selected categories                 ║
    ║   [4] Full Optimization  → Complete system optimization               ║
    ║   [5] System Status      → Show system health & info                 ║
    ║   [6] Monitor Mode       → Real-time CPU/RAM/Disk monitoring         ║
    ║   [7] Backup Settings    → Backup configuration                      ║
    ║   [8] Restore Settings   → Restore from backup                       ║
    ║   [9] Exit               → Exit application                        ║
    ║                                                                       ║
    ╚═══════════════════════════════════════════════════════════════════════╝


================================================================================
                    QUICK OPTIMIZE FLOW
================================================================================

    Start
      │
      ▼
    ┌──────────────────┐
    │ Check Admin?      │
    └────────┬─────────┘
             │
      ┌──────┴──────┐
      │             │
      ▼             ▼
   ┌─────┐     ┌─────────┐
   │ YES │     │  NO/WARN │
   └──┬──┘     └────┬────┘
      │            │
      ▼            ▼
   ┌────────────────────────┐
   │ 1. Set Power Plan     │
   │    (High Performance)  │
   └────────┬───────────────┘
            │
            ▼
   ┌────────────────────────┐
   │ 2. Disable Telemetry   │
   │    (Registry: AllowTelemetry = 0) │
   └────────┬───────────────┘
            │
            ▼
   ┌────────────────────────┐
   │ 3. Optimize Memory     │
   │    (GC.Collect)        │
   └────────┬───────────────┘
            │
            ▼
   ┌────────────────────────┐
   │ 4. Show Results        │
   │    & Log Actions       │
   └────────┬───────────────┘
            │
            ▼
         Done!


================================================================================
                    FULL OPTIMIZATION FLOW
================================================================================

    ┌─────────────────────────────────────────────────────────────────────┐
    │                      FULL OPTIMIZATION SUITE                        │
    └─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
    ┌─────────────────────────────────────────────────────────────────────┐
    │ [1/6] SYSTEM CLEANING                                               │
    │  • User Temp Files       → Delete $env:TEMP\*                      │
    │  • System Temp Files      → Delete $env:SystemRoot\Temp\*           │
    │  • Windows Update Cache   → Clean SoftwareDistribution\Download     │
    │  • Recycle Bin           → Clear-RecycleBin                        │
    │  • Browser Caches        → Chrome, Firefox, Edge                     │
    └─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
    ┌─────────────────────────────────────────────────────────────────────┐
    │ [2/6] OPTIMIZATION                                                  │
    │  • Disable Telemetry    → Registry settings                         │
    │  • Power Plan           → High Performance                         │
    │  • Services             → Optimize unnecessary services             │
    │  • Memory               → Garbage Collection                       │
    └─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
    ┌─────────────────────────────────────────────────────────────────────┐
    │ [3/6] NETWORK TUNING                                              │
    │  • Flush DNS           → ipconfig /flushdns                         │
    │  • Reset TCP/IP        → netsh int ip reset                         │
    │  • Reset Winsock       → netsh winsock reset                        │
    │  • Set DNS             → Preferred DNS server                      │
    └─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
    ┌─────────────────────────────────────────────────────────────────────┐
    │ [4/6] SYSTEM TUNING                                                │
    │  • Menu Speed         → Control Panel → Performance Options         │
    │  • Visual Effects     → Adjust for best performance                │
    │  • NTFS Settings     → Disable last access update                   │
    └─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
    ┌─────────────────────────────────────────────────────────────────────┐
    │ [5/6] STARTUP OPTIMIZATION                                         │
    │  • Analyze Startup    → Get startup items                          │
    │  • Risk Assessment    → Score each item                            │
    │  • Disable Non-Essential → Safe to disable items                   │
    └─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
    ┌─────────────────────────────────────────────────────────────────────┐
    │ [6/6] GENERATE REPORT                                              │
    │  • System Info       → CPU, RAM, Disk, Network                      │
    │  • Health Score     → Calculate overall health                     │
    │  • Actions Taken    → List all optimizations                       │
    │  • Export           → HTML/JSON report                            │
    └─────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
                           COMPLETE!


================================================================================
                    MONITOR MODE (Real-time)
================================================================================

    ┌─────────────────────────────────────────────────────────────────────┐
    │                        MONITOR MODE                                 │
    │              Press Ctrl+C to exit                                  │
    └─────────────────────────────────────────────────────────────────────┘

    ╭───────────────────────────────────────────────────────────────────╮
    │ Time    │ CPU % │ RAM (Used/Total) │ Disk │ Processes           │
    ├──────────────────────────────────────────────────────────────────┤
    │ 14:32:05│  23%  │  8.2 / 16.0 GB   │ 78%  │    142             │
    ╰──────────────────────────────────────────────────────────────────╯
         │       │              │               │        │
         │       │              │               │        │
         │       │              │               │        │
    Update every 2 seconds (single line refresh)


================================================================================
                    ERROR HANDLING
================================================================================

    ┌─────────────────────────────────────────────────────────────────────┐
    │                        ERROR HANDLING                              │
    └─────────────────────────────────────────────────────────────────────┘

    Operation
        │
        ▼
    ┌──────────────────┐
    │ Is TestMode?    │
    └────────┬─────────┘
             │
      ┌──────┴──────┐
      │             │
      ▼             ▼
   ┌─────┐     ┌─────────┐
   │ YES │     │  NO     │
   └──┬──┘     └────┬────┘
      │            │
      ▼            ▼
   ┌─────────────────┐     ┌──────────────────┐
   │ Log: "Would    │     │ Is Admin?        │
   │  [Action]"     │     └────────┬─────────┘
   └─────────────────┘              │
                          ┌────────┴────────┐
                          │                 │
                          ▼                 ▼
                     ┌─────────┐      ┌─────────────┐
                     │  YES    │      │ NO/WARNING  │
                     └────┬────┘      └──────┬──────┘
                          │                 │
                          ▼                 ▼
                   ┌─────────────────┐ ┌─────────────────┐
                   │ Execute Action  │ │ Skip + Warn    │
                   │ Try-Catch       │ │ Continue       │
                   └────────┬────────┘ └─────────────────┘
                            │
                   ┌────────┴────────┐
                   │                 │
                   ▼                 ▼
            ┌─────────────┐    ┌─────────────┐
            │  Success   │    │   Error     │
            │ Log-Success│    │ Log-Error   │
            └─────────────┘    └─────────────┘
