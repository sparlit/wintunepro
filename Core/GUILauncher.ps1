function global:Start-GUIMode {
    # Load UI module
    . "$scriptRoot\UI\MainWindow.ps1"
    
    try {
        # Create main window
        $mainWindow = Initialize-MainWindow
        
        if (-not $mainWindow) {
            Write-Host "[ERROR] Failed to create main window" -ForegroundColor Red
            return
        }
        
        # Load modules
        Load-AppModules
        
        # Bind event handlers
        Bind-EventHandlers -Window $mainWindow
        
        # Show window
        $mainWindow.ShowDialog() | Out-Null
        
    } catch {
        Write-Host "[ERROR] GUI Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    }
}

