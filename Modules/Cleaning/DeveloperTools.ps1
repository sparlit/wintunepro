#Requires -Version 5.1
<#
.SYNOPSIS
    Developer Tools Cache Cleaning Module
.DESCRIPTION
    Functions for cleaning caches from VS Code, JetBrains IDEs, Sublime Text,
    and orphaned node_modules directories.
#>

function global:Clear-VSCodeCache {
    <#
    .SYNOPSIS
        Clears VS Code caches including workspace storage, cached data, and logs.
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
        $vsCodePaths = @(
            "$env:APPDATA\Code\User\workspaceStorage",
            "$env:APPDATA\Code\Cache",
            "$env:APPDATA\Code\CachedData",
            "$env:APPDATA\Code\GPUCache",
            "$env:APPDATA\Code\Code Cache",
            "$env:APPDATA\Code\logs",
            "$env:LOCALAPPDATA\Code\Cache",
            "$env:LOCALAPPDATA\Code\CachedData",
            "$env:LOCALAPPDATA\Code\GPUCache"
        )

        foreach ($p in $Paths) {
            if ($p -match "\*") {
                $resolved = Resolve-Path -Path $p -ErrorAction SilentlyContinue
                if ($resolved) { $vsCodePaths += $resolved.Path }
            } else {
                $vsCodePaths += $p
            }
        }

        foreach ($path in $vsCodePaths) {
            if (Test-Path $path) {
                try {
                    $size = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                             Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                    $count = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                              Measure-Object -ErrorAction SilentlyContinue).Count
                    if ($WhatIf) {
                        Write-Log -Level "INFO" -Category "System" -Message "Would remove $path ($count items)" -Category "DevTools"
                    } else {
                        Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction Stop
                        $result.BytesRecovered += if ($size) { $size } else { 0 }
                        $result.ItemsRemoved += if ($count) { $count } else { 0 }
                        Write-Log -Level "SUCCESS" -Category "DevTools" -Message "Cleared VS Code cache: $path"
                    }
                } catch {
                    Write-Log -Level "WARNING" -Category "System" -Message "Failed to clear VS Code cache '$path': $($_.Exception.Message)" -Category "DevTools"
                }
            }
        }

        $result.Success = $true
        $result.Message = "VS Code cache cleared: $($result.ItemsRemoved) items, $([math]::Round(($result.BytesRecovered / 1MB), 2)) MB"
    } catch {
        $result.Message = "Error clearing VS Code cache: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "System" -Message $result.Message -Category "DevTools"
    }

    return $result
}

function global:Clear-JetBrainsCache {
    <#
    .SYNOPSIS
        Clears JetBrains IDE caches (IntelliJ, PyCharm, WebStorm, etc.).
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
        $jetBrainsPaths = @(
            "$env:LOCALAPPDATA\JetBrains",
            "$env:APPDATA\JetBrains"
        )

        foreach ($p in $Paths) {
            if ($p -match "\*") {
                $resolved = Resolve-Path -Path $p -ErrorAction SilentlyContinue
                if ($resolved) { $jetBrainsPaths += $resolved.Path }
            } else {
                $jetBrainsPaths += $p
            }
        }

        $cacheSubfolders = @("caches", "log", "tmp", "system\tmp", "system\log")

        foreach ($basePath in $jetBrainsPaths) {
            if (-not (Test-Path $basePath)) { continue }

            $productDirs = Get-ChildItem -Path $basePath -Directory -ErrorAction SilentlyContinue

            foreach ($productDir in $productDirs) {
                foreach ($sub in $cacheSubfolders) {
                    $targetPath = Join-Path $productDir.FullName $sub
                    if (Test-Path $targetPath) {
                        try {
                            $size = (Get-ChildItem -Path $targetPath -Recurse -Force -ErrorAction SilentlyContinue |
                                     Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                            $count = (Get-ChildItem -Path $targetPath -Recurse -Force -ErrorAction SilentlyContinue |
                                      Measure-Object -ErrorAction SilentlyContinue).Count
                            if ($WhatIf) {
                                Write-Log -Level "INFO" -Category "System" -Message "Would remove $targetPath ($count items)" -Category "DevTools"
                            } else {
                                Remove-Item -Path "$targetPath\*" -Recurse -Force -ErrorAction Stop
                                $result.BytesRecovered += if ($size) { $size } else { 0 }
                                $result.ItemsRemoved += if ($count) { $count } else { 0 }
                                Write-Log -Level "SUCCESS" -Category "DevTools" -Message "Cleared JetBrains cache: $targetPath"
                            }
                        } catch {
                            Write-Log -Level "WARNING" -Category "System" -Message "Failed to clear JetBrains cache '$targetPath': $($_.Exception.Message)" -Category "DevTools"
                        }
                    }
                }
            }
        }

        $result.Success = $true
        $result.Message = "JetBrains cache cleared: $($result.ItemsRemoved) items, $([math]::Round(($result.BytesRecovered / 1MB), 2)) MB"
    } catch {
        $result.Message = "Error clearing JetBrains cache: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "System" -Message $result.Message -Category "DevTools"
    }

    return $result
}

function global:Clear-SublimeTextCache {
    <#
    .SYNOPSIS
        Clears Sublime Text caches and session data.
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
        $sublimePaths = @(
            "$env:APPDATA\Sublime Text\Cache",
            "$env:APPDATA\Sublime Text\Local\Session.sublime_session"
        )

        foreach ($p in $Paths) {
            if ($p -match "\*") {
                $resolved = Resolve-Path -Path $p -ErrorAction SilentlyContinue
                if ($resolved) { $sublimePaths += $resolved.Path }
            } else {
                $sublimePaths += $p
            }
        }

        foreach ($path in $sublimePaths) {
            if (Test-Path $path) {
                try {
                    $size = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                             Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                    if ($WhatIf) {
                        Write-Log -Level "INFO" -Category "System" -Message "Would remove $path" -Category "DevTools"
                    } else {
                        Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
                        $result.BytesRecovered += if ($size) { $size } else { 0 }
                        $result.ItemsRemoved++
                        Write-Log -Level "SUCCESS" -Category "DevTools" -Message "Cleared Sublime Text cache: $path"
                    }
                } catch {
                    Write-Log -Level "WARNING" -Category "System" -Message "Failed to clear Sublime Text cache '$path': $($_.Exception.Message)" -Category "DevTools"
                }
            }
        }

        $result.Success = $true
        $result.Message = "Sublime Text cache cleared: $([math]::Round(($result.BytesRecovered / 1MB), 2)) MB"
    } catch {
        $result.Message = "Error clearing Sublime Text cache: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "System" -Message $result.Message -Category "DevTools"
    }

    return $result
}

function global:Clear-NodeModulesCache {
    <#
    .SYNOPSIS
        Finds and removes orphaned node_modules directories.
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
        $searchPaths = @(
            "$env:USERPROFILE\source",
            "$env:USERPROFILE\projects",
            "$env:USERPROFILE\Documents",
            "$env:USERPROFILE\repos"
        )

        foreach ($p in $Paths) {
            if ($p -match "\*") {
                $resolved = Resolve-Path -Path $p -ErrorAction SilentlyContinue
                if ($resolved) { $searchPaths += $resolved.Path }
            } else {
                $searchPaths += $p
            }
        }

        Write-Log -Level "INFO" -Category "System" -Message "Scanning for orphaned node_modules directories..." -Category "DevTools"

        foreach ($searchPath in $searchPaths) {
            if (-not (Test-Path $searchPath)) { continue }

            try {
                $nodeModulesDirs = Get-ChildItem -Path $searchPath -Directory -Recurse -Force -ErrorAction SilentlyContinue |
                                   Where-Object { $_.Name -eq "node_modules" -and (Test-Path (Join-Path $_.Parent.FullName "package.json") -ErrorAction SilentlyContinue) }

                foreach ($nmDir in $nodeModulesDirs) {
                    try {
                        $size = (Get-ChildItem -Path $nmDir.FullName -Recurse -Force -ErrorAction SilentlyContinue |
                                 Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                        if ($WhatIf) {
                            Write-Log -Level "INFO" -Category "System" -Message "Would remove $($nmDir.FullName)" -Category "DevTools"
                        } else {
                            Remove-Item -Path $nmDir.FullName -Recurse -Force -ErrorAction Stop
                            $result.BytesRecovered += if ($size) { $size } else { 0 }
                            $result.ItemsRemoved++
                            Write-Log -Level "SUCCESS" -Category "DevTools" -Message "Removed node_modules: $($nmDir.FullName)"
                        }
                    } catch {
                        Write-Log -Level "WARNING" -Category "System" -Message "Failed to remove node_modules '$($nmDir.FullName)': $($_.Exception.Message)" -Category "DevTools"
                    }
                }
            } catch {
                Write-Log -Level "WARNING" -Category "System" -Message "Failed scanning '$searchPath': $($_.Exception.Message)" -Category "DevTools"
            }
        }

        $result.Success = $true
        $result.Message = "Node modules cleanup: $($result.ItemsRemoved) directories, $([math]::Round(($result.BytesRecovered / 1GB), 2)) GB"
    } catch {
        $result.Message = "Error clearing node_modules: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "System" -Message $result.Message -Category "DevTools"
    }

    return $result
}

function global:Clear-AllDevToolsCache {
    <#
    .SYNOPSIS
        Runs all developer tools cache cleaning functions.
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
        @{ Name = "VS Code Cache";      Function = "Clear-VSCodeCache" },
        @{ Name = "JetBrains Cache";    Function = "Clear-JetBrainsCache" },
        @{ Name = "Sublime Text Cache"; Function = "Clear-SublimeTextCache" },
        @{ Name = "Node Modules";       Function = "Clear-NodeModulesCache" }
    )

    Write-Log -Level "INFO" -Category "System" -Message "Starting all developer tools cache cleanup" -Category "DevTools"

    foreach ($op in $operations) {
        try {
            Write-Log -Level "INFO" -Category "System" -Message "Cleaning $($op.Name)..." -Category "DevTools"
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
            Write-Log -Level "ERROR" -Category "System" -Message "Error in $($op.Name): $($_.Exception.Message)" -Category "DevTools"
            $results.Operations += @{
                Name           = $op.Name
                Success        = $false
                BytesRecovered = 0
                Message        = "Error: $($_.Exception.Message)"
            }
        }
    }

    $results.Success = $true
    $results.Message = "All dev tools caches cleared: $([math]::Round(($results.TotalBytesRecovered / 1MB), 2)) MB recovered"
    Write-Log -Level "SUCCESS" -Category "DevTools" -Message $results.Message

    return $results
}
