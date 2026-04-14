# WinTune Pro - Cleaning Module
# PowerShell 5.1+ Compatible

function global:Invoke-CleaningScan {
    $results = @{}
    $totalSize = 0
    
    # User Temp Files
    $userTempSize = Get-FolderSize -Path $env:TEMP
    $results["UserTemp"] = @{
        Name = "User Temporary Files"
        Size = $userTempSize
        Path = $env:TEMP
    }
    $totalSize += $userTempSize
    
    # System Temp Files
    $sysTempSize = Get-FolderSize -Path "$env:SystemRoot\Temp"
    $results["SystemTemp"] = @{
        Name = "System Temporary Files"
        Size = $sysTempSize
        Path = "$env:SystemRoot\Temp"
    }
    $totalSize += $sysTempSize
    
    # Windows Update Cache
    $wuCacheSize = Get-FolderSize -Path "$env:SystemRoot\SoftwareDistribution\Download"
    $results["WUCache"] = @{
        Name = "Windows Update Cache"
        Size = $wuCacheSize
        Path = "$env:SystemRoot\SoftwareDistribution\Download"
    }
    $totalSize += $wuCacheSize
    
    # Windows Update Logs
    $wuLogSize = Get-FolderSize -Path "$env:SystemRoot\SoftwareDistribution\ReportingEvents.log"
    $results["WULogs"] = @{
        Name = "Windows Update Logs"
        Size = $wuLogSize
        Path = "$env:SystemRoot\SoftwareDistribution\ReportingEvents.log"
    }
    $totalSize += $wuLogSize
    
    # Recycle Bin
    $recycleSize = Get-RecycleBinSize
    $results["RecycleBin"] = @{
        Name = "Recycle Bin"
        Size = $recycleSize
        Path = "Recycle Bin"
    }
    $totalSize += $recycleSize
    
    # Thumbnail Cache
    $thumbCacheSize = Get-FolderSize -Path "$env:LocalAppData\Microsoft\Windows\Explorer"
    $results["ThumbnailCache"] = @{
        Name = "Thumbnail Cache"
        Size = $thumbCacheSize
        Path = "$env:LocalAppData\Microsoft\Windows\Explorer"
    }
    $totalSize += $thumbCacheSize
    
    # Icon Cache
    $iconCacheSize = Get-FolderSize -Path "$env:LocalAppData\Microsoft\Windows\Explorer\iconcache_*.db"
    $results["IconCache"] = @{
        Name = "Icon Cache"
        Size = $iconCacheSize
        Path = "$env:LocalAppData\Microsoft\Windows\Explorer"
    }
    $totalSize += $iconCacheSize
    
    # Prefetch
    $prefetchSize = Get-FolderSize -Path "$env:SystemRoot\Prefetch"
    $results["Prefetch"] = @{
        Name = "Prefetch Files"
        Size = $prefetchSize
        Path = "$env:SystemRoot\Prefetch"
    }
    $totalSize += $prefetchSize
    
    # DNS Cache
    $dnsCacheSize = Get-DnsCacheSize
    $results["DNSCache"] = @{
        Name = "DNS Resolver Cache"
        Size = $dnsCacheSize
        Path = "DNS Cache"
    }
    $totalSize += $dnsCacheSize
    
    # Font Cache
    $fontCacheSize = Get-FolderSize -Path "$env:SystemRoot\ServiceProfiles\LocalService\AppData\Local\FontCache"
    $results["FontCache"] = @{
        Name = "Font Cache"
        Size = $fontCacheSize
        Path = "$env:SystemRoot\ServiceProfiles\LocalService\AppData\Local\FontCache"
    }
    $totalSize += $fontCacheSize
    
    # Crash Dumps
    $crashDumpSize = Get-FolderSize -Path "$env:SystemRoot\Minidump"
    $results["CrashDumps"] = @{
        Name = "System Crash Dumps"
        Size = $crashDumpSize
        Path = "$env:SystemRoot\Minidump"
    }
    $totalSize += $crashDumpSize
    
    # Error Reporting
    $errorReportSize = Get-FolderSize -Path "$env:ProgramData\Microsoft\Windows\WER\ReportArchive"
    $results["ErrorReporting"] = @{
        Name = "Windows Error Reporting"
        Size = $errorReportSize
        Path = "$env:ProgramData\Microsoft\Windows\WER\ReportArchive"
    }
    $totalSize += $errorReportSize
    
    # IIS Temporary Files (if IIS is installed)
    $iisTempSize = Get-FolderSize -Path "$env:SystemRoot\inetpub\temp"
    $results["IISTemp"] = @{
        Name = "IIS Temporary Files"
        Size = $iisTempSize
        Path = "$env:SystemRoot\inetpub\temp"
    }
    $totalSize += $iisTempSize
    
    # IIS Logs (if IIS is installed)
    $iisLogSize = Get-FolderSize -Path "$env:SystemRoot\inetpub\logs"
    $results["IISLogs"] = @{
        Name = "IIS Logs"
        Size = $iisLogSize
        Path = "$env:SystemRoot\inetpub\logs"
    }
    $totalSize += $iisLogSize
    
    # Windows Defender Temporary Files
    $defenderTempSize = Get-FolderSize -Path "$env:ProgramData\Microsoft\Windows Defender\Scans\History\Service"
    $results["DefenderTemp"] = @{
        Name = "Windows Defender Temporary"
        Size = $defenderTempSize
        Path = "$env:ProgramData\Microsoft\Windows Defender\Scans\History\Service"
    }
    $totalSize += $defenderTempSize
    
    # Search Indexer Data
    $searchIndexSize = Get-FolderSize -Path "$env:ProgramData\Microsoft\Search\Data"
    $results["SearchIndex"] = @{
        Name = "Windows Search Indexer"
        Size = $searchIndexSize
        Path = "$env:ProgramData\Microsoft\Search\Data"
    }
    $totalSize += $searchIndexSize
    
    # Temporary ASP.NET Files
    $aspNetTempSize = Get-FolderSize -Path "$env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319\Temporary ASP.NET Files"
    $results["ASPNETTemp"] = @{
        Name = "ASP.NET Temporary Files"
        Size = $aspNetTempSize
        Path = "$env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319\Temporary ASP.NET Files"
    }
    $totalSize += $aspNetTempSize
    
    # Browser Caches
    $chromeSize = Get-FolderSize -Path "$env:LocalAppData\Google\Chrome\User Data\Default\Cache"
    $edgeSize = Get-FolderSize -Path "$env:LocalAppData\Microsoft\Edge\User Data\Default\Cache"
    $firefoxSize = Get-FirefoxCacheSize
    
    $results["ChromeCache"] = @{
        Name = "Chrome Cache"
        Size = $chromeSize
        Path = "$env:LocalAppData\Google\Chrome\User Data\Default\Cache"
    }
    $totalSize += $chromeSize
    
    $results["EdgeCache"] = @{
        Name = "Edge Cache"
        Size = $edgeSize
        Path = "$env:LocalAppData\Microsoft\Edge\User Data\Default\Cache"
    }
    $totalSize += $edgeSize
    
    $results["FirefoxCache"] = @{
        Name = "Firefox Cache"
        Size = $firefoxSize
        Path = "$env:LocalAppData\Mozilla\Firefox\Profiles"
    }
    $totalSize += $firefoxSize
    
    return @{
        Results = $results
        TotalSize = $totalSize
    }
}

function global:Get-FolderSize {
    param([string]$Path)
    
    if (-not (Test-Path $Path -ErrorAction SilentlyContinue)) {
        return 0
    }
    
    try {
        $size = (Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue -File | Measure-Object -Property Length -Sum).Sum
        return [math]::Round($size / 1MB, 2)
    } catch {
        return 0
    }
}

function global:Get-RecycleBinSize {
    try {
        $shell = New-Object -ComObject Shell.Application
        $recycleBin = $shell.NameSpace(0xa)
        $size = ($recycleBin.Items() | Measure-Object -Property Size -Sum).Sum
        return [math]::Round($size / 1MB, 2)
    } catch {
        return 0
    }
}

function global:Get-FirefoxCacheSize {
    $firefoxPath = "$env:LocalAppData\Mozilla\Firefox\Profiles"
    
    if (-not (Test-Path $firefoxPath)) {
        return 0
    }
    
    $totalSize = 0
    Get-ChildItem -Path $firefoxPath -Directory | ForEach-Object {
        $cachePath = Join-Path $_.FullName "cache2"
        if (Test-Path $cachePath) {
            $totalSize += Get-FolderSize -Path $cachePath
        }
    }
    
    return $totalSize
}

function global:Get-DnsCacheSize {
    try {
        # DNS cache size is negligible but we can report the record count
        $dnsRecords = Get-DnsClientCache | Measure-Object
        # Return approximate size based on record count (each record ~100 bytes)
        return [math]::Round(($dnsRecords.Count * 100) / 1MB, 2)
    } catch {
        return 0
    }
}

function global:Invoke-Cleaning {
    param(
        [string[]]$Categories,
        [bool]$TestMode = $false
    )
    
    $results = @{}
    $totalFreed = 0
    
    foreach ($category in $Categories) {
        $result = Invoke-SingleClean -Category $category -TestMode $TestMode
        $results[$category] = $result
        $totalFreed += $result.Freed
    }
    
    return @{
        Results = $results
        TotalFreed = $totalFreed
    }
}

function global:Invoke-SingleClean {
    param(
        [string]$Category,
        [bool]$TestMode = $false
    )
    
    $result = @{
        Category = $Category
        Freed = 0
        FilesDeleted = 0
        Success = $true
        Error = ""
    }
    
     $paths = @{
         # Basic temp files
         "UserTemp" = $env:TEMP
         "SystemTemp" = "$env:SystemRoot\Temp"
         "WUCache" = "$env:SystemRoot\SoftwareDistribution\Download"
         "WULogs" = "$env:SystemRoot\SoftwareDistribution\ReportingEvents.log"
         "ThumbnailCache" = "$env:LocalAppData\Microsoft\Windows\Explorer"
         "IconCache" = "$env:LocalAppData\Microsoft\Windows\Explorer"
         "Prefetch" = "$env:SystemRoot\Prefetch"
         "DNSCache" = "DNS Cache"
         "FontCache" = "$env:SystemRoot\ServiceProfiles\LocalService\AppData\Local\FontCache"
         "CrashDumps" = "$env:SystemRoot\Minidump"
         "ErrorReporting" = "$env:ProgramData\Microsoft\Windows\WER\ReportArchive"
         "IISTemp" = "$env:SystemRoot\inetpub\temp"
         "IISLogs" = "$env:SystemRoot\inetpub\logs"
         "DefenderTemp" = "$env:ProgramData\Microsoft\Windows Defender\Scans\History\Service"
         "SearchIndex" = "$env:ProgramData\Microsoft\Search\Data"
         "ASPNETTemp" = "$env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319\Temporary ASP.NET Files"
         "ChromeCache" = "$env:LocalAppData\Google\Chrome\User Data\Default\Cache"
         "EdgeCache" = "$env:LocalAppData\Microsoft\Edge\User Data\Default\Cache"
         # In-depth Windows OS cleaning
         "WindowsLogs" = "$env:SystemRoot\Logs"
         "CBSLogs" = "$env:SystemRoot\Logs\CBS"
         "DISMLogs" = "$env:SystemRoot\Logs\DISM"
         "SetupLogs" = "$env:SystemRoot\Panther"
         "WERQueue" = "$env:ProgramData\Microsoft\Windows\WER\ReportQueue"
         "WERArchive" = "$env:ProgramData\Microsoft\Windows\WER\ReportArchive"
         "DeliveryOpt" = "$env:SystemRoot\SoftwareDistribution\DeliveryOptimization"
         "InstallerCache" = "$env:SystemRoot\Installer"
         "DriverCache" = "$env:SystemRoot\System32\DriverStore\FileRepository"
         "FontCacheExt" = "$env:LocalAppData\FontCache"
         "OneDriveCache" = "$env:LocalAppData\Microsoft\OneDrive\setup\logs"
         "OfficeCache" = "$env:LocalAppData\Microsoft\Office\16.0\Wef"
         "SpoolerTemp" = "$env:SystemRoot\System32\spool\PRINTERS"
         "RecentDocs" = "$env:AppData\Microsoft\Windows\Recent"
         "JumpLists" = "$env:AppData\Microsoft\Windows\Recent\AutomaticDestinations"
         "ThumbnailDB" = "$env:LocalAppData\Microsoft\Windows\Explorer\thumbcache_*.db"
     }
    
if ($Category -eq "RecycleBin") {
         if ($TestMode) {
             $result.Freed = Get-RecycleBinSize
             Log-Info "Test Mode: Would clear Recycle Bin ($($result.Freed) MB)" -Category "Cleaning"
         } else {
             try {
                 $result.Freed = Get-RecycleBinSize
                 # Try multiple methods to clear recycle bin
                 $success = $false
                 
                 # Method 1: Using Shell.Application COM object (most compatible)
                 try {
                     $shell = New-Object -ComObject Shell.Application
                     $recycleBin = $shell.NameSpace(0xa)
                     $recycleBin.Items() | ForEach-Object { $_.InvokeVerb("delete") }
                     $success = $true
                     Log-Success "Cleared Recycle Bin ($($result.Freed) MB) via Shell.Application" -Category "Cleaning"
                 } catch {
                     # Method 2: Using PowerShell cmdlet if available
                     try {
                         Clear-RecycleBin -Force -ErrorAction Stop
                         $success = $true
                         Log-Success "Cleared Recycle Bin ($($result.Freed) MB) via Clear-RecycleBin" -Category "Cleaning"
                     } catch {
                         # Method 3: Using rd /s /q on the recycle bin directories
                         try {
                             $recyclePaths = @("$env:SystemRoot\$Recycle.Bin", 
                                             "$env:SystemRoot\Recycler",
                                             "$env:SystemRoot\Recycled")
                             foreach ($path in $recyclePaths) {
                                 if (Test-Path $path) {
                                     rd /s /q "$path" 2>$null
                                 }
                             }
                             $success = $true
                             Log-Success "Cleared Recycle Bin ($($result.Freed) MB) via direct deletion" -Category "Cleaning"
                         } catch {
                             $result.Success = $false
                             $result.Error = "All methods failed to clear Recycle Bin: $($_.Exception.Message)"
                             Log-Error "Failed to clear Recycle Bin: All methods failed" -Category "Cleaning"
                         }
                     }
                 }
                 
                 if (-not $success) {
                     $result.Success = $false
                     $result.Error = "Failed to clear Recycle Bin"
                     Log-Error "Failed to clear Recycle Bin: All methods failed" -Category "Cleaning"
                 }
             } catch {
                 $result.Success = $false
                 $result.Error = $_.Exception.Message
                 Log-Error "Failed to clear Recycle Bin: $($_.Exception.Message)" -Category "Cleaning"
             }
         }
         return $result
     }
    
    if ($paths.ContainsKey($Category)) {
        $path = $paths[$Category]
        
        if (-not (Test-Path $path -ErrorAction SilentlyContinue)) {
            $result.Success = $false
            $result.Error = "Path not found"
            return $result
        }
        
        if ($TestMode) {
            $result.Freed = Get-FolderSize -Path $path
            Log-Info "Test Mode: Would clean $Category ($($result.Freed) MB)" -Category "Cleaning"
        } else {
            try {
                $result.Freed = Get-FolderSize -Path $path
                $files = Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                $result.FilesDeleted = @($files).Count
                
                Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
                
                Log-Success "Cleaned $Category ($($result.Freed) MB, $($result.FilesDeleted) files)" -Category "Cleaning"
            } catch {
                $result.Success = $false
                $result.Error = $_.Exception.Message
                Log-Error "Failed to clean ${Category}: $($_.Exception.Message)" -Category "Cleaning"
            }
        }
    }
    
    return $result
}

function global:Invoke-MasterClean {
    param([bool]$TestMode = $false)
    
    $categories = @(
        # Basic cleaning
        "UserTemp", "SystemTemp", "WUCache", "WULogs", "RecycleBin",
        "ThumbnailCache", "IconCache", "Prefetch", "DNSCache",
        "FontCache", "CrashDumps", "ErrorReporting", "IISTemp",
        "IISLogs", "DefenderTemp", "SearchIndex", "ASPNETTemp",
        "ChromeCache", "EdgeCache", "FirefoxCache",
        # In-depth Windows OS cleaning
        "WindowsLogs", "CBSLogs", "DISMLogs", "SetupLogs",
        "WERQueue", "WERArchive", "DeliveryOpt",
        "FontCacheExt", "OneDriveCache", "OfficeCache",
        "SpoolerTemp", "RecentDocs", "JumpLists", "ThumbnailDB"
    )
    
    return Invoke-Cleaning -Categories $categories -TestMode $TestMode
}

function global:Invoke-DeepClean {
    param([bool]$TestMode = $false)
    
    $results = @{
        Actions = @()
        SpaceRecovered = 0
        Success = $true
    }
    
    # Run master clean first
    $masterResult = Invoke-MasterClean -TestMode $TestMode
    $results.SpaceRecovered += $masterResult.TotalFreed
    
    # Additional deep clean operations
    if (-not $TestMode) {
        # Windows Error Reporting dumps
        try {
            $werPath = "$env:ProgramData\Microsoft\Windows\WER\ReportQueue"
            if (Test-Path $werPath -ErrorAction SilentlyContinue) {
                $size = Get-FolderSize -Path $werPath
                Remove-Item -Path "$werPath\*" -Recurse -Force -ErrorAction SilentlyContinue
                $results.SpaceRecovered += $size
                $results.Actions += "Cleared WER ReportQueue ($size MB)"
            }
        } catch { }
        
        # Delivery Optimization cache
        try {
            $doPath = "$env:SystemRoot\SoftwareDistribution\DeliveryOptimization"
            if (Test-Path $doPath -ErrorAction SilentlyContinue) {
                $size = Get-FolderSize -Path $doPath
                Remove-Item -Path "$doPath\*" -Recurse -Force -ErrorAction SilentlyContinue
                $results.SpaceRecovered += $size
                $results.Actions += "Cleared Delivery Optimization ($size MB)"
            }
        } catch { }
        
        # Windows.old folder
        try {
            $oldPath = "$env:SystemDrive\Windows.old"
            if (Test-Path $oldPath -ErrorAction SilentlyContinue) {
                $size = Get-FolderSize -Path $oldPath
                takeown /F $oldPath /R /D Y 2>$null | Out-Null
                icacls $oldPath /grant administrators:F /T 2>$null | Out-Null
                Remove-Item -Path $oldPath -Recurse -Force -ErrorAction SilentlyContinue
                $results.SpaceRecovered += $size
                $results.Actions += "Removed Windows.old ($size MB)"
            }
        } catch { }
        
        # Old Windows Update downloads
        try {
            $wuPath = "$env:SystemRoot\SoftwareDistribution\Download"
            if (Test-Path $wuPath -ErrorAction SilentlyContinue) {
                net stop wuauserv 2>$null | Out-Null
                $size = Get-FolderSize -Path $wuPath
                Remove-Item -Path "$wuPath\*" -Recurse -Force -ErrorAction SilentlyContinue
                net start wuauserv 2>$null | Out-Null
                $results.SpaceRecovered += $size
                $results.Actions += "Cleared Windows Update cache ($size MB)"
            }
        } catch { }
        
        # System log files older than 7 days
        try {
            $logPath = "$env:SystemRoot\Logs"
            $oldLogs = Get-ChildItem -Path $logPath -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) }
            $logSize = ($oldLogs | Measure-Object -Property Length -Sum).Sum
            $oldLogs | Remove-Item -Force -ErrorAction SilentlyContinue
            $results.SpaceRecovered += [math]::Round($logSize / 1MB, 2)
            $results.Actions += "Removed old log files ($([math]::Round($logSize/1MB,2)) MB)"
        } catch { }
        
        # Thumbnail cache (Windows 10/11)
        try {
            $thumbPath = "$env:LocalAppData\Microsoft\Windows\Explorer"
            $thumbFiles = Get-ChildItem -Path $thumbPath -Filter "thumbcache_*.db" -ErrorAction SilentlyContinue
            $thumbSize = ($thumbFiles | Measure-Object -Property Length -Sum).Sum
            $thumbFiles | Remove-Item -Force -ErrorAction SilentlyContinue
            $results.SpaceRecovered += [math]::Round($thumbSize / 1MB, 2)
            $results.Actions += "Cleared thumbnail cache ($([math]::Round($thumbSize/1MB,2)) MB)"
        } catch { }
        
        # Windows Search index (if large)
        try {
            $searchPath = "$env:ProgramData\Microsoft\Search\Data\Applications\Windows\Windows.edb"
            if (Test-Path $searchPath -ErrorAction SilentlyContinue) {
                $searchSize = (Get-Item $searchPath -ErrorAction SilentlyContinue).Length
                if ($searchSize -gt 100MB) {
                    net stop WSearch 2>$null | Out-Null
                    Remove-Item -Path $searchPath -Force -ErrorAction SilentlyContinue
                    net start WSearch 2>$null | Out-Null
                    $results.SpaceRecovered += [math]::Round($searchSize / 1MB, 2)
                    $results.Actions += "Cleared search index ($([math]::Round($searchSize/1MB,2)) MB)"
                }
            }
        } catch { }
    }
    
    return $results
}

function global:Invoke-FullClean {
    param([bool]$TestMode = $false)
    
    $results = @{
        Operations = @()
        TotalSpaceRecovered = 0
        Success = $true
    }
    
    # Phase 1: Basic clean
    Write-Progress -Activity "Full Clean" -Status "Basic cleaning..." -PercentComplete 10
    $basicResult = Invoke-MasterClean -TestMode $TestMode
    $results.TotalSpaceRecovered += $basicResult.TotalFreed
    $results.Operations += "Basic clean: $(Format-FileSize $basicResult.TotalFreed)"
    
    # Phase 2: Deep clean
    Write-Progress -Activity "Full Clean" -Status "Deep cleaning..." -PercentComplete 30
    $deepResult = Invoke-DeepClean -TestMode $TestMode
    $results.TotalSpaceRecovered += $deepResult.SpaceRecovered
    $results.Operations += "Deep clean: $(Format-FileSize $deepResult.SpaceRecovered)"
    
    # Phase 3: Browser clean
    Write-Progress -Activity "Full Clean" -Status "Browser cleaning..." -PercentComplete 50
    $browserResult = Invoke-BrowserClean -TestMode $TestMode
    $results.TotalSpaceRecovered += $browserResult.SpaceRecovered
    $results.Operations += "Browser clean: $(Format-FileSize $browserResult.SpaceRecovered)"
    
    # Phase 4: Registry clean
    Write-Progress -Activity "Full Clean" -Status "Registry cleanup..." -PercentComplete 70
    $regResult = Invoke-RegistryClean -TestMode $TestMode
    $results.TotalSpaceRecovered += $regResult.SpaceRecovered
    $results.Operations += "Registry clean: $(Format-FileSize $regResult.SpaceRecovered)"
    
    # Phase 5: Log clean
    Write-Progress -Activity "Full Clean" -Status "Log cleanup..." -PercentComplete 90
    $logResult = Invoke-LogClean -TestMode $TestMode
    $results.TotalSpaceRecovered += $logResult.SpaceRecovered
    $results.Operations += "Log clean: $(Format-FileSize $logResult.SpaceRecovered)"
    
    Write-Progress -Activity "Full Clean" -Completed
    
    return $results
}

function global:Invoke-BrowserClean {
    param([bool]$TestMode = $false)
    $results = @{ SpaceRecovered = 0; Actions = @() }
    if ($TestMode) { return $results }
    try {
        # Chrome
        $chromePath = "$env:LocalAppData\Google\Chrome\User Data\Default"
        if (Test-Path $chromePath -ErrorAction SilentlyContinue) {
            @("Cache","Code Cache","GPUCache","Service Worker") | ForEach-Object {
                $p = Join-Path $chromePath $_
                if (Test-Path $p -ErrorAction SilentlyContinue) {
                    $size = Get-FolderSize -Path $p
                    Remove-Item -Path "$p\*" -Recurse -Force -ErrorAction SilentlyContinue
                    $results.SpaceRecovered += $size
                }
            }
            $results.Actions += "Chrome cache cleared"
        }
        # Firefox
        $ffPath = "$env:AppData\Mozilla\Firefox\Profiles"
        if (Test-Path $ffPath -ErrorAction SilentlyContinue) {
            Get-ChildItem $ffPath -Directory | ForEach-Object {
                @("cache2","thumbnails") | ForEach-Object {
                    $p = Join-Path $_.FullName $_
                    if (Test-Path $p -ErrorAction SilentlyContinue) {
                        $size = Get-FolderSize -Path $p
                        Remove-Item -Path "$p\*" -Recurse -Force -ErrorAction SilentlyContinue
                        $results.SpaceRecovered += $size
                    }
                }
            }
            $results.Actions += "Firefox cache cleared"
        }
        # Edge
        $edgePath = "$env:LocalAppData\Microsoft\Edge\User Data\Default"
        if (Test-Path $edgePath -ErrorAction SilentlyContinue) {
            @("Cache","Code Cache","GPUCache") | ForEach-Object {
                $p = Join-Path $edgePath $_
                if (Test-Path $p -ErrorAction SilentlyContinue) {
                    $size = Get-FolderSize -Path $p
                    Remove-Item -Path "$p\*" -Recurse -Force -ErrorAction SilentlyContinue
                    $results.SpaceRecovered += $size
                }
            }
            $results.Actions += "Edge cache cleared"
        }
    } catch { }
    return $results
}

function global:Invoke-RegistryClean {
    param([bool]$TestMode = $false)
    $results = @{ SpaceRecovered = 0; Actions = @() }
    if ($TestMode) { return $results }
    try {
        # Clean MRU lists
        $mruPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU"
        if (Test-Path $mruPath -ErrorAction SilentlyContinue) {
            Remove-Item -Path $mruPath -Recurse -Force -ErrorAction SilentlyContinue
            $results.Actions += "Cleared Run MRU list"
        }
        # Clean recent documents
        $recentPath = "$env:AppData\Microsoft\Windows\Recent"
        if (Test-Path $recentPath -ErrorAction SilentlyContinue) {
            $size = Get-FolderSize -Path $recentPath
            Remove-Item -Path "$recentPath\*" -Force -ErrorAction SilentlyContinue
            $results.SpaceRecovered += $size
            $results.Actions += "Cleared recent documents"
        }
    } catch { }
    return $results
}

function global:Invoke-LogClean {
    param([bool]$TestMode = $false)
    $results = @{ SpaceRecovered = 0; Actions = @() }
    if ($TestMode) { return $results }
    try {
        # Windows Event Logs
        wevtutil el 2>$null | ForEach-Object { wevtutil cl "$_" 2>$null }
        $results.Actions += "Cleared event logs"
        # CBS logs
        $cbsPath = "$env:SystemRoot\Logs\CBS"
        if (Test-Path $cbsPath -ErrorAction SilentlyContinue) {
            $size = Get-FolderSize -Path $cbsPath
            Remove-Item -Path "$cbsPath\*" -Force -ErrorAction SilentlyContinue
            $results.SpaceRecovered += $size
            $results.Actions += "Cleared CBS logs"
        }
        # DISM logs
        $dismPath = "$env:SystemRoot\Logs\DISM"
        if (Test-Path $dismPath -ErrorAction SilentlyContinue) {
            $size = Get-FolderSize -Path $dismPath
            Remove-Item -Path "$dismPath\*" -Force -ErrorAction SilentlyContinue
            $results.SpaceRecovered += $size
            $results.Actions += "Cleared DISM logs"
        }
    } catch { }
    return $results
}

# ============================================================================
# DEDICATED CLEANING TOOLS
# ============================================================================

function global:Invoke-WindowsCleaner {
    param([bool]$TestMode = $false)
    
    $results = @{
        Actions = @()
        SpaceRecovered = 0
        Success = $true
    }
    
    if ($TestMode) {
        $results.Actions += "[Preview] Would run Windows Cleaner"
        return $results
    }
    
    Write-Log -Level "INFO" -Category "Cleaning" -Message "Running Windows Cleaner..."
    
    # 1. Cleanmgr with sagerun
    $results.SpaceRecovered += (Invoke-Cleanmgr -TestMode $TestMode).SpaceRecovered
    $results.Actions += "Ran Cleanmgr"
    
    # 2. Clean temp
    $results.SpaceRecovered += (Invoke-CleanTemp -TestMode $TestMode).SpaceRecovered
    $results.Actions += "Cleaned temp files"
    
    # 3. Clean update cache
    $results.SpaceRecovered += (Invoke-CleanUpdateCache -TestMode $TestMode).SpaceRecovered
    $results.Actions += "Cleaned update cache"
    
    # 4. Clean recent
    $results.SpaceRecovered += (Invoke-CleanRecent -TestMode $TestMode).SpaceRecovered
    $results.Actions += "Cleaned recent items"
    
    # 5. Clean prefetch
    $results.SpaceRecovered += (Invoke-CleanPrefetch -TestMode $TestMode).SpaceRecovered
    $results.Actions += "Cleaned prefetch"
    
    Write-Log -Level "SUCCESS" -Category "Cleaning" -Message "Windows Cleaner complete: $(Format-FileSize $results.SpaceRecovered)"
    return $results
}

function global:Invoke-Cleanmgr {
    param([bool]$TestMode = $false)
    
    $results = @{
        Actions = @()
        SpaceRecovered = 0
        Success = $true
    }
    
    if ($TestMode) {
        $results.Actions += "[Preview] Would run Cleanmgr"
        return $results
    }
    
    # Set cleanmgr sagerun flags
    $sageKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
    $cleanFlags = @(
        "Active Setup Temp Folders",
        "BranchCache",
        "D3D Shader Cache",
        "Delivery Optimization Files",
        "Device Driver Packages",
        "Downloaded Program Files",
        "Internet Cache Files",
        "Old ChkDsk Files",
        "Previous Installations",
        "Recycle Bin",
        "Setup Log Files",
        "System error memory dump files",
        "System error minidump files",
        "Temporary Files",
        "Temporary Setup Files",
        "Thumbnail Cache",
        "Update Cleanup",
        "Upgrade Discarded Files",
        "User file versions",
        "Windows Defender",
        "Windows Error Reporting Files",
        "Windows ESD installation files",
        "Windows Upgrade Log Files"
    )
    
    foreach ($flag in $cleanFlags) {
        $path = Join-Path $sageKey $flag
        if (Test-Path $path -ErrorAction SilentlyContinue) {
            try {
                Set-ItemProperty -Path $path -Name "StateFlags0100" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
            } catch { }
        }
    }
    
    # Run cleanmgr
    try {
        $proc = Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:100" -Wait -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue
        if ($proc.ExitCode -eq 0) {
            $results.Actions += "Cleanmgr completed"
        }
    } catch { }
    
    Write-Log -Level "SUCCESS" -Category "Cleaning" -Message "Cleanmgr completed"
    return $results
}

function global:Invoke-CleanTemp {
    param([bool]$TestMode = $false)
    
    $results = @{
        Actions = @()
        SpaceRecovered = 0
        Success = $true
    }
    
    if ($TestMode) {
        $results.Actions += "[Preview] Would clean temp files"
        return $results
    }
    
    $tempPaths = @(
        $env:TEMP,
        "$env:SystemRoot\Temp",
        "$env:SystemRoot\Prefetch",
        "$env:LocalAppData\Microsoft\Windows\INetCache",
        "$env:LocalAppData\Microsoft\Windows\INetCookies",
        "$env:LocalAppData\Microsoft\Windows\Temporary Internet Files",
        "$env:LocalAppData\Microsoft\Windows\WebCache",
        "$env:LocalAppData\Microsoft\Windows\WER",
        "$env:LocalAppData\Microsoft\Windows\History",
        "$env:LocalAppData\Temp"
    )
    
    foreach ($path in $tempPaths) {
        if (Test-Path $path -ErrorAction SilentlyContinue) {
            try {
                $size = Get-FolderSize -Path $path
                Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
                $results.SpaceRecovered += $size
                $results.Actions += "Cleaned $(Split-Path $path -Leaf)"
            } catch { }
        }
    }
    
    Write-Log -Level "SUCCESS" -Category "Cleaning" -Message "Cleaned temp: $(Format-FileSize $results.SpaceRecovered)"
    return $results
}

function global:Invoke-CleanUpdateCache {
    param([bool]$TestMode = $false)
    
    $results = @{
        Actions = @()
        SpaceRecovered = 0
        Success = $true
    }
    
    if ($TestMode) {
        $results.Actions += "[Preview] Would clean update cache"
        return $results
    }
    
    $updatePaths = @(
        "$env:SystemRoot\SoftwareDistribution\Download",
        "$env:SystemRoot\SoftwareDistribution\DataStore",
        "$env:SystemRoot\SoftwareDistribution\PostRebootEventCache",
        "$env:SystemRoot\SoftwareDistribution\SLS",
        "$env:SystemRoot\SoftwareDistribution\AuthCabs",
        "$env:SystemRoot\System32\catroot2"
    )
    
    # Stop services first
    try {
        Stop-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue
        Stop-Service -Name "bits" -Force -ErrorAction SilentlyContinue
        Stop-Service -Name "cryptsvc" -Force -ErrorAction SilentlyContinue
        $results.Actions += "Stopped update services"
    } catch { }
    
    foreach ($path in $updatePaths) {
        if (Test-Path $path -ErrorAction SilentlyContinue) {
            try {
                $size = Get-FolderSize -Path $path
                Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
                $results.SpaceRecovered += $size
                $results.Actions += "Cleaned $(Split-Path $path -Leaf)"
            } catch { }
        }
    }
    
    # Restart services
    try {
        Start-Service -Name "cryptsvc" -ErrorAction SilentlyContinue
        Start-Service -Name "bits" -ErrorAction SilentlyContinue
        Start-Service -Name "wuauserv" -ErrorAction SilentlyContinue
        $results.Actions += "Restarted update services"
    } catch { }
    
    Write-Log -Level "SUCCESS" -Category "Cleaning" -Message "Update cache cleaned: $(Format-FileSize $results.SpaceRecovered)"
    return $results
}

function global:Invoke-CleanRecent {
    param([bool]$TestMode = $false)
    
    $results = @{
        Actions = @()
        SpaceRecovered = 0
        Success = $true
    }
    
    if ($TestMode) {
        $results.Actions += "[Preview] Would clean recent items"
        return $results
    }
    
    $recentPaths = @(
        "$env:AppData\Microsoft\Windows\Recent",
        "$env:AppData\Microsoft\Windows\Recent\AutomaticDestinations",
        "$env:AppData\Microsoft\Windows\Recent\CustomDestinations"
    )
    
    foreach ($path in $recentPaths) {
        if (Test-Path $path -ErrorAction SilentlyContinue) {
            try {
                $size = Get-FolderSize -Path $path
                Remove-Item -Path "$path\*" -Force -ErrorAction SilentlyContinue
                $results.SpaceRecovered += $size
                $results.Actions += "Cleaned $(Split-Path $path -Leaf)"
            } catch { }
        }
    }
    
    # Clear run MRU
    try {
        $runPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU"
        if (Test-Path $runPath -ErrorAction SilentlyContinue) {
            Remove-Item -Path $runPath -Recurse -Force -ErrorAction SilentlyContinue
            $results.Actions += "Cleared Run MRU history"
        }
    } catch { }
    
    # Clear typed paths
    try {
        $typedPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths"
        if (Test-Path $typedPath -ErrorAction SilentlyContinue) {
            Remove-Item -Path $typedPath -Recurse -Force -ErrorAction SilentlyContinue
            $results.Actions += "Cleared typed paths"
        }
    } catch { }
    
    Write-Log -Level "SUCCESS" -Category "Cleaning" -Message "Recent items cleaned: $(Format-FileSize $results.SpaceRecovered)"
    return $results
}

function global:Invoke-CleanPrefetch {
    param([bool]$TestMode = $false)
    
    $results = @{
        Actions = @()
        SpaceRecovered = 0
        Success = $true
    }
    
    if ($TestMode) {
        $results.Actions += "[Preview] Would clean prefetch"
        return $results
    }
    
    $prefetchPaths = @(
        "$env:SystemRoot\Prefetch",
        "$env:SystemRoot\Prefetch\Layout.ini"
    )
    
    foreach ($path in $prefetchPaths) {
        if (Test-Path $path -ErrorAction SilentlyContinue) {
            try {
                if ((Get-Item $path -ErrorAction SilentlyContinue).PSIsContainer) {
                    $size = Get-FolderSize -Path $path
                    Remove-Item -Path "$path\*" -Force -ErrorAction SilentlyContinue
                    $results.SpaceRecovered += $size
                    $results.Actions += "Cleaned prefetch files"
                } else {
                    $size = (Get-Item $path -ErrorAction SilentlyContinue).Length
                    Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
                    $results.SpaceRecovered += [math]::Round($size / 1MB, 2)
                    $results.Actions += "Removed layout.ini"
                }
            } catch { }
        }
    }
    
    Write-Log -Level "SUCCESS" -Category "Cleaning" -Message "Prefetch cleaned: $(Format-FileSize $results.SpaceRecovered)"
    return $results
}

# Export functions
