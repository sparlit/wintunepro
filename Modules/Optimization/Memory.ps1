<#
.SYNOPSIS
    WinTune Pro Memory Module - Memory optimization operations
.DESCRIPTION
    Memory management, working set optimization, and paging file configuration
#>

# ============================================================================
# MEMORY INFORMATION
# ============================================================================


function global:Get-MemoryInfo {
    <#
    .SYNOPSIS
        Gets detailed memory information.
    #>
    
    $os = Get-CachedCimInstance "Win32_OperatingSystem"
    $cs = Get-CachedCimInstance "Win32_ComputerSystem"
    
    $totalPhysical = $os.TotalVisibleMemorySize * 1KB
    $freePhysical = $os.FreePhysicalMemory * 1KB
    $totalVirtual = $os.TotalVirtualMemorySize * 1KB
    $freeVirtual = $os.FreeVirtualMemory * 1KB
    
    $memoryInfo = @{
        # Physical Memory
        TotalPhysical = $totalPhysical
        FreePhysical = $freePhysical
        UsedPhysical = $totalPhysical - $freePhysical
        PhysicalUsagePercent = if ($totalPhysical -gt 0) { [math]::Round((($totalPhysical - $freePhysical) / $totalPhysical) * 100, 2) } else { 0 }
        
        # Virtual Memory
        TotalVirtual = $totalVirtual
        FreeVirtual = $freeVirtual
        UsedVirtual = $totalVirtual - $freeVirtual
        VirtualUsagePercent = if ($totalVirtual -gt 0) { [math]::Round((($totalVirtual - $freeVirtual) / $totalVirtual) * 100, 2) } else { 0 }
        
        # Paging File
        PageSize = $cs.TotalPhysicalMemory
        
        # Formatted values
        TotalPhysicalFormatted = Format-FileSize $totalPhysical
        FreePhysicalFormatted = Format-FileSize $freePhysical
        UsedPhysicalFormatted = Format-FileSize ($totalPhysical - $freePhysical)
        TotalVirtualFormatted = Format-FileSize $totalVirtual
        FreeVirtualFormatted = Format-FileSize $freeVirtual
        
        # System info
        InstalledRAM = $cs.TotalPhysicalMemory
        InstalledRAMFormatted = Format-FileSize $cs.TotalPhysicalMemory
    }
    
    # Get page file info
    try {
        $pageFile = Get-CachedCimInstance "Win32_PageFileUsage"
        if ($pageFile) {
            $memoryInfo.PageFileSize = $pageFile.AllocatedBaseSize * 1MB
            $memoryInfo.PageFileUsage = $pageFile.CurrentUsage * 1MB
            $memoryInfo.PageFilePeak = $pageFile.PeakUsage * 1MB
            $memoryInfo.PageFileSizeFormatted = Format-FileSize ($pageFile.AllocatedBaseSize * 1MB)
            $memoryInfo.PageFileUsageFormatted = Format-FileSize ($pageFile.CurrentUsage * 1MB)
        }
    } catch { Write-Log -Level "WARNING" -Category "Memory" -Message $_.Exception.Message }

    return $memoryInfo
}

function global:Get-PagingFileInfo {
    <#
    .SYNOPSIS
        Gets detailed paging file information.
    #>
    
    $pageFileInfo = @{
        AutomaticManaged = $false
        Files = @()
        TotalSize = 0
        TotalUsage = 0
        RecommendedSize = 0
    }
    
    try {
        # Check if automatically managed
        $computerSystem = Get-CachedCimInstance "Win32_ComputerSystem"
        $pageFileInfo.AutomaticManaged = $computerSystem.AutomaticManagedPagefile
        
        # Get page file settings
        $pageFileSettings = Get-CachedCimInstance "Win32_PageFileSetting"
        
        # Get page file usage
        $pageFileUsage = Get-CachedCimInstance "Win32_PageFileUsage"
        
        if ($pageFileUsage) {
            foreach ($pf in $pageFileUsage) {
                $pageFileInfo.Files += @{
                    Name = $pf.Name
                    AllocatedSize = $pf.AllocatedBaseSize * 1MB
                    CurrentUsage = $pf.CurrentUsage * 1MB
                    PeakUsage = $pf.PeakUsage * 1MB
                    AllocatedSizeFormatted = Format-FileSize ($pf.AllocatedBaseSize * 1MB)
                    CurrentUsageFormatted = Format-FileSize ($pf.CurrentUsage * 1MB)
                }
                $pageFileInfo.TotalSize += $pf.AllocatedBaseSize * 1MB
                $pageFileInfo.TotalUsage += $pf.CurrentUsage * 1MB
            }
        }
        
        # Calculate recommended size (1.5x RAM for systems < 16GB, 1x for >= 16GB)
        $totalRAM = (Get-CachedCimInstance "Win32_ComputerSystem").TotalPhysicalMemory
        if ($totalRAM -lt 16GB) {
            $pageFileInfo.RecommendedSize = $totalRAM * 1.5
        } else {
            $pageFileInfo.RecommendedSize = $totalRAM
        }
        $pageFileInfo.RecommendedSizeFormatted = Format-FileSize $pageFileInfo.RecommendedSize
        
    } catch {
        Write-Log -Level "DEBUG" -Category "Memory" -Message "Error getting page file info: $($_.Exception.Message)"
    }
    
    return $pageFileInfo
}

# ============================================================================
# MEMORY OPTIMIZATION
# ============================================================================



function global:Optimize-Memory {
    <#
    .SYNOPSIS
        Optimizes system memory by clearing working sets.
    #>
    param(
        [switch]$ClearStandbyList,
        [switch]$ClearModifiedList,
        [switch]$Preview
    )
    
    $result = @{
        Success = $true
        MemoryBefore = $null
        MemoryAfter = $null
        MemoryRecovered = 0
        Message = ""
        Actions = @()
        Errors = @()
    }
    
    # Capture before state
    $result.MemoryBefore = Get-MemoryInfo
    
    if ($Preview) {
        $result.Message = "[PREVIEW] Would optimize memory"
        $result.Actions += "[PREVIEW] Would trigger garbage collection"
        $result.Actions += "[PREVIEW] Would clear standby list"
        return $result
    }
    
    Write-Log -Level "INFO" -Category "Memory" -Message "Starting memory optimization..."
    
    # Method 1: .NET Garbage Collection
    try {
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        [System.GC]::Collect()
        
        $result.Actions += "Executed .NET garbage collection"
        Write-Log -Level "DEBUG" -Category "Memory" -Message "Garbage collection completed"
    } catch {
        $result.Errors += "Garbage collection failed: $($_.Exception.Message)"
    }
    
    # Method 2: Empty Working Sets (requires admin)
    if ($script:State.IsElevated) {
        try {
            Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class MemoryManagement {
    [DllImport("psapi.dll")]
    public static extern bool EmptyWorkingSet(IntPtr hProcess);
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetCurrentProcess();
    public static void ClearWorkingSet() {
        EmptyWorkingSet(GetCurrentProcess());
    }
}
"@ -Language CSharp -ErrorAction SilentlyContinue
            [MemoryManagement]::ClearWorkingSet()
            $result.Actions += "Cleared current process working set"
        } catch {
            $result.Errors += "Working set clear failed: $($_.Exception.Message)"
        }
    }
    
    # Capture after state
    $result.MemoryAfter = Get-MemoryInfo
    $result.MemoryRecovered = $result.MemoryBefore.UsedPhysical - $result.MemoryAfter.UsedPhysical
    if ($result.MemoryRecovered -lt 0) { $result.MemoryRecovered = 0 }
    
    $result.Message = "Memory optimization complete. Recovered: $(Format-FileSize $result.MemoryRecovered)"
    Write-Log -Level "SUCCESS" -Category "Memory" -Message $result.Message
    
    return $result
}

function global:Optimize-PagingFile {
    <#
    .SYNOPSIS
        Optimizes paging file settings.
    #>
    param(
        [switch]$AutoManage,
        [switch]$Preview
    )
    
    $result = @{
        Success = $true
        Message = ""
        Actions = @()
        Errors = @()
    }
    
    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Message = "Administrator privileges required"
        return $result
    }
    
    if ($Preview) {
        $result.Message = "[PREVIEW] Would optimize paging file"
        return $result
    }
    
    Write-Log -Level "INFO" -Category "Memory" -Message "Optimizing paging file..."
    
    try {
        # Set to system managed
        $cs = Get-CachedCimInstance "Win32_ComputerSystem"
        if (-not $cs.AutomaticManagedPagefile) {
            $cs.AutomaticManagedPagefile = $true
            $cs | Set-CimInstance
            $result.Actions += "Enabled automatic page file management"
            Write-Log -Level "SUCCESS" -Category "Memory" -Message "Automatic page file management enabled"
        } else {
            $result.Actions += "Page file already system-managed"
        }
    } catch {
        $result.Success = $false
        $result.Errors += "Failed to optimize paging file: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "Memory" -Message "Paging file optimization failed: $($_.Exception.Message)"
    }
    
    return $result
}

function global:Get-MemoryRecommendations {
    <#
    .SYNOPSIS
        Gets memory optimization recommendations.
    #>
    
    $memInfo = Get-MemoryInfo
    $pageFileInfo = Get-PagingFileInfo
    
    $recommendations = @{
        MemoryUsagePercent = $memInfo.PhysicalUsagePercent
        PageFileUsagePercent = if ($pageFileInfo.TotalSize -gt 0) { [math]::Round(($pageFileInfo.TotalUsage / $pageFileInfo.TotalSize) * 100, 1) } else { 0 }
        Recommendations = @()
        Warnings = @()
        TopMemoryConsumers = @()
    }
    
    # Check memory usage
    if ($memInfo.PhysicalUsagePercent -gt 90) {
        $recommendations.Warnings += "Critical: Memory usage above 90%. System may become unstable."
        $recommendations.Recommendations += "Close unnecessary applications immediately"
    } elseif ($memInfo.PhysicalUsagePercent -gt 80) {
        $recommendations.Warnings += "High memory usage detected (above 80%)"
        $recommendations.Recommendations += "Consider closing unused applications"
    }
    
    # Check page file
    if ($recommendations.PageFileUsagePercent -gt 80) {
        $recommendations.Warnings += "Page file usage is high ($($recommendations.PageFileUsagePercent)%)"
        $recommendations.Recommendations += "Increase page file size or add more RAM"
    }
    
    # Check total RAM
    $totalRAM = $memInfo.InstalledRAM
    if ($totalRAM -lt 4GB) {
        $recommendations.Recommendations += "Consider upgrading RAM (currently $($memInfo.InstalledRAMFormatted))"
    }
    
    # Check automatic page file management
    if ($totalRAM -ge 16GB -and -not $pageFileInfo.AutomaticManaged) {
        $recommendations.Recommendations += "Enable automatic page file management for systems with 16GB+ RAM"
    }
    
    if ($totalRAM -ge 32GB) {
        $recommendations.Recommendations += "Consider DisablePagingExecutive setting for improved kernel performance"
    }
    
    # Top memory consumers
    if ($memInfo.TopProcesses) {
        $recommendations.TopMemoryConsumers = $memInfo.TopProcesses | Select-Object -First 5
    }
    
    return $recommendations
}

