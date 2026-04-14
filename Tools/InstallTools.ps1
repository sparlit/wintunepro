# Install PowerToys and Sysinternals Suite using winget

Write-Host "Installing Microsoft PowerToys..."
winget install --id Microsoft.PowerToys --source winget -e --accept-package-agreements --accept-source-agreements

Write-Host "Installing Sysinternals Suite..."
winget install --id Microsoft.SysinternalsSuite --source winget -e --accept-package-agreements --accept-source-agreements

Write-Host "Installation complete. PowerToys and Sysinternals Suite are ready to use."
