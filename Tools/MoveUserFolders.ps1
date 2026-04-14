# Define source and destination
$UserName = "ITS01"
$SourcePath = "C:\Users\$UserName"
$DestDrive = "E:\Users\$UserName"

# Create destination folder if not exists
if (!(Test-Path $DestDrive)) {
    New-Item -ItemType Directory -Path $DestDrive
}

# List of common user folders to move
$Folders = @("Documents", "Downloads", "Pictures", "Music", "Videos", "Desktop")

foreach ($Folder in $Folders) {
    $SourceFolder = Join-Path $SourcePath $Folder
    $DestFolder   = Join-Path $DestDrive $Folder

    # Create destination folder
    if (!(Test-Path $DestFolder)) {
        New-Item -ItemType Directory -Path $DestFolder
    }

    # Move contents only if source exists
    if (Test-Path $SourceFolder) {
        Write-Host "Moving $Folder..."
        Move-Item -Path "$SourceFolder\*" -Destination $DestFolder -Force
    } else {
        Write-Host "Skipping $Folder (not found on C:)"
    }

    # Update registry to point Windows to new location
    $RegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
    Set-ItemProperty -Path $RegPath -Name $Folder -Value $DestFolder
}

Write-Host "User folders redirected successfully to $DestDrive"
