<#
.SYNOPSIS
    WinTune Pro Services Module - Windows Service Optimization
.DESCRIPTION
    Safe Windows service optimization with backup and rollback
#>

# Safe-to-disable services configuration
$script:ServiceConfig = @(
    @{
        Name = "DiagTrack"
        DisplayName = "Connected User Experiences and Telemetry"
        Description = "Sends telemetry data to Microsoft"
        DefaultStartup = "Auto"
        RecommendedStartup = "Disabled"
        Risk = "Low"
        Category = "Privacy"
    },
    @{
        Name = "dmwappushservice"
        DisplayName = "WAP Push Message Routing Service"
        Description = "Used for MDM mobile device management"
        DefaultStartup = "Manual"
        RecommendedStartup = "Disabled"
        Risk = "Low"
        Category = "Privacy"
    },
    @{
        Name = "SysMain"
        DisplayName = "Superfetch / SysMain"
        Description = "Preloads applications. High disk I/O on HDD"
        DefaultStartup = "Auto"
        RecommendedStartup = "Disabled"
        Risk = "Low"
        Category = "Performance"
    },
    @{
        Name = "WSearch"
        DisplayName = "Windows Search"
        Description = "Indexing service. High disk/CPU usage"
        DefaultStartup = "Auto"
        RecommendedStartup = "Manual"
        Risk = "Medium"
        Category = "Performance"
    },
    @{
        Name = "XblAuthManager"
        DisplayName = "Xbox Live Auth Manager"
        Description = "Xbox authentication service"
        DefaultStartup = "Manual"
        RecommendedStartup = "Disabled"
        Risk = "Low"
        Category = "Gaming"
    },
    @{
        Name = "XblGameSave"
        DisplayName = "Xbox Live Game Save"
        Description = "Xbox cloud saves"
        DefaultStartup = "Manual"
        RecommendedStartup = "Disabled"
        Risk = "Low"
        Category = "Gaming"
    },
    @{
        Name = "XboxNetApiSvc"
        DisplayName = "Xbox Live Networking Service"
        Description = "Xbox networking"
        DefaultStartup = "Manual"
        RecommendedStartup = "Disabled"
        Risk = "Low"
        Category = "Gaming"
    },
    @{
        Name = "Fax"
        DisplayName = "Fax Service"
        Description = "Legacy fax support"
        DefaultStartup = "Manual"
        RecommendedStartup = "Disabled"
        Risk = "Low"
        Category = "Legacy"
    },
    @{
        Name = "RemoteRegistry"
        DisplayName = "Remote Registry"
        Description = "Security risk - allows remote registry access"
        DefaultStartup = "Manual"
        RecommendedStartup = "Disabled"
        Risk = "Low"
        Category = "Security"
    },
    @{
        Name = "TrkWks"
        DisplayName = "Distributed Link Tracking Client"
        Description = "Tracks shortcuts across network"
        DefaultStartup = "Auto"
        RecommendedStartup = "Manual"
        Risk = "Low"
        Category = "Network"
    },
    @{
        Name = "lfsvc"
        DisplayName = "Geolocation Service"
        Description = "Location services"
        DefaultStartup = "Manual"
        RecommendedStartup = "Disabled"
        Risk = "Low"
        Category = "Privacy"
    },
    @{
        Name = "MapsBroker"
        DisplayName = "Downloaded Maps Manager"
        Description = "Windows Maps service"
        DefaultStartup = "Auto"
        RecommendedStartup = "Disabled"
        Risk = "Low"
        Category = "Apps"
    },
    @{
        Name = "WerSvc"
        DisplayName = "Windows Error Reporting Service"
        Description = "Error reporting to Microsoft"
        DefaultStartup = "Manual"
        RecommendedStartup = "Disabled"
        Risk = "Low"
        Category = "Privacy"
    },
    @{
        Name = "PcaSvc"
        DisplayName = "Program Compatibility Assistant Service"
        Description = "Compatibility notifications"
        DefaultStartup = "Auto"
        RecommendedStartup = "Manual"
        Risk = "Low"
        Category = "System"
    }
)


function global:Get-OptimizableServices {
    <#
    .SYNOPSIS
        Returns list of services that can be optimized.
    #>
    param(
        [string]$Category,
        [string]$Risk
    )
    
    $services = @()
    
    foreach ($config in $script:ServiceConfig) {
        # Apply filters
        if ($Category -and $config.Category -ne $Category) { continue }
        if ($Risk -and $config.Risk -ne $Risk) { continue }
        
        # Check if service exists
        try {
            $service = Get-Service -Name $config.Name -ErrorAction SilentlyContinue
            if ($service) {
                $services += @{
                    Name = $config.Name
                    DisplayName = $config.DisplayName
                    Description = $config.Description
                    CurrentStatus = $service.Status
                    CurrentStartup = $service.StartType
                    RecommendedStartup = $config.RecommendedStartup
                    Risk = $config.Risk
                    Category = $config.Category
                }
            }
        } catch { Write-Log -Level "WARNING" -Category "System" -Message $_.Exception.Message }


function global:Optimize-Service {
    <#
    .SYNOPSIS
        Optimizes a single service with backup and rollback.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet("Auto","Manual","Disabled")]
        [string]$StartupType,
        
        [switch]$Preview,
        [switch]$Force
    )
    
    $result = @{
        Success = $true
        ServiceName = $Name
        PreviousStartupType = $null
        PreviousStatus = $null
        NewStartupType = $StartupType
        NewStatus = $null
        Message = ""
        Errors = @()
    }
    
    if (-not $script:State.IsElevated) {
        $result.Success = $false
        $result.Message = "Administrator privileges required"
        return $result
    }
    
    try {
        $service = Get-Service -Name $Name -ErrorAction Stop
        
        $result.PreviousStartupType = $service.StartType
        $result.PreviousStatus = $service.Status
        
        if ($Preview) {
            $result.Message = "[PREVIEW] Would change $Name from $($service.StartType) to $StartupType"
            return $result
        }
        
        # Register for rollback
        Register-ServiceChange -ServiceName $Name -PreviousStartupType $service.StartType -PreviousStatus $service.Status -NewStartupType $StartupType
        
        # Apply change
        Set-Service -Name $Name -StartupType $StartupType -ErrorAction Stop
        
        # Update status if disabling
        if ($StartupType -eq "Disabled" -and $service.Status -eq "Running") {
            Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
        }
        
        # Get new status
        $service = Get-Service -Name $Name
        $result.NewStatus = $service.Status
        
        $result.Message = "Service $Name changed from $($result.PreviousStartupType) to $StartupType"
        Write-Log -Level "SUCCESS" -Category "Optimization" -Message $result.Message
        
        # Track in state - null-safe
        if ($script:State) {
            if (-not $script:State.ServicesModified) {
                $script:State.ServicesModified = @()
            }
            $script:State.ServicesModified += $Name
        }
        
        Write-OperationLog -Operation "Optimize-Service" -Target $Name -Result "Success" -Details @{ Previous = $result.PreviousStartupType; New = $StartupType }
        
    } catch {
        $result.Success = $false
        $result.Message = $_.Exception.Message
        $result.Errors += $_.Exception.Message
        Write-Log -Level "ERROR" -Category "Optimization" -Message "Failed to optimize service $Name : $($_.Exception.Message)"
    }
    
    return $result
}



function global:Invoke-ServiceOptimization {
    <#
    .SYNOPSIS
        Optimizes multiple services based on configuration.
    #>
    param(
        [string[]]$Categories = @("Privacy", "Performance", "Gaming", "Legacy", "Security"),
        [string]$MaxRisk = "Medium",
        [switch]$Preview,
        [switch]$Force
    )
    
    $results = @{
        Success = $true
        ServicesOptimized = 0
        ServicesSkipped = 0
        Results = @()
        Errors = @()
    }
    
    Write-Log -Level "INFO" -Category "Optimization" -Message "Starting service optimization..."
    
    # Get services to optimize
    $services = Get-OptimizableServices | Where-Object { $_.Category -in $Categories }
    
    foreach ($svc in $services) {
        # Skip if already in desired state
        if ($svc.CurrentStartup -eq $svc.RecommendedStartup) {
            $results.ServicesSkipped++
            continue
        }
        
        $result = Optimize-Service -Name $svc.Name -StartupType $svc.RecommendedStartup -Preview:$Preview -Force:$Force
        $results.Results += $result
        
        if ($result.Success) {
            $results.ServicesOptimized++
        } else {
            $results.Errors += $result.Message
        }
    }
    
    Write-Log -Level "SUCCESS" -Category "Optimization" -Message "Service optimization complete: $($results.ServicesOptimized) optimized, $($results.ServicesSkipped) already optimal"
    
    return $results
}



function global:Restore-ServiceDefaults {
    <#
    .SYNOPSIS
        Restores all modified services to their default states.
    #>
    param([switch]$Preview)
    
    $results = @{
        Success = $true
        ServicesRestored = 0
        Results = @()
    }
    
    foreach ($config in $script:ServiceConfig) {
        try {
            $service = Get-Service -Name $config.Name -ErrorAction SilentlyContinue
            if ($service -and $service.StartType -ne $config.DefaultStartup) {
                if (-not $Preview) {
                    Set-Service -Name $config.Name -StartupType $config.DefaultStartup -ErrorAction SilentlyContinue
                }
                $results.ServicesRestored++
                $results.Results += @{ Name = $config.Name; RestoredTo = $config.DefaultStartup }
            }
        } catch { Write-Log -Level "WARNING" -Category "System" -Message $_.Exception.Message }
    }
    
    Write-Log -Level "SUCCESS" -Category "Optimization" -Message "Restored $($results.ServicesRestored) services to defaults"
    
    return $results
}
    }
    
    return $services
}
