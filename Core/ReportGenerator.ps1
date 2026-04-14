# WinTune Pro - HTML Report Generator
# PowerShell 5.1+ Compatible
# Generates professional health reports with historical tracking

# Initialize report generator
function global:Initialize-ReportGenerator {
    $paths = Get-Paths
    $reportsDir = $paths.Reports

    if (-not (Test-Path $reportsDir)) {
        New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
        Write-Log -Level "INFO" -Category "Report" -Message "Created reports directory: $reportsDir"
    }

    Write-Log -Level "INFO" -Category "Report" -Message "Report generator initialized"
    return $true
}

# Load historical scores from data folder
function global:Get-HistoricalScores {
    param(
        [int]$Count = 30
    )

    Write-Log -Level "INFO" -Category "Report" -Message "Loading historical health scores..."

    $paths = Get-Paths
    $historyFile = Join-Path $paths.Data "health_scores.json"

    if (-not (Test-Path $historyFile)) {
        Write-Log -Level "INFO" -Category "Report" -Message "No historical scores found"
        return @()
    }

    try {
        $content = Get-Content $historyFile -Raw -ErrorAction Stop
        $history = $content | ConvertFrom-Json -ErrorAction Stop

        # Convert to array if single entry
        if ($history -isnot [Array]) {
            $history = @($history)
        }

        # Return most recent entries
        $recent = $history | Sort-Object { [DateTime]$_.Date } -Descending | Select-Object -First $Count
        Write-Log -Level "INFO" -Category "Report" -Message "Loaded $($recent.Count) historical scores"
        return $recent
    } catch {
        Write-Log -Level "ERROR" -Category "Report" -Message "Error loading historical scores: $($_.Exception.Message)"
        return @()
    }
}

# Save health score to history
function global:Save-HealthScore {
    param(
        [hashtable]$HealthScore,
        [long]$SpaceRecovered = 0
    )

    Write-Log -Level "INFO" -Category "Report" -Message "Saving health score to history..."

    $paths = Get-Paths
    $historyFile = Join-Path $paths.Data "health_scores.json"

    # Load existing history
    $history = @(Get-HistoricalScores -Count 9999)

    # Create new entry
    $entry = @{
        Date = $HealthScore.Timestamp
        TotalScore = $HealthScore.TotalScore
        Grade = $HealthScore.Grade
        Categories = @{}
        SessionId = $HealthScore.SessionId
        SpaceRecovered = $SpaceRecovered
    }

    # Copy category scores
    foreach ($cat in $HealthScore.Categories.Keys) {
        $entry.Categories[$cat] = @{
            Score = $HealthScore.Categories[$cat].Score
            MaxScore = $HealthScore.Categories[$cat].MaxScore
        }
    }

    # Add to history (keep last 365 entries)
    $history += $entry
    $history = $history | Sort-Object { [DateTime]$_.Date } -Descending | Select-Object -First 365

    # Save to file
    try {
        $history | ConvertTo-Json -Depth 10 | Out-File -FilePath $historyFile -Encoding UTF8 -Force
        Write-Log -Level "SUCCESS" -Category "Report" -Message "Health score saved to history"
    } catch {
        Write-Log -Level "ERROR" -Category "Report" -Message "Error saving health score: $($_.Exception.Message)"
    }

    return $entry
}

# Generate comparison chart HTML
function global:New-ComparisonChart {
    param(
        [hashtable]$Before,
        [hashtable]$After
    )

    Write-Log -Level "INFO" -Category "Report" -Message "Generating comparison chart..."

    $comparisons = @(
        @{ Name = "Health Score"; Before = "$($Before.TotalScore)/100"; After = "$($After.TotalScore)/100"; Change = $After.TotalScore - $Before.TotalScore }
    )

    # Compare disk space if available
    if ($Before.DiskFreeGB -and $After.DiskFreeGB) {
        $comparisons += @{
            Name = "Disk Free Space"
            Before = "$($Before.DiskFreeGB) GB"
            After = "$($After.DiskFreeGB) GB"
            Change = [math]::Round($After.DiskFreeGB - $Before.DiskFreeGB, 2)
        }
    }

    # Compare memory if available
    if ($Before.MemoryUsedPercent -and $After.MemoryUsedPercent) {
        $comparisons += @{
            Name = "Memory Used"
            Before = "$($Before.MemoryUsedPercent)%"
            After = "$($After.MemoryUsedPercent)%"
            Change = $Before.MemoryUsedPercent - $After.MemoryUsedPercent
        }
    }

    # Compare service count if available
    if ($Before.ServicesRunning -and $After.ServicesRunning) {
        $comparisons += @{
            Name = "Running Services"
            Before = $Before.ServicesRunning
            After = $After.ServicesRunning
            Change = $Before.ServicesRunning - $After.ServicesRunning
        }
    }

    $html = '<div class="comparison-section">' + "`n"
    $html += '<h2>Before / After Comparison</h2>' + "`n"
    $html += '<table class="comparison-table">' + "`n"
    $html += '<thead><tr><th>Metric</th><th>Before</th><th>After</th><th>Change</th></tr></thead>' + "`n"
    $html += '<tbody>' + "`n"

    foreach ($comp in $comparisons) {
        $changeClass = if ($comp.Change -gt 0) { "positive" } elseif ($comp.Change -lt 0) { "negative" } else { "neutral" }
        $changePrefix = if ($comp.Change -gt 0) { "+" } else { "" }
        $html += "<tr>"
        $html += "<td>$($comp.Name)</td>"
        $html += "<td>$($comp.Before)</td>"
        $html += "<td>$($comp.After)</td>"
        $html += "<td class=`"$changeClass`">$changePrefix$($comp.Change)</td>"
        $html += "</tr>`n"
    }

    $html += '</tbody></table></div>' + "`n"

    return $html
}

# Generate recommendations based on health score
function global:Get-HealthRecommendations {
    param(
        [hashtable]$HealthScore
    )

    $recommendations = @()

    # Disk recommendations
    $diskCat = $HealthScore.Categories.Disk
    if ($diskCat.Score -lt 15) {
        $recommendations += @{
            Priority = "High"
            Category = "Disk"
            Title = "Free up disk space"
            Details = "Your system drive has limited free space. Run disk cleanup, remove temporary files, or uninstall unused programs."
        }
    }

    # Startup recommendations
    $startupCat = $HealthScore.Categories.Startup
    if ($startupCat.Score -lt 10) {
        $recommendations += @{
            Priority = "Medium"
            Category = "Startup"
            Title = "Reduce startup items"
            Details = "Too many programs launch at startup, slowing boot time. Disable unnecessary startup items via Task Manager > Startup."
        }
    }

    # Service recommendations
    $serviceCat = $HealthScore.Categories.Services
    if ($serviceCat.Score -lt 10) {
        $recommendations += @{
            Priority = "Medium"
            Category = "Services"
            Title = "Disable unnecessary services"
            Details = "Several unnecessary services are running. Consider disabling telemetry, Xbox, and other non-essential services."
        }
    }

    # Privacy recommendations
    $privacyCat = $HealthScore.Categories.Privacy
    if ($privacyCat.Score -lt 7) {
        $recommendations += @{
            Priority = "Medium"
            Category = "Privacy"
            Title = "Strengthen privacy settings"
            Details = "Windows telemetry and activity tracking are enabled. Consider disabling diagnostic data and activity history."
        }
    }

    # Security recommendations
    $securityCat = $HealthScore.Categories.Security
    if ($securityCat.Score -lt 7) {
        $recommendations += @{
            Priority = "High"
            Category = "Security"
            Title = "Review security settings"
            Details = "Windows Defender, firewall, or updates may not be fully active. Ensure real-time protection and firewall are enabled."
        }
    }

    # Freshness recommendations
    $freshnessCat = $HealthScore.Categories.Freshness
    if ($freshnessCat.Score -lt 10) {
        $recommendations += @{
            Priority = "Low"
            Category = "Freshness"
            Title = "Restart your system"
            Details = "System has been running for a while. A restart can clear memory, apply pending updates, and improve performance."
        }
    }

    # Network recommendations
    $networkCat = $HealthScore.Categories.Network
    if ($networkCat.Score -lt 10) {
        $recommendations += @{
            Priority = "Low"
            Category = "Network"
            Title = "Check network performance"
            Details = "Network latency or DNS resolution is slow. Consider changing DNS servers (1.1.1.1 or 8.8.8.8) or checking adapter settings."
        }
    }

    return $recommendations
}

# Get system info for report
function global:Get-ReportSystemInfo {
    $info = @{
        ComputerName = $env:COMPUTERNAME
        UserName = $env:USERNAME
        OSVersion = "Unknown"
        OSBuild = "Unknown"
        CPU = "Unknown"
        RAM = "Unknown"
        DiskInfo = "Unknown"
        NetworkAdapter = "Unknown"
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
    }

    try {
        $os = Get-WmiObject -Class Win32_OperatingSystem -ErrorAction Stop
        $info.OSVersion = $os.Caption
        $info.OSBuild = $os.BuildNumber
    } catch { Write-Log -Level "DEBUG" -Category "Report" -Message "Could not get OS info" }

    try {
        $cpu = Get-WmiObject -Class Win32_Processor -ErrorAction Stop | Select-Object -First 1
        $info.CPU = $cpu.Name.Trim()
    } catch { Write-Log -Level "DEBUG" -Category "Report" -Message "Could not get CPU info" }

    try {
        $cs = Get-WmiObject -Class Win32_ComputerSystem -ErrorAction Stop
        $info.RAM = "$([math]::Round($cs.TotalPhysicalMemory / 1GB, 1)) GB"
    } catch { Write-Log -Level "DEBUG" -Category "Report" -Message "Could not get RAM info" }

    try {
        $disks = Get-WmiObject -Class Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction Stop
        $diskStrings = @()
        foreach ($d in $disks) {
            $totalGB = [math]::Round($d.Size / 1GB, 1)
            $freeGB = [math]::Round($d.FreeSpace / 1GB, 1)
            $diskStrings += "$($d.DeviceID) $freeGB/$totalGB GB free"
        }
        $info.DiskInfo = $diskStrings -join " | "
    } catch { Write-Log -Level "DEBUG" -Category "Report" -Message "Could not get disk info" }

    try {
        $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
        if ($adapters) {
            $info.NetworkAdapter = "$($adapters.Name) ($($adapters.InterfaceDescription))"
        }
    } catch { Write-Log -Level "DEBUG" -Category "Report" -Message "Could not get network adapter info" }

    return $info
}

# Generate full HTML report
function global:New-HealthReport {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$HealthScore,
        [hashtable]$BeforeScore = $null,
        [array]$Operations = @(),
        [long]$SpaceRecovered = 0,
        [array]$Warnings = @(),
        [array]$Errors = @()
    )

    Write-Log -Level "INFO" -Category "Report" -Message "Generating health report HTML..."

    $sessionId = $HealthScore.SessionId
    $timestamp = $HealthScore.Timestamp
    $totalScore = $HealthScore.TotalScore
    $grade = $HealthScore.Grade

    # Get trend indicator
    $trend = "same"
    $trendIcon = "&#9654;"  # Right arrow
    $trendText = "No change"
    if ($BeforeScore) {
        $diff = $totalScore - $BeforeScore.TotalScore
        if ($diff -gt 0) {
            $trend = "up"
            $trendIcon = "&#9650;"  # Up triangle
            $trendText = "+$diff from last run"
        } elseif ($diff -lt 0) {
            $trend = "down"
            $trendIcon = "&#9660;"  # Down triangle
            $trendText = "$diff from last run"
        }
    }

    # Get system info
    $sysInfo = Get-ReportSystemInfo

    # Get recommendations
    $recommendations = Get-HealthRecommendations -HealthScore $HealthScore

    # Build score bar color
    $scoreColor = if ($totalScore -ge 80) { "#22c55e" } elseif ($totalScore -ge 60) { "#eab308" } elseif ($totalScore -ge 40) { "#f97316" } else { "#ef4444" }

    # Build category bars
    $categoryBars = ""
    foreach ($catKey in @("Disk", "Startup", "Services", "Network", "Privacy", "Security", "Freshness")) {
        $cat = $HealthScore.Categories[$catKey]
        $pct = if ($cat.MaxScore -gt 0) { [math]::Round(($cat.Score / $cat.MaxScore) * 100) } else { 0 }
        $barColor = if ($pct -ge 80) { "#22c55e" } elseif ($pct -ge 60) { "#eab308" } elseif ($pct -ge 40) { "#f97316" } else { "#ef4444" }

        $categoryBars += @"
        <div class="category-row">
            <div class="category-label">$($cat.Name)</div>
            <div class="category-bar-bg">
                <div class="category-bar-fill" style="width:${pct}%;background:${barColor}"></div>
            </div>
            <div class="category-score">$($cat.Score)/$($cat.MaxScore)</div>
        </div>
"@
    }

    # Build detailed items
    $detailSections = ""
    foreach ($catKey in @("Disk", "Startup", "Services", "Network", "Privacy", "Security", "Freshness")) {
        $cat = $HealthScore.Categories[$catKey]
        $itemsHtml = ""
        foreach ($item in $cat.Items) {
            $statusClass = switch ($item.Status) {
                "Good" { "item-good" }
                "Warning" { "item-warning" }
                "Critical" { "item-critical" }
                default { "item-neutral" }
            }
            $statusIcon = switch ($item.Status) {
                "Good" { "&#10003;" }
                "Warning" { "&#9888;" }
                "Critical" { "&#10007;" }
                default { "&#8226;" }
            }
            $itemsHtml += @"
            <div class="detail-item $statusClass">
                <span class="item-icon">$statusIcon</span>
                <span class="item-name">$($item.Name)</span>
                <span class="item-value">$($item.Value)</span>
                <span class="item-note">$($item.Note)</span>
            </div>
"@
        }

        $detailSections += @"
        <div class="detail-category">
            <h3>$($cat.Name)</h3>
            <p class="category-detail-desc">$($cat.Details)</p>
            $itemsHtml
        </div>
"@
    }

    # Build operations table
    $operationsHtml = ""
    if ($Operations.Count -gt 0) {
        $operationsHtml = '<div class="operations-section">' + "`n"
        $operationsHtml += '<h2>Operations Performed</h2>' + "`n"
        $operationsHtml += '<table class="operations-table"><thead><tr><th>Operation</th><th>Status</th><th>Space Recovered</th><th>Time</th></tr></thead><tbody>' + "`n"
        foreach ($op in $Operations) {
            $statusClass = if ($op.Success) { "op-success" } else { "op-failed" }
            $statusText = if ($op.Success) { "Success" } else { "Failed" }
            $space = if ($op.SpaceRecovered) { Format-FileSize -Bytes $op.SpaceRecovered } else { "-" }
            $time = if ($op.Duration) { "$([math]::Round($op.Duration, 1))s" } else { "-" }
            $operationsHtml += "<tr><td>$($op.Name)</td><td class=`"$statusClass`">$statusText</td><td>$space</td><td>$time</td></tr>`n"
        }
        $operationsHtml += '</tbody></table></div>' + "`n"
    }

    # Build comparison section
    $comparisonHtml = ""
    if ($BeforeScore) {
        $comparisonHtml = New-ComparisonChart -Before $BeforeScore -After @{
            TotalScore = $HealthScore.TotalScore
            DiskFreeGB = ($sysInfo.DiskInfo -split '/')[0] -replace '[^\d.]', ''
        }
    }

    # Build warnings/errors section
    $alertsHtml = ""
    if ($Warnings.Count -gt 0 -or $Errors.Count -gt 0) {
        $alertsHtml = '<div class="alerts-section"><h2>Warnings & Errors</h2>' + "`n"
        foreach ($w in $Warnings) {
            $alertsHtml += "<div class=`"alert alert-warning`"><span>&#9888;</span> $w</div>`n"
        }
        foreach ($e in $Errors) {
            $alertsHtml += "<div class=`"alert alert-error`"><span>&#10007;</span> $e</div>`n"
        }
        $alertsHtml += '</div>' + "`n"
    }

    # Build recommendations section
    $recoHtml = ""
    if ($recommendations.Count -gt 0) {
        $recoHtml = '<div class="recommendations-section"><h2>Recommendations</h2>' + "`n"
        foreach ($rec in $recommendations) {
            $priorityClass = switch ($rec.Priority) {
                "High" { "reco-high" }
                "Medium" { "reco-medium" }
                "Low" { "reco-low" }
                default { "reco-medium" }
            }
            $recoHtml += @"
            <div class="recommendation $priorityClass">
                <div class="reco-header">
                    <span class="reco-priority">$($rec.Priority)</span>
                    <span class="reco-category">$($rec.Category)</span>
                    <span class="reco-title">$($rec.Title)</span>
                </div>
                <div class="reco-details">$($rec.Details)</div>
            </div>
"@
        }
        $recoHtml += '</div>' + "`n"
    }

    # Assemble full HTML report
    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>WinTune Pro - Health Report</title>
    <style>
        :root {
            --bg-primary: #0f172a;
            --bg-secondary: #1e293b;
            --bg-card: #1e293b;
            --bg-card-hover: #334155;
            --text-primary: #f1f5f9;
            --text-secondary: #94a3b8;
            --text-muted: #64748b;
            --accent-blue: #3b82f6;
            --accent-cyan: #06b6d4;
            --accent-green: #22c55e;
            --accent-yellow: #eab308;
            --accent-orange: #f97316;
            --accent-red: #ef4444;
            --border-color: #334155;
            --score-green: #22c55e;
            --score-yellow: #eab308;
            --score-orange: #f97316;
            --score-red: #ef4444;
        }

        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, sans-serif;
            background: var(--bg-primary);
            color: var(--text-primary);
            line-height: 1.6;
            padding: 0;
        }

        .report-container {
            max-width: 1000px;
            margin: 0 auto;
            padding: 24px;
        }

        /* Header */
        .report-header {
            text-align: center;
            padding: 40px 20px;
            background: linear-gradient(135deg, #1e3a5f 0%, #0f172a 100%);
            border-bottom: 2px solid var(--accent-blue);
            margin-bottom: 32px;
        }

        .report-header h1 {
            font-size: 2.5rem;
            font-weight: 700;
            color: var(--text-primary);
            margin-bottom: 8px;
            letter-spacing: -0.5px;
        }

        .report-header h1 span {
            color: var(--accent-blue);
        }

        .report-subtitle {
            color: var(--text-secondary);
            font-size: 1rem;
            margin-bottom: 16px;
        }

        .report-meta {
            display: flex;
            justify-content: center;
            gap: 24px;
            color: var(--text-muted);
            font-size: 0.875rem;
            flex-wrap: wrap;
        }

        .report-meta span {
            background: rgba(59, 130, 246, 0.1);
            padding: 4px 12px;
            border-radius: 4px;
            border: 1px solid rgba(59, 130, 246, 0.2);
        }

        /* Executive Summary */
        .executive-summary {
            text-align: center;
            padding: 48px 24px;
            background: var(--bg-card);
            border-radius: 16px;
            border: 1px solid var(--border-color);
            margin-bottom: 32px;
        }

        .score-circle {
            width: 180px;
            height: 180px;
            border-radius: 50%;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            margin: 0 auto 24px;
            border: 6px solid $scoreColor;
            background: rgba(0,0,0,0.3);
        }

        .score-number {
            font-size: 4rem;
            font-weight: 800;
            color: $scoreColor;
            line-height: 1;
        }

        .score-label {
            font-size: 0.875rem;
            color: var(--text-secondary);
            text-transform: uppercase;
            letter-spacing: 1px;
        }

        .grade-badge {
            display: inline-block;
            font-size: 1.5rem;
            font-weight: 700;
            padding: 8px 24px;
            border-radius: 8px;
            background: $scoreColor;
            color: #000;
            margin-bottom: 16px;
        }

        .trend-indicator {
            font-size: 1rem;
            color: $(if ($trend -eq "up") { "#22c55e" } elseif ($trend -eq "down") { "#ef4444" } else { "#94a3b8" });
            margin-top: 8px;
        }

        /* Category Scores */
        .category-scores {
            background: var(--bg-card);
            border-radius: 12px;
            padding: 24px;
            border: 1px solid var(--border-color);
            margin-bottom: 32px;
        }

        .category-scores h2 {
            font-size: 1.25rem;
            margin-bottom: 20px;
            color: var(--text-primary);
            border-bottom: 1px solid var(--border-color);
            padding-bottom: 12px;
        }

        .category-row {
            display: flex;
            align-items: center;
            margin-bottom: 12px;
            gap: 12px;
        }

        .category-label {
            width: 160px;
            font-size: 0.875rem;
            color: var(--text-secondary);
            flex-shrink: 0;
        }

        .category-bar-bg {
            flex: 1;
            height: 24px;
            background: rgba(255,255,255,0.05);
            border-radius: 12px;
            overflow: hidden;
        }

        .category-bar-fill {
            height: 100%;
            border-radius: 12px;
            transition: width 0.5s ease;
        }

        .category-score {
            width: 60px;
            text-align: right;
            font-size: 0.875rem;
            font-weight: 600;
            color: var(--text-primary);
        }

        /* Detailed Breakdown */
        .detailed-breakdown {
            background: var(--bg-card);
            border-radius: 12px;
            padding: 24px;
            border: 1px solid var(--border-color);
            margin-bottom: 32px;
        }

        .detailed-breakdown h2 {
            font-size: 1.25rem;
            margin-bottom: 20px;
            color: var(--text-primary);
            border-bottom: 1px solid var(--border-color);
            padding-bottom: 12px;
        }

        .detail-category {
            margin-bottom: 24px;
        }

        .detail-category h3 {
            font-size: 1rem;
            color: var(--accent-cyan);
            margin-bottom: 8px;
        }

        .category-detail-desc {
            font-size: 0.8rem;
            color: var(--text-muted);
            margin-bottom: 12px;
        }

        .detail-item {
            display: flex;
            align-items: center;
            padding: 8px 12px;
            border-radius: 6px;
            margin-bottom: 4px;
            font-size: 0.875rem;
            gap: 12px;
        }

        .item-good { background: rgba(34, 197, 94, 0.08); }
        .item-warning { background: rgba(234, 179, 8, 0.08); }
        .item-critical { background: rgba(239, 68, 68, 0.08); }
        .item-neutral { background: rgba(255,255,255,0.03); }

        .item-icon {
            width: 20px;
            text-align: center;
            flex-shrink: 0;
        }

        .item-good .item-icon { color: var(--accent-green); }
        .item-warning .item-icon { color: var(--accent-yellow); }
        .item-critical .item-icon { color: var(--accent-red); }

        .item-name {
            font-weight: 500;
            color: var(--text-primary);
            flex-shrink: 0;
        }

        .item-value {
            color: var(--text-secondary);
            flex-shrink: 0;
            margin-left: auto;
        }

        .item-note {
            color: var(--text-muted);
            font-size: 0.8rem;
            flex-shrink: 0;
            width: 200px;
            text-align: right;
        }

        /* Operations Table */
        .operations-section {
            background: var(--bg-card);
            border-radius: 12px;
            padding: 24px;
            border: 1px solid var(--border-color);
            margin-bottom: 32px;
        }

        .operations-section h2 {
            font-size: 1.25rem;
            margin-bottom: 16px;
            color: var(--text-primary);
            border-bottom: 1px solid var(--border-color);
            padding-bottom: 12px;
        }

        .operations-table {
            width: 100%;
            border-collapse: collapse;
        }

        .operations-table th,
        .operations-table td {
            padding: 10px 12px;
            text-align: left;
            border-bottom: 1px solid var(--border-color);
            font-size: 0.875rem;
        }

        .operations-table th {
            color: var(--text-muted);
            font-weight: 600;
            text-transform: uppercase;
            font-size: 0.75rem;
            letter-spacing: 0.5px;
        }

        .op-success { color: var(--accent-green); font-weight: 600; }
        .op-failed { color: var(--accent-red); font-weight: 600; }

        /* System Information */
        .system-info {
            background: var(--bg-card);
            border-radius: 12px;
            padding: 24px;
            border: 1px solid var(--border-color);
            margin-bottom: 32px;
        }

        .system-info h2 {
            font-size: 1.25rem;
            margin-bottom: 16px;
            color: var(--text-primary);
            border-bottom: 1px solid var(--border-color);
            padding-bottom: 12px;
        }

        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
            gap: 12px;
        }

        .info-item {
            display: flex;
            gap: 8px;
            font-size: 0.875rem;
        }

        .info-label {
            color: var(--text-muted);
            min-width: 120px;
            flex-shrink: 0;
        }

        .info-value {
            color: var(--text-primary);
        }

        /* Comparison */
        .comparison-section {
            background: var(--bg-card);
            border-radius: 12px;
            padding: 24px;
            border: 1px solid var(--border-color);
            margin-bottom: 32px;
        }

        .comparison-section h2 {
            font-size: 1.25rem;
            margin-bottom: 16px;
            color: var(--text-primary);
            border-bottom: 1px solid var(--border-color);
            padding-bottom: 12px;
        }

        .comparison-table {
            width: 100%;
            border-collapse: collapse;
        }

        .comparison-table th,
        .comparison-table td {
            padding: 10px 12px;
            text-align: left;
            border-bottom: 1px solid var(--border-color);
            font-size: 0.875rem;
        }

        .comparison-table th {
            color: var(--text-muted);
            font-weight: 600;
            text-transform: uppercase;
            font-size: 0.75rem;
            letter-spacing: 0.5px;
        }

        .positive { color: var(--accent-green); font-weight: 600; }
        .negative { color: var(--accent-red); font-weight: 600; }
        .neutral { color: var(--text-muted); }

        /* Alerts */
        .alerts-section {
            background: var(--bg-card);
            border-radius: 12px;
            padding: 24px;
            border: 1px solid var(--border-color);
            margin-bottom: 32px;
        }

        .alerts-section h2 {
            font-size: 1.25rem;
            margin-bottom: 16px;
            color: var(--text-primary);
            border-bottom: 1px solid var(--border-color);
            padding-bottom: 12px;
        }

        .alert {
            padding: 10px 14px;
            border-radius: 6px;
            margin-bottom: 8px;
            font-size: 0.875rem;
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .alert-warning {
            background: rgba(234, 179, 8, 0.1);
            border: 1px solid rgba(234, 179, 8, 0.3);
            color: var(--accent-yellow);
        }

        .alert-error {
            background: rgba(239, 68, 68, 0.1);
            border: 1px solid rgba(239, 68, 68, 0.3);
            color: var(--accent-red);
        }

        /* Recommendations */
        .recommendations-section {
            background: var(--bg-card);
            border-radius: 12px;
            padding: 24px;
            border: 1px solid var(--border-color);
            margin-bottom: 32px;
        }

        .recommendations-section h2 {
            font-size: 1.25rem;
            margin-bottom: 16px;
            color: var(--text-primary);
            border-bottom: 1px solid var(--border-color);
            padding-bottom: 12px;
        }

        .recommendation {
            padding: 16px;
            border-radius: 8px;
            margin-bottom: 12px;
            border-left: 4px solid;
        }

        .reco-high {
            background: rgba(239, 68, 68, 0.08);
            border-left-color: var(--accent-red);
        }

        .reco-medium {
            background: rgba(234, 179, 8, 0.08);
            border-left-color: var(--accent-yellow);
        }

        .reco-low {
            background: rgba(59, 130, 246, 0.08);
            border-left-color: var(--accent-blue);
        }

        .reco-header {
            display: flex;
            align-items: center;
            gap: 12px;
            margin-bottom: 8px;
        }

        .reco-priority {
            font-size: 0.7rem;
            font-weight: 700;
            text-transform: uppercase;
            padding: 2px 8px;
            border-radius: 4px;
            letter-spacing: 0.5px;
        }

        .reco-high .reco-priority { background: var(--accent-red); color: #000; }
        .reco-medium .reco-priority { background: var(--accent-yellow); color: #000; }
        .reco-low .reco-priority { background: var(--accent-blue); color: #fff; }

        .reco-category {
            font-size: 0.75rem;
            color: var(--text-muted);
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }

        .reco-title {
            font-weight: 600;
            color: var(--text-primary);
        }

        .reco-details {
            font-size: 0.85rem;
            color: var(--text-secondary);
            line-height: 1.5;
        }

        /* Footer */
        .report-footer {
            text-align: center;
            padding: 24px;
            color: var(--text-muted);
            font-size: 0.8rem;
            border-top: 1px solid var(--border-color);
            margin-top: 24px;
        }

        .report-footer a {
            color: var(--accent-blue);
            text-decoration: none;
        }

        /* Print styles */
        @media print {
            body {
                background: #fff;
                color: #1a1a1a;
            }

            .report-container {
                max-width: 100%;
                padding: 0;
            }

            .report-header {
                background: #f8f9fa;
                border-bottom: 2px solid #333;
            }

            .report-header h1 span {
                color: #333;
            }

            .executive-summary,
            .category-scores,
            .detailed-breakdown,
            .operations-section,
            .system-info,
            .comparison-section,
            .alerts-section,
            .recommendations-section {
                background: #fff;
                border: 1px solid #ddd;
            }

            .score-circle {
                border-color: #333;
                background: #fff;
            }

            .score-number { color: #333; }

            .category-bar-bg {
                background: #eee;
            }

            .detail-item {
                border: 1px solid #eee;
            }

            :root {
                --text-primary: #1a1a1a;
                --text-secondary: #555;
                --text-muted: #888;
            }
        }

        /* Responsive */
        @media (max-width: 768px) {
            .report-container {
                padding: 12px;
            }

            .report-header h1 {
                font-size: 1.75rem;
            }

            .report-meta {
                flex-direction: column;
                align-items: center;
                gap: 8px;
            }

            .score-circle {
                width: 140px;
                height: 140px;
            }

            .score-number {
                font-size: 3rem;
            }

            .category-row {
                flex-wrap: wrap;
            }

            .category-label {
                width: 100%;
            }

            .category-bar-bg {
                flex: 1;
            }

            .detail-item {
                flex-wrap: wrap;
            }

            .item-note {
                width: 100%;
                text-align: left;
            }

            .info-grid {
                grid-template-columns: 1fr;
            }

            .reco-header {
                flex-wrap: wrap;
            }
        }
    </style>
</head>
<body>
    <div class="report-container">
        <!-- Header -->
        <div class="report-header">
            <h1>Win<span>Tune</span> Pro</h1>
            <div class="report-subtitle">System Health Assessment Report</div>
            <div class="report-meta">
                <span>&#128197; $timestamp</span>
                <span>&#128187; $($sysInfo.ComputerName)</span>
                <span>&#128272; Session: $sessionId</span>
            </div>
        </div>

        <!-- Executive Summary -->
        <div class="executive-summary">
            <div class="grade-badge">Grade $grade</div>
            <div class="score-circle">
                <div class="score-number">$totalScore</div>
                <div class="score-label">Health Score</div>
            </div>
            <div class="trend-indicator">$trendIcon $trendText</div>
        </div>

        <!-- Category Scores -->
        <div class="category-scores">
            <h2>Category Scores</h2>
            $categoryBars
        </div>

        <!-- Detailed Breakdown -->
        <div class="detailed-breakdown">
            <h2>Detailed Breakdown</h2>
            $detailSections
        </div>

        $operationsHtml

        <!-- System Information -->
        <div class="system-info">
            <h2>System Information</h2>
            <div class="info-grid">
                <div class="info-item">
                    <span class="info-label">Operating System</span>
                    <span class="info-value">$($sysInfo.OSVersion) (Build $($sysInfo.OSBuild))</span>
                </div>
                <div class="info-item">
                    <span class="info-label">Processor</span>
                    <span class="info-value">$($sysInfo.CPU)</span>
                </div>
                <div class="info-item">
                    <span class="info-label">Memory</span>
                    <span class="info-value">$($sysInfo.RAM)</span>
                </div>
                <div class="info-item">
                    <span class="info-label">Storage</span>
                    <span class="info-value">$($sysInfo.DiskInfo)</span>
                </div>
                <div class="info-item">
                    <span class="info-label">Network</span>
                    <span class="info-value">$($sysInfo.NetworkAdapter)</span>
                </div>
                <div class="info-item">
                    <span class="info-label">PowerShell</span>
                    <span class="info-value">v$($sysInfo.PowerShellVersion)</span>
                </div>
            </div>
        </div>

        $comparisonHtml

        $alertsHtml

        $recoHtml

        <!-- Footer -->
        <div class="report-footer">
            <p>Generated by <strong>WinTune Pro</strong> | $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
            <p>This report was generated automatically. Results may vary based on system configuration.</p>
        </div>
    </div>
</body>
</html>
"@

    Write-Log -Level "SUCCESS" -Category "Report" -Message "Health report HTML generated ($($html.Length) bytes)"
    return $html
}

# Export report to file
function global:Export-HealthReport {
    param(
        [Parameter(Mandatory=$true)]
        [string]$HtmlContent,
        [string]$FileName = "",
        [string]$OutputPath = ""
    )

    if (-not $FileName) {
        $FileName = "WinTune_HealthReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
    }

    if (-not $OutputPath) {
        $paths = Get-Paths
        $OutputPath = $paths.Reports
    }

    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    $filePath = Join-Path $OutputPath $FileName

    try {
        $HtmlContent | Out-File -FilePath $filePath -Encoding UTF8 -Force
        Write-Log -Level "SUCCESS" -Category "Report" -Message "Report exported to: $filePath"
        return $filePath
    } catch {
        Write-Log -Level "ERROR" -Category "Report" -Message "Error exporting report: $($_.Exception.Message)"
        return $null
    }
}

# Generate and export report in one step
function global:New-AndExportHealthReport {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$HealthScore,
        [hashtable]$BeforeScore = $null,
        [array]$Operations = @(),
        [long]$SpaceRecovered = 0,
        [array]$Warnings = @(),
        [array]$Errors = @(),
        [string]$FileName = ""
    )

    # Save to history
    Save-HealthScore -HealthScore $HealthScore -SpaceRecovered $SpaceRecovered

    # Generate HTML
    $html = New-HealthReport -HealthScore $HealthScore -BeforeScore $BeforeScore -Operations $Operations -SpaceRecovered $SpaceRecovered -Warnings $Warnings -Errors $Errors

    # Export to file
    $filePath = Export-HealthReport -HtmlContent $html -FileName $FileName

    return @{
        Html = $html
        FilePath = $filePath
        Success = ($filePath -ne $null)
    }
}

# Wrapper for New-SystemReport (used by main script)
function global:New-SystemReport {
    param(
        [ValidateSet("HTML", "TXT")]
        [string]$Format = "HTML"
    )
    try {
        $hs = Get-SystemHealthScore
        $result = New-AndExportHealthReport -HealthScore $hs
        if ($result -and $result.FilePath) { return $result.FilePath }
    } catch { }
    return $null
}


