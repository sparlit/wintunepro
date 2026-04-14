function global:Bind-DashboardEvents {
    # Dashboard buttons
    $quickOptBtn = Find-UIElement "QuickOptimizeBtn"
    if ($quickOptBtn) {
        $quickOptBtn.Add_Click({
            # Auto-backup before changes
            $backupPath = Invoke-AutoBackup -OperationName "QuickOptimize"
            if ($backupPath) {
                Add-ActivityLog "Auto-backup created: $(Split-Path $backupPath -Leaf)"
            }
            
            Update-Status -Text "Running Quick Optimize..." -State "Working"
            Add-ActivityLog "Starting Quick Optimization..."
            
            try {
                Add-ActivityLog "[DEBUG] Running Quick Optimize..."
                $testMode = Get-ConfigValue "TestMode"
                Add-ActivityLog "[DEBUG] TestMode: $testMode"
                
                $result = Invoke-QuickOptimize -TestMode $testMode
                Add-ActivityLog "[DEBUG] Optimize result received"
                
                foreach ($action in $result.Actions) {
                    Add-ActivityLog $action
                }
                Update-DashboardStats
                Update-Status -Text "Quick Optimize completed" -State "Success"
                Add-ActivityLog "Quick Optimization completed"
            } catch {
                Add-ActivityLog "[ERROR] Quick Optimize: $($_.Exception.Message)"
                Update-Status -Text "Quick Optimize failed" -State "Error"
                Add-ActivityLog "Error: $($_.Exception.Message)"
            }
        })
    }
    
    $masterCleanBtn = Find-UIElement "MasterCleanBtn"
    $masterCleanAllBtn = Find-UIElement "MasterCleanAllBtn"
    
    $masterCleanAction = {
        Update-Status -Text "Running Master Clean..." -State "Working"
        Add-ActivityLog "Starting Master Clean..."
        
        try {
            $result = Invoke-MasterClean -TestMode (Get-ConfigValue "TestMode")
            Add-ActivityLog "Cleaned $($result.TotalFreed) MB"
            Update-DashboardStats
            Update-Status -Text "Master Clean completed" -State "Success"
        } catch {
            Update-Status -Text "Master Clean failed" -State "Error"
            Add-ActivityLog "Error: $($_.Exception.Message)"
        }
    }
    
    if ($masterCleanBtn) { $masterCleanBtn.Add_Click($masterCleanAction) }
    if ($masterCleanAllBtn) { $masterCleanAllBtn.Add_Click($masterCleanAction) }
    
    # Cleaning tab
    $scanCleanBtn = Find-UIElement "ScanCleaningBtn"
    if ($scanCleanBtn) {
        $scanCleanBtn.Add_Click({
            $scanBtnRef = Find-UIElement "ScanCleaningBtn"
            if ($scanBtnRef) { $scanBtnRef.IsEnabled = $false }
            Update-Status -Text "Scanning for recoverable space..." -State "Working"
            try {
                $result = Invoke-CleaningScan
                $totalSizeGB = [math]::Round($result.TotalSize / 1024, 2)
                $totalSizeText = Find-UIElement "CleaningTotalSize"
                if ($totalSizeText) { $totalSizeText.Text = "Total: $totalSizeGB GB recoverable" }
                Update-Status -Text "Scan completed - $totalSizeGB GB recoverable" -State "Success"
                Add-ActivityLog "Scan found $totalSizeGB GB recoverable"
            } catch {
                Update-Status -Text "Scan failed" -State "Error"
                Add-ActivityLog "Scan error: $($_.Exception.Message)"
            }
            if ($scanBtnRef) { $scanBtnRef.IsEnabled = $true }
        })
    }
    
    $runCleanBtn = Find-UIElement "RunCleaningBtn"
    if ($runCleanBtn) {
        $runCleanBtn.Add_Click({
            # Auto-backup before cleaning
            $backupPath = Invoke-AutoBackup -OperationName "Cleaning"
            if ($backupPath) {
                Add-ActivityLog "Auto-backup created: $(Split-Path $backupPath -Leaf)"
            }
            
            $cleanBtnRef = Find-UIElement "RunCleaningBtn"
            if ($cleanBtnRef) { $cleanBtnRef.IsEnabled = $false }
            Update-Status -Text "Running cleaning..." -State "Working"
            
            $categories = @()
            if ((Find-UIElement "CleanUserTemp").IsChecked) { $categories += "UserTemp" }
            if ((Find-UIElement "CleanSystemTemp").IsChecked) { $categories += "SystemTemp" }
            if ((Find-UIElement "CleanWUCache").IsChecked) { $categories += "WUCache" }
            if ((Find-UIElement "CleanRecycleBin").IsChecked) { $categories += "RecycleBin" }
            if ((Find-UIElement "CleanThumbnailCache").IsChecked) { $categories += "ThumbnailCache" }
            if ((Find-UIElement "CleanPrefetch").IsChecked) { $categories += "Prefetch" }
            
            try {
                Add-ActivityLog "[DEBUG] Running cleaning with categories: $($categories -join ', ')"
                $testMode = Get-ConfigValue "TestMode"
                Add-ActivityLog "[DEBUG] TestMode: $testMode"
                
                $result = Invoke-Cleaning -Categories $categories -TestMode $testMode
                Add-ActivityLog "[DEBUG] Cleaning completed"
                
                $freedMB = $result.TotalFreed
                if ($freedMB -eq $null) { $freedMB = 0 }
                $freedGB = [math]::Round($freedMB / 1024, 2)
                Add-ActivityLog "[DEBUG] Freed: $freedGB GB"
                
                $spaceText = Find-UIElement "SpaceRecoveredText"
                if ($spaceText) { $spaceText.Text = "$freedGB GB" }
                
                Update-DashboardStats
                Update-Status -Text "Cleaning completed - $freedGB GB recovered" -State "Success"
                Add-ActivityLog "Cleaned $freedGB GB"
            } catch {
                Add-ActivityLog "[ERROR] Cleaning: $($_.Exception.Message)"
                Update-Status -Text "Cleaning failed" -State "Error"
                Add-ActivityLog "Clean error: $($_.Exception.Message)"
            }
            if ($cleanBtnRef) { $cleanBtnRef.IsEnabled = $true }
        })
    }
}
