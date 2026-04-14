# InstallerCache.ps1 - PS5.1 compatible Windows Installer cache cleaning

function Get-InstallerCacheSize {
    [CmdletBinding()]
    param()

    $installerPath = 'C:\Windows\Installer'

    if (-not (Test-Path $installerPath)) {
        Write-Log -Level "WARNING" -Category "Cleaning" -Message "Windows Installer cache not found"
        return @{ TotalSizeMB = 0; FileCount = 0 }
    }

    try {
        $msiFiles = Get-ChildItem -Path $installerPath -Include '*.msi', '*.msp' -Recurse -Force -ErrorAction Stop
        $totalSize = ($msiFiles | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        if (-not $totalSize) { $totalSize = 0 }

        $result = @{
            TotalSizeMB = [math]::Round($totalSize / 1MB, 2)
            FileCount   = $msiFiles.Count
        }
        Write-Log -Level "INFO" -Category "Cleaning" -Message "Installer cache size: $($result.TotalSizeMB) MB across $($result.FileCount) files"
        return $result
    } catch {
        Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message
        return @{ TotalSizeMB = 0; FileCount = 0 }
    }
}

function Clear-InstallerCache {
    [CmdletBinding()]
    param(
        [switch]$Preview,
        [switch]$TestMode
    )

    $result = @{ Success = $false; BytesRecovered = 0; Message = ''; ItemsCleaned = 0 }
    $installerPath = 'C:\Windows\Installer'

    if (-not (Test-Path $installerPath)) {
        $result.Message = 'Windows Installer cache not found'
        Write-Log -Level "WARNING" -Category "Cleaning" -Message $result.Message
        return $result
    }

    try {
        $installedProducts = @()
        try {
            $regPaths = @(
                'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\*\Products\*\InstallProperties',
                'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
            )
            foreach ($regPath in $regPaths) {
                $items = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
                foreach ($item in $items) {
                    if ($item.LocalPackage -and (Test-Path $item.LocalPackage)) {
                        $installedProducts += $item.LocalPackage
                    }
                    if ($item.ModifyPath) {
                        $installedProducts += $item.ModifyPath
                    }
                }
            }
        } catch {
            Write-Log -Level "WARNING" -Category "Cleaning" -Message "Registry scan failed: $($_.Exception.Message)"
        }

        $installedProducts = $installedProducts | Select-Object -Unique

        $allFiles = Get-ChildItem -Path $installerPath -Include '*.msi', '*.msp' -Recurse -Force -ErrorAction SilentlyContinue
        $orphaned = $allFiles | Where-Object { $installedProducts -notcontains $_.FullName }

        Write-Log -Level "INFO" -Category "Cleaning" -Message "Found $($orphaned.Count) orphaned installer files"

        foreach ($file in $orphaned) {
            try {
                $size = $file.Length
                if ($Preview) {
                    Write-Log -Level "INFO" -Category "Cleaning" -Message "Orphaned $($file.Name) - $([math]::Round($size / 1MB, 2)) MB (Preview)"
                } elseif ($TestMode) {
                    Write-Log -Level "INFO" -Category "Cleaning" -Message "Orphaned $($file.Name) - Test mode, skipped"
                } else {
                    Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                    $result.BytesRecovered += $size
                    $result.ItemsCleaned++
                    Write-Log -Level "SUCCESS" -Category "Cleaning" -Message "Removed orphaned $($file.Name) - $([math]::Round($size / 1MB, 2)) MB"
                }
            } catch {
                Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message
            }
        }

        $result.Success = $true
        $result.Message = "Installer cache cleaned - $([math]::Round($result.BytesRecovered / 1MB, 2)) MB recovered, $($result.ItemsCleaned) files"
    } catch {
        Write-Log -Level "WARNING" -Category "Cleaning" -Message $_.Exception.Message
        $result.Message = $_.Exception.Message
    }

    return $result
}
