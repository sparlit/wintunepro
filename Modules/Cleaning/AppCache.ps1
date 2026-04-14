#Requires -Version 5.1
<#
.SYNOPSIS
    App Cache Module - Third-Party Application Cache Cleaning
.DESCRIPTION
    Comprehensive cleaning of application caches including GPU caches (NVIDIA/AMD/Intel),
    Windows Apps, Teams, OneDrive, Spotify, Visual Studio, Steam, Epic Games,
    Discord, Slack, Zoom, Adobe apps, and development tools.
#>

function global:Clear-NVIDIACache {
    $result = @{ Success = $false; BytesRecovered = 0; Message = ""; ItemsCleaned = @() }
    try {
        $paths = @("$env:ProgramData\NVIDIA Corporation\DXCache","$env:ProgramData\NVIDIA Corporation\GLCache","$env:ProgramData\NVIDIA Corporation\Downloader","$env:ProgramData\NVIDIA Corporation\NetService","$env:LOCALAPPDATA\NVIDIA\DXCache","$env:LOCALAPPDATA\NVIDIA\GLCache","$env:ProgramFiles\NVIDIA Corporation\Installer2","$env:ProgramFiles\NVIDIA Corporation\NVSMI","$env:LOCALAPPDATA\NVIDIA\NvBackend\ApplicationOptimizationCache","$env:ProgramData\NVIDIA Corporation\GeForce Experience\Logs","$env:ProgramData\NVIDIA Corporation\GeForce Experience\StagingArea","$env:LOCALAPPDATA\NVIDIA Corporation\GFESDK","$env:ProgramData\NVIDIA Corporation\NvTelemetry","$env:LOCALAPPDATA\NVIDIA Corporation\NvTelemetry")
        foreach ($path in $paths) { if (Test-Path $path) { $sz = Get-AppFolderSize $path; try { Remove-Item "$path\*" -Recurse -Force -EA SilentlyContinue; $result.BytesRecovered += $sz; $result.ItemsCleaned += $path } catch { Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message } } }
        $result.Success = $true; $result.Message = "NVIDIA cache cleared"
    } catch { $result.Message = "Error: $($_.Exception.Message)" }
    return $result
}

function global:Clear-AMDCache {
    $result = @{ Success = $false; BytesRecovered = 0; Message = ""; ItemsCleaned = @() }
    try {
        $paths = @("$env:ProgramData\AMD\DxCache","$env:ProgramData\AMD\GLCache","$env:LOCALAPPDATA\AMD\DxCache","$env:LOCALAPPDATA\AMD\GLCache","$env:ProgramData\AMD\DPP","$env:ProgramData\AMD\PPC","$env:LOCALAPPDATA\AMD\CN","$env:ProgramFiles\AMD\CNext\CNext\Cache")
        foreach ($path in $paths) { if (Test-Path $path) { $sz = Get-AppFolderSize $path; try { Remove-Item "$path\*" -Recurse -Force -EA SilentlyContinue; $result.BytesRecovered += $sz; $result.ItemsCleaned += $path } catch { Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message } } }
        $result.Success = $true; $result.Message = "AMD cache cleared"
    } catch { $result.Message = "Error: $($_.Exception.Message)" }
    return $result
}

function global:Clear-IntelGPUCache {
    $result = @{ Success = $false; BytesRecovered = 0; Message = ""; ItemsCleaned = @() }
    try {
        $paths = @("$env:ProgramData\Intel\ShaderCache","$env:ProgramData\Intel\DXCache","$env:LOCALAPPDATA\Intel\ShaderCache","$env:LOCALAPPDATA\Intel\DXCache","$env:ProgramData\Intel\GFX","$env:LOCALAPPDATA\Intel\GFX","$env:ProgramData\Intel\IGCC","$env:LOCALAPPDATA\Intel\IGCC")
        foreach ($path in $paths) { if (Test-Path $path) { $sz = Get-AppFolderSize $path; try { Remove-Item "$path\*" -Recurse -Force -EA SilentlyContinue; $result.BytesRecovered += $sz; $result.ItemsCleaned += $path } catch { Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message } } }
        $result.Success = $true; $result.Message = "Intel GPU cache cleared"
    } catch { $result.Message = "Error: $($_.Exception.Message)" }
    return $result
}

function global:Clear-WindowsAppCache {
    $result = @{ Success = $false; BytesRecovered = 0; Message = ""; ItemsCleaned = @() }
    try {
        $pkgPath = "$env:LOCALAPPDATA\Packages"
        if (Test-Path $pkgPath) {
            Get-ChildItem $pkgPath -Directory -EA SilentlyContinue | ForEach-Object {
                $cacheDirs = @("LocalCache","TempState","AC\AppCache","AC\INetCache","AC\Temp","LocalState\Cache","LocalState\Temp")
                foreach ($cd in $cacheDirs) { $cp = Join-Path $_.FullName $cd; if (Test-Path $cp) { $sz = Get-AppFolderSize $cp; try { Remove-Item "$cp\*" -Recurse -Force -EA SilentlyContinue; $result.BytesRecovered += $sz; $result.ItemsCleaned += $cp } catch { Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message } } }
            }
        }
        $result.Success = $true; $result.Message = "Windows App caches cleared"
    } catch { $result.Message = "Error: $($_.Exception.Message)" }
    return $result
}

function global:Clear-OneDriveCache {
    $result = @{ Success = $false; BytesRecovered = 0; Message = ""; ItemsCleaned = @() }
    try {
        $paths = @("$env:LOCALAPPDATA\Microsoft\OneDrive\logs","$env:LOCALAPPDATA\Microsoft\OneDrive\setup\logs","$env:LOCALAPPDATA\Microsoft\OneDrive\cache","$env:LOCALAPPDATA\Microsoft\OneDrive\temp","$env:LOCALAPPDATA\Microsoft\Office\OneDriveLogs")
        foreach ($path in $paths) { if (Test-Path $path) { $sz = Get-AppFolderSize $path; try { Remove-Item "$path\*" -Recurse -Force -EA SilentlyContinue; $result.BytesRecovered += $sz; $result.ItemsCleaned += $path } catch { Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message } } }
        $result.Success = $true; $result.Message = "OneDrive cache cleared"
    } catch { $result.Message = "Error: $($_.Exception.Message)" }
    return $result
}

function global:Clear-TeamsCache {
    $result = @{ Success = $false; BytesRecovered = 0; Message = ""; ItemsCleaned = @() }
    try {
        Get-Process Teams -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue; Start-Sleep 3
        $paths = @("$env:APPDATA\Microsoft\Teams\Cache","$env:APPDATA\Microsoft\Teams\Code Cache","$env:APPDATA\Microsoft\Teams\GPUCache","$env:APPDATA\Microsoft\Teams\DawnCache","$env:APPDATA\Microsoft\Teams\blob_storage","$env:APPDATA\Microsoft\Teams\databases","$env:APPDATA\Microsoft\Teams\IndexedDB","$env:APPDATA\Microsoft\Teams\Local Storage","$env:APPDATA\Microsoft\Teams\Session Storage","$env:APPDATA\Microsoft\Teams\tmp","$env:APPDATA\Microsoft\Teams\logs","$env:APPDATA\Microsoft\Teams\old_logs")
        $paths2 = @("$env:LOCALAPPDATA\Packages\MSTeams_8wekyb3d8bbwe\LocalCache","$env:LOCALAPPDATA\Packages\MSTeams_8wekyb3d8bbwe\TempState")
        foreach ($path in ($paths + $paths2)) { if (Test-Path $path) { $sz = Get-AppFolderSize $path; try { Remove-Item "$path\*" -Recurse -Force -EA SilentlyContinue; $result.BytesRecovered += $sz; $result.ItemsCleaned += $path } catch { Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message } } }
        $result.Success = $true; $result.Message = "Teams cache cleared"
    } catch { $result.Message = "Error: $($_.Exception.Message)" }
    return $result
}

function global:Clear-SpotifyCache {
    $result = @{ Success = $false; BytesRecovered = 0; Message = ""; ItemsCleaned = @() }
    try {
        $paths = @("$env:LOCALAPPDATA\Spotify\Storage","$env:LOCALAPPDATA\Spotify\Browser\Cache","$env:LOCALAPPDATA\Spotify\Browser\Code Cache","$env:LOCALAPPDATA\Spotify\Browser\GPUCache","$env:LOCALAPPDATA\Spotify\Data","$env:LOCALAPPDATA\Spotify\Logs")
        foreach ($path in $paths) { if (Test-Path $path) { $sz = Get-AppFolderSize $path; try { Remove-Item "$path\*" -Recurse -Force -EA SilentlyContinue; $result.BytesRecovered += $sz; $result.ItemsCleaned += $path } catch { Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message } } }
        $result.Success = $true; $result.Message = "Spotify cache cleared"
    } catch { $result.Message = "Error: $($_.Exception.Message)" }
    return $result
}

function global:Clear-DiscordCache {
    $result = @{ Success = $false; BytesRecovered = 0; Message = ""; ItemsCleaned = @() }
    try {
        $paths = @("$env:APPDATA\discord\Cache","$env:APPDATA\discord\Code Cache","$env:APPDATA\discord\GPUCache","$env:APPDATA\discord\DawnCache","$env:APPDATA\discord\blob_storage","$env:APPDATA\discord\databases","$env:APPDATA\discord\IndexedDB","$env:APPDATA\discord\Local Storage","$env:APPDATA\discord\Session Storage","$env:APPDATA\discord\Crashpad")
        foreach ($path in $paths) { if (Test-Path $path) { $sz = Get-AppFolderSize $path; try { Remove-Item "$path\*" -Recurse -Force -EA SilentlyContinue; $result.BytesRecovered += $sz; $result.ItemsCleaned += $path } catch { Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message } } }
        $result.Success = $true; $result.Message = "Discord cache cleared"
    } catch { $result.Message = "Error: $($_.Exception.Message)" }
    return $result
}

function global:Clear-SlackCache {
    $result = @{ Success = $false; BytesRecovered = 0; Message = ""; ItemsCleaned = @() }
    try {
        $paths = @("$env:APPDATA\Slack\Cache","$env:APPDATA\Slack\Code Cache","$env:APPDATA\Slack\GPUCache","$env:APPDATA\Slack\DawnCache","$env:APPDATA\Slack\blob_storage","$env:APPDATA\Slack\IndexedDB","$env:APPDATA\Slack\Local Storage","$env:APPDATA\Slack\Session Storage","$env:APPDATA\Slack\Crashpad")
        foreach ($path in $paths) { if (Test-Path $path) { $sz = Get-AppFolderSize $path; try { Remove-Item "$path\*" -Recurse -Force -EA SilentlyContinue; $result.BytesRecovered += $sz; $result.ItemsCleaned += $path } catch { Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message } } }
        $result.Success = $true; $result.Message = "Slack cache cleared"
    } catch { $result.Message = "Error: $($_.Exception.Message)" }
    return $result
}

function global:Clear-ZoomCache {
    $result = @{ Success = $false; BytesRecovered = 0; Message = ""; ItemsCleaned = @() }
    try {
        $paths = @("$env:APPDATA\Zoom\data","$env:APPDATA\Zoom\bin\CrashDump","$env:APPDATA\Zoom\logs","$env:LOCALAPPDATA\Zoom\CrashDump","$env:LOCALAPPDATA\Zoom\Recordings\temp")
        foreach ($path in $paths) { if (Test-Path $path) { $sz = Get-AppFolderSize $path; try { Remove-Item "$path\*" -Recurse -Force -EA SilentlyContinue; $result.BytesRecovered += $sz; $result.ItemsCleaned += $path } catch { Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message } } }
        $result.Success = $true; $result.Message = "Zoom cache cleared"
    } catch { $result.Message = "Error: $($_.Exception.Message)" }
    return $result
}

function global:Clear-VisualStudioCache {
    $result = @{ Success = $false; BytesRecovered = 0; Message = ""; ItemsCleaned = @() }
    try {
        $basePaths = @("$env:LOCALAPPDATA\Microsoft\VisualStudio","$env:LOCALAPPDATA\Microsoft\VSCommon")
        foreach ($bp in $basePaths) {
            if (Test-Path $bp) {
                Get-ChildItem $bp -Directory -EA SilentlyContinue | ForEach-Object {
                    $subdirs = @("ComponentModelCache","Designer\ReflectedSchemas","ProjectAssemblies","Cache","Backup")
                    foreach ($sd in $subdirs) { $fp = Join-Path $_.FullName $sd; if (Test-Path $fp) { $sz = Get-AppFolderSize $fp; try { Remove-Item "$fp\*" -Recurse -Force -EA SilentlyContinue; $result.BytesRecovered += $sz; $result.ItemsCleaned += $fp } catch { Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message } } }
                }
            }
        }
        $result.Success = $true; $result.Message = "Visual Studio cache cleared"
    } catch { $result.Message = "Error: $($_.Exception.Message)" }
    return $result
}

function global:Clear-NuGetCache {
    $result = @{ Success = $false; BytesRecovered = 0; Message = ""; ItemsCleaned = @() }
    try {
        $paths = @("$env:USERPROFILE\.nuget\packages","$env:LOCALAPPDATA\NuGet\Cache","$env:LOCALAPPDATA\NuGet\v3-cache","$env:LOCALAPPDATA\NuGet\http-cache")
        foreach ($path in $paths) { if (Test-Path $path) { $sz = Get-AppFolderSize $path; try { Remove-Item "$path\*" -Recurse -Force -EA SilentlyContinue; $result.BytesRecovered += $sz; $result.ItemsCleaned += $path } catch { Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message } } }
        $result.Success = $true; $result.Message = "NuGet cache cleared"
    } catch { $result.Message = "Error: $($_.Exception.Message)" }
    return $result
}

function global:Clear-NPMCache {
    $result = @{ Success = $false; BytesRecovered = 0; Message = ""; ItemsCleaned = @() }
    try {
        $paths = @("$env:APPDATA\npm-cache","$env:APPDATA\npm\_cacache")
        foreach ($path in $paths) { if (Test-Path $path) { $sz = Get-AppFolderSize $path; try { Remove-Item "$path\*" -Recurse -Force -EA SilentlyContinue; $result.BytesRecovered += $sz; $result.ItemsCleaned += $path } catch { Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message } } }
        $result.Success = $true; $result.Message = "NPM cache cleared"
    } catch { $result.Message = "Error: $($_.Exception.Message)" }
    return $result
}

function global:Clear-PipCache {
    $result = @{ Success = $false; BytesRecovered = 0; Message = ""; ItemsCleaned = @() }
    try {
        $paths = @("$env:LOCALAPPDATA\pip\cache","$env:USERPROFILE\pip\cache","$env:LOCALAPPDATA\pip\http")
        foreach ($path in $paths) { if (Test-Path $path) { $sz = Get-AppFolderSize $path; try { Remove-Item "$path\*" -Recurse -Force -EA SilentlyContinue; $result.BytesRecovered += $sz; $result.ItemsCleaned += $path } catch { Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message } } }
        $result.Success = $true; $result.Message = "pip cache cleared"
    } catch { $result.Message = "Error: $($_.Exception.Message)" }
    return $result
}

function global:Clear-SteamCache {
    $result = @{ Success = $false; BytesRecovered = 0; Message = ""; ItemsCleaned = @() }
    try {
        $steamInstall = @("${env:ProgramFiles(x86)}\Steam","$env:ProgramFiles\Steam") | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($steamInstall) {
            $paths = @("appcache","depotcache","dumps","logs","steamapps\downloading","steamapps\temp","steamapps\shadercache") | ForEach-Object { Join-Path $steamInstall $_ }
            foreach ($path in $paths) { if (Test-Path $path) { $sz = Get-AppFolderSize $path; try { Remove-Item "$path\*" -Recurse -Force -EA SilentlyContinue; $result.BytesRecovered += $sz; $result.ItemsCleaned += $path } catch { Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message } } }
        }
        $result.Success = $true; $result.Message = "Steam cache cleared"
    } catch { $result.Message = "Error: $($_.Exception.Message)" }
    return $result
}

function global:Clear-EpicGamesCache {
    $result = @{ Success = $false; BytesRecovered = 0; Message = ""; ItemsCleaned = @() }
    try {
        $paths = @("$env:LOCALAPPDATA\EpicGamesLauncher\Saved\webcache","$env:LOCALAPPDATA\EpicGamesLauncher\Saved\Logs","$env:LOCALAPPDATA\EpicGamesLauncher\Saved\Cache","$env:LOCALAPPDATA\EpicGamesLauncher\Saved\Crashes")
        foreach ($path in $paths) { if (Test-Path $path) { $sz = Get-AppFolderSize $path; try { Remove-Item "$path\*" -Recurse -Force -EA SilentlyContinue; $result.BytesRecovered += $sz; $result.ItemsCleaned += $path } catch { Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message } } }
        $result.Success = $true; $result.Message = "Epic Games cache cleared"
    } catch { $result.Message = "Error: $($_.Exception.Message)" }
    return $result
}

function global:Clear-AdobeCache {
    $result = @{ Success = $false; BytesRecovered = 0; Message = ""; ItemsCleaned = @() }
    try {
        $paths = @("$env:APPDATA\Adobe\Common\Media Cache","$env:APPDATA\Adobe\Common\Media Cache Files","$env:APPDATA\Adobe\Common\Peak Files","$env:APPDATA\Adobe\Common\AME\Cache","$env:LOCALAPPDATA\Adobe\Lightroom\Cache","$env:LOCALAPPDATA\Adobe\CameraRaw\Cache","$env:LOCALAPPDATA\Adobe\Acrobat\DC\Cache","$env:LOCALAPPDATA\Adobe\AdobeCreativeCloud\Cache")
        foreach ($path in $paths) { if (Test-Path $path) { $sz = Get-AppFolderSize $path; try { Remove-Item "$path\*" -Recurse -Force -EA SilentlyContinue; $result.BytesRecovered += $sz; $result.ItemsCleaned += $path } catch { Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message } } }
        $result.Success = $true; $result.Message = "Adobe cache cleared"
    } catch { $result.Message = "Error: $($_.Exception.Message)" }
    return $result
}

function global:Clear-WindowsMediaPlayerCache {
    $result = @{ Success = $false; BytesRecovered = 0; Message = ""; ItemsCleaned = @() }
    try {
        $paths = @("$env:LOCALAPPDATA\Microsoft\Media Player\Art Cache","$env:LOCALAPPDATA\Microsoft\Media Player\Transcoded Files Cache","$env:LOCALAPPDATA\Microsoft\Media Player\cache")
        foreach ($path in $paths) { if (Test-Path $path) { $sz = Get-AppFolderSize $path; try { Remove-Item "$path\*" -Recurse -Force -EA SilentlyContinue; $result.BytesRecovered += $sz; $result.ItemsCleaned += $path } catch { Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message } } }
        $result.Success = $true; $result.Message = "WMP cache cleared"
    } catch { $result.Message = "Error: $($_.Exception.Message)" }
    return $result
}

function global:Clear-VLCCache {
    $result = @{ Success = $false; BytesRecovered = 0; Message = ""; ItemsCleaned = @() }
    try {
        $paths = @("$env:APPDATA\vlc\art","$env:APPDATA\vlc\crashdump","$env:APPDATA\vlc\cache","$env:APPDATA\vlc\ml\temp")
        foreach ($path in $paths) { if (Test-Path $path) { $sz = Get-AppFolderSize $path; try { Remove-Item "$path\*" -Recurse -Force -EA SilentlyContinue; $result.BytesRecovered += $sz; $result.ItemsCleaned += $path } catch { Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message } } }
        $result.Success = $true; $result.Message = "VLC cache cleared"
    } catch { $result.Message = "Error: $($_.Exception.Message)" }
    return $result
}

function global:Clear-AllAppCaches {
    $results = @{ TotalBytesRecovered = 0; Operations = @() }
    $ops = @("Clear-NVIDIACache","Clear-AMDCache","Clear-IntelGPUCache","Clear-WindowsAppCache","Clear-OneDriveCache","Clear-TeamsCache","Clear-SpotifyCache","Clear-DiscordCache","Clear-SlackCache","Clear-ZoomCache","Clear-VisualStudioCache","Clear-NuGetCache","Clear-NPMCache","Clear-PipCache","Clear-SteamCache","Clear-EpicGamesCache","Clear-AdobeCache","Clear-WindowsMediaPlayerCache","Clear-VLCCache")
    foreach ($op in $ops) {
        try {
            $r = & $op
            $results.Operations += @{ Name = $op; Success = $r.Success; BytesRecovered = $r.BytesRecovered; Message = $r.Message }
            $results.TotalBytesRecovered += $r.BytesRecovered
        } catch {
            $results.Operations += @{ Name = $op; Success = $false; BytesRecovered = 0; Message = "Error: $($_.Exception.Message)" }
        }
    }
    return $results
}

function global:Get-AppFolderSize {
    param([string]$Path)
    if (Get-Command Get-FolderSize -EA SilentlyContinue) { return Get-FolderSize -Path $Path }
    if (-not (Test-Path $Path)) { return 0 }
    try { $s = (Get-ChildItem $Path -Recurse -Force -EA SilentlyContinue | Measure-Object Length -Sum -EA SilentlyContinue).Sum; return [int]$(if($s){$s}else{0}) } catch { return 0 }
}
