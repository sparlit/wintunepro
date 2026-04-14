# Disable background apps permissions for installed apps
Write-Host "Disabling background apps permissions..."

$apps = @(
    "MicrosoftTeams",
    "Spotify",
    "Zoom",
    "Adobe Acrobat",
    "XboxApp"
)

foreach ($app in $apps) {
    try {
        Write-Host "Setting background permission to 'Never' for $app..."
        Get-AppxPackage -Name $app | ForEach-Object {
            $packageFamilyName = $_.PackageFamilyName
            $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications\$packageFamilyName"
            if (!(Test-Path $regPath)) {
                New-Item -Path $regPath -Force | Out-Null
            }
            Set-ItemProperty -Path $regPath -Name "Disabled" -Value 1
        }
    } catch {
        Write-Host "Skipping $app (not installed)"
    }
}

# Optimize services (set non-essential ones to Manual)
Write-Host "Optimizing services..."

$services = @(
    "XboxNetApiSvc",
    "XboxGipSvc",
    "XblGameSave",
    "DiagTrack"   # Connected User Experiences and Telemetry
)

foreach ($svc in $services) {
    try {
        Write-Host "Setting $svc to Manual startup..."
        Set-Service -Name $svc -StartupType Manual
    } catch {
        Write-Host "Skipping $svc (not found)"
    }
}

Write-Host "Background apps and services optimized successfully."
