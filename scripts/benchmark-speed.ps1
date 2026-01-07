<#
.SYNOPSIS
    LLM Speed Benchmark Script with Documentation Output
.DESCRIPTION
    Benchmarks multiple LLM models for inference speed and resource usage.
    Outputs results to console, JSON (machine-readable), and CSV (tabular).
.PARAMETER OutputDir
    Directory to save results. Default: C:\Users\14104\llm-benchmarks\results
.PARAMETER Models
    Array of model names to benchmark. Default: common model sizes
.PARAMETER Prompt
    Custom prompt to use for benchmarking
.PARAMETER Verbose
    Show detailed output during benchmarking
.EXAMPLE
    .\benchmark-speed.ps1
    Runs default benchmarks on standard model set
.EXAMPLE
    .\benchmark-speed.ps1 -Models @("llama3.1:8b", "gpt-oss:120b")
    Benchmarks only specified models
#>

param(
    [string]$OutputDir = "C:\Users\14104\llm-benchmarks\results",
    [string[]]$Models = @("llama3.1:8b", "qwen2.5:14b", "qwen2.5:32b", "gpt-oss:120b"),
    [string]$Prompt = "Explain the theory of general relativity in exactly 200 words. Be precise and technical.",
    [switch]$SkipPull
)

# Import utility functions
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptDir\utils\Export-BenchmarkResult.ps1"

# Configure GPU for maximum utilization
Set-OllamaGpuConfig -NumGpu 999 -NumThread 8

Write-Host @"

╔═══════════════════════════════════════════════════════════════╗
║           LLM SPEED BENCHMARK SUITE v1.0                      ║
║           Hardware Performance Testing                        ║
╚═══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# Display hardware profile
$hardware = Get-HardwareProfile
Write-Host "Hardware Profile:" -ForegroundColor Yellow
Write-Host "  GPU:  $($hardware.gpu) ($($hardware.vram_gb)GB VRAM)"
Write-Host "  RAM:  $($hardware.ram_gb)GB"
Write-Host "  CPU:  $($hardware.cpu)"
Write-Host ""

$results = @()
$csvResults = @()

foreach ($model in $Models) {
    Write-Host "`n$('─' * 60)" -ForegroundColor DarkGray
    Write-Host "Testing: $model" -ForegroundColor Cyan
    Write-Host "$('─' * 60)" -ForegroundColor DarkGray

    # Pull model if not present (unless skipped)
    if (-not $SkipPull) {
        Write-Host "  Ensuring model is available..." -ForegroundColor DarkGray
        ollama pull $model 2>&1 | Out-Null
    }

    # Warm up run (first run is often slower due to model loading)
    Write-Host "  Warming up model..." -ForegroundColor DarkGray
    ollama run $model "Hello" 2>&1 | Out-Null

    # Get model info before benchmark
    Start-Sleep -Milliseconds 500
    $psInfoBefore = ollama ps 2>&1 | Out-String

    # Run benchmark with timing
    Write-Host "  Running benchmark..." -ForegroundColor DarkGray
    $startTime = Get-Date

    # Capture verbose output for token stats
    $output = ollama run $model $Prompt 2>&1 | Out-String
    $endTime = Get-Date
    $totalSeconds = ($endTime - $startTime).TotalSeconds

    # Get model loading info after run
    $psInfo = ollama ps 2>&1 | Out-String

    # Parse CPU/GPU split from ollama ps output
    # Format: "72%/28% CPU/GPU" or similar
    $gpuPercent = 100
    $cpuPercent = 0
    if ($psInfo -match '(\d+)%/(\d+)%\s*(CPU/GPU|GPU/CPU)') {
        if ($Matches[3] -eq "CPU/GPU") {
            $cpuPercent = [int]$Matches[1]
            $gpuPercent = [int]$Matches[2]
        } else {
            $gpuPercent = [int]$Matches[1]
            $cpuPercent = [int]$Matches[2]
        }
    }

    # Try to get token stats from verbose mode (if available)
    # Note: ollama run doesn't always provide this, so we estimate
    $wordCount = ($output -split '\s+').Count
    $estimatedTokens = [math]::Round($wordCount * 1.3)  # Rough token estimate
    $estimatedTps = if ($totalSeconds -gt 0) { [math]::Round($estimatedTokens / $totalSeconds, 1) } else { 0 }

    # Get VRAM usage
    try {
        $vramUsed = [math]::Round([int](nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits) / 1024, 1)
    } catch {
        $vramUsed = 0
    }

    # Get model size info
    $modelInfo = ollama show $model 2>&1 | Out-String
    $paramCount = 0
    $quantization = "Unknown"
    if ($modelInfo -match 'parameters\s+(\d+\.?\d*)([BM])') {
        $paramCount = [double]$Matches[1]
        if ($Matches[2] -eq "M") { $paramCount = $paramCount / 1000 }
    }
    if ($modelInfo -match 'quantization\s+(\S+)') {
        $quantization = $Matches[1]
    }

    # Build result object
    $result = @{
        model = $model
        parameters_b = $paramCount
        quantization = $quantization
        metrics = @{
            tokens_per_second = $estimatedTps
            total_time_seconds = [math]::Round($totalSeconds, 2)
            gpu_percent = $gpuPercent
            cpu_percent = $cpuPercent
            vram_used_gb = $vramUsed
            estimated_output_tokens = $estimatedTokens
        }
        pass = ($estimatedTps -gt 1)
        notes = ""
    }

    $results += $result

    # Build CSV row
    $csvResults += [PSCustomObject]@{
        timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        model = $model
        parameters_b = $paramCount
        quantization = $quantization
        tokens_per_second = $estimatedTps
        total_time_seconds = [math]::Round($totalSeconds, 2)
        gpu_percent = $gpuPercent
        cpu_percent = $cpuPercent
        vram_used_gb = $vramUsed
    }

    # Display result
    $grade = Get-SpeedGrade -TokensPerSecond $estimatedTps
    $gradeColor = switch ($grade) {
        "A" { "Green" }
        "B" { "Yellow" }
        "C" { "DarkYellow" }
        default { "Red" }
    }

    Write-Host ""
    Write-Host "  Results:" -ForegroundColor White
    Write-Host "    Speed:      " -NoNewline; Write-Host "$estimatedTps tok/s [$grade]" -ForegroundColor $gradeColor
    Write-Host "    Time:       $([math]::Round($totalSeconds, 1))s"
    Write-Host "    GPU/CPU:    $gpuPercent% / $cpuPercent%"
    Write-Host "    VRAM Used:  $vramUsed GB"
}

# Export results
Write-Host "`n$('═' * 60)" -ForegroundColor Cyan
Write-Host "EXPORTING RESULTS" -ForegroundColor Cyan
Write-Host "$('═' * 60)`n" -ForegroundColor Cyan

Export-JsonResult -TestName "speed_benchmark" -Category "hardware" -Results $results -OutputDir "$OutputDir\raw"
Export-CsvResult -TestName "speed_benchmark" -Results $csvResults -OutputDir "$OutputDir\csv"

# Console summary
Write-ConsoleReport -Results $results -Title "SPEED BENCHMARK SUMMARY"

# Grade legend
Write-Host "Grade Legend:" -ForegroundColor DarkGray
Write-Host "  A: >30 tok/s (Interactive)" -ForegroundColor Green
Write-Host "  B: 10-30 tok/s (Usable)" -ForegroundColor Yellow
Write-Host "  C: 3-10 tok/s (Slow)" -ForegroundColor DarkYellow
Write-Host "  D: <3 tok/s (Batch only)" -ForegroundColor Red
Write-Host ""
