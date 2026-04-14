# WinTune Pro - System Benchmark Module
# PowerShell 5.1+ Compatible

function global:Invoke-SystemBenchmark {
    param([bool]$QuickMode = $false, [bool]$TestMode = $false)
    $results = @{ Overall = 0; CPU = 0; Memory = 0; Disk = 0; Network = 0; Duration = 0; Details = @() }
    $startTime = Get-Date
    $results.CPU = Invoke-CPUBenchmark -Quick $QuickMode; $results.Details += "CPU Score: $($results.CPU)"
    $results.Memory = Invoke-MemoryBenchmark; $results.Details += "Memory Score: $($results.Memory)"
    $results.Disk = Invoke-DiskBenchmark -Quick $QuickMode; $results.Details += "Disk Score: $($results.Disk)"
    if (-not $QuickMode) { $results.Network = Invoke-NetworkBenchmark -TestMode $TestMode; $results.Details += "Network Score: $($results.Network)" } else { $results.Network = 50 }
    $results.Overall = [math]::Round(($results.CPU + $results.Memory + $results.Disk + $results.Network) / 4, 0)
    $results.Duration = ((Get-Date) - $startTime).TotalSeconds
    return $results
}

function global:Invoke-CPUBenchmark {
    param([bool]$Quick = $false)
    $iterations = if ($Quick) { 10000 } else { 100000 }; $score = 100
    try {
        $startTime = Get-Date; $result = 0
        for ($i = 0; $i -lt $iterations; $i++) { $result += [math]::Sqrt($i) * [math]::Sin($i) }
        $elapsed = ((Get-Date) - $startTime).TotalMilliseconds
        $baseTime = if ($Quick) { 50 } else { 500 }; $score = [math]::Round(($baseTime / $elapsed) * 50, 0)
        if ($score -gt 100) { $score = 100 }; if ($score -lt 10) { $score = 10 }
    } catch { $score = 50 }
    return $score
}

function global:Invoke-MemoryBenchmark {
    $score = 100
    try {
        $os = Get-WmiObject -Class Win32_OperatingSystem; $totalMem = $os.TotalVisibleMemorySize / 1MB; $freeMem = $os.FreePhysicalMemory / 1MB
        $usedPercent = (($totalMem - $freeMem) / $totalMem) * 100
        if ($usedPercent -gt 90) { $score = 30 } elseif ($usedPercent -gt 80) { $score = 50 } elseif ($usedPercent -gt 70) { $score = 70 } else { $score = 90 }
        if ($totalMem -ge 16) { $score = [math]::Min(100, $score + 10) }
    } catch { $score = 50 }
    return $score
}

function global:Invoke-DiskBenchmark {
    param([bool]$Quick = $false)
    $score = 100
    try {
        $testFile = Join-Path $env:TEMP "wintune_benchmark_test.tmp"; $fileSize = if ($Quick) { 1MB } else { 10MB }
        $writeStart = Get-Date; $buffer = [byte[]]::new($fileSize); (New-Object Random).NextBytes($buffer)
        [System.IO.File]::WriteAllBytes($testFile, $buffer); $writeTime = ((Get-Date) - $writeStart).TotalMilliseconds
        $readStart = Get-Date; [System.IO.File]::ReadAllBytes($testFile) | Out-Null; $readTime = ((Get-Date) - $readStart).TotalMilliseconds
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
        $expectedWriteTime = if ($Quick) { 100 } else { 500 }; $expectedReadTime = if ($Quick) { 50 } else { 200 }
        $writeScore = ($expectedWriteTime / $writeTime) * 50; $readScore = ($expectedReadTime / $readTime) * 50
        $score = [math]::Round(($writeScore + $readScore), 0)
        if ($score -gt 100) { $score = 100 }; if ($score -lt 10) { $score = 10 }
    } catch { $score = 50 }
    return $score
}

function global:Invoke-NetworkBenchmark {
    param([bool]$TestMode = $false)
    $score = 100; if ($TestMode) { return 50 }
    try {
        $latency = 0; $success = 0; $targets = @("8.8.8.8", "1.1.1.1")
        foreach ($target in $targets) {
            try { $ping = Test-Connection -ComputerName $target -Count 2 -ErrorAction SilentlyContinue; if ($ping) { $latency += ($ping | Measure-Object -Property ResponseTime -Average).Average; $success++ } } catch { Write-Log -Level "WARNING" -Category "System" -Message $_.Exception.Message }
        }
        if ($success -gt 0) {
            $avgLatency = $latency / $success
            if ($avgLatency -lt 10) { $score = 100 } elseif ($avgLatency -lt 30) { $score = 90 } elseif ($avgLatency -lt 50) { $score = 80 } elseif ($avgLatency -lt 100) { $score = 70 } elseif ($avgLatency -lt 200) { $score = 50 } else { $score = 30 }
        } else { $score = 20 }
    } catch { $score = 50 }
    return $score
}

function global:Get-BenchmarkRating {
    param([int]$Score)
    if ($Score -ge 90) { return "Excellent" }
    if ($Score -ge 75) { return "Very Good" }
    if ($Score -ge 60) { return "Good" }
    if ($Score -ge 40) { return "Fair" }
    return "Poor"
}

function global:Get-BenchmarkBaseline {
    return @{
        CPU = @{ Excellent = 80; Good = 60; Poor = 30 }
        Memory = @{ Excellent = 85; Good = 65; Poor = 40 }
        Disk = @{ Excellent = 70; Good = 50; Poor = 25 }
        Network = @{ Excellent = 80; Good = 60; Poor = 30 }
        Overall = @{ Excellent = 75; Good = 55; Poor = 30 }
    }
}

