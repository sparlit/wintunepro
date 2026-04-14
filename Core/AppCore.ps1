# WinTune Pro - Application Core Module
# PowerShell 5.1+ Compatible

$script:Modules = @{}
$script:IsAdmin = $false
$script:SessionId = ""
$script:UIMainWindow = $null
$script:AppStartTime = Get-Date
$script:WmiCache = @{}
$script:WmiCacheExpiry = [TimeSpan]::FromSeconds(30)

# Check if running as administrator
function global:Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Generate session ID
function global:New-SessionId {
    return "WT$(Get-Date -Format 'yyyyMMddHHmmss')$([guid]::NewGuid().ToString().Substring(0,8))"
}

# Initialize application
function global:Initialize-Application {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RootPath
    )

    # Check admin status
    $script:IsAdmin = Test-Administrator
    $script:AppStartTime = Get-Date
    if (-not $script:IsAdmin) {
        Write-Host "WARNING: Not running as Administrator. Some features may be limited." -ForegroundColor Yellow
    }

    # Generate session ID
    $script:SessionId = New-SessionId

    # Initialize config paths
    Initialize-ConfigPaths -RootPath $RootPath

    # Ensure directories exist
    Initialize-Directories -RootPath $RootPath

    # Initialize logger
    $logDir = Join-Path $RootPath "Logs"
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    Initialize-Logger -LogDirectory $logDir -SessionIdentifier $script:SessionId

    # Load saved settings
    Load-Settings

    Log-Info "WinTune Pro initialized - Session: $($script:SessionId)" -Category "Core"
    Log-Info "Administrator: $($script:IsAdmin)" -Category "Core"
    Log-Info "PowerShell Version: $($PSVersionTable.PSVersion)" -Category "Core"

    return $true
}

# Get module status
function global:Get-ModuleStatus {
    return $script:Modules
}

# Cached system info helper - uses real CIM data with caching
function global:Get-CachedCimInstance {
    param(
        [Parameter(Mandatory)]
        [string]$ClassName,
        [string]$Filter = ""
    )

    $cacheKey = "$ClassName`_$Filter"
    $now = Get-Date

    if ($script:WmiCache.ContainsKey($cacheKey)) {
        $cached = $script:WmiCache[$cacheKey]
        if (($now - $cached.Time) -lt $script:WmiCacheExpiry) {
            return $cached.Data
        }
    }

    $data = $null

    try {
        if ($Filter) {
            $data = Get-CimInstance -ClassName $ClassName -Filter $Filter -ErrorAction Stop
        } else {
            $data = Get-CimInstance -ClassName $ClassName -ErrorAction Stop
        }
    } catch {
        try {
            $data = Get-WmiObject -ClassName $ClassName -ErrorAction Stop
        } catch {
            $data = $null
        }
    }

    $script:WmiCache[$cacheKey] = @{ Data = $data; Time = $now }
    return $data
}

# Get elapsed session time
function global:Get-SessionElapsed {
    return (Get-Date) - $script:AppStartTime
}

# Get system information
function global:Get-SystemInfo {
    $totalMemBytes = 0
    $freeMemKB = 0
    
    try {
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        $totalMemBytes = [int64]$cs.TotalPhysicalMemory
    } catch {
        $totalMemBytes = [int64]17000000000
    }
    
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $freeMemKB = [int64]$os.FreePhysicalMemory
        $osCaption = $os.Caption
        $osBuild = $os.BuildNumber
    } catch {
        $osCaption = "Windows"
        $osBuild = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name CurrentBuild -ErrorAction SilentlyContinue).CurrentBuild
    }
    
    try {
        $cpu = Get-CimInstance Win32_Processor -ErrorAction Stop
        $cpuName = if ($cpu -is [array]) { $cpu[0].Name } else { $cpu.Name }
        $cpuCores = if ($cpu -is [array]) { ($cpu | Measure-Object -Property NumberOfCores -Sum).Sum } else { $cpu.NumberOfCores }
        $cpuThreads = if ($cpu -is [array]) { ($cpu | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum } else { $cpu.NumberOfLogicalProcessors }
    } catch {
        $cpuName = "Unknown CPU"
        $cpuCores = [Environment]::ProcessorCount
        $cpuThreads = [Environment]::ProcessorCount
    }

    $totalGB = [math]::Round($totalMemBytes / 1GB, 2)
    $freeGB = [math]::Round($freeMemKB / 1MB, 2)
    $usedGB = [math]::Round($totalGB - $freeGB, 2)
    $memPercent = if ($totalGB -gt 0) { [math]::Round(($usedGB / $totalGB) * 100, 1) } else { 0 }

    $result = [PSCustomObject]@{
        ComputerName = $env:COMPUTERNAME
        UserName = $env:USERNAME
        OSVersion = $osCaption
        OSBuild = $osBuild
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        CPU = $cpuName
        CPUCores = $cpuCores
        CPUThreads = $cpuThreads
        TotalMemory = $totalGB
        FreeMemory = $freeGB
        UsedMemory = $usedGB
        MemoryPercent = $memPercent
    }

    return $result
}

# Get disk information
function global:Get-DiskInfo {
    $disks = @()

    try {
        $logicalDisks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction Stop
    } catch {
        $logicalDisks = @()
    }
    
    foreach ($disk in $logicalDisks) {
        $total = [math]::Round([int64]$disk.Size / 1GB, 1)
        $free = [math]::Round([int64]$disk.FreeSpace / 1GB, 1)
        $used = [math]::Round($total - $free, 1)
        $percent = if ($total -gt 0) { [math]::Round(($used / $total) * 100, 1) } else { 0 }

        $disks += [PSCustomObject]@{
            Drive = $disk.DeviceID
            Label = $disk.VolumeName
            Total = $total
            Used = $used
            Free = $free
            PercentUsed = $percent
            FileSystem = $disk.FileSystem
        }
    }

    return $disks
}

# Get running services count
function global:Get-RunningServicesCount {
    return @(Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Running' }).Count
}

# Get startup items count
function global:Get-StartupItemsCount {
    $count = 0

    # Registry startup items
    $regPaths = @(
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
    )

    foreach ($path in $regPaths) {
        if (Test-Path $path) {
            $count += (Get-Item $path).ValueNames.Count
        }
    }

    return $count
}

# Calculate system health score

# Get CPU usage
function global:Get-CPUUsage {
    try {
        # First call primes the counter, second call gets the value
        Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue | Out-Null
        Start-Sleep -Milliseconds 200
        $cpu = [math]::Round((Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue).CounterSamples.CookedValue, 1)
        return $cpu
    } catch {
        return 0
    }
}

# Get process count
function global:Get-ProcessCount {
    return @(Get-Process).Count
}

# Show confirmation dialog
function global:Show-Confirmation {
    param(
        [string]$Title = "Confirm",
        [string]$Message = "Are you sure?"
    )

    if (-not (Get-ConfigValue "ShowConfirmations")) {
        return $true
    }

    # Use WPF message box
    Add-Type -AssemblyName PresentationFramework

    $result = [System.Windows.MessageBox]::Show($Message, $Title, "YesNo", "Question")

    return ($result -eq "Yes")
}

# Get session ID
function global:Get-SessionId {
    return $script:SessionId
}

# Get admin status
function global:Get-AdminStatus {
    return $script:IsAdmin
}

# Set UI window reference
function global:Set-UIWindow {
    param($Window)
    $script:UIMainWindow = $Window
}

# Get UI window reference
function global:Get-UIWindow {
    return $script:UIMainWindow
}

