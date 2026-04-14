#Requires -Version 5.1
<#
.SYNOPSIS
    Gaming and Social Cache Cleaning Module
.DESCRIPTION
    Functions for cleaning caches from Discord, Battle.net, GOG Galaxy,
    Xbox Game Pass, Rockstar Launcher, and Twitch.
#>

function global:Clear-DiscordCacheSocial {
    <#
    .SYNOPSIS
        Clears Discord cache, including GPU cache and old update packages.
    #>
    param(
        [string[]]$Paths = @(),
        [switch]$WhatIf
    )

    $result = @{
        Success       = $false
        Message       = ""
        BytesRecovered = 0
        ItemsRemoved  = 0
    }

    try {
        try {
            $discordProcs = Get-Process -Name "Discord","DiscordPTB","DiscordCanary" -ErrorAction SilentlyContinue
            if ($discordProcs) {
                if (-not $WhatIf) {
                    $discordProcs | Stop-Process -Force -ErrorAction Stop
                    Start-Sleep -Seconds 2
                }
                Write-Log -Level "INFO" -Category "System" -Message "Stopped Discord processes" -Category "GamingSocial"
            }
        } catch {
            Write-Log -Level "WARNING" -Category "System" -Message "Could not stop Discord: $($_.Exception.Message)" -Category "GamingSocial"
        }

        $discordPaths = @(
            "$env:APPDATA\discord\Cache",
            "$env:APPDATA\discord\Code Cache",
            "$env:APPDATA\discord\GPUCache",
            "$env:APPDATA\discord\Session Storage",
            "$env:LOCALAPPDATA\Discord\Update",
            "$env:LOCALAPPDATA\Discord\Packages"
        )

        foreach ($p in $Paths) {
            if ($p -match "\*") {
                $resolved = Resolve-Path -Path $p -ErrorAction SilentlyContinue
                if ($resolved) { $discordPaths += $resolved.Path }
            } else {
                $discordPaths += $p
            }
        }

        foreach ($path in $discordPaths) {
            if (Test-Path $path) {
                try {
                    $size = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                             Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                    $count = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                              Measure-Object -ErrorAction SilentlyContinue).Count
                    if ($WhatIf) {
                        Write-Log -Level "INFO" -Category "System" -Message "Would remove $path ($count items)" -Category "GamingSocial"
                    } else {
                        Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction Stop
                        $result.BytesRecovered += if ($size) { $size } else { 0 }
                        $result.ItemsRemoved += if ($count) { $count } else { 0 }
                        Write-Log -Level "SUCCESS" -Category "GamingSocial" -Message "Cleared Discord cache: $path"
                    }
                } catch {
                    Write-Log -Level "WARNING" -Category "System" -Message "Failed to clear Discord cache '$path': $($_.Exception.Message)" -Category "GamingSocial"
                }
            }
        }

        $result.Success = $true
        $result.Message = "Discord cache cleared: $([math]::Round(($result.BytesRecovered / 1MB), 2)) MB"
    } catch {
        $result.Message = "Error clearing Discord cache: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "System" -Message $result.Message -Category "GamingSocial"
    }

    return $result
}

function global:Clear-BattleNetCacheSocial {
    <#
    .SYNOPSIS
        Clears Battle.net cache and temp data.
    #>
    param(
        [string[]]$Paths = @(),
        [switch]$WhatIf
    )

    $result = @{
        Success       = $false
        Message       = ""
        BytesRecovered = 0
        ItemsRemoved  = 0
    }

    try {
        $bnetPaths = @(
            "$env:LOCALAPPDATA\Battle.net\Cache",
            "$env:LOCALAPPDATA\Battle.net\BrowserCache",
            "$env:LOCALAPPDATA\Battle.net\Logs",
            "$env:PROGRAMDATA\Battle.net\Setup"
        )

        foreach ($p in $Paths) {
            if ($p -match "\*") {
                $resolved = Resolve-Path -Path $p -ErrorAction SilentlyContinue
                if ($resolved) { $bnetPaths += $resolved.Path }
            } else {
                $bnetPaths += $p
            }
        }

        foreach ($path in $bnetPaths) {
            if (Test-Path $path) {
                try {
                    $size = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                             Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                    $count = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                              Measure-Object -ErrorAction SilentlyContinue).Count
                    if ($WhatIf) {
                        Write-Log -Level "INFO" -Category "System" -Message "Would remove $path ($count items)" -Category "GamingSocial"
                    } else {
                        Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction Stop
                        $result.BytesRecovered += if ($size) { $size } else { 0 }
                        $result.ItemsRemoved += if ($count) { $count } else { 0 }
                        Write-Log -Level "SUCCESS" -Category "GamingSocial" -Message "Cleared Battle.net cache: $path"
                    }
                } catch {
                    Write-Log -Level "WARNING" -Category "System" -Message "Failed to clear Battle.net cache '$path': $($_.Exception.Message)" -Category "GamingSocial"
                }
            }
        }

        $result.Success = $true
        $result.Message = "Battle.net cache cleared: $([math]::Round(($result.BytesRecovered / 1MB), 2)) MB"
    } catch {
        $result.Message = "Error clearing Battle.net cache: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "System" -Message $result.Message -Category "GamingSocial"
    }

    return $result
}

function global:Clear-GOGGalaxyCacheSocial {
    <#
    .SYNOPSIS
        Clears GOG Galaxy cache and temporary installer data.
    #>
    param(
        [string[]]$Paths = @(),
        [switch]$WhatIf
    )

    $result = @{
        Success       = $false
        Message       = ""
        BytesRecovered = 0
        ItemsRemoved  = 0
    }

    try {
        $gogPaths = @(
            "$env:PROGRAMDATA\GOG.com\Galaxy\webcache",
            "$env:LOCALAPPDATA\GOG.com\Galaxy\Logs",
            "$env:LOCALAPPDATA\GOG.com\Galaxy\Temporary"
        )

        foreach ($p in $Paths) {
            if ($p -match "\*") {
                $resolved = Resolve-Path -Path $p -ErrorAction SilentlyContinue
                if ($resolved) { $gogPaths += $resolved.Path }
            } else {
                $gogPaths += $p
            }
        }

        foreach ($path in $gogPaths) {
            if (Test-Path $path) {
                try {
                    $size = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                             Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                    if ($WhatIf) {
                        Write-Log -Level "INFO" -Category "System" -Message "Would remove $path" -Category "GamingSocial"
                    } else {
                        Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction Stop
                        $result.BytesRecovered += if ($size) { $size } else { 0 }
                        Write-Log -Level "SUCCESS" -Category "GamingSocial" -Message "Cleared GOG Galaxy cache: $path"
                    }
                } catch {
                    Write-Log -Level "WARNING" -Category "System" -Message "Failed to clear GOG cache '$path': $($_.Exception.Message)" -Category "GamingSocial"
                }
            }
        }

        $result.Success = $true
        $result.Message = "GOG Galaxy cache cleared: $([math]::Round(($result.BytesRecovered / 1MB), 2)) MB"
    } catch {
        $result.Message = "Error clearing GOG Galaxy cache: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "System" -Message $result.Message -Category "GamingSocial"
    }

    return $result
}

function global:Clear-XboxGamePassCacheSocial {
    <#
    .SYNOPSIS
        Clears Xbox Game Pass and Xbox app caches.
    #>
    param(
        [string[]]$Paths = @(),
        [switch]$WhatIf
    )

    $result = @{
        Success       = $false
        Message       = ""
        BytesRecovered = 0
        ItemsRemoved  = 0
    }

    try {
        $xboxPaths = @(
            "$env:LOCALAPPDATA\Packages\Microsoft.XboxGamingOverlay_8wekyb3d8bbwe\TempState",
            "$env:LOCALAPPDATA\Packages\Microsoft.Xbox.TCUI_8wekyb3d8bbwe\TempState",
            "$env:LOCALAPPDATA\Packages\Microsoft.XboxApp_8wekyb3d8bbwe\TempState",
            "$env:LOCALAPPDATA\Packages\Microsoft.GamingApp_8wekyb3d8bbwe\TempState"
        )

        foreach ($p in $Paths) {
            if ($p -match "\*") {
                $resolved = Resolve-Path -Path $p -ErrorAction SilentlyContinue
                if ($resolved) { $xboxPaths += $resolved.Path }
            } else {
                $xboxPaths += $p
            }
        }

        foreach ($path in $xboxPaths) {
            if (Test-Path $path) {
                try {
                    $size = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                             Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                    if ($WhatIf) {
                        Write-Log -Level "INFO" -Category "System" -Message "Would remove $path" -Category "GamingSocial"
                    } else {
                        Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction Stop
                        $result.BytesRecovered += if ($size) { $size } else { 0 }
                        Write-Log -Level "SUCCESS" -Category "GamingSocial" -Message "Cleared Xbox cache: $path"
                    }
                } catch {
                    Write-Log -Level "WARNING" -Category "System" -Message "Failed to clear Xbox cache '$path': $($_.Exception.Message)" -Category "GamingSocial"
                }
            }
        }

        $result.Success = $true
        $result.Message = "Xbox Game Pass cache cleared: $([math]::Round(($result.BytesRecovered / 1MB), 2)) MB"
    } catch {
        $result.Message = "Error clearing Xbox cache: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "System" -Message $result.Message -Category "GamingSocial"
    }

    return $result
}

function global:Clear-RockstarLauncherCacheSocial {
    <#
    .SYNOPSIS
        Clears Rockstar Games Launcher cache and crash dumps.
    #>
    param(
        [string[]]$Paths = @(),
        [switch]$WhatIf
    )

    $result = @{
        Success       = $false
        Message       = ""
        BytesRecovered = 0
        ItemsRemoved  = 0
    }

    try {
        $rockstarPaths = @(
            "$env:LOCALAPPDATA\Rockstar Games\Launcher\cache",
            "$env:LOCALAPPDATA\Rockstar Games\Logs",
            "$env:LOCALAPPDATA\Rockstar Games\CrashDumps"
        )

        foreach ($p in $Paths) {
            if ($p -match "\*") {
                $resolved = Resolve-Path -Path $p -ErrorAction SilentlyContinue
                if ($resolved) { $rockstarPaths += $resolved.Path }
            } else {
                $rockstarPaths += $p
            }
        }

        foreach ($path in $rockstarPaths) {
            if (Test-Path $path) {
                try {
                    $size = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                             Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                    if ($WhatIf) {
                        Write-Log -Level "INFO" -Category "System" -Message "Would remove $path" -Category "GamingSocial"
                    } else {
                        Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction Stop
                        $result.BytesRecovered += if ($size) { $size } else { 0 }
                        Write-Log -Level "SUCCESS" -Category "GamingSocial" -Message "Cleared Rockstar cache: $path"
                    }
                } catch {
                    Write-Log -Level "WARNING" -Category "System" -Message "Failed to clear Rockstar cache '$path': $($_.Exception.Message)" -Category "GamingSocial"
                }
            }
        }

        $result.Success = $true
        $result.Message = "Rockstar Launcher cache cleared: $([math]::Round(($result.BytesRecovered / 1MB), 2)) MB"
    } catch {
        $result.Message = "Error clearing Rockstar cache: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "System" -Message $result.Message -Category "GamingSocial"
    }

    return $result
}

function global:Clear-TwitchCache {
    <#
    .SYNOPSIS
        Clears Twitch desktop app cache.
    #>
    param(
        [string[]]$Paths = @(),
        [switch]$WhatIf
    )

    $result = @{
        Success       = $false
        Message       = ""
        BytesRecovered = 0
        ItemsRemoved  = 0
    }

    try {
        $twitchPaths = @(
            "$env:APPDATA\Twitch\Cache",
            "$env:APPDATA\Twitch\GPUCache",
            "$env:APPDATA\Twitch\Code Cache",
            "$env:APPDATA\Twitch\Logs"
        )

        foreach ($p in $Paths) {
            if ($p -match "\*") {
                $resolved = Resolve-Path -Path $p -ErrorAction SilentlyContinue
                if ($resolved) { $twitchPaths += $resolved.Path }
            } else {
                $twitchPaths += $p
            }
        }

        foreach ($path in $twitchPaths) {
            if (Test-Path $path) {
                try {
                    $size = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                             Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                    if ($WhatIf) {
                        Write-Log -Level "INFO" -Category "System" -Message "Would remove $path" -Category "GamingSocial"
                    } else {
                        Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction Stop
                        $result.BytesRecovered += if ($size) { $size } else { 0 }
                        Write-Log -Level "SUCCESS" -Category "GamingSocial" -Message "Cleared Twitch cache: $path"
                    }
                } catch {
                    Write-Log -Level "WARNING" -Category "System" -Message "Failed to clear Twitch cache '$path': $($_.Exception.Message)" -Category "GamingSocial"
                }
            }
        }

        $result.Success = $true
        $result.Message = "Twitch cache cleared: $([math]::Round(($result.BytesRecovered / 1MB), 2)) MB"
    } catch {
        $result.Message = "Error clearing Twitch cache: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "System" -Message $result.Message -Category "GamingSocial"
    }

    return $result
}

function global:Clear-AllGamingSocialCaches {
    <#
    .SYNOPSIS
        Runs all gaming and social cache cleaning functions.
    #>
    param(
        [switch]$WhatIf
    )

    $results = @{
        Success       = $false
        Message       = ""
        TotalBytesRecovered = 0
        TotalItemsRemoved = 0
        Operations    = @()
    }

    $operations = @(
        @{ Name = "Discord Cache";            Function = "Clear-DiscordCacheSocial" },
        @{ Name = "Battle.net Cache";         Function = "Clear-BattleNetCacheSocial" },
        @{ Name = "GOG Galaxy Cache";         Function = "Clear-GOGGalaxyCacheSocial" },
        @{ Name = "Xbox Game Pass Cache";     Function = "Clear-XboxGamePassCacheSocial" },
        @{ Name = "Rockstar Launcher Cache";  Function = "Clear-RockstarLauncherCacheSocial" },
        @{ Name = "Twitch Cache";             Function = "Clear-TwitchCache" }
    )

    Write-Log -Level "INFO" -Category "System" -Message "Starting all gaming/social cache cleanup" -Category "GamingSocial"

    foreach ($op in $operations) {
        try {
            Write-Log -Level "INFO" -Category "System" -Message "Cleaning $($op.Name)..." -Category "GamingSocial"
            if ($WhatIf) {
                $result = & $op.Function -WhatIf
            } else {
                $result = & $op.Function
            }
            $results.Operations += @{
                Name           = $op.Name
                Success        = $result.Success
                BytesRecovered = $result.BytesRecovered
                Message        = $result.Message
            }
            $results.TotalBytesRecovered += $result.BytesRecovered
            $results.TotalItemsRemoved += $result.ItemsRemoved
        } catch {
            Write-Log -Level "ERROR" -Category "System" -Message "Error in $($op.Name): $($_.Exception.Message)" -Category "GamingSocial"
            $results.Operations += @{
                Name           = $op.Name
                Success        = $false
                BytesRecovered = 0
                Message        = "Error: $($_.Exception.Message)"
            }
        }
    }

    $results.Success = $true
    $results.Message = "All gaming/social caches cleared: $([math]::Round(($results.TotalBytesRecovered / 1MB), 2)) MB recovered"
    Write-Log -Level "SUCCESS" -Category "GamingSocial" -Message $results.Message

    return $results
}
