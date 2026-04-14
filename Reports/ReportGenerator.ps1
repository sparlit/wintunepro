# WinTune Pro - Report Generator Module
# PowerShell 5.1+ Compatible

# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)
# Function New-SystemReport removed (duplicate of E:\WinTunePro\Core\ReportGenerator.ps1)

function global:New-HTMLReport {
    param($SystemInfo, $DiskInfo, $HealthScore, $NetworkInfo, $Benchmark)
    
    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>WinTune Pro - System Report</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: #0D0D1A;
            color: #FFFFFF;
            margin: 0;
            padding: 20px;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        .header {
            background: #1A1A2E;
            padding: 30px;
            border-radius: 12px;
            margin-bottom: 20px;
            text-align: center;
        }
        .header h1 {
            color: #6C5CE7;
            margin: 0 0 10px 0;
        }
        .header .subtitle {
            color: #A0A0B0;
        }
        .card {
            background: #1A1A2E;
            border-radius: 12px;
            padding: 20px;
            margin-bottom: 20px;
            border: 1px solid #2D2D4A;
        }
        .card h2 {
            color: #00CEC9;
            margin-top: 0;
            border-bottom: 2px solid #6C5CE7;
            padding-bottom: 10px;
        }
        .health-score {
            text-align: center;
            padding: 30px;
        }
        .health-score .score {
            font-size: 72px;
            font-weight: bold;
            color: #00B894;
        }
        .health-score .label {
            color: #A0A0B0;
            font-size: 18px;
        }
        .info-grid {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 15px;
        }
        .info-item {
            background: #16213E;
            padding: 15px;
            border-radius: 8px;
        }
        .info-item .label {
            color: #A0A0B0;
            font-size: 12px;
            margin-bottom: 5px;
        }
        .info-item .value {
            font-size: 16px;
            font-weight: 600;
        }
        .disk-bar {
            background: #2D2D4A;
            border-radius: 4px;
            height: 20px;
            margin: 10px 0;
            overflow: hidden;
        }
        .disk-bar-fill {
            height: 100%;
            border-radius: 4px;
            transition: width 0.3s ease;
        }
        .success { color: #00B894; }
        .warning { color: #FDCB6E; }
        .danger { color: #E17055; }
        .info { color: #74B9FF; }
        .footer {
            text-align: center;
            color: #606070;
            margin-top: 30px;
            padding: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>WinTune Pro - System Report</h1>
            <div class="subtitle">Generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</div>
        </div>

        <div class="card">
            <div class="health-score">
                <div class="score">$HealthScore</div>
                <div class="label">System Health Score</div>
            </div>
        </div>

        <div class="card">
            <h2>System Information</h2>
            <div class="info-grid">
                <div class="info-item">
                    <div class="label">Computer Name</div>
                    <div class="value">$($SystemInfo.ComputerName)</div>
                </div>
                <div class="info-item">
                    <div class="label">Operating System</div>
                    <div class="value">$($SystemInfo.OSVersion)</div>
                </div>
                <div class="info-item">
                    <div class="label">Processor</div>
                    <div class="value">$($SystemInfo.CPU)</div>
                </div>
                <div class="info-item">
                    <div class="label">CPU Cores / Threads</div>
                    <div class="value">$($SystemInfo.CPUCores) / $($SystemInfo.CPUThreads)</div>
                </div>
                <div class="info-item">
                    <div class="label">Total Memory</div>
                    <div class="value">$($SystemInfo.TotalMemory) GB</div>
                </div>
                <div class="info-item">
                    <div class="label">Available Memory</div>
                    <div class="value success">$($SystemInfo.FreeMemory) GB</div>
                </div>
            </div>
        </div>

        <div class="card">
            <h2>Disk Usage</h2>
            $(foreach ($disk in $DiskInfo) {
                $color = if ($disk.PercentUsed -gt 80) { "#E17055" } elseif ($disk.PercentUsed -gt 60) { "#FDCB6E" } else { "#00B894" }
                @"
            <div style="margin-bottom: 20px;">
                <div style="display: flex; justify-content: space-between;">
                    <span><strong>$($disk.Drive)</strong> - $($disk.Label)</span>
                    <span>$($disk.Free) GB free of $($disk.Total) GB</span>
                </div>
                <div class="disk-bar">
                    <div class="disk-bar-fill" style="width: $($disk.PercentUsed)%; background: $color;"></div>
                </div>
                <div style="text-align: right; font-size: 12px; color: #A0A0B0;">$($disk.PercentUsed)% used</div>
            </div>
"@
            })
        </div>
"@

    if ($Benchmark) {
        $html += @"
        <div class="card">
            <h2>Benchmark Results</h2>
            <div class="info-grid">
                <div class="info-item">
                    <div class="label">Overall Score</div>
                    <div class="value">$($Benchmark.Overall)</div>
                </div>
                <div class="info-item">
                    <div class="label">CPU Score</div>
                    <div class="value">$($Benchmark.CPU)</div>
                </div>
                <div class="info-item">
                    <div class="label">Memory Score</div>
                    <div class="value">$($Benchmark.Memory)</div>
                </div>
                <div class="info-item">
                    <div class="label">Disk Score</div>
                    <div class="value">$($Benchmark.Disk)</div>
                </div>
            </div>
        </div>
"@
    }

    $html += @"
        <div class="footer">
            <p>Generated by WinTune Pro v2.0</p>
            <p>Session ID: $(Get-SessionId)</p>
        </div>
    </div>
</body>
</html>
"@

    return $html
}

function global:New-TextReport {
    param($SystemInfo, $DiskInfo, $HealthScore, $NetworkInfo, $Benchmark)
    
    $text = @"
================================================================================
                      WinTune Pro - System Report
================================================================================
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Session ID: $(Get-SessionId)

================================================================================
                           SYSTEM HEALTH SCORE
================================================================================

    Score: $HealthScore / 100

================================================================================
                           SYSTEM INFORMATION
================================================================================

    Computer Name:     $($SystemInfo.ComputerName)
    Operating System:  $($SystemInfo.OSVersion)
    Build Number:      $($SystemInfo.OSBuild)
    
    Processor:         $($SystemInfo.CPU)
    CPU Cores:         $($SystemInfo.CPUCores)
    CPU Threads:       $($SystemInfo.CPUThreads)
    
    Total Memory:      $($SystemInfo.TotalMemory) GB
    Available Memory:  $($SystemInfo.FreeMemory) GB
    Memory Usage:      $($SystemInfo.MemoryPercent)%

================================================================================
                              DISK USAGE
================================================================================

"@

    foreach ($disk in $DiskInfo) {
        $text += @"
    $($disk.Drive) - $($disk.Label)
        Total:      $($disk.Total) GB
        Used:       $($disk.Used) GB
        Free:       $($disk.Free) GB
        Usage:      $($disk.PercentUsed)%

"@
    }

    if ($Benchmark) {
        $text += @"
================================================================================
                          BENCHMARK RESULTS
================================================================================

    Overall Score:  $($Benchmark.Overall)
    CPU Score:      $($Benchmark.CPU)
    Memory Score:   $($Benchmark.Memory)
    Disk Score:     $($Benchmark.Disk)
    Network Score:  $($Benchmark.Network)
    Duration:       $([math]::Round($Benchmark.Duration, 2)) seconds

"@
    }

    $text += @"
================================================================================
                         END OF REPORT
================================================================================
Generated by WinTune Pro v2.0
"@

    return $text
}

function global:Get-ReportHistory {
    $reportsPath = Get-ConfigValue "ReportsPath"
    
    if (-not (Test-Path $reportsPath)) {
        return @()
    }
    
    $reports = @()
    
    Get-ChildItem -Path $reportsPath -Filter "*.html" | Sort-Object LastWriteTime -Descending | ForEach-Object {
        $reports += @{
            Name = $_.Name
            Path = $_.FullName
            Date = $_.LastWriteTime
            Size = [math]::Round($_.Length / 1KB, 2)
        }
    }
    
    Get-ChildItem -Path $reportsPath -Filter "*.txt" | Sort-Object LastWriteTime -Descending | ForEach-Object {
        $reports += @{
            Name = $_.Name
            Path = $_.FullName
            Date = $_.LastWriteTime
            Size = [math]::Round($_.Length / 1KB, 2)
        }
    }
    
    return $reports | Sort-Object Date -Descending
}

function global:Clear-OldReports {
    param([int]$DaysToKeep = 30)
    
    $reportsPath = Get-ConfigValue "ReportsPath"
    $cutoff = (Get-Date).AddDays(-$DaysToKeep)
    
    $removed = 0
    
    Get-ChildItem -Path $reportsPath | Where-Object {
        $_.LastWriteTime -lt $cutoff
    } | ForEach-Object {
        Remove-Item $_.FullName -Force
        $removed++
    }
    
    Log-Info "Removed $removed old reports" -Category "Report"
    
    return $removed
}

# Export functions

