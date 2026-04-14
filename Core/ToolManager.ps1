# ToolManager.ps1 - Manages 60+ external tools
#Requires -Version 5.1

$script:ToolManagerState = @{
    Initialized = $false
    ToolsRoot   = $null
    Manifest    = $null
    InstallLog  = [System.Collections.Generic.List[PSObject]]::new()
}

function global:Initialize-ToolManager {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ToolsRoot = (Join-Path -Path $PSScriptRoot -ChildPath '..\Tools')
    )

    try {
        $script:ToolManagerState.ToolsRoot = $ToolsRoot

        if (-not (Test-Path -Path $ToolsRoot)) {
            New-Item -Path $ToolsRoot -ItemType Directory -Force | Out-Null
            Write-Log -Level "INFO" -Category "ToolManager" -Message "Created tools root directory: $ToolsRoot"
        }

        $categories = @('Cleaning','Optimization','Privacy','Security','Analysis','Monitoring','Debloat','System')
        foreach ($category in $categories) {
            $catPath = Join-Path -Path $ToolsRoot -ChildPath $category
            if (-not (Test-Path -Path $catPath)) {
                New-Item -Path $catPath -ItemType Directory -Force | Out-Null
            }
        }

        $script:ToolManagerState.Manifest = Get-ToolManifest
        $script:ToolManagerState.Initialized = $true
        $script:ToolManagerState.InstallLog = [System.Collections.Generic.List[PSObject]]::new()

        Write-Log -Level "INFO" -Category "ToolManager" -Message "ToolManager initialized with tools root: $ToolsRoot"
        return $true
    }
    catch {
        Write-Log -Level "ERROR" -Category "ToolManager" -Message "Failed to initialize ToolManager: $($_.Exception.Message)"
        throw
    }
}

function global:Get-ToolManifest {
    [CmdletBinding()]
    param()

    try {
        $manifest = @{
            # Cleaning
            BleachBit = @{
                Name        = 'BleachBit'
                Category    = 'Cleaning'
                Description = 'System cleaner and privacy tool'
                DownloadUrl = 'https://download.bleachbit.org/BleachBit-4.6.0-setup.exe'
                Version     = '4.6.0'
                Hash        = ''
                SizeMB      = 12
                SilentArgs  = '/S'
            }
            CleanmgrPlus = @{
                Name        = 'Cleanmgr+'
                Category    = 'Cleaning'
                Description = 'Extended disk cleanup utility'
                DownloadUrl = 'https://github.com/builtbybel/CleanmgrPlus/releases/download/1.4.6.0/CleanmgrPlus.exe'
                Version     = '1.4.6.0'
                Hash        = ''
                SizeMB      = 3
                SilentArgs  = ''
            }
            CCleaner = @{
                Name        = 'CCleaner'
                Category    = 'Cleaning'
                Description = 'Disk cleanup and optimization'
                DownloadUrl = 'https://download.ccleaner.com/ccsetup608.exe'
                Version     = '6.08'
                Hash        = ''
                SizeMB      = 45
                SilentArgs  = '/S'
            }
            TempCleaner = @{
                Name        = 'Temp_Cleaner_GUI'
                Category    = 'Cleaning'
                Description = 'Temporary file cleaner'
                DownloadUrl = 'https://github.com/builtbybel/TempCleaner/releases/download/1.0/TempCleaner.exe'
                Version     = '1.0'
                Hash        = ''
                SizeMB      = 2
                SilentArgs  = ''
            }

            # Optimization
            TronScript = @{
                Name        = 'TronScript'
                Category    = 'Optimization'
                Description = 'Automated PC cleanup and disinfection'
                DownloadUrl = 'https://bmrf.org/repos/tron/Tron.exe'
                Version     = '12.1.0'
                Hash        = ''
                SizeMB      = 650
                SilentArgs  = ''
            }
            WinUtil = @{
                Name        = 'WinUtil'
                Category    = 'Optimization'
                Description = 'Chris Titus Tech Windows Utility'
                DownloadUrl = 'https://raw.githubusercontent.com/ChrisTitusTech/winutil/main/winutil.ps1'
                Version     = '24.01'
                Hash        = ''
                SizeMB      = 1
                SilentArgs  = ''
            }
            Optimizer = @{
                Name        = 'Optimizer'
                Category    = 'Optimization'
                Description = 'Windows optimizer and tweaker'
                DownloadUrl = 'https://github.com/hellzerg/optimizer/releases/download/15.7/Optimizer-15.7.exe'
                Version     = '15.7'
                Hash        = ''
                SizeMB      = 5
                SilentArgs  = ''
            }
            SophiaScript = @{
                Name        = 'SophiaScript'
                Category    = 'Optimization'
                Description = 'Windows 10/11 PowerShell module for fine-tuning'
                DownloadUrl = 'https://raw.githubusercontent.com/Sophia-Community/SophiApp/master/Sophia/Sophia.ps1'
                Version     = '5.16.4'
                Hash        = ''
                SizeMB      = 2
                SilentArgs  = ''
            }
            Win11Debloat = @{
                Name        = 'Win11Debloat'
                Category    = 'Optimization'
                Description = 'Windows 11 debloat script'
                DownloadUrl = 'https://github.com/Raphire/Win11Debloat/releases/download/2024.01/Win11Debloat.ps1'
                Version     = '2024.01'
                Hash        = ''
                SizeMB      = 1
                SilentArgs  = ''
            }
            WinaeroTweaker = @{
                Name        = 'WinaeroTweaker'
                Category    = 'Optimization'
                Description = 'Windows tweaker and customization tool'
                DownloadUrl = 'https://winaerotweaker.com/download/winaerotweaker.exe'
                Version     = '1.55.0.0'
                Hash        = ''
                SizeMB      = 8
                SilentArgs  = '/S'
            }

            # Privacy
            OOSU10 = @{
                Name        = 'OOSU10'
                Category    = 'Privacy'
                Description = 'O&O ShutUp10 - Anti-spy tool'
                DownloadUrl = 'https://dl5.oo-software.com/files/ooshutup10/OOSU10.exe'
                Version     = '1.9.1437'
                Hash        = ''
                SizeMB      = 2
                SilentArgs  = '/quiet'
            }
            WPD = @{
                Name        = 'WPD'
                Category    = 'Privacy'
                Description = 'Windows Privacy Dashboard'
                DownloadUrl = 'https://wpd.app/get/latest.zip'
                Version     = '1.5.2042'
                Hash        = ''
                SizeMB      = 5
                SilentArgs  = ''
            }
            PrivateZilla = @{
                Name        = 'PrivateZilla'
                Category    = 'Privacy'
                Description = 'Privacy settings manager'
                DownloadUrl = 'https://github.com/builtbybel/Privatezilla/releases/download/0.90/Privatezilla.exe'
                Version     = '0.90'
                Hash        = ''
                SizeMB      = 3
                SilentArgs  = ''
            }
            WindowsSpyBlocker = @{
                Name        = 'WindowsSpyBlocker'
                Category    = 'Privacy'
                Description = 'Block Windows spying and telemetry'
                DownloadUrl = 'https://github.com/crazy-max/WindowsSpyBlocker/releases/download/4.40.0/WindowsSpyBlocker.exe'
                Version     = '4.40.0'
                Hash        = ''
                SizeMB      = 4
                SilentArgs  = ''
            }
            Debotnet = @{
                Name        = 'Debotnet'
                Category    = 'Privacy'
                Description = 'Stop Windows from spying on you'
                DownloadUrl = 'https://github.com/builtbybel/Debotnet/releases/download/0.9.1/Debotnet.exe'
                Version     = '0.9.1'
                Hash        = ''
                SizeMB      = 3
                SilentArgs  = ''
            }
            PrivacySexy = @{
                Name        = 'Privacy.Sexy'
                Category    = 'Privacy'
                Description = 'Privacy tool for Windows'
                DownloadUrl = 'https://github.com/undergroundwires/privacy.sexy/releases/download/0.13.0/privacy.sexy-0.13.0-win-x64.exe'
                Version     = '0.13.0'
                Hash        = ''
                SizeMB      = 80
                SilentArgs  = '/S'
            }
            BetterPrivacy = @{
                Name        = 'BetterPrivacy'
                Category    = 'Privacy'
                Description = 'Enhanced privacy settings'
                DownloadUrl = 'https://github.com/builtbybel/BetterPrivacy/releases/download/1.0/BetterPrivacy.exe'
                Version     = '1.0'
                Hash        = ''
                SizeMB      = 2
                SilentArgs  = ''
            }

            # Security
            Autoruns = @{
                Name        = 'Autoruns'
                Category    = 'Security'
                Description = 'Sysinternals autoruns manager'
                DownloadUrl = 'https://download.sysinternals.com/files/Autoruns.zip'
                Version     = '14.11'
                Hash        = ''
                SizeMB      = 3
                SilentArgs  = ''
            }
            WindowsPrivacyFixup = @{
                Name        = 'WindowsPrivacyFixup'
                Category    = 'Security'
                Description = 'Windows privacy security fix'
                DownloadUrl = 'https://github.com/builtbybel/WindowsPrivacyFixup/releases/download/1.0/WindowsPrivacyFixup.exe'
                Version     = '1.0'
                Hash        = ''
                SizeMB      = 2
                SilentArgs  = ''
            }
            WindowsOnReins = @{
                Name        = 'WindowsOnReins'
                Category    = 'Security'
                Description = 'Windows security hardening'
                DownloadUrl = 'https://github.com/builtbybel/WindowsOnReins/releases/download/1.0/WindowsOnReins.exe'
                Version     = '1.0'
                Hash        = ''
                SizeMB      = 2
                SilentArgs  = ''
            }

            # Analysis
            WinDirStat = @{
                Name        = 'WinDirStat'
                Category    = 'Analysis'
                Description = 'Disk usage statistics viewer'
                DownloadUrl = 'https://github.com/windirstat/windirstat/releases/download/release%2Fv1.1.2/WinDirStat_1_1_2_setup.exe'
                Version     = '1.1.2'
                Hash        = ''
                SizeMB      = 5
                SilentArgs  = '/S'
            }
            SysInternalsSuite = @{
                Name        = 'SysInternalsSuite'
                Category    = 'Analysis'
                Description = 'Complete Sysinternals toolkit'
                DownloadUrl = 'https://download.sysinternals.com/files/SysinternalsSuite.zip'
                Version     = '2024.01'
                Hash        = ''
                SizeMB      = 35
                SilentArgs  = ''
            }
            UltraDefrag = @{
                Name        = 'UltraDefrag'
                Category    = 'Analysis'
                Description = 'Disk defragmenter'
                DownloadUrl = 'https://sourceforge.net/projects/ultradefrag/files/stable-release/7.1.4/ultradefrag-7.1.4.bin.amd64.exe/download'
                Version     = '7.1.4'
                Hash        = ''
                SizeMB      = 4
                SilentArgs  = '/S'
            }
            WinMemoryCleaner = @{
                Name        = 'WinMemoryCleaner'
                Category    = 'Analysis'
                Description = 'Windows memory optimization'
                DownloadUrl = 'https://github.com/IgorMundstein/WinMemoryCleaner/releases/download/2.7/WinMemoryCleaner.exe'
                Version     = '2.7'
                Hash        = ''
                SizeMB      = 2
                SilentArgs  = ''
            }

            # Monitoring
            ProcessExplorer = @{
                Name        = 'ProcessExplorer'
                Category    = 'Monitoring'
                Description = 'Advanced process viewer'
                DownloadUrl = 'https://download.sysinternals.com/files/ProcessExplorer.zip'
                Version     = '17.06'
                Hash        = ''
                SizeMB      = 4
                SilentArgs  = ''
            }
            ProcessMonitor = @{
                Name        = 'ProcessMonitor'
                Category    = 'Monitoring'
                Description = 'Real-time file/registry/process monitor'
                DownloadUrl = 'https://download.sysinternals.com/files/ProcessMonitor.zip'
                Version     = '3.94'
                Hash        = ''
                SizeMB      = 3
                SilentArgs  = ''
            }
            TCPView = @{
                Name        = 'TCPView'
                Category    = 'Monitoring'
                Description = 'TCP/UDP endpoint viewer'
                DownloadUrl = 'https://download.sysinternals.com/files/TCPView.zip'
                Version     = '4.01'
                Hash        = ''
                SizeMB      = 2
                SilentArgs  = ''
            }
            RAMMap = @{
                Name        = 'RAMMap'
                Category    = 'Monitoring'
                Description = 'Physical memory usage analyzer'
                DownloadUrl = 'https://download.sysinternals.com/files/RAMMap.zip'
                Version     = '1.61'
                Hash        = ''
                SizeMB      = 1
                SilentArgs  = ''
            }

            # Debloat
            BloatBox = @{
                Name        = 'BloatBox'
                Category    = 'Debloat'
                Description = 'Windows bloatware remover'
                DownloadUrl = 'https://github.com/builtbybel/Bloatbox/releases/download/0.13.0.0/Bloatbox.exe'
                Version     = '0.13.0.0'
                Hash        = ''
                SizeMB      = 3
                SilentArgs  = ''
            }
            BloatyNosy = @{
                Name        = 'BloatyNosy'
                Category    = 'Debloat'
                Description = 'Windows bloatware removal tool'
                DownloadUrl = 'https://github.com/builtbybel/bloatynosy/releases/download/0.10.0/BloatyNosy.exe'
                Version     = '0.10.0'
                Hash        = ''
                SizeMB      = 3
                SilentArgs  = ''
            }
            WinDebloatTools = @{
                Name        = 'WinDebloatTools'
                Category    = 'Debloat'
                Description = 'Windows debloat utility'
                DownloadUrl = 'https://github.com/LeDragoX/Win-Debloat-Tools/releases/download/v2.9.0/WinDebloatTools.exe'
                Version     = '2.9.0'
                Hash        = ''
                SizeMB      = 5
                SilentArgs  = ''
            }

            # System
            PowerToys = @{
                Name        = 'PowerToys'
                Category    = 'System'
                Description = 'Microsoft PowerToys utilities'
                DownloadUrl = 'https://github.com/microsoft/PowerToys/releases/download/v0.77.0/PowerToysSetup-0.77.0-x64.exe'
                Version     = '0.77.0'
                Hash        = ''
                SizeMB      = 250
                SilentArgs  = '/silent'
            }
            SevenZip = @{
                Name        = '7-Zip'
                Category    = 'System'
                Description = 'File archiver with high compression'
                DownloadUrl = 'https://www.7-zip.org/a/7z2301-x64.exe'
                Version     = '23.01'
                Hash        = ''
                SizeMB      = 4
                SilentArgs  = '/S'
            }
            NotepadPlusPlus = @{
                Name        = 'Notepad++'
                Category    = 'System'
                Description = 'Source code editor'
                DownloadUrl = 'https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/v8.6.2/npp.8.6.2.Installer.x64.exe'
                Version     = '8.6.2'
                Hash        = ''
                SizeMB      = 8
                SilentArgs  = '/S'
            }
            Everything = @{
                Name        = 'Everything'
                Category    = 'System'
                Description = 'Instant file search tool'
                DownloadUrl = 'https://www.voidtools.com/Everything-1.4.1.1024.x64-Setup.exe'
                Version     = '1.4.1.1024'
                Hash        = ''
                SizeMB      = 3
                SilentArgs  = '/S'
            }
        }

        Write-Log -Level "DEBUG" -Category "System" -Message "Tool manifest loaded: $($manifest.Count) tools defined"
        return $manifest
    }
    catch {
        Write-Log -Level "ERROR" -Category "System" -Message "Error loading tool manifest: $($_.Exception.Message)"
        throw
    }
}

function global:Install-Tool {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ToolName,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$Verify
    )

    try {
        if (-not $script:ToolManagerState.Initialized) {
            Initialize-ToolManager
        }

        $manifest = $script:ToolManagerState.Manifest
        if (-not $manifest.ContainsKey($ToolName)) {
            Write-Log -Level "ERROR" -Category "System" -Message "Tool '$ToolName' not found in manifest"
            return $false
        }

        $tool = $manifest[$ToolName]
        $toolDir = Join-Path -Path $script:ToolManagerState.ToolsRoot -ChildPath "$($tool.Category)\$($tool.Name)"
        $fileName = Split-Path -Path $tool.DownloadUrl -Leaf
        $downloadPath = Join-Path -Path $toolDir -ChildPath $fileName

        if ((Test-Path -Path $downloadPath) -and -not $Force) {
            if ($Verify) {
                $valid = Test-ToolIntegrity -ToolName $ToolName
                if ($valid) {
                    Write-Log -Level "INFO" -Category "System" -Message "Tool '$ToolName' already installed and verified"
                    return $true
                }
            }
            else {
                Write-Log -Level "INFO" -Category "System" -Message "Tool '$ToolName' already installed, use -Force to reinstall"
                return $true
            }
        }

        if (-not (Test-Path -Path $toolDir)) {
            New-Item -Path $toolDir -ItemType Directory -Force | Out-Null
        }

        Write-Log -Level "INFO" -Category "System" -Message "Downloading '$ToolName' from $($tool.DownloadUrl)"

        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($tool.DownloadUrl, $downloadPath)
            $webClient.Dispose()
        }
        catch {
            $webClient.Dispose()
            Write-Log -Level "ERROR" -Category "System" -Message "Download failed for '$ToolName': $($_.Exception.Message)"
            throw
        }

        if ($Verify -and -not [string]::IsNullOrEmpty($tool.Hash)) {
            $valid = Test-ToolIntegrity -ToolName $ToolName
            if (-not $valid) {
                Remove-Item -Path $downloadPath -Force -ErrorAction SilentlyContinue
                Write-Log -Level "ERROR" -Category "System" -Message "Hash verification failed for '$ToolName', file removed"
                return $false
            }
        }

        if ($downloadPath -match '\.zip$') {
            try {
                Expand-Archive -Path $downloadPath -DestinationPath $toolDir -Force
                Remove-Item -Path $downloadPath -Force -ErrorAction SilentlyContinue
                Write-Log -Level "INFO" -Category "System" -Message "Extracted '$ToolName' to $toolDir"
            }
            catch {
                Write-Log -Level "WARNING" -Category "System" -Message "Extraction failed for '$ToolName': $($_.Exception.Message)"
            }
        }

        $script:ToolManagerState.InstallLog.Add([PSCustomObject]@{
            Tool      = $ToolName
            Action    = 'Install'
            Path      = $downloadPath
            Success   = $true
            Timestamp = [DateTime]::Now
        })

        Write-Log -Level "INFO" -Category "System" -Message "Successfully installed '$ToolName' ($($tool.Version))"
        return $true
    }
    catch {
        $script:ToolManagerState.InstallLog.Add([PSCustomObject]@{
            Tool      = $ToolName
            Action    = 'Install'
            Path      = ''
            Success   = $false
            Error     = $_.Exception.Message
            Timestamp = [DateTime]::Now
        })
        Write-Log -Level "ERROR" -Category "System" -Message "Failed to install '$ToolName': $($_.Exception.Message)"
        return $false
    }
}

function global:Install-AllTools {
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [string[]]$Categories = @('Cleaning','Optimization','Privacy','Security','Analysis','Monitoring','Debloat','System')
    )

    try {
        if (-not $script:ToolManagerState.Initialized) {
            Initialize-ToolManager
        }

        $manifest = $script:ToolManagerState.Manifest
        $results = [System.Collections.Generic.List[PSObject]]::new()

        $filteredTools = $manifest.Values | Where-Object { $_.Category -in $Categories }

        Write-Log -Level "INFO" -Category "System" -Message "Installing $($filteredTools.Count) tools across categories: $($Categories -join ', ')"

        foreach ($tool in $filteredTools) {
            $success = Install-Tool -ToolName $tool.Name -Force:$Force
            $results.Add([PSCustomObject]@{
                Tool    = $tool.Name
                Success = $success
            })
        }

        $installed = ($results | Where-Object { $_.Success }).Count
        $failed = ($results | Where-Object { -not $_.Success }).Count

        Write-Log -Level "INFO" -Category "System" -Message "All tools installation complete: $installed succeeded, $failed failed"
        return $results.ToArray()
    }
    catch {
        Write-Log -Level "ERROR" -Category "System" -Message "Install-AllTools failed: $($_.Exception.Message)"
        throw
    }
}

function global:Update-Tool {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ToolName
    )

    try {
        if (-not $script:ToolManagerState.Initialized) {
            Initialize-ToolManager
        }

        $manifest = $script:ToolManagerState.Manifest
        if (-not $manifest.ContainsKey($ToolName)) {
            Write-Log -Level "ERROR" -Category "System" -Message "Tool '$ToolName' not found in manifest"
            return $false
        }

        $tool = $manifest[$ToolName]
        $toolDir = Join-Path -Path $script:ToolManagerState.ToolsRoot -ChildPath "$($tool.Category)\$($tool.Name)"

        if (-not (Test-Path -Path $toolDir)) {
            Write-Log -Level "INFO" -Category "System" -Message "Tool '$ToolName' not installed, installing instead"
            return Install-Tool -ToolName $ToolName
        }

        Write-Log -Level "INFO" -Category "System" -Message "Updating '$ToolName' to version $($tool.Version)"
        return Install-Tool -ToolName $ToolName -Force
    }
    catch {
        Write-Log -Level "ERROR" -Category "System" -Message "Failed to update '$ToolName': $($_.Exception.Message)"
        return $false
    }
}

function global:Test-ToolIntegrity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ToolName
    )

    try {
        if (-not $script:ToolManagerState.Initialized) {
            Initialize-ToolManager
        }

        $manifest = $script:ToolManagerState.Manifest
        if (-not $manifest.ContainsKey($ToolName)) {
            Write-Log -Level "ERROR" -Category "System" -Message "Tool '$ToolName' not found in manifest"
            return $false
        }

        $tool = $manifest[$ToolName]

        if ([string]::IsNullOrEmpty($tool.Hash)) {
            Write-Log -Level "DEBUG" -Category "System" -Message "No hash defined for '$ToolName', skipping verification"
            return $true
        }

        $toolDir = Join-Path -Path $script:ToolManagerState.ToolsRoot -ChildPath "$($tool.Category)\$($tool.Name)"
        $files = Get-ChildItem -Path $toolDir -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -match '\.(exe|msi|ps1)$' }

        if ($files.Count -eq 0) {
            Write-Log -Level "WARNING" -Category "System" -Message "No executable found for '$ToolName'"
            return $false
        }

        $hash = (Get-FileHash -Path $files[0].FullName -Algorithm SHA256).Hash
        if ($hash -eq $tool.Hash) {
            Write-Log -Level "DEBUG" -Category "System" -Message "Hash verified for '$ToolName'"
            return $true
        }

        Write-Log -Level "ERROR" -Category "System" -Message "Hash mismatch for '$ToolName': expected $($tool.Hash), got $hash"
        return $false
    }
    catch {
        Write-Log -Level "ERROR" -Category "System" -Message "Integrity check failed for '$ToolName': $($_.Exception.Message)"
        return $false
    }
}

function global:Get-ToolStatus {
    [CmdletBinding()]
    param()

    try {
        if (-not $script:ToolManagerState.Initialized) {
            Initialize-ToolManager
        }

        $manifest = $script:ToolManagerState.Manifest
        $status = [System.Collections.Generic.List[PSObject]]::new()

        foreach ($tool in $manifest.Values) {
            $toolDir = Join-Path -Path $script:ToolManagerState.ToolsRoot -ChildPath "$($tool.Category)\$($tool.Name)"
            $installed = Test-Path -Path $toolDir
            $hasFiles = $false

            if ($installed) {
                $hasFiles = (Get-ChildItem -Path $toolDir -File -ErrorAction SilentlyContinue).Count -gt 0
            }

            $status.Add([PSCustomObject]@{
                Name        = $tool.Name
                Category    = $tool.Category
                Installed   = ($installed -and $hasFiles)
                Path        = $toolDir
                Version     = $tool.Version
                SizeMB      = $tool.SizeMB
            })
        }

        $installedCount = ($status | Where-Object { $_.Installed }).Count
        $totalCount = $status.Count
        Write-Log -Level "DEBUG" -Category "System" -Message "Tool status: $installedCount of $totalCount tools installed"

        return $status.ToArray()
    }
    catch {
        Write-Log -Level "ERROR" -Category "System" -Message "Error getting tool status: $($_.Exception.Message)"
        throw
    }
}

function global:Invoke-Tool {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ToolName,

        [Parameter()]
        [string]$Arguments = '',

        [Parameter()]
        [switch]$Wait,

        [Parameter()]
        [int]$TimeoutSeconds = 300
    )

    try {
        if (-not $script:ToolManagerState.Initialized) {
            Initialize-ToolManager
        }

        $manifest = $script:ToolManagerState.Manifest
        if (-not $manifest.ContainsKey($ToolName)) {
            Write-Log -Level "ERROR" -Category "System" -Message "Tool '$ToolName' not found in manifest"
            return $null
        }

        $tool = $manifest[$ToolName]
        $toolDir = Join-Path -Path $script:ToolManagerState.ToolsRoot -ChildPath "$($tool.Category)\$($tool.Name)"

        if (-not (Test-Path -Path $toolDir)) {
            Write-Log -Level "ERROR" -Category "System" -Message "Tool '$ToolName' not installed, install it first"
            return $null
        }

        $executables = Get-ChildItem -Path $toolDir -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Extension -match '\.(exe|msi|ps1)$' }

        if ($executables.Count -eq 0) {
            Write-Log -Level "ERROR" -Category "System" -Message "No executable found for '$ToolName'"
            return $null
        }

        $exe = $executables | Where-Object { $_.Name -like "$($tool.Name)*" } | Select-Object -First 1
        if ($null -eq $exe) {
            $exe = $executables | Select-Object -First 1
        }

        Write-Log -Level "INFO" -Category "System" -Message "Invoking '$ToolName': $($exe.FullName) $Arguments"

        if ($exe.Extension -eq '.ps1') {
            $process = Start-Process -FilePath 'powershell.exe' -ArgumentList "-ExecutionPolicy Bypass -File `"$($exe.FullName)`" $Arguments" -Wait:$Wait -PassThru -NoNewWindow
        }
        else {
            $process = Start-Process -FilePath $exe.FullName -ArgumentList $Arguments -Wait:$Wait -PassThru
        }

        if ($Wait) {
            Write-Log -Level "INFO" -Category "System" -Message "'$ToolName' exited with code $($process.ExitCode)"
        }

        return $process
    }
    catch {
        Write-Log -Level "ERROR" -Category "System" -Message "Failed to invoke '$ToolName': $($_.Exception.Message)"
        return $null
    }
}

function global:Remove-Tool {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ToolName,

        [Parameter()]
        [switch]$Force
    )

    try {
        if (-not $script:ToolManagerState.Initialized) {
            Initialize-ToolManager
        }

        $manifest = $script:ToolManagerState.Manifest
        if (-not $manifest.ContainsKey($ToolName)) {
            Write-Log -Level "ERROR" -Category "System" -Message "Tool '$ToolName' not found in manifest"
            return $false
        }

        $tool = $manifest[$ToolName]
        $toolDir = Join-Path -Path $script:ToolManagerState.ToolsRoot -ChildPath "$($tool.Category)\$($tool.Name)"

        if (-not (Test-Path -Path $toolDir)) {
            Write-Log -Level "INFO" -Category "System" -Message "Tool '$ToolName' not installed"
            return $true
        }

        Remove-Item -Path $toolDir -Recurse -Force -ErrorAction Stop

        $script:ToolManagerState.InstallLog.Add([PSCustomObject]@{
            Tool      = $ToolName
            Action    = 'Remove'
            Path      = $toolDir
            Success   = $true
            Timestamp = [DateTime]::Now
        })

        Write-Log -Level "INFO" -Category "System" -Message "Removed '$ToolName' from $toolDir"
        return $true
    }
    catch {
        Write-Log -Level "ERROR" -Category "System" -Message "Failed to remove '$ToolName': $($_.Exception.Message)"
        return $false
    }
}
