<#
.SYNOPSIS
    WinTune Pro Startup Module - Startup program management
.DESCRIPTION
    Comprehensive startup program detection, analysis, and optimization
.NOTES
    File: Modules\OSOptimizer\Startup.ps1
    Version: 1.0.1
    PowerShell: 5.1+
    Compatible: Windows 10, Windows 11
#>

# ============================================================================
# STARTUP DETECTION
# ============================================================================


function global:Get-StartupItems {
    <#
    .SYNOPSIS
        Gets all startup items from all locations.
    #>
    param(
        [switch]$IncludeDisabled,
        [switch]$IncludeSystem
    )
    
    $startupItems = @()
    
    # 1. Registry - Current User Run
    $startupItems += Get-RegistryStartupItems -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Location "HKCU_Run" -Scope "User"
    
    # 2. Registry - Local Machine Run
    $startupItems += Get-RegistryStartupItems -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" -Location "HKLM_Run" -Scope "System"
    
    # 3. Registry - Current User RunOnce
    $startupItems += Get-RegistryStartupItems -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Location "HKCU_RunOnce" -Scope "User"
    
    # 4. Registry - Local Machine RunOnce
    $startupItems += Get-RegistryStartupItems -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Location "HKLM_RunOnce" -Scope "System"
    
    # 5. Registry - Wow6432Node (32-bit apps on 64-bit Windows)
    $startupItems += Get-RegistryStartupItems -Path "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run" -Location "HKLM_Run_WOW64" -Scope "System"
    
    # 6. Startup Folders
    $startupItems += Get-FolderStartupItems -Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup" -Location "UserStartupFolder" -Scope "User"
    $startupItems += Get-FolderStartupItems -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup" -Location "CommonStartupFolder" -Scope "System"
    
    # 7. Task Scheduler
    $startupItems += Get-ScheduledTaskStartupItems
    
    # 8. Services set to Auto start
    if ($IncludeSystem) {
        $startupItems += Get-ServiceStartupItems
    }
    
    # Filter if not including disabled
    if (-not $IncludeDisabled) {
        $startupItems = $startupItems | Where-Object { $_.Enabled -eq $true }
    }
    
    return $startupItems | Sort-Object Name
}



function global:Get-RegistryStartupItems {
    <#
    .SYNOPSIS
        Gets startup items from a registry key.
    #>
    param(
        [string]$Path,
        [string]$Location,
        [string]$Scope
    )
    
    $items = @()
    
    if (-not (Test-Path $Path)) { return $items }
    
    try {
        $properties = Get-ItemProperty -Path $Path -ErrorAction Stop
        
        foreach ($prop in $properties.PSObject.Properties) {
            # Skip PowerShell system properties
            if ($prop.Name -in @('PSPath','PSParentPath','PSChildName','PSDrive','PSProvider')) { continue }
            
            $value = $prop.Value
            $isValid = Test-StartupTargetValid -Command $value
            
            $items += [PSCustomObject]@{
                Name = $prop.Name
                Command = $value
                Location = $Location
                Scope = $Scope
                Type = "Registry"
                Enabled = $true
                ValidTarget = $isValid
                Publisher = Get-FilePublisher -Command $value
                Category = Get-StartupCategory -Name $prop.Name -Command $value
                Risk = Get-StartupRisk -Name $prop.Name -Command $value
            }
        }
    } catch {
        Write-Log -Level "DEBUG" -Category "Startup" -Message "Error reading startup from $Path : $($_.Exception.Message)"
    }
    
    return $items
}



function global:Get-FolderStartupItems {
    <#
    .SYNOPSIS
        Gets startup items from a startup folder.
    #>
    param(
        [string]$Path,
        [string]$Location,
        [string]$Scope
    )
    
    $items = @()
    
    if (-not (Test-Path $Path)) { return $items }
    
    try {
        $shortcuts = Get-ChildItem -Path $Path -Filter "*.lnk" -ErrorAction SilentlyContinue
        
        foreach ($shortcut in $shortcuts) {
            try {
                $shell = New-Object -ComObject WScript.Shell
                $link = $shell.CreateShortcut($shortcut.FullName)
                $target = $link.TargetPath
                $arguments = $link.Arguments
                
                $command = if ($arguments) { "$target $arguments" } else { $target }
                $isValid = Test-StartupTargetValid -Command $command
                
                $items += [PSCustomObject]@{
                    Name = $shortcut.BaseName
                    Command = $command
                    Location = $Location
                    Scope = $Scope
                    Type = "Shortcut"
                    Enabled = $true
                    ValidTarget = $isValid
                    Publisher = Get-FilePublisher -Command $target
                    Category = Get-StartupCategory -Name $shortcut.BaseName -Command $command
                    Risk = Get-StartupRisk -Name $shortcut.BaseName -Command $command
                    ShortcutPath = $shortcut.FullName
                }
        } catch { Write-Log -Level "WARNING" -Category "System" -Message $_.Exception.Message }


function global:Get-ScheduledTaskStartupItems {
    <#
    .SYNOPSIS
        Gets startup items from Task Scheduler (logon triggers).
    #>
    $items = @()
    
    try {
        $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | 
            Where-Object { 
                $_.Triggers -and 
                $_.Triggers[0].CimClass.CimClassName -eq 'MSFT_TaskLogonTrigger' -and
                $_.State -ne 'Disabled'
            }
        
        foreach ($task in $tasks) {
            $action = $task.Actions[0]
            $command = if ($action.Arguments) { "$($action.Execute) $($action.Arguments)" } else { $action.Execute }
            
            $items += [PSCustomObject]@{
                Name = $task.TaskName
                Command = $command
                Location = "TaskScheduler"
                Scope = if ($task.Principal.UserId -eq $env:USERNAME) { "User" } else { "System" }
                Type = "ScheduledTask"
                Enabled = ($task.State -eq 'Ready')
                ValidTarget = Test-StartupTargetValid -Command $action.Execute
                Publisher = Get-FilePublisher -Command $action.Execute
                Category = Get-StartupCategory -Name $task.TaskName -Command $command
                Risk = Get-StartupRisk -Name $task.TaskName -Command $command
                TaskPath = $task.TaskPath
            }
        }
    } catch {
        Write-Log -Level "DEBUG" -Category "Startup" -Message "Error reading scheduled tasks: $($_.Exception.Message)"
    }
    
    return $items
}



function global:Get-ServiceStartupItems {
    <#
    .SYNOPSIS
        Gets services that start automatically.
    #>
    $items = @()
    
    try {
        $services = Get-Service | Where-Object { $_.StartType -eq 'Automatic' -and $_.Status -eq 'Running' }
        
        foreach ($service in $services) {
            try {
                $svcInfo = Get-WmiObject -Class Win32_Service -Filter "Name='$($service.Name)'" -ErrorAction SilentlyContinue
                
                $items += [PSCustomObject]@{
                    Name = $service.DisplayName
                    Command = $svcInfo.PathName
                    Location = "Services"
                    Scope = "System"
                    Type = "Service"
                    Enabled = $true
                    ValidTarget = $true
                    Publisher = $svcInfo.StartName
                    Category = "System"
                    Risk = "Low"
                    ServiceName = $service.Name
                }
            } catch { Write-Log -Level "WARNING" -Category "System" -Message $_.Exception.Message }
        }
    } catch { Write-Log -Level "WARNING" -Category "System" -Message $_.Exception.Message }
    
    return $items
}

# ============================================================================
# STARTUP ANALYSIS HELPERS
# ============================================================================



function global:Test-StartupTargetValid {
    <#
    .SYNOPSIS
        Tests if a startup item's target file exists.
    #>
    param([string]$Command)
    
    if ([string]::IsNullOrWhiteSpace($Command)) { return $false }
    
    # Extract file path
    $filePath = $Command
    
    # Handle quoted paths
    if ($Command -match '"([^"]+)"') {
        $filePath = $Matches[1]
    } else {
        # Unquoted - get first token
        $filePath = $Command.Split(' ')[0]
    }
    
    # Handle environment variables
    $filePath = [Environment]::ExpandEnvironmentVariables($filePath)
    
    # System utilities are always valid
    if ($filePath -match "^(rundll32|regsvr32|msiexec|schtasks|powershell|cmd|cscript|wscript|explorer)") {
        return $true
    }
    
    # Check if file exists
    return (Test-Path -Path $filePath -PathType Leaf -ErrorAction SilentlyContinue)
}



function global:Get-FilePublisher {
    <#
    .SYNOPSIS
        Gets the publisher/manufacturer of a file.
    #>
    param([string]$Command)
    
    try {
        $filePath = $Command
        
        if ($Command -match '"([^"]+)"') {
            $filePath = $Matches[1]
        } else {
            $filePath = $Command.Split(' ')[0]
        }
        
        $filePath = [Environment]::ExpandEnvironmentVariables($filePath)
        
        if (Test-Path $filePath -PathType Leaf) {
            $fileInfo = Get-Item $filePath
            if ($fileInfo.VersionInfo.CompanyName) {
                return $fileInfo.VersionInfo.CompanyName
            }
        }
    } catch { Write-Log -Level "WARNING" -Category "System" -Message $_.Exception.Message }
    
    return "Unknown"
}



function global:Get-StartupCategory {
    <#
    .SYNOPSIS
        Categorizes a startup item.
    #>
    param([string]$Name, [string]$Command)
    
    $nameLower = $Name.ToLower()
    $cmdLower = $Command.ToLower()
    
    # Security/Antivirus
    if ($nameLower -match "(antivirus|defender|security|avast|avg|mcafee|norton|kaspersky|malwarebytes|eset|avira|bitdefender|sophos|trend micro)") {
        return "Security"
    }
    
    # Cloud Storage
    if ($nameLower -match "(dropbox|onedrive|google drive|icloud|mega|pcloud|box)") {
        return "Cloud Storage"
    }
    
    # Communication
    if ($nameLower -match "(teams|slack|discord|skype|zoom|webex|telegram|whatsapp|outlook|thunderbird)") {
        return "Communication"
    }
    
    # Gaming
    if ($nameLower -match "(steam|epic|origin|uplay|battlenet|gog|nvidia|geforce|radeon|steam|discord|spotify|xbox)") {
        return "Gaming/Media"
    }
    
    # Hardware
    if ($nameLower -match "(audio|sound|realtek|nvidia|amd|intel|razer|logitech|corsair|asus|msi|gigabyte|synaptics|touchpad)") {
        return "Hardware"
    }
    
    # Browser
    if ($nameLower -match "(chrome|firefox|edge|opera|brave|browser)") {
        return "Browser"
    }
    
    # System
    if ($nameLower -match "(windows|microsoft|office|onedrive|language|input|display)") {
        return "System"
    }
    
    # Update
    if ($nameLower -match "(update|updater|updatecheck)") {
        return "Update"
    }
    
    # Utilities
    if ($nameLower -match "(utility|helper|assistant|manager|agent|service)") {
        return "Utility"
    }
    
    return "Other"
}



function global:Get-StartupRisk {
    <#
    .SYNOPSIS
        Assesses the risk level of disabling a startup item.
    #>
    param([string]$Name, [string]$Command)
    
    $nameLower = $Name.ToLower()
    
    # High Risk - Should not disable
    $highRisk = @("defender", "security", "antivirus", "malware", "windows security", "bitlocker", "firewall")
    foreach ($pattern in $highRisk) {
        if ($nameLower -match $pattern) { return "High" }
    }
    
    # Medium Risk - May affect functionality
    $mediumRisk = @("audio", "sound", "bluetooth", "wifi", "network", "touchpad", "mouse", "keyboard", "display", "driver")
    foreach ($pattern in $mediumRisk) {
        if ($nameLower -match $pattern) { return "Medium" }
    }
    
    # Low Risk - Safe to disable
    $safeToDisable = @("update", "updater", "updatecheck", "telemetry", "feedback", "chrome", "firefox", 
                       "steam", "spotify", "dropbox", "onedrive", "skype", "teams", "slack", "discord")
    foreach ($pattern in $safeToDisable) {
        if ($nameLower -match $pattern) { return "Low" }
    }
    
    return "Low"
}

# ============================================================================
# STARTUP MANAGEMENT OPERATIONS
# ============================================================================



function global:Disable-StartupItem {
    <#
    .SYNOPSIS
        Disables a startup item.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$true)]
        [string]$Location,
        
        [switch]$Preview,
        [switch]$Force
    )
    
    $result = @{
        Success = $true
        Name = $Name
        Location = $Location
        Message = ""
        Errors = @()
    }
    
    if ($Preview) {
        $result.Message = "[PREVIEW] Would disable startup item: $Name"
        return $result
    }
    
    Write-Log -Level "INFO" -Category "Startup" -Message "Disabling startup item: $Name ($Location)"
    
    switch -Regex ($Location) {
        "HKCU_Run" {
            try {
                $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
                $value = (Get-ItemProperty -Path $path -ErrorAction Stop).$Name
                Register-StartupChange -Name $Name -Location $Location -Command $value -Action "Disabled"
                Remove-ItemProperty -Path $path -Name $Name -Force -ErrorAction Stop
                $result.Message = "Disabled registry startup: $Name"
            } catch {
                $result.Success = $false
                $result.Errors += $_.Exception.Message
            }
        }
        
        "HKLM_Run" {
            if (-not $script:State.IsElevated) {
                $result.Success = $false
                $result.Message = "Administrator privileges required"
                return $result
            }
            try {
                $path = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"
                $value = (Get-ItemProperty -Path $path -ErrorAction Stop).$Name
                Register-StartupChange -Name $Name -Location $Location -Command $value -Action "Disabled"
                Remove-ItemProperty -Path $path -Name $Name -Force -ErrorAction Stop
                $result.Message = "Disabled registry startup: $Name"
            } catch {
                $result.Success = $false
                $result.Errors += $_.Exception.Message
            }
        }
        
        "StartupFolder|UserStartupFolder|CommonStartupFolder" {
            try {
                # For folder shortcuts, rename to .disabled
                $shortcutPath = Join-Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup" "$Name.lnk"
                if (Test-Path $shortcutPath) {
                    $disabledPath = "$shortcutPath.disabled"
                    Rename-Item -Path $shortcutPath -NewName "$Name.lnk.disabled" -Force -ErrorAction Stop
                    Register-StartupChange -Name $Name -Location $Location -Command $shortcutPath -Action "Disabled"
                    $result.Message = "Disabled startup shortcut: $Name"
                }
            } catch {
                $result.Success = $false
                $result.Errors += $_.Exception.Message
            }
        }
        
        "TaskScheduler" {
            try {
                $task = Get-ScheduledTask -TaskName $Name -ErrorAction Stop
                Disable-ScheduledTask -TaskName $Name -ErrorAction Stop | Out-Null
                Register-StartupChange -Name $Name -Location $Location -Command $task.TaskPath -Action "Disabled"
                $result.Message = "Disabled scheduled task: $Name"
            } catch {
                $result.Success = $false
                $result.Errors += $_.Exception.Message
            }
        }
        
        default {
            $result.Success = $false
            $result.Message = "Unknown startup location: $Location"
        }
    }
    
    if ($result.Success) {
        Write-Log -Level "SUCCESS" -Category "Startup" -Message $result.Message
    } else {
        Write-Log -Level "ERROR" -Category "Startup" -Message "Failed to disable $Name : $($result.Errors -join '; ')"
    }
    
    return $result
}



function global:Remove-StartupItem {
    <#
    .SYNOPSIS
        Permanently removes a startup item.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$true)]
        [string]$Location,
        
        [switch]$Preview,
        [switch]$Force
    )
    
    $result = @{
        Success = $true
        Name = $Name
        Location = $Location
        Message = ""
        Errors = @()
    }
    
    if (-not $Force) {
        Write-Log -Level "WARNING" -Category "Startup" -Message "Remove operation requires -Force parameter for safety"
        $result.Message = "Use -Force to permanently remove startup items"
        return $result
    }
    
    if ($Preview) {
        $result.Message = "[PREVIEW] Would permanently remove startup item: $Name"
        return $result
    }
    
    Write-Log -Level "WARNING" -Category "Startup" -Message "Removing startup item: $Name ($Location)"
    
    switch -Regex ($Location) {
        "HKCU_Run|HKLM_Run|HKCU_RunOnce|HKLM_RunOnce" {
            try {
                $path = $Location -replace "HKCU_", "HKCU:\" -replace "HKLM_", "HKLM:\" -replace "_Run", "\Software\Microsoft\Windows\CurrentVersion\Run" -replace "_RunOnce", "\Software\Microsoft\Windows\CurrentVersion\RunOnce"
                Remove-ItemProperty -Path $path -Name $Name -Force -ErrorAction Stop
                $result.Message = "Removed registry startup: $Name"
            } catch {
                $result.Success = $false
                $result.Errors += $_.Exception.Message
            }
        }
        
        "StartupFolder|UserStartupFolder|CommonStartupFolder" {
            try {
                $shortcutPath = Join-Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup" "$Name.lnk"
                if (Test-Path $shortcutPath) {
                    Remove-Item -Path $shortcutPath -Force -ErrorAction Stop
                    $result.Message = "Removed startup shortcut: $Name"
                }
            } catch {
                $result.Success = $false
                $result.Errors += $_.Exception.Message
            }
        }
        
        "TaskScheduler" {
            try {
                Unregister-ScheduledTask -TaskName $Name -Confirm:$false -ErrorAction Stop
                $result.Message = "Removed scheduled task: $Name"
            } catch {
                $result.Success = $false
                $result.Errors += $_.Exception.Message
            }
        }
    }
    
    return $result
}

# ============================================================================
# STARTUP OPTIMIZATION
# ============================================================================



function global:Invoke-StartupOptimization {
    <#
    .SYNOPSIS
        Performs automated startup optimization.
    #>
    param(
        [string[]]$CategoriesToDisable = @("Update", "Other"),
        [string]$MaxRisk = "Low",
        [switch]$Preview,
        [switch]$RemoveInvalid
    )
    
    $results = @{
        Success = $true
        ItemsProcessed = 0
        ItemsDisabled = 0
        ItemsRemoved = 0
        InvalidRemoved = 0
        Results = @()
        Errors = @()
    }
    
    Write-Log -Level "INFO" -Category "Startup" -Message "Starting startup optimization..."
    
    # Get all startup items
    $items = Get-StartupItems
    
    # Remove invalid targets if requested
    if ($RemoveInvalid) {
        $invalidItems = $items | Where-Object { $_.ValidTarget -eq $false }
        foreach ($item in $invalidItems) {
            $result = Disable-StartupItem -Name $item.Name -Location $item.Location -Preview:$Preview
            $results.Results += $result
            $results.InvalidRemoved++
            $results.ItemsProcessed++
        }
    }
    
    # Disable items in specified categories with acceptable risk
    $toDisable = $items | Where-Object { 
        $_.Category -in $CategoriesToDisable -and 
        $_.Risk -eq $MaxRisk -and
        $_.ValidTarget -eq $true
    }
    
    foreach ($item in $toDisable) {
        $result = Disable-StartupItem -Name $item.Name -Location $item.Location -Preview:$Preview
        $results.Results += $result
        
        if ($result.Success) {
            $results.ItemsDisabled++
        } else {
            $results.Errors += "Failed: $($item.Name)"
        }
        
        $results.ItemsProcessed++
    }
    
    # Update stats
    $remaining = Get-StartupItems
    $script:State.ServicesModified += $results.ItemsDisabled.ToString()
    
    Write-Log -Level "SUCCESS" -Category "Startup" -Message "Startup optimization complete: $($results.ItemsDisabled) disabled, $($results.InvalidRemoved) invalid removed"
    
    return $results
}



function global:Get-StartupOptimizationRecommendations {
    <#
    .SYNOPSIS
        Gets recommendations for startup optimization.
    #>
    $items = Get-StartupItems
    
    $recommendations = @{
        TotalItems = $items.Count
        InvalidItems = @($items | Where-Object { $_.ValidTarget -eq $false })
        SafeToDisable = @($items | Where-Object { $_.Risk -eq "Low" -and $_.ValidTarget -eq $true })
        ConsiderDisabling = @($items | Where-Object { $_.Risk -eq "Medium" -and $_.ValidTarget -eq $true })
        KeepEnabled = @($items | Where-Object { $_.Risk -eq "High" })
        ByCategory = @{}
    }
    
    # Group by category
    $items | Group-Object Category | ForEach-Object {
        $recommendations.ByCategory[$_.Name] = $_.Count
    }
    
    return $recommendations
}



function global:Export-StartupReport {
    <#
    .SYNOPSIS
        Exports startup items to a report file.
    #>
    param(
        [string]$Path,
        [ValidateSet('CSV','JSON','HTML')]
        [string]$Format = 'CSV'
    )
    
    $items = Get-StartupItems -IncludeDisabled
    
    switch ($Format) {
        'CSV' {
            $items | Select-Object Name, Command, Location, Scope, Type, Enabled, ValidTarget, Publisher, Category, Risk |
                Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
        }
        'JSON' {
            $items | ConvertTo-Json -Depth 5 | Set-Content $Path -Encoding UTF8
        }
        'HTML' {
            $html = "<html><head><title>Startup Items Report</title>"
            $html += "<style>table { border-collapse: collapse; width: 100%; } th, td { border: 1px solid #ddd; padding: 8px; text-align: left; } th { background-color: #4CAF50; color: white; }</style></head><body>"
            $html += "<h1>Startup Items Report</h1>"
            $html += "<p>Generated: $(Get-Date)</p>"
            $html += "<table><tr><th>Name</th><th>Location</th><th>Category</th><th>Risk</th><th>Valid</th></tr>"
            
            foreach ($item in $items) {
                $riskColor = switch ($item.Risk) {
                    "High" { "red" }
                    "Medium" { "orange" }
                    default { "green" }
                }
                $html += "<tr><td>$($item.Name)</td><td>$($item.Location)</td><td>$($item.Category)</td><td style='color:$riskColor'>$($item.Risk)</td><td>$($item.ValidTarget)</td></tr>"
            }
            
            $html += "</table></body></html>"
            $html | Set-Content $Path -Encoding UTF8
        }
    }
    
    Write-Log -Level "SUCCESS" -Category "Startup" -Message "Startup report exported to $Path"
    
    return $Path
}
        }
    } catch {
        Write-Log -Level "DEBUG" -Category "Startup" -Message "Error reading startup folder $Path : $($_.Exception.Message)"
    }
    
    return $items
}
