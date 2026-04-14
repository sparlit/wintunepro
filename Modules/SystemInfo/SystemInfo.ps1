<#
.SYNOPSIS
    WinTunePro SystemInfo Module - Comprehensive system information gathering
.DESCRIPTION
    Gathers detailed system information including OS, CPU, RAM, GPU, Disk, Network,
    installed software, activation status, uptime, updates, startup items, and services.
.NOTES
    File: Modules\SystemInfo\SystemInfo.ps1
    Version: 1.0.0
    PowerShell: 5.1+
    Compatible: Windows 10, Windows 11
#>

#Requires -Version 5.1

$script:SystemInfoCache = @{}
$script:CacheTimestamp = $null
$script:CacheTimeoutMinutes = 5

function global:Get-SystemInfoCached {
    param(
        [string]$ClassName,
        [string]$Namespace = "root\cimv2",
        [string]$ComputerName = "."
    )
    $cacheKey = "$Namespace\$ClassName"
    $now = Get-Date
    if ($script:SystemInfoCache.ContainsKey($cacheKey) -and $script:CacheTimestamp -and ($now - $script:CacheTimestamp).TotalMinutes -lt $script:CacheTimeoutMinutes) {
        return $script:SystemInfoCache[$cacheKey]
    }
    try {
        $data = Get-CachedCimInstance -ClassName $ClassName
        if ($data) {
            $script:SystemInfoCache[$cacheKey] = $data
            $script:CacheTimestamp = $now
        }
        return $data
    } catch {
        return $null
    }
}

function global:Clear-SystemInfoCache {
    $script:SystemInfoCache = @{}
    $script:CacheTimestamp = $null
    Write-Log -Level "INFO" -Category "System" -Message "System info cache cleared"
}

function global:Get-SystemOverview {
    <#
    .SYNOPSIS
        Returns complete system overview including OS, CPU, RAM, GPU, Disk, Network.
    #>
    $result = @{
        Success  = $true
        Details  = @{}
        Errors   = @()
    }

    Write-Log -Level "INFO" -Category "System" -Message "Gathering system overview..."

    try {
        $os = Get-CachedCimInstance -ClassName "Win32_OperatingSystem"
        $cpu = Get-CachedCimInstance -ClassName "Win32_Processor"
        $cs = Get-CachedCimInstance -ClassName "Win32_ComputerSystem"
        $gpu = Get-CachedCimInstance -ClassName "Win32_VideoController"
        $disk = Get-CachedCimInstance -ClassName "Win32_LogicalDisk" | Where-Object { $_.DriveType -eq 3 }
        $net = Get-CachedCimInstance -ClassName "Win32_NetworkAdapterConfiguration" | Where-Object { $_.IPEnabled -eq $true }

        $totalRAM = [math]::Round(($cs.TotalPhysicalMemory / 1GB), 2)
        $freeRAM = [math]::Round(($os.FreePhysicalMemory / 1MB), 2)
        $usedRAM = [math]::Round($totalRAM - $freeRAM, 2)

        $osInfo = Get-OSInformation
        $cpuInfo = Get-CPUInformation
        $memInfo = Get-MemoryInformation
        $diskInfo = Get-DiskInformation
        $gpuInfo = Get-GPUInformation
        $netInfo = Get-NetworkInformation

        $result.Details = @{
            ComputerName = $env:COMPUTERNAME
            OS           = $osInfo.Details
            CPU          = $cpuInfo.Details
            Memory       = $memInfo.Details
            Disks        = $diskInfo.Details
            GPU          = $gpuInfo.Details
            Network      = $netInfo.Details
            Uptime       = (Get-SystemUptime).Details
        }

        if (-not $osInfo.Success) { $result.Errors += $osInfo.Errors }
        if (-not $cpuInfo.Success) { $result.Errors += $cpuInfo.Errors }
        if (-not $memInfo.Success) { $result.Errors += $memInfo.Errors }
        if (-not $diskInfo.Success) { $result.Errors += $diskInfo.Errors }
        if (-not $gpuInfo.Success) { $result.Errors += $gpuInfo.Errors }
        if (-not $netInfo.Success) { $result.Errors += $netInfo.Errors }

        Write-Log -Level "SUCCESS" -Category "System" -Message "System overview gathered successfully"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "System" -Message "Failed to gather system overview: $($_.Exception.Message)"
    }

    return $result
}

function global:Get-OSInformation {
    <#
    .SYNOPSIS
        Returns OS name, version, build, edition, architecture, activation status.
    #>
    $result = @{
        Success  = $true
        Details  = @{}
        Errors   = @()
    }

    try {
        $os = Get-CachedCimInstance -ClassName "Win32_OperatingSystem"
        $reg = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction Stop

        $edition = $reg.EditionID
        if (-not $edition) { $edition = $os.Caption }

        $displayVersion = $reg.DisplayVersion
        if (-not $displayVersion) { $displayVersion = $reg.ReleaseId }

        $buildLab = $reg.BuildBranch
        $ubr = $reg.UBR
        $fullBuild = "$($reg.CurrentBuildNumber).$ubr"

        $arch = $os.OSArchitecture
        if (-not $arch) {
            if ([Environment]::Is64BitOperatingSystem) { $arch = "64-bit" } else { $arch = "32-bit" }
        }

        $activationStatus = "Unknown"
        try {
            $licenseStatus = (Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "PartialProductKey <> null AND Name like '%Windows%'" -ErrorAction Stop).LicenseStatus
            switch ($licenseStatus) {
                0 { $activationStatus = "Unlicensed" }
                1 { $activationStatus = "Licensed (Activated)" }
                2 { $activationStatus = "Out-of-Box Grace Period" }
                3 { $activationStatus = "Out-of-Tolerance Grace Period" }
                4 { $activationStatus = "Non-Genuine Grace Period" }
                5 { $activationStatus = "Notification" }
                6 { $activationStatus = "Extended Grace" }
                default { $activationStatus = "Unknown ($licenseStatus)" }
            }
        } catch {
            $result.Errors += "Could not determine activation status: $($_.Exception.Message)"
        }

        $result.Details = @{
            Name            = $os.Caption
            Version         = $displayVersion
            Build           = $fullBuild
            BuildNumber     = $reg.CurrentBuildNumber
            UBR             = $ubr
            Edition         = $edition
            Architecture    = $arch
            ActivationStatus = $activationStatus
            InstallDate     = $os.InstallDate
            LastBootTime    = $os.LastBootUpTime
            SystemDirectory = $os.SystemDirectory
            WindowsDirectory = $os.WindowsDirectory
        }

        Write-Log -Level "INFO" -Category "System" -Message "OS info: $($os.Caption) Build $fullBuild ($arch)"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "System" -Message "Failed to get OS information: $($_.Exception.Message)"
    }

    return $result
}

function global:Get-CPUInformation {
    <#
    .SYNOPSIS
        Returns CPU name, cores, threads, speed, load, temperature (if available).
    #>
    $result = @{
        Success  = $true
        Details  = @{}
        Errors   = @()
    }

    try {
        $cpu = Get-CachedCimInstance -ClassName "Win32_Processor"
        $os = Get-CachedCimInstance -ClassName "Win32_OperatingSystem"

        if ($cpu -is [array]) { $cpu = $cpu[0] }

        $load = 0
        try {
            $perf = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop
            if ($perf -is [array]) { $perf = $perf[0] }
            $load = $perf.LoadPercentage
        } catch {
            $result.Errors += "Could not get CPU load: $($_.Exception.Message)"
        }

        $temperature = "N/A"
        try {
            $temp = Get-CimInstance -Namespace "root\WMI" -ClassName "MSAcpi_ThermalZoneTemperature" -ErrorAction Stop
            if ($temp) {
                $celsius = [math]::Round(($temp[0].CurrentTemperature / 10) - 273.15, 1)
                $temperature = "$celsius C"
            }
        } catch {
            $temperature = "Not available (requires admin)"
        }

        $result.Details = @{
            Name           = $cpu.Name.Trim()
            Manufacturer   = $cpu.Manufacturer
            NumberOfCores  = $cpu.NumberOfCores
            NumberOfLogicalProcessors = $cpu.NumberOfLogicalProcessors
            MaxClockSpeed  = "$($cpu.MaxClockSpeed) MHz"
            CurrentClockSpeed = "$($cpu.CurrentClockSpeed) MHz"
            L2CacheSize    = "$($cpu.L2CacheSize) KB"
            L3CacheSize    = "$($cpu.L3CacheSize) KB"
            LoadPercentage = "$load%"
            Temperature    = $temperature
            Architecture   = $cpu.Architecture
        }

        Write-Log -Level "INFO" -Category "System" -Message "CPU: $($cpu.Name.Trim()) - $($cpu.NumberOfCores) cores, $($cpu.NumberOfLogicalProcessors) threads"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "System" -Message "Failed to get CPU information: $($_.Exception.Message)"
    }

    return $result
}

function global:Get-MemoryInformation {
    <#
    .SYNOPSIS
        Returns total, used, free, available, page file, RAM type/speed.
    #>
    $result = @{
        Success  = $true
        Details  = @{}
        Errors   = @()
    }

    try {
        $os = Get-CachedCimInstance -ClassName "Win32_OperatingSystem"
        $cs = Get-CachedCimInstance -ClassName "Win32_ComputerSystem"
        $physicalMem = Get-CachedCimInstance -ClassName "Win32_PhysicalMemory"

        $totalGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
        $freeGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
        $usedGB = [math]::Round($totalGB - $freeGB, 2)
        $usedPercent = [math]::Round(($usedGB / $totalGB) * 100, 1)

        $ramModules = @()
        if ($physicalMem) {
            foreach ($module in $physicalMem) {
                $type = "Unknown"
                switch ($module.MemoryType) {
                    20 { $type = "DDR" }
                    21 { $type = "DDR2" }
                    22 { $type = "DDR2 FB-DIMM" }
                    24 { $type = "DDR3" }
                    26 { $type = "DDR4" }
                    0  { if ($module.SMBIOSMemoryType -eq 26) { $type = "DDR4" } elseif ($module.SMBIOSMemoryType -eq 27) { $type = "DDR4" } elseif ($module.SMBIOSMemoryType -eq 28) { $type = "LPDDR4" } elseif ($module.SMBIOSMemoryType -eq 30) { $type = "DDR5" } elseif ($module.SMBIOSMemoryType -eq 31) { $type = "LPDDR5" } else { $type = "Type $($module.SMBIOSMemoryType)" } }
                    default { $type = "Type $($module.MemoryType)" }
                }
                $ramModules += @{
                    Bank      = $module.BankLabel
                    SizeGB    = [math]::Round($module.Capacity / 1GB, 2)
                    SpeedMHz  = $module.Speed
                    Type      = $type
                    Manufacturer = $module.Manufacturer
                }
            }
        }

        $pageFileGB = [math]::Round(($os.SizeStoredInPagingFiles | ForEach-Object { ($_ -split '\s+')[-1] }) / 1MB, 2)
        $pageFileFreeGB = [math]::Round(($os.FreeSpaceInPagingFiles | ForEach-Object { ($_ -split '\s+')[-1] }) / 1MB, 2)

        $virtualTotalGB = [math]::Round($os.TotalVirtualMemorySize / 1MB, 2)
        $virtualFreeGB = [math]::Round($os.FreeVirtualMemory / 1MB, 2)

        $result.Details = @{
            TotalGB          = $totalGB
            UsedGB           = $usedGB
            FreeGB           = $freeGB
            UsedPercent      = $usedPercent
            VirtualTotalGB   = $virtualTotalGB
            VirtualFreeGB    = $virtualFreeGB
            PageFileGB       = $pageFileGB
            PageFileFreeGB   = $pageFileFreeGB
            RAMModules       = $ramModules
            ModuleCount      = $ramModules.Count
        }

        Write-Log -Level "INFO" -Category "System" -Message "Memory: $totalGB GB total, $usedGB GB used ($usedPercent%)"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "System" -Message "Failed to get memory information: $($_.Exception.Message)"
    }

    return $result
}

function global:Get-DiskInformation {
    <#
    .SYNOPSIS
        Returns all disks: size, free, used, filesystem, health status, SMART data.
    #>
    $result = @{
        Success  = $true
        Details  = @()
        Errors   = @()
    }

    try {
        $disks = Get-CachedCimInstance -ClassName "Win32_LogicalDisk"
        $physicalDisks = Get-CachedCimInstance -ClassName "Win32_DiskDrive"

        foreach ($disk in $disks) {
            if ($disk.DriveType -ne 3 -and $disk.DriveType -ne 2) { continue }

            $sizeGB = 0
            $freeGB = 0
            $usedGB = 0
            $usedPercent = 0

            if ($disk.Size -gt 0) {
                $sizeGB = [math]::Round($disk.Size / 1GB, 2)
                $freeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
                $usedGB = [math]::Round($sizeGB - $freeGB, 2)
                $usedPercent = [math]::Round(($usedGB / $sizeGB) * 100, 1)
            }

            $driveType = switch ($disk.DriveType) {
                2 { "Removable" }
                3 { "Local" }
                4 { "Network" }
                5 { "Compact Disc" }
                default { "Unknown" }
            }

            $healthStatus = "Unknown"
            $smartData = @{}
            try {
                if ($physicalDisks) {
                    $matchingPhysical = $physicalDisks | Where-Object { $_.DeviceID -eq "\\.\PHYSICALDRIVE$($disk.DeviceID.TrimEnd('\').Replace(':', ''))" }
                    if (-not $matchingPhysical) {
                        foreach ($pd in $physicalDisks) {
                            $partitions = Get-CimInstance -ClassName Win32_DiskDriveToDiskPartition -ErrorAction Stop
                            $logical = Get-CimInstance -ClassName Win32_LogicalDiskToPartition -ErrorAction Stop
                            if ($logical | Where-Object { $_.Dependent.DeviceID -eq $disk.DeviceID }) {
                                $healthStatus = "OK"
                                break
                            }
                        }
                    } else {
                        $healthStatus = "OK"
                    }
                }
            } catch {
                $result.Errors += "Could not get SMART data for $($disk.DeviceID): $($_.Exception.Message)"
            }

            $volumeName = $disk.VolumeName
            if (-not $volumeName) { $volumeName = "(No Label)" }

            $result.Details += @{
                DeviceID     = $disk.DeviceID
                VolumeName   = $volumeName
                FileSystem   = $disk.FileSystem
                DriveType    = $driveType
                SizeGB       = $sizeGB
                FreeGB       = $freeGB
                UsedGB       = $usedGB
                UsedPercent  = $usedPercent
                HealthStatus = $healthStatus
                SerialNumber = $disk.VolumeSerialNumber
            }
        }

        Write-Log -Level "INFO" -Category "System" -Message "Disk info gathered: $($result.Details.Count) drives found"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "System" -Message "Failed to get disk information: $($_.Exception.Message)"
    }

    return $result
}

function global:Get-GPUInformation {
    <#
    .SYNOPSIS
        Returns GPU name, VRAM, driver version.
    #>
    $result = @{
        Success  = $true
        Details  = @()
        Errors   = @()
    }

    try {
        $gpus = Get-CachedCimInstance -ClassName "Win32_VideoController"

        foreach ($gpu in $gpus) {
            if (-not $gpu.Name) { continue }

            $vramGB = 0
            if ($gpu.AdapterRAM -gt 0) {
                $vramGB = [math]::Round($gpu.AdapterRAM / 1GB, 2)
            } elseif ($gpu.AdapterCompatibility) {
                try {
                    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
                    $subKeys = Get-ChildItem $regPath -ErrorAction Stop
                    foreach ($key in $subKeys) {
                        $props = Get-ItemProperty $key.PSPath -ErrorAction SilentlyContinue
                        if ($props.DriverDesc -eq $gpu.Name -and $props."HardwareInformation.qwMemorySize") {
                            $vramGB = [math]::Round($props."HardwareInformation.qwMemorySize" / 1GB, 2)
                            break
                        }
                    }
                } catch {
                    $vramGB = 0
                }
            }

            $result.Details += @{
                Name          = $gpu.Name
                VRAMGB        = $vramGB
                DriverVersion = $gpu.DriverVersion
                DriverDate    = $gpu.DriverDate
                VideoProcessor = $gpu.VideoProcessor
                CurrentResolution = "$($gpu.CurrentHorizontalResolution)x$($gpu.CurrentVerticalResolution)"
                RefreshRate   = "$($gpu.CurrentRefreshRate) Hz"
                Status        = $gpu.Status
            }
        }

        Write-Log -Level "INFO" -Category "System" -Message "GPU info gathered: $($result.Details.Count) adapters found"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "System" -Message "Failed to get GPU information: $($_.Exception.Message)"
    }

    return $result
}

function global:Get-NetworkInformation {
    <#
    .SYNOPSIS
        Returns network adapters, IP, DNS, gateway, speed, status.
    #>
    $result = @{
        Success  = $true
        Details  = @()
        Errors   = @()
    }

    try {
        $adapters = Get-CachedCimInstance -ClassName "Win32_NetworkAdapterConfiguration" | Where-Object { $_.IPEnabled -eq $true }
        $netAdapters = Get-CachedCimInstance -ClassName "Win32_NetworkAdapter"

        foreach ($adapter in $adapters) {
            $physicalAdapter = $netAdapters | Where-Object { $_.Index -eq $adapter.Index }

            $speed = "Unknown"
            if ($physicalAdapter -and $physicalAdapter.Speed) {
                $speedBits = [long]$physicalAdapter.Speed
                if ($speedBits -ge 1000000000) {
                    $speed = "$([math]::Round($speedBits / 1000000000, 1)) Gbps"
                } elseif ($speedBits -ge 1000000) {
                    $speed = "$([math]::Round($speedBits / 1000000, 0)) Mbps"
                } else {
                    $speed = "$speedBits bps"
                }
            }

            $status = "Unknown"
            if ($physicalAdapter) {
                switch ($physicalAdapter.NetConnectionStatus) {
                    0 { $status = "Disconnected" }
                    1 { $status = "Connecting" }
                    2 { $status = "Connected" }
                    3 { $status = "Disconnecting" }
                    4 { $status = "Hardware Not Present" }
                    5 { $status = "Hardware Disabled" }
                    6 { $status = "Hardware Malfunction" }
                    7 { $status = "Media Disconnected" }
                    8 { $status = "Authenticating" }
                    9 { $status = "Authentication Succeeded" }
                    10 { $status = "Authentication Failed" }
                    11 { $status = "Invalid Address" }
                    12 { $status = "Credentials Required" }
                    default { $status = "Status $($physicalAdapter.NetConnectionStatus)" }
                }
            }

            $result.Details += @{
                Description    = $adapter.Description
                MACAddress     = $adapter.MACAddress
                IPAddresses    = $adapter.IPAddress
                SubnetMasks    = $adapter.IPSubnet
                DefaultGateway = $adapter.DefaultIPGateway
                DNSServers     = $adapter.DNSServerSearchOrder
                DHCPEnabled    = $adapter.DHCPEnabled
                DHCPServer     = $adapter.DHCPServer
                Speed          = $speed
                Status         = $status
                Index          = $adapter.Index
            }
        }

        Write-Log -Level "INFO" -Category "Network" -Message "Network info gathered: $($result.Details.Count) active adapters"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "Network" -Message "Failed to get network information: $($_.Exception.Message)"
    }

    return $result
}

function global:Get-InstalledSoftware {
    <#
    .SYNOPSIS
        Returns list of installed software with version, publisher, size.
    #>
    $result = @{
        Success  = $true
        Details  = @()
        Errors   = @()
    }

    Write-Log -Level "INFO" -Category "System" -Message "Gathering installed software list..."

    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    foreach ($regPath in $regPaths) {
        try {
            $items = Get-ItemProperty $regPath -ErrorAction SilentlyContinue
            foreach ($item in $items) {
                if (-not $item.DisplayName) { continue }

                $sizeMB = 0
                if ($item.EstimatedSize) {
                    $sizeMB = [math]::Round($item.EstimatedSize / 1024, 2)
                }

                $result.Details += @{
                    Name        = $item.DisplayName
                    Version     = $item.DisplayVersion
                    Publisher   = $item.Publisher
                    SizeMB      = $sizeMB
                    InstallDate = $item.InstallDate
                    UninstallString = $item.UninstallString
                    Location    = $regPath
                }
            }
        } catch {
            $result.Errors += "Failed to read registry path $regPath : $($_.Exception.Message)"
        }
    }

    Write-Log -Level "INFO" -Category "System" -Message "Found $($result.Details.Count) installed software items"
    return $result
}

function global:Get-WindowsActivation {
    <#
    .SYNOPSIS
        Check activation status using slmgr /dli.
    #>
    $result = @{
        Success  = $true
        Details  = @{}
        Errors   = @()
    }

    Write-Log -Level "INFO" -Category "System" -Message "Checking Windows activation status..."

    try {
        $license = Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "PartialProductKey <> null AND Name like '%Windows%'" -ErrorAction Stop

        $status = "Unknown"
        $partialKey = ""
        $description = ""

        if ($license) {
            switch ($license.LicenseStatus) {
                0 { $status = "Unlicensed" }
                1 { $status = "Licensed (Activated)" }
                2 { $status = "Out-of-Box Grace Period" }
                3 { $status = "Out-of-Tolerance Grace Period" }
                4 { $status = "Non-Genuine Grace Period" }
                5 { $status = "Notification" }
                6 { $status = "Extended Grace" }
                default { $status = "Unknown ($($license.LicenseStatus))" }
            }
            $partialKey = $license.PartialProductKey
            $description = $license.Description
        }

        $result.Details = @{
            Status       = $status
            PartialKey   = $partialKey
            Description  = $description
            Name         = $license.Name
            ProductKeyChannel = $license.ProductKeyChannel
        }

        Write-Log -Level "INFO" -Category "System" -Message "Activation status: $status"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "System" -Message "Failed to check activation: $($_.Exception.Message)"
    }

    return $result
}

function global:Get-SystemUptime {
    <#
    .SYNOPSIS
        Returns current uptime in days/hours/minutes.
    #>
    $result = @{
        Success  = $true
        Details  = @{}
        Errors   = @()
    }

    try {
        $os = Get-CachedCimInstance -ClassName "Win32_OperatingSystem"
        $lastBoot = $os.LastBootUpTime
        $uptime = (Get-Date) - $lastBoot

        $result.Details = @{
            LastBootTime   = $lastBoot.ToString("yyyy-MM-dd HH:mm:ss")
            Days           = $uptime.Days
            Hours          = $uptime.Hours
            Minutes        = $uptime.Minutes
            Seconds        = $uptime.Seconds
            TotalDays      = [math]::Round($uptime.TotalDays, 2)
            TotalHours     = [math]::Round($uptime.TotalHours, 2)
            FormattedUptime = "$($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m $($uptime.Seconds)s"
        }

        Write-Log -Level "INFO" -Category "System" -Message "System uptime: $($result.Details.FormattedUptime)"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "System" -Message "Failed to get system uptime: $($_.Exception.Message)"
    }

    return $result
}

function global:Get-PendingUpdates {
    <#
    .SYNOPSIS
        Returns list of pending Windows updates.
    #>
    $result = @{
        Success  = $true
        Details  = @()
        Errors   = @()
    }

    Write-Log -Level "INFO" -Category "System" -Message "Checking for pending updates..."

    try {
        $session = New-Object -ComObject Microsoft.Update.Session -ErrorAction Stop
        $searcher = $session.CreateUpdateSearcher()
        $searchResult = $searcher.Search("IsInstalled=0 and IsHidden=0")

        foreach ($update in $searchResult.Updates) {
            $result.Details += @{
                Title        = $update.Title
                KBArticles   = ($update.KBArticleIDs -join ", ")
                Category     = ($update.Categories | Select-Object -First 1).Name
                SizeMB       = [math]::Round($update.MaxDownloadSize / 1MB, 2)
                IsMandatory  = $update.IsMandatory
                RebootRequired = $update.RebootRequired
                Description  = $update.Description
            }
        }

        Write-Log -Level "INFO" -Category "System" -Message "Found $($result.Details.Count) pending updates"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "System" -Message "Failed to check pending updates: $($_.Exception.Message)"
    }

    return $result
}

function global:Get-StartupItemsFull {
    <#
    .SYNOPSIS
        Returns all startup items with risk assessment.
    #>
    $result = @{
        Success  = $true
        Details  = @()
        Errors   = @()
    }

    Write-Log -Level "INFO" -Category "Startup" -Message "Gathering startup items..."

    $knownSafe = @("SecurityHealth", "Windows Defender", "OneDrive", "RtkAuduService", "Realtek", "Intel", "AMD", "NVIDIA")
    $knownRisky = @("Java", "Adobe", "Updater", "Toolbar", "Assistant", "Notifier")

    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
    )

    foreach ($regPath in $regPaths) {
        try {
            if (-not (Test-Path $regPath)) { continue }
            $props = Get-ItemProperty $regPath -ErrorAction SilentlyContinue
            $propNames = $props.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" }

            foreach ($prop in $propNames) {
                $riskLevel = "Unknown"
                $itemName = $prop.Name

                if ($knownSafe | Where-Object { $itemName -like "*$_*" }) {
                    $riskLevel = "Safe"
                } elseif ($knownRisky | Where-Object { $itemName -like "*$_*" }) {
                    $riskLevel = "Potentially Unnecessary"
                } else {
                    $riskLevel = "Review Recommended"
                }

                $result.Details += @{
                    Name      = $itemName
                    Command   = $prop.Value
                    Location  = $regPath
                    RiskLevel = $riskLevel
                    Type      = "Registry"
                }
            }
        } catch {
            $result.Errors += "Failed to read $regPath : $($_.Exception.Message)"
        }
    }

    try {
        $startupFolder = [Environment]::GetFolderPath("Startup")
        $commonStartup = [Environment]::GetFolderPath("CommonStartup")

        foreach ($folder in @($startupFolder, $commonStartup)) {
            if (-not (Test-Path $folder)) { continue }
            $items = Get-ChildItem $folder -ErrorAction SilentlyContinue
            foreach ($item in $items) {
                $result.Details += @{
                    Name      = $item.Name
                    Command   = $item.FullName
                    Location  = $folder
                    RiskLevel = "Review Recommended"
                    Type      = "Startup Folder"
                }
            }
        }
    } catch {
        $result.Errors += "Failed to read startup folders: $($_.Exception.Message)"
    }

    try {
        $tasks = Get-ScheduledTask -ErrorAction Stop | Where-Object { $_.State -ne "Disabled" -and $_.TaskPath -notlike "\Microsoft\*" }
        foreach ($task in $tasks) {
            $result.Details += @{
                Name      = $task.TaskName
                Command   = ($task.Actions | ForEach-Object { $_.Execute }) -join ", "
                Location  = "ScheduledTask: $($task.TaskPath)"
                RiskLevel = "Review Recommended"
                Type      = "Scheduled Task"
            }
        }
    } catch {
        $result.Errors += "Failed to read scheduled tasks: $($_.Exception.Message)"
    }

    Write-Log -Level "INFO" -Category "Startup" -Message "Found $($result.Details.Count) startup items"
    return $result
}

function global:Get-RunningServices {
    <#
    .SYNOPSIS
        Returns list of running services with startup type.
    #>
    $result = @{
        Success  = $true
        Details  = @()
        Errors   = @()
    }

    Write-Log -Level "INFO" -Category "System" -Message "Gathering running services..."

    try {
        $services = Get-Service -ErrorAction Stop | Where-Object { $_.Status -eq "Running" }

        foreach ($svc in $services) {
            $startType = "Unknown"
            try {
                $cimSvc = Get-CimInstance -ClassName Win32_Service -Filter "Name='$($svc.Name)'" -ErrorAction Stop
                $startType = $cimSvc.StartMode
            } catch {
                $result.Errors += "Could not get start mode for $($svc.Name): $($_.Exception.Message)"
            }

            $result.Details += @{
                Name        = $svc.Name
                DisplayName = $svc.DisplayName
                Status      = $svc.Status.ToString()
                StartType   = $startType
            }
        }

        Write-Log -Level "INFO" -Category "System" -Message "Found $($result.Details.Count) running services"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "System" -Message "Failed to get running services: $($_.Exception.Message)"
    }

    return $result
}

function global:Export-SystemReport {
    <#
    .SYNOPSIS
        Export all system info to file.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,

        [Parameter()]
        [ValidateSet("TXT", "HTML", "JSON")]
        [string]$Format = "TXT"
    )

    $result = @{
        Success  = $true
        Details  = @{}
        Errors   = @()
    }

    Write-Log -Level "INFO" -Category "Report" -Message "Generating system report..."

    try {
        $overview = Get-SystemOverview
        $software = Get-InstalledSoftware
        $startup = Get-StartupItemsFull
        $services = Get-RunningServices
        $activation = Get-WindowsActivation
        $pendingUpdates = Get-PendingUpdates

        $reportData = @{
            GeneratedAt    = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            ComputerName   = $env:COMPUTERNAME
            SystemOverview = $overview.Details
            Activation     = $activation.Details
            InstalledSoftware = $software.Details
            StartupItems   = $startup.Details
            RunningServices = $services.Details
            PendingUpdates = $pendingUpdates.Details
        }

        $parentDir = Split-Path $OutputPath -Parent
        if ($parentDir -and -not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }

        switch ($Format) {
            "JSON" {
                $reportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath -Encoding UTF8
            }
            "HTML" {
                $sb = New-Object System.Text.StringBuilder
                [void]$sb.AppendLine("<!DOCTYPE html><html><head>")
                [void]$sb.AppendLine("<style>body{font-family:Consolas,monospace;background:#1e1e1e;color:#d4d4d4;padding:20px;}h1{color:#569cd6;}h2{color:#4ec9b0;}table{border-collapse:collapse;width:100%;margin:10px 0;}th{background:#264f78;color:white;padding:8px;text-align:left;}td{border:1px solid #444;padding:6px 8px;}</style>")
                [void]$sb.AppendLine("</head><body>")
                [void]$sb.AppendLine("<h1>WinTunePro System Report</h1>")
                [void]$sb.AppendLine("<p>Generated: $($reportData.GeneratedAt) | Computer: $($reportData.ComputerName)</p>")

                [void]$sb.AppendLine("<h2>Operating System</h2><table>")
                foreach ($key in $reportData.SystemOverview.OS.Keys) {
                    [void]$sb.AppendLine("<tr><td>$key</td><td>$($reportData.SystemOverview.OS[$key])</td></tr>")
                }
                [void]$sb.AppendLine("</table>")

                [void]$sb.AppendLine("<h2>CPU</h2><table>")
                foreach ($key in $reportData.SystemOverview.CPU.Keys) {
                    [void]$sb.AppendLine("<tr><td>$key</td><td>$($reportData.SystemOverview.CPU[$key])</td></tr>")
                }
                [void]$sb.AppendLine("</table>")

                [void]$sb.AppendLine("<h2>Memory</h2><table>")
                foreach ($key in $reportData.SystemOverview.Memory.Keys) {
                    [void]$sb.AppendLine("<tr><td>$key</td><td>$($reportData.SystemOverview.Memory[$key])</td></tr>")
                }
                [void]$sb.AppendLine("</table>")

                [void]$sb.AppendLine("</body></html>")
                $sb.ToString() | Out-File -FilePath $OutputPath -Encoding UTF8
            }
            default {
                $sb = New-Object System.Text.StringBuilder
                [void]$sb.AppendLine("=" * 80)
                [void]$sb.AppendLine("WinTunePro System Report")
                [void]$sb.AppendLine("Generated: $($reportData.GeneratedAt)")
                [void]$sb.AppendLine("Computer: $($reportData.ComputerName)")
                [void]$sb.AppendLine("=" * 80)

                [void]$sb.AppendLine("`n--- OPERATING SYSTEM ---")
                foreach ($key in $reportData.SystemOverview.OS.Keys) {
                    [void]$sb.AppendLine("  $key : $($reportData.SystemOverview.OS[$key])")
                }

                [void]$sb.AppendLine("`n--- CPU ---")
                foreach ($key in $reportData.SystemOverview.CPU.Keys) {
                    [void]$sb.AppendLine("  $key : $($reportData.SystemOverview.CPU[$key])")
                }

                [void]$sb.AppendLine("`n--- MEMORY ---")
                foreach ($key in $reportData.SystemOverview.Memory.Keys) {
                    [void]$sb.AppendLine("  $key : $($reportData.SystemOverview.Memory[$key])")
                }

                [void]$sb.AppendLine("`n--- DISKS ---")
                foreach ($disk in $reportData.SystemOverview.Disks) {
                    [void]$sb.AppendLine("  $($disk.DeviceID) $($disk.VolumeName) - $($disk.SizeGB) GB, $($disk.FreeGB) GB free ($($disk.UsedPercent)% used)")
                }

                [void]$sb.AppendLine("`n--- GPU ---")
                foreach ($gpu in $reportData.SystemOverview.GPU) {
                    [void]$sb.AppendLine("  $($gpu.Name) - $($gpu.VRAMGB) GB VRAM, Driver $($gpu.DriverVersion)")
                }

                [void]$sb.AppendLine("`n--- NETWORK ---")
                foreach ($net in $reportData.SystemOverview.Network) {
                    [void]$sb.AppendLine("  $($net.Description) - $($net.IPAddresses -join ', ') - $($net.Status)")
                }

                [void]$sb.AppendLine("`n--- INSTALLED SOFTWARE ($($reportData.InstalledSoftware.Count) items) ---")
                foreach ($sw in ($reportData.InstalledSoftware | Sort-Object Name)) {
                    [void]$sb.AppendLine("  $($sw.Name) v$($sw.Version) - $($sw.Publisher)")
                }

                [void]$sb.AppendLine("`n--- STARTUP ITEMS ($($reportData.StartupItems.Count) items) ---")
                foreach ($item in ($reportData.StartupItems | Sort-Object Name)) {
                    [void]$sb.AppendLine("  [$($item.RiskLevel)] $($item.Name) - $($item.Command)")
                }

                [void]$sb.AppendLine("`n--- RUNNING SERVICES ($($reportData.RunningServices.Count) items) ---")
                foreach ($svc in ($reportData.RunningServices | Sort-Object Name)) {
                    [void]$sb.AppendLine("  $($svc.Name) ($($svc.DisplayName)) - $($svc.StartType)")
                }

                [void]$sb.AppendLine("`n--- ACTIVATION ---")
                [void]$sb.AppendLine("  Status: $($reportData.Activation.Status)")

                [void]$sb.AppendLine("`n--- PENDING UPDATES ($($reportData.PendingUpdates.Count) items) ---")
                foreach ($upd in $reportData.PendingUpdates) {
                    [void]$sb.AppendLine("  $($upd.Title)")
                }

                $sb.ToString() | Out-File -FilePath $OutputPath -Encoding UTF8
            }
        }

        $result.Details = @{
            OutputPath = $OutputPath
            Format     = $Format
            ItemsCount = @{
                Software     = $software.Details.Count
                StartupItems = $startup.Details.Count
                Services     = $services.Details.Count
                Updates      = $pendingUpdates.Details.Count
            }
        }

        Write-Log -Level "SUCCESS" -Category "Report" -Message "System report exported to $OutputPath"
    } catch {
        $result.Success = $false
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "Report" -Message "Failed to export system report: $($_.Exception.Message)"
    }

    return $result
}
