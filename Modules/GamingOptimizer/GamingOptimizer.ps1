# WinTune Pro - Gaming Optimizer Module
# PowerShell 5.1+ Compatible

function global:Get-GameModeStatus {
    $status = @{
        Enabled = $false
        Supported = $true
    }

    try {
        $gameMode = Get-ItemProperty -Path "HKCU:\Software\Microsoft\GameBar" -Name "AutoGameModeEnabled" -ErrorAction SilentlyContinue
        if ($gameMode) {
            $status.Enabled = ($gameMode.AutoGameModeEnabled -eq 1)
        }
    } catch {
        $status.Supported = $false
    }

    return $status
}

function global:Set-GameMode {
    param([bool]$Enable = $true)

    try {
        $value = if ($Enable) { 1 } else { 0 }
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Value $value -Force -ErrorAction SilentlyContinue
        Log-Success "$(if($Enable){'Enabled'}else{'Disabled'}) Windows Game Mode" -Category "Gaming"
        return $true
    } catch {
        Log-Error "Failed to set Game Mode: $($_.Exception.Message)" -Category "Gaming"
        return $false
    }
}

function global:Invoke-GamingOptimization {
    param(
        [ValidateSet("Quick", "Full", "Aggressive")]
        [string]$Mode = "Quick",
        [bool]$EnableGPUScheduling = $true,
        [bool]$DisableGameDVR = $true,
        [bool]$SetUltimatePerformance = $false,
        [bool]$TestMode = $false
    )

    $results = @{
        Actions = @()
        Success = $true
    }

    if ($TestMode) {
        $results.Actions += "Test Mode: Would apply gaming optimization"
        return $results
    }

    try {
        Set-GameMode -Enable $true
        $results.Actions += "Enabled Windows Game Mode"
    } catch {
        Write-Log -Level "WARNING" -Category "Gaming" -Message "Error enabling Game Mode: $($_.Exception.Message)"
    }

    if ($DisableGameDVR) {
        try {
            Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0 -Force -ErrorAction SilentlyContinue
            $results.Actions += "Disabled Game DVR"
        } catch {
            Write-Log -Level "WARNING" -Category "Gaming" -Message "Error disabling Game DVR: $($_.Exception.Message)"
        }
    }

    if ($EnableGPUScheduling) {
        try {
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Value 2 -Force -ErrorAction SilentlyContinue
            $results.Actions += "Enabled GPU Hardware Scheduling (restart required)"
        } catch {
            Write-Log -Level "WARNING" -Category "Gaming" -Message "Error enabling GPU scheduling: $($_.Exception.Message)"
        }
    }

    if ($Mode -eq "Aggressive" -or $SetUltimatePerformance) {
        try {
            $ultimateGUID = "e9a42b02-d5df-448d-aa00-03f14749eb61"
            $plans = powercfg /list
            if ($plans -match $ultimateGUID) {
                powercfg /setactive $ultimateGUID
                $results.Actions += "Set Ultimate Performance power plan"
            } else {
                $highPerfGUID = "8c5e7fda-e8bf-4a96-9a85-a6e23a8486b7"
                powercfg /setactive $highPerfGUID
                $results.Actions += "Set High Performance power plan"
            }
        } catch {
            Write-Log -Level "WARNING" -Category "Gaming" -Message "Error setting power plan: $($_.Exception.Message)"
        }
    }

    if ($Mode -eq "Aggressive") {
        try {
            Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "ScreenSaveActive" -Value "0" -Force
            $results.Actions += "Disabled screensaver"
        } catch {
            Write-Log -Level "WARNING" -Category "Gaming" -Message "Error disabling screensaver: $($_.Exception.Message)"
        }

        try {
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" -Name "Priority" -Value 6 -Force -ErrorAction SilentlyContinue
            $results.Actions += "Set high priority for games"
        } catch {
            Write-Log -Level "WARNING" -Category "Gaming" -Message "Error setting game priority: $($_.Exception.Message)"
        }
    }

    Log-Success "Applied $Mode gaming optimization" -Category "Gaming"

    return $results
}

function global:Clear-GameCache {
    param(
        [bool]$Steam = $true,
        [bool]$Epic = $true,
        [bool]$All = $false,
        [bool]$TestMode = $false
    )

    $results = @{
        Actions = @()
        TotalFreed = 0
    }

    if ($TestMode) {
        $results.Actions += "Test Mode: Would clear game caches"
        return $results
    }

    if ($Steam -or $All) {
        $steamPath = "${env:ProgramFiles(x86)}\Steam\appcache"
        if (Test-Path $steamPath) {
            try {
                $size = Get-FolderSize -Path $steamPath
                Remove-Item -Path "$steamPath\*" -Recurse -Force -ErrorAction SilentlyContinue
                $results.Actions += "Cleared Steam cache ($size MB)"
                $results.TotalFreed += $size
            } catch {
                Write-Log -Level "WARNING" -Category "Gaming" -Message "Error clearing Steam cache: $($_.Exception.Message)"
            }
        }
    }

    if ($Epic -or $All) {
        $epicPath = "$env:LocalAppData\EpicGamesLauncher\Saved\webcache"
        if (Test-Path $epicPath) {
            try {
                $size = Get-FolderSize -Path $epicPath
                Remove-Item -Path "$epicPath\*" -Recurse -Force -ErrorAction SilentlyContinue
                $results.Actions += "Cleared Epic Games cache ($size MB)"
                $results.TotalFreed += $size
            } catch {
                Write-Log -Level "WARNING" -Category "Gaming" -Message "Error clearing Epic cache: $($_.Exception.Message)"
            }
        }
    }

    Log-Success "Cleared game caches - Total freed: $($results.TotalFreed) MB" -Category "Gaming"

    return $results
}

# Note: Get-FolderSize is defined in CleaningCore.ps1 and available globally
