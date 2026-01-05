<#
.SYNOPSIS
    Aggregate benchmark results from multiple runs.
.DESCRIPTION
    Combines multiple benchmark result files to calculate statistics including
    mean, standard deviation, confidence intervals, and trends over time.
.PARAMETER ResultDir
    Directory containing result JSON files.
.PARAMETER Pattern
    Glob pattern to filter result files. Default: *.json
.PARAMETER OutputFile
    Optional path to save aggregated results.
.PARAMETER ShowDetails
    Show detailed per-test statistics.
.EXAMPLE
    .\aggregate-results.ps1 -ResultDir "results/raw" -Pattern "*bundle*"
.EXAMPLE
    .\aggregate-results.ps1 -ResultDir "results/raw" -OutputFile "results/aggregated/summary.json"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ResultDir,

    [string]$Pattern = "*.json",

    [string]$OutputFile = "",

    [switch]$ShowDetails
)

# Import utilities
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptDir\utils\Get-BenchmarkStats.ps1"
. "$scriptDir\utils\Export-BenchmarkResult.ps1"

Write-Host @"

╔═══════════════════════════════════════════════════════════════╗
║           BENCHMARK RESULT AGGREGATOR v1.0                    ║
║           Multi-Run Statistical Analysis                      ║
╚═══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# Find result files
$resultPath = Resolve-Path $ResultDir -ErrorAction Stop
$files = Get-ChildItem $resultPath -Filter $Pattern -Recurse | Where-Object { $_.Extension -eq ".json" }

if ($files.Count -eq 0) {
    Write-Error "No result files found matching pattern: $Pattern"
    exit 1
}

Write-Host "Found $($files.Count) result files" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor DarkGray

# Load and aggregate results
$allResults = @()
$byBundle = @{}
$byTimestamp = @{}

foreach ($file in $files) {
    try {
        $content = Get-Content $file.FullName -Raw | ConvertFrom-Json

        $bundleName = $content.meta.bundle_name
        $timestamp = $content.meta.timestamp

        if (-not $byBundle.ContainsKey($bundleName)) {
            $byBundle[$bundleName] = @()
        }
        $byBundle[$bundleName] += $content

        $allResults += $content
        Write-Host "  Loaded: $($file.Name)" -ForegroundColor DarkGray
    }
    catch {
        Write-Warning "Failed to load $($file.Name): $($_.Exception.Message)"
    }
}

Write-Host "`n$('═' * 60)" -ForegroundColor Cyan
Write-Host "AGGREGATED STATISTICS" -ForegroundColor Cyan
Write-Host "$('═' * 60)`n" -ForegroundColor Cyan

# Aggregate by bundle
foreach ($bundleName in $byBundle.Keys) {
    $bundleResults = $byBundle[$bundleName]

    Write-Host "Bundle: $bundleName" -ForegroundColor Yellow
    Write-Host "  Runs: $($bundleResults.Count)" -ForegroundColor White

    # Collect metrics across all runs
    $routingAccuracies = @()
    $responseAccuracies = @()
    $avgLatencies = @()
    $avgTokS = @()
    $efficiencyScores = @()

    foreach ($run in $bundleResults) {
        if ($run.summary) {
            $routingAccuracies += $run.summary.routing_accuracy
            $responseAccuracies += $run.summary.response_accuracy

            if ($run.summary.avg_latency_ms) {
                $avgLatencies += $run.summary.avg_latency_ms
            }
            if ($run.summary.avg_tokens_per_second) {
                $avgTokS += $run.summary.avg_tokens_per_second
            }
            if ($run.summary.efficiency_score) {
                $efficiencyScores += $run.summary.efficiency_score
            }
        }
    }

    # Calculate stats
    if ($routingAccuracies.Count -gt 0) {
        $routingStats = Get-BenchmarkStats -Values $routingAccuracies
        Write-Host "  Routing Accuracy:" -ForegroundColor Cyan
        Write-Host "    Mean: $([Math]::Round($routingStats.mean * 100, 1))% ± $([Math]::Round($routingStats.ci_95.margin * 100, 1))%" -ForegroundColor White
        Write-Host "    Range: $([Math]::Round($routingStats.min * 100, 1))% - $([Math]::Round($routingStats.max * 100, 1))%" -ForegroundColor DarkGray
    }

    if ($responseAccuracies.Count -gt 0) {
        $responseStats = Get-BenchmarkStats -Values $responseAccuracies
        Write-Host "  Response Accuracy:" -ForegroundColor Cyan
        Write-Host "    Mean: $([Math]::Round($responseStats.mean * 100, 1))% ± $([Math]::Round($responseStats.ci_95.margin * 100, 1))%" -ForegroundColor White
        Write-Host "    StdDev: $([Math]::Round($responseStats.std_dev * 100, 2))%" -ForegroundColor DarkGray
    }

    if ($avgLatencies.Count -gt 0) {
        $latencyStats = Get-BenchmarkStats -Values $avgLatencies
        Write-Host "  Latency (ms):" -ForegroundColor Cyan
        Write-Host "    Mean: $([Math]::Round($latencyStats.mean, 0))ms ± $([Math]::Round($latencyStats.ci_95.margin, 0))ms" -ForegroundColor White
        Write-Host "    P50: $([Math]::Round($latencyStats.median, 0))ms, Range: $([Math]::Round($latencyStats.min, 0))-$([Math]::Round($latencyStats.max, 0))ms" -ForegroundColor DarkGray
    }

    if ($avgTokS.Count -gt 0) {
        $tokStats = Get-BenchmarkStats -Values $avgTokS
        Write-Host "  Tokens/Second:" -ForegroundColor Cyan
        Write-Host "    Mean: $([Math]::Round($tokStats.mean, 1)) tok/s ± $([Math]::Round($tokStats.ci_95.margin, 1))" -ForegroundColor White
    }

    if ($efficiencyScores.Count -gt 0) {
        $effStats = Get-BenchmarkStats -Values $efficiencyScores
        Write-Host "  Efficiency Score:" -ForegroundColor Cyan
        Write-Host "    Mean: $([Math]::Round($effStats.mean, 2)) ± $([Math]::Round($effStats.ci_95.margin, 2))" -ForegroundColor White
    }

    Write-Host ""
}

# Per-test aggregation if requested
if ($ShowDetails -and $allResults.Count -gt 0) {
    Write-Host "`n$('═' * 60)" -ForegroundColor Cyan
    Write-Host "PER-TEST STATISTICS" -ForegroundColor Cyan
    Write-Host "$('═' * 60)`n" -ForegroundColor Cyan

    # Collect all test IDs
    $testData = @{}

    foreach ($run in $allResults) {
        foreach ($result in $run.results) {
            $testId = $result.test_id
            if (-not $testData.ContainsKey($testId)) {
                $testData[$testId] = @{
                    routing = @()
                    response = @()
                    latency = @()
                }
            }

            $testData[$testId].routing += [int]$result.routing_correct
            $testData[$testId].response += [int]$result.response_correct
            if ($result.latency_ms) {
                $testData[$testId].latency += $result.latency_ms
            }
        }
    }

    # Show tests with variance
    $variableTests = @()

    foreach ($testId in $testData.Keys) {
        $data = $testData[$testId]

        if ($data.response.Count -gt 1) {
            $responseStd = Get-StandardDeviation -Values $data.response
            if ($responseStd -gt 0) {
                $variableTests += @{
                    test_id = $testId
                    runs = $data.response.Count
                    pass_rate = [Math]::Round(($data.response | Measure-Object -Average).Average * 100, 1)
                    std_dev = [Math]::Round($responseStd * 100, 1)
                }
            }
        }
    }

    if ($variableTests.Count -gt 0) {
        Write-Host "Tests with Variable Results:" -ForegroundColor Yellow
        $variableTests | Sort-Object { $_.std_dev } -Descending | ForEach-Object {
            Write-Host "  $($_.test_id): $($_.pass_rate)% pass rate (±$($_.std_dev)%, n=$($_.runs))" -ForegroundColor White
        }
    } else {
        Write-Host "All tests showed consistent results across runs." -ForegroundColor Green
    }
}

# Export aggregated results
if ($OutputFile) {
    $aggregatedOutput = @{
        meta = @{
            aggregated_at = (Get-Date -Format "o")
            source_files = $files.Count
            source_dir = $ResultDir
        }
        bundles = @{}
    }

    foreach ($bundleName in $byBundle.Keys) {
        $bundleResults = $byBundle[$bundleName]

        $routingAccuracies = $bundleResults | Where-Object { $_.summary } | ForEach-Object { $_.summary.routing_accuracy }
        $responseAccuracies = $bundleResults | Where-Object { $_.summary } | ForEach-Object { $_.summary.response_accuracy }

        $aggregatedOutput.bundles[$bundleName] = @{
            run_count = $bundleResults.Count
            routing_accuracy = if ($routingAccuracies.Count -gt 0) { Get-BenchmarkStats -Values $routingAccuracies } else { $null }
            response_accuracy = if ($responseAccuracies.Count -gt 0) { Get-BenchmarkStats -Values $responseAccuracies } else { $null }
        }
    }

    $outputPath = Split-Path $OutputFile -Parent
    if ($outputPath -and -not (Test-Path $outputPath)) {
        New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
    }

    $aggregatedOutput | ConvertTo-Json -Depth 10 | Set-Content $OutputFile -Encoding UTF8
    Write-Host "`nAggregated results saved to: $OutputFile" -ForegroundColor Green
}

Write-Host "`n$('═' * 60)" -ForegroundColor Cyan
Write-Host "AGGREGATION COMPLETE" -ForegroundColor Cyan
Write-Host "$('═' * 60)" -ForegroundColor Cyan
