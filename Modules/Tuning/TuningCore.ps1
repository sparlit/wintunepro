# WinTune Pro - System Tuning Module
# PowerShell 5.1+ Compatible

function global:Get-BootConfiguration {
    $config = @{
        FastBoot = $false
        BootTime = 0
        Services = @()
    }

    try {
        $fastBoot = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -ErrorAction SilentlyContinue
        $config.FastBoot = ($fastBoot.HiberbootEnabled -eq 1)
    } catch {
        Write-Log -Level "WARNING" -Category "Tuning" -Message "Error checking Fast Boot: $($_.Exception.Message)"
    }

    try {
        $os = Get-WmiObject -Class Win32_OperatingSystem;$bootTime = $os.LastBootUpTime
        $config.BootTime = (Get-Date) - $bootTime
    } catch {
        Write-Log -Level "WARNING" -Category "Tuning" -Message "Error getting boot time: $($_.Exception.Message)"
    }

    return $config
}

function global:Get-VisualEffectsSettings {
    $settings = @{
        Animations = $true
        Transparency = $true
        PerformanceMode = $false
    }

    try {
        $visual = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -ErrorAction SilentlyContinue
        if ($visual) {
            $settings.PerformanceMode = ($visual.VisualFXSetting -eq 2)
        }
    } catch {
        Write-Log -Level "WARNING" -Category "Tuning" -Message "Error reading visual effects: $($_.Exception.Message)"
    }

    return $settings
}

function global:Invoke-SystemTuning {
    param(
        [bool]$OptimizeBoot = $true,
        [bool]$DisableFastBoot = $false,
        [bool]$ReduceAnimations = $true,
        [bool]$FastMenuSpeed = $true,
        [bool]$OptimizeNTFS = $true,
        [bool]$TestMode = $false,
        [switch]$RestoreDefaults
    )

    $results = @{
        Actions = @()
        Success = $true
    }

    if ($RestoreDefaults) {
        return Invoke-RestoreDefaults -TestMode $TestMode
    }

    if ($TestMode) {
        $results.Actions += "Test Mode: Would apply system tuning"
        return $results
    }

    if ($FastMenuSpeed) {
        try {
            Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value "0" -Force
            $results.Actions += "Set menu delay to 0ms"
            Log-Success "Optimized menu speed" -Category "Tuning"
        } catch {
            $results.Actions += "Failed to set menu speed"
        }
    }

    if ($ReduceAnimations) {
        try {
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2 -Force
            $results.Actions += "Reduced visual effects"
            Log-Success "Reduced visual effects" -Category "Tuning"
        } catch {
            $results.Actions += "Failed to reduce visual effects"
        }
    }

    if ($DisableFastBoot) {
        try {
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Value 0 -Force
            $results.Actions += "Disabled Fast Boot"
            Log-Success "Disabled Fast Boot" -Category "Tuning"
        } catch {
            $results.Actions += "Failed to disable Fast Boot"
        }
    }

    if ($OptimizeNTFS) {
        try {
            fsutil 8dot3name set 0 1 | Out-Null
            $results.Actions += "Disabled 8.3 filename creation"
            Log-Success "Optimized NTFS settings" -Category "Tuning"
        } catch {
            $results.Actions += "Failed to optimize NTFS"
        }
    }

    return $results
}

function global:Invoke-RestoreDefaults {
    param([bool]$TestMode = $false)

    $results = @{
        Actions = @()
        Success = $true
    }

    if ($TestMode) {
        $results.Actions += "Test Mode: Would restore defaults"
        return $results
    }

    try {
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value "400" -Force
        $results.Actions += "Restored menu delay to default"
    } catch {
        Write-Log -Level "WARNING" -Category "Tuning" -Message "Error restoring menu delay: $($_.Exception.Message)"
    }

    try {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 0 -Force
        $results.Actions += "Restored visual effects to default"
    } catch {
        Write-Log -Level "WARNING" -Category "Tuning" -Message "Error restoring visual effects: $($_.Exception.Message)"
    }

    try {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Value 1 -Force
        $results.Actions += "Enabled Fast Boot"
    } catch {
        Write-Log -Level "WARNING" -Category "Tuning" -Message "Error enabling Fast Boot: $($_.Exception.Message)"
    }

    Log-Info "Restored system defaults" -Category "Tuning"

    return $results
}

function global:Get-AppliedTweaks {
    $tweaks = @()

    try {
        $menuDelay = Get-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -ErrorAction SilentlyContinue
        if ($menuDelay -and $menuDelay.MenuShowDelay -eq "0") {
            $tweaks += "Fast Menu Speed"
        }
    } catch {
        Write-Log -Level "WARNING" -Category "Tuning" -Message "Error checking menu speed: $($_.Exception.Message)"
    }

    try {
        $visual = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -ErrorAction SilentlyContinue
        if ($visual -and $visual.VisualFXSetting -eq 2) {
            $tweaks += "Performance Visual Effects"
        }
    } catch {
        Write-Log -Level "WARNING" -Category "Tuning" -Message "Error checking visual effects: $($_.Exception.Message)"
    }

    try {
        $ntfs = fsutil 8dot3name query C: 2>$null
        if ($ntfs -match "disabled") {
            $tweaks += "NTFS 8.3 Disabled"
        }
    } catch {
        Write-Log -Level "WARNING" -Category "Tuning" -Message "Error checking NTFS 8.3: $($_.Exception.Message)"
    }

    return $tweaks
}

