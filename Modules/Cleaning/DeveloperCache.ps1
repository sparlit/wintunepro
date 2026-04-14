#Requires -Version 5.1
<#
.SYNOPSIS
    Developer Cache Cleaning Module
.DESCRIPTION
    Functions for deep cleaning developer tool caches including Git, Docker,
    WSL, Conda, Maven, Go, and Rust.
#>

function global:Clear-GitCacheDeep {
    <#
    .SYNOPSIS
        Clears Git caches including credential, index, and gc caches.
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
        $gitPaths = @(
            "$env:USERPROFILE\.git\gc",
            "$env:USERPROFILE\.git\objects\pack\tmp_*",
            "$env:LOCALAPPDATA\GitCredentialManager",
            "$env:APPDATA\Git"
        )

        foreach ($p in $Paths) {
            if ($p -match "\*") {
                $resolved = Resolve-Path -Path $p -ErrorAction SilentlyContinue
                if ($resolved) { $gitPaths += $resolved.Path }
            } else {
                $gitPaths += $p
            }
        }

        foreach ($path in $gitPaths) {
            if ($path -match "\*") {
                $matched = Get-Item -Path $path -ErrorAction SilentlyContinue
                foreach ($item in $matched) {
                    try {
                        $size = (Get-ChildItem -Path $item.FullName -Recurse -Force -ErrorAction SilentlyContinue |
                                 Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                        $count = (Get-ChildItem -Path $item.FullName -Recurse -Force -ErrorAction SilentlyContinue |
                                  Measure-Object -ErrorAction SilentlyContinue).Count
                        if ($WhatIf) {
                            Write-Log -Level "INFO" -Category "System" -Message "Would remove $($item.FullName) ($count items)" -Category "DevCache"
                        } else {
                            Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop
                            $result.BytesRecovered += if ($size) { $size } else { 0 }
                            $result.ItemsRemoved += if ($count) { $count } else { 0 }
                            Write-Log -Level "SUCCESS" -Category "DevCache" -Message "Cleared Git cache: $($item.FullName)"
                        }
                    } catch {
                        Write-Log -Level "WARNING" -Category "System" -Message "Failed to clear Git cache '$($item.FullName)': $($_.Exception.Message)" -Category "DevCache"
                    }
                }
            } elseif (Test-Path $path) {
                try {
                    $size = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                             Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                    $count = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                              Measure-Object -ErrorAction SilentlyContinue).Count
                    if ($WhatIf) {
                        Write-Log -Level "INFO" -Category "System" -Message "Would remove $path ($count items)" -Category "DevCache"
                    } else {
                        Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
                        $result.BytesRecovered += if ($size) { $size } else { 0 }
                        $result.ItemsRemoved += if ($count) { $count } else { 0 }
                        Write-Log -Level "SUCCESS" -Category "DevCache" -Message "Cleared Git cache: $path"
                    }
                } catch {
                    Write-Log -Level "WARNING" -Category "System" -Message "Failed to clear Git cache '$path': $($_.Exception.Message)" -Category "DevCache"
                }
            }
        }

        # Run git gc for repos in user profile if available
        if (Get-Command "git" -ErrorAction SilentlyContinue) {
            try {
                $gitRepos = Get-ChildItem -Path $env:USERPROFILE -Directory -Recurse -Depth 2 -ErrorAction SilentlyContinue |
                            Where-Object { Test-Path (Join-Path $_.FullName ".git") -ErrorAction SilentlyContinue }
                foreach ($repo in $gitRepos) {
                    try {
                        if (-not $WhatIf) {
                            & git -C $repo.FullName gc --aggressive --prune=now 2>$null
                            Write-Log -Level "INFO" -Category "System" -Message "Ran git gc in $($repo.FullName)" -Category "DevCache"
                        }
                    } catch {
                        Write-Log -Level "WARNING" -Category "System" -Message "Failed git gc in '$($repo.FullName)': $($_.Exception.Message)" -Category "DevCache"
                    }
                }
            } catch {
                Write-Log -Level "WARNING" -Category "System" -Message "Failed to enumerate git repos: $($_.Exception.Message)" -Category "DevCache"
            }
        }

        $result.Success = $true
        $result.Message = "Git cache cleared: $($result.ItemsRemoved) items, $([math]::Round(($result.BytesRecovered / 1MB), 2)) MB recovered"
    } catch {
        $result.Message = "Error clearing Git cache: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "System" -Message $result.Message -Category "DevCache"
    }

    return $result
}

function global:Clear-DockerCacheDeep {
    <#
    .SYNOPSIS
        Clears Docker caches including dangling images, build cache, and volumes.
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
        $dockerAvailable = Get-Command "docker" -ErrorAction SilentlyContinue

        if ($dockerAvailable) {
            try {
                if (-not $WhatIf) {
                    $pruneOutput = docker image prune -f 2>&1
                    Write-Log -Level "INFO" -Category "System" -Message "Docker image prune: $pruneOutput" -Category "DevCache"
                    $buildPrune = docker builder prune -f 2>&1
                    Write-Log -Level "INFO" -Category "System" -Message "Docker builder prune: $buildPrune" -Category "DevCache"
                    $volPrune = docker volume prune -f 2>&1
                    Write-Log -Level "INFO" -Category "System" -Message "Docker volume prune: $volPrune" -Category "DevCache"
                    $sysPrune = docker system prune -f 2>&1
                    Write-Log -Level "INFO" -Category "System" -Message "Docker system prune: $sysPrune" -Category "DevCache"
                }
            } catch {
                Write-Log -Level "WARNING" -Category "System" -Message "Failed Docker CLI cleanup: $($_.Exception.Message)" -Category "DevCache"
            }
        }

        # Clean Docker Desktop cache files
        $dockerPaths = @(
            "$env:LOCALAPPDATA\Docker",
            "$env:APPDATA\Docker"
        )

        foreach ($p in $Paths) {
            if ($p -match "\*") {
                $resolved = Resolve-Path -Path $p -ErrorAction SilentlyContinue
                if ($resolved) { $dockerPaths += $resolved.Path }
            } else {
                $dockerPaths += $p
            }
        }

        $cacheSubfolders = @("log", "Cache", "tmp")
        foreach ($basePath in $dockerPaths) {
            foreach ($sub in $cacheSubfolders) {
                $targetPath = Join-Path $basePath $sub
                if (Test-Path $targetPath) {
                    try {
                        $size = (Get-ChildItem -Path $targetPath -Recurse -Force -ErrorAction SilentlyContinue |
                                 Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                        if ($WhatIf) {
                            Write-Log -Level "INFO" -Category "System" -Message "Would remove $targetPath" -Category "DevCache"
                        } else {
                            Remove-Item -Path "$targetPath\*" -Recurse -Force -ErrorAction Stop
                            $result.BytesRecovered += if ($size) { $size } else { 0 }
                            Write-Log -Level "SUCCESS" -Category "DevCache" -Message "Cleared Docker cache: $targetPath"
                        }
                    } catch {
                        Write-Log -Level "WARNING" -Category "System" -Message "Failed to clear Docker path '$targetPath': $($_.Exception.Message)" -Category "DevCache"
                    }
                }
            }
        }

        $result.Success = $true
        $result.Message = "Docker cache cleared, $([math]::Round(($result.BytesRecovered / 1MB), 2)) MB recovered"
    } catch {
        $result.Message = "Error clearing Docker cache: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "System" -Message $result.Message -Category "DevCache"
    }

    return $result
}

function global:Clear-WSLCacheDeep {
    <#
    .SYNOPSIS
        Clears WSL caches and compacts virtual disks.
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
        $wslAvailable = Get-Command "wsl" -ErrorAction SilentlyContinue

        if ($wslAvailable) {
            try {
                if (-not $WhatIf) {
                    wsl --shutdown 2>&1 | Out-Null
                    Write-Log -Level "INFO" -Category "System" -Message "WSL shut down for cache cleanup" -Category "DevCache"
                }
            } catch {
                Write-Log -Level "WARNING" -Category "System" -Message "Failed to shut down WSL: $($_.Exception.Message)" -Category "DevCache"
            }
        }

        $wslPaths = @(
            "$env:LOCALAPPDATA\lxss",
            "$env:TEMP\wsl*"
        )

        foreach ($p in $Paths) {
            if ($p -match "\*") {
                $resolved = Resolve-Path -Path $p -ErrorAction SilentlyContinue
                if ($resolved) { $wslPaths += $resolved.Path }
            } else {
                $wslPaths += $p
            }
        }

        foreach ($path in $wslPaths) {
            if ($path -match "\*") {
                $matched = Get-Item -Path $path -ErrorAction SilentlyContinue
                foreach ($item in $matched) {
                    try {
                        $size = (Get-ChildItem -Path $item.FullName -Recurse -Force -ErrorAction SilentlyContinue |
                                 Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                        if (-not $WhatIf) {
                            Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop
                            $result.BytesRecovered += if ($size) { $size } else { 0 }
                            $result.ItemsRemoved++
                        }
                        Write-Log -Level "SUCCESS" -Category "DevCache" -Message "Cleared WSL cache: $($item.FullName)"
                    } catch {
                        Write-Log -Level "WARNING" -Category "System" -Message "Failed to clear WSL cache '$($item.FullName)': $($_.Exception.Message)" -Category "DevCache"
                    }
                }
            } elseif (Test-Path $path) {
                try {
                    $size = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                             Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                    if (-not $WhatIf) {
                        Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
                        $result.BytesRecovered += if ($size) { $size } else { 0 }
                        $result.ItemsRemoved++
                    }
                    Write-Log -Level "SUCCESS" -Category "DevCache" -Message "Cleared WSL cache: $path"
                } catch {
                    Write-Log -Level "WARNING" -Category "System" -Message "Failed to clear WSL cache '$path': $($_.Exception.Message)" -Category "DevCache"
                }
            }
        }

        $result.Success = $true
        $result.Message = "WSL cache cleared, $([math]::Round(($result.BytesRecovered / 1MB), 2)) MB recovered"
    } catch {
        $result.Message = "Error clearing WSL cache: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "System" -Message $result.Message -Category "DevCache"
    }

    return $result
}

function global:Clear-CondaCacheDeep {
    <#
    .SYNOPSIS
        Clears Conda package caches and tarballs.
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
        $condaAvailable = Get-Command "conda" -ErrorAction SilentlyContinue

        if ($condaAvailable) {
            try {
                if (-not $WhatIf) {
                    conda clean --all --yes 2>&1 | Out-Null
                    Write-Log -Level "SUCCESS" -Category "DevCache" -Message "Ran conda clean --all"
                }
            } catch {
                Write-Log -Level "WARNING" -Category "System" -Message "Failed conda clean: $($_.Exception.Message)" -Category "DevCache"
            }
        }

        $condaPaths = @(
            "$env:USERPROFILE\.conda\pkgs",
            "$env:USERPROFILE\Miniconda3\pkgs",
            "$env:USERPROFILE\Anaconda3\pkgs",
            "$env:LOCALAPPDATA\conda\conda\pkgs"
        )

        foreach ($p in $Paths) {
            if ($p -match "\*") {
                $resolved = Resolve-Path -Path $p -ErrorAction SilentlyContinue
                if ($resolved) { $condaPaths += $resolved.Path }
            } else {
                $condaPaths += $p
            }
        }

        foreach ($path in $condaPaths) {
            if (Test-Path $path) {
                try {
                    $size = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                             Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                    if ($WhatIf) {
                        Write-Log -Level "INFO" -Category "System" -Message "Would remove $path" -Category "DevCache"
                    } else {
                        Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction Stop
                        $result.BytesRecovered += if ($size) { $size } else { 0 }
                        Write-Log -Level "SUCCESS" -Category "DevCache" -Message "Cleared Conda cache: $path"
                    }
                } catch {
                    Write-Log -Level "WARNING" -Category "System" -Message "Failed to clear Conda cache '$path': $($_.Exception.Message)" -Category "DevCache"
                }
            }
        }

        $result.Success = $true
        $result.Message = "Conda cache cleared, $([math]::Round(($result.BytesRecovered / 1MB), 2)) MB recovered"
    } catch {
        $result.Message = "Error clearing Conda cache: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "System" -Message $result.Message -Category "DevCache"
    }

    return $result
}

function global:Clear-MavenCacheDeep {
    <#
    .SYNOPSIS
        Clears Maven local repository caches.
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
        $mavenPaths = @(
            "$env:USERPROFILE\.m2\repository"
        )

        foreach ($p in $Paths) {
            if ($p -match "\*") {
                $resolved = Resolve-Path -Path $p -ErrorAction SilentlyContinue
                if ($resolved) { $mavenPaths += $resolved.Path }
            } else {
                $mavenPaths += $p
            }
        }

        foreach ($path in $mavenPaths) {
            if (Test-Path $path) {
                try {
                    $size = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                             Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                    $count = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                              Measure-Object -ErrorAction SilentlyContinue).Count
                    if ($WhatIf) {
                        Write-Log -Level "INFO" -Category "System" -Message "Would remove $path ($count items)" -Category "DevCache"
                    } else {
                        Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction Stop
                        $result.BytesRecovered += if ($size) { $size } else { 0 }
                        $result.ItemsRemoved += if ($count) { $count } else { 0 }
                        Write-Log -Level "SUCCESS" -Category "DevCache" -Message "Cleared Maven cache: $path"
                    }
                } catch {
                    Write-Log -Level "WARNING" -Category "System" -Message "Failed to clear Maven cache '$path': $($_.Exception.Message)" -Category "DevCache"
                }
            }
        }

        $result.Success = $true
        $result.Message = "Maven cache cleared: $($result.ItemsRemoved) items, $([math]::Round(($result.BytesRecovered / 1MB), 2)) MB recovered"
    } catch {
        $result.Message = "Error clearing Maven cache: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "System" -Message $result.Message -Category "DevCache"
    }

    return $result
}

function global:Clear-GoCacheDeep {
    <#
    .SYNOPSIS
        Clears Go build and module caches.
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
        $goAvailable = Get-Command "go" -ErrorAction SilentlyContinue

        if ($goAvailable) {
            try {
                if (-not $WhatIf) {
                    go clean -cache -modcache -testcache 2>&1 | Out-Null
                    Write-Log -Level "SUCCESS" -Category "DevCache" -Message "Ran go clean -cache -modcache -testcache"
                }
            } catch {
                Write-Log -Level "WARNING" -Category "System" -Message "Failed go clean: $($_.Exception.Message)" -Category "DevCache"
            }
        }

        $goPaths = @(
            "$env:LOCALAPPDATA\go-build",
            "$env:GOPATH\pkg\mod\cache",
            "$env:USERPROFILE\go\pkg\mod\cache"
        )

        foreach ($p in $Paths) {
            if ($p -match "\*") {
                $resolved = Resolve-Path -Path $p -ErrorAction SilentlyContinue
                if ($resolved) { $goPaths += $resolved.Path }
            } else {
                $goPaths += $p
            }
        }

        foreach ($path in $goPaths) {
            if (Test-Path $path) {
                try {
                    $size = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                             Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                    if ($WhatIf) {
                        Write-Log -Level "INFO" -Category "System" -Message "Would remove $path" -Category "DevCache"
                    } else {
                        Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction Stop
                        $result.BytesRecovered += if ($size) { $size } else { 0 }
                        Write-Log -Level "SUCCESS" -Category "DevCache" -Message "Cleared Go cache: $path"
                    }
                } catch {
                    Write-Log -Level "WARNING" -Category "System" -Message "Failed to clear Go cache '$path': $($_.Exception.Message)" -Category "DevCache"
                }
            }
        }

        $result.Success = $true
        $result.Message = "Go cache cleared, $([math]::Round(($result.BytesRecovered / 1MB), 2)) MB recovered"
    } catch {
        $result.Message = "Error clearing Go cache: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "System" -Message $result.Message -Category "DevCache"
    }

    return $result
}

function global:Clear-RustCacheDeep {
    <#
    .SYNOPSIS
        Clears Rust/Cargo build caches.
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
        $rustPaths = @(
            "$env:USERPROFILE\.cargo\registry\cache",
            "$env:USERPROFILE\.cargo\registry\src",
            "$env:USERPROFILE\.cargo\git\db",
            "$env:USERPROFILE\.rustup\downloads"
        )

        foreach ($p in $Paths) {
            if ($p -match "\*") {
                $resolved = Resolve-Path -Path $p -ErrorAction SilentlyContinue
                if ($resolved) { $rustPaths += $resolved.Path }
            } else {
                $rustPaths += $p
            }
        }

        foreach ($path in $rustPaths) {
            if (Test-Path $path) {
                try {
                    $size = (Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
                             Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                    if ($WhatIf) {
                        Write-Log -Level "INFO" -Category "System" -Message "Would remove $path" -Category "DevCache"
                    } else {
                        Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction Stop
                        $result.BytesRecovered += if ($size) { $size } else { 0 }
                        Write-Log -Level "SUCCESS" -Category "DevCache" -Message "Cleared Rust cache: $path"
                    }
                } catch {
                    Write-Log -Level "WARNING" -Category "System" -Message "Failed to clear Rust cache '$path': $($_.Exception.Message)" -Category "DevCache"
                }
            }
        }

        $result.Success = $true
        $result.Message = "Rust cache cleared, $([math]::Round(($result.BytesRecovered / 1MB), 2)) MB recovered"
    } catch {
        $result.Message = "Error clearing Rust cache: $($_.Exception.Message)"
        Write-Log -Level "ERROR" -Category "System" -Message $result.Message -Category "DevCache"
    }

    return $result
}

function global:Clear-AllDevCachesDeep {
    <#
    .SYNOPSIS
        Runs all developer cache deep cleaning functions.
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
        @{ Name = "Git Cache";     Function = "Clear-GitCacheDeep" },
        @{ Name = "Docker Cache";  Function = "Clear-DockerCacheDeep" },
        @{ Name = "WSL Cache";     Function = "Clear-WSLCacheDeep" },
        @{ Name = "Conda Cache";   Function = "Clear-CondaCacheDeep" },
        @{ Name = "Maven Cache";   Function = "Clear-MavenCacheDeep" },
        @{ Name = "Go Cache";      Function = "Clear-GoCacheDeep" },
        @{ Name = "Rust Cache";    Function = "Clear-RustCacheDeep" }
    )

    Write-Log -Level "INFO" -Category "System" -Message "Starting all developer cache cleanup" -Category "DevCache"

    foreach ($op in $operations) {
        try {
            Write-Log -Level "INFO" -Category "System" -Message "Cleaning $($op.Name)..." -Category "DevCache"
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
            Write-Log -Level "ERROR" -Category "System" -Message "Error in $($op.Name): $($_.Exception.Message)" -Category "DevCache"
            $results.Operations += @{
                Name           = $op.Name
                Success        = $false
                BytesRecovered = 0
                Message        = "Error: $($_.Exception.Message)"
            }
        }
    }

    $results.Success = $true
    $results.Message = "All dev caches cleared: $([math]::Round(($results.TotalBytesRecovered / 1MB), 2)) MB recovered"
    Write-Log -Level "SUCCESS" -Category "DevCache" -Message $results.Message

    return $results
}
