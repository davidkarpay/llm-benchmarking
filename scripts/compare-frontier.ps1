<#
.SYNOPSIS
    LLM Bundle vs Frontier Model Comparison
.DESCRIPTION
    Compares specialist model bundle performance against frontier models.
    Supports both live API testing and published benchmark score comparison.
.PARAMETER BundleConfig
    Path to bundle configuration JSON file
.PARAMETER RouterConfig
    Path to router configuration JSON file
.PARAMETER TestSuite
    Path to test suite JSON file or directory
.PARAMETER FrontierModels
    Array of frontier models to compare (e.g., @("openai:gpt-4o", "anthropic:claude-sonnet-4"))
.PARAMETER OutputDir
    Directory to save results
.PARAMETER UsePublishedBenchmarks
    Compare against published benchmark scores instead of live API calls
.PARAMETER MaxTestCases
    Maximum number of test cases to run (to control API costs)
.EXAMPLE
    .\compare-frontier.ps1 -BundleConfig ".\configs\bundles\general-bundle.json" -RouterConfig ".\configs\routers\semantic-router.json" -TestSuite ".\test-suites\general" -FrontierModels @("openai:gpt-4o-mini")
.EXAMPLE
    .\compare-frontier.ps1 -BundleConfig ".\configs\bundles\general-bundle.json" -UsePublishedBenchmarks
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$BundleConfig,

    [string]$RouterConfig = "C:\Users\14104\llm-benchmarks\configs\routers\semantic-router.json",

    [string]$TestSuite = "C:\Users\14104\llm-benchmarks\test-suites\general",

    [string[]]$FrontierModels = @("openai:gpt-4o-mini"),

    [string]$OutputDir = "C:\Users\14104\llm-benchmarks\results",

    [switch]$UsePublishedBenchmarks,

    [int]$MaxTestCases = 0
)

# Import utility functions
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptDir\utils\Export-BenchmarkResult.ps1"
. "$scriptDir\utils\Invoke-BundleRouter.ps1"
. "$scriptDir\utils\Invoke-FrontierAPI.ps1"

Write-Host @"

╔═══════════════════════════════════════════════════════════════╗
║           LLM BUNDLE vs FRONTIER COMPARISON v1.0              ║
║           Testing Specialist Bundles Against Frontiers        ║
╚═══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# ═══════════════════════════════════════════════════════════════
# MODE: PUBLISHED BENCHMARKS COMPARISON
# ═══════════════════════════════════════════════════════════════

if ($UsePublishedBenchmarks) {
    Write-Host "Mode: Published Benchmark Comparison" -ForegroundColor Yellow
    Write-Host ""

    # Load bundle
    $bundlePath = Resolve-Path $BundleConfig -ErrorAction Stop
    $bundle = Get-JsonAsHashtable -Path $bundlePath

    Write-Host "Bundle: $($bundle.name)" -ForegroundColor White
    $totalParams = ($bundle.specialists | Measure-Object -Property parameters_b -Sum).Sum
    Write-Host "Total Parameters: $($totalParams)B" -ForegroundColor White
    Write-Host ""

    # Get all available published benchmarks
    $config = Get-FrontierConfig
    $benchmarkModels = $config.published_benchmarks.Keys

    Write-Host "$('═' * 60)" -ForegroundColor Cyan
    Write-Host "PUBLISHED BENCHMARK COMPARISON" -ForegroundColor Cyan
    Write-Host "$('═' * 60)`n" -ForegroundColor Cyan

    Write-Host "Note: Bundle scores would need to be measured on the same benchmarks" -ForegroundColor DarkGray
    Write-Host "      (MMLU, HumanEval, GPQA, MATH, ARC-Challenge)" -ForegroundColor DarkGray
    Write-Host ""

    # Print comparison table
    Write-Host ("Model".PadRight(25)) -NoNewline
    Write-Host "MMLU   " -NoNewline -ForegroundColor Cyan
    Write-Host "HumanEval " -NoNewline -ForegroundColor Cyan
    Write-Host "GPQA   " -NoNewline -ForegroundColor Cyan
    Write-Host "MATH   " -NoNewline -ForegroundColor Cyan
    Write-Host "ARC    " -ForegroundColor Cyan
    Write-Host ("-" * 75)

    foreach ($model in $benchmarkModels) {
        $scores = Get-PublishedBenchmarkScores -Model $model

        Write-Host ($model.PadRight(25)) -NoNewline -ForegroundColor Yellow

        $mmlu = if ($scores.mmlu) { "$($scores.mmlu)%".PadRight(7) } else { "N/A".PadRight(7) }
        $humaneval = if ($scores.humaneval) { "$($scores.humaneval)%".PadRight(10) } else { "N/A".PadRight(10) }
        $gpqa = if ($scores.gpqa) { "$($scores.gpqa)%".PadRight(7) } else { "N/A".PadRight(7) }
        $math = if ($scores.math) { "$($scores.math)%".PadRight(7) } else { "N/A".PadRight(7) }
        $arc = if ($scores.arc_challenge) { "$($scores.arc_challenge)%" } else { "N/A" }

        Write-Host $mmlu -NoNewline
        Write-Host $humaneval -NoNewline
        Write-Host $gpqa -NoNewline
        Write-Host $math -NoNewline
        Write-Host $arc
    }

    Write-Host ""
    Write-Host "To compete, run standard benchmarks on your bundle and compare results." -ForegroundColor DarkGray
    Write-Host "Recommended: Use lm-evaluation-harness for standardized testing." -ForegroundColor DarkGray

    exit 0
}

# ═══════════════════════════════════════════════════════════════
# MODE: LIVE API COMPARISON
# ═══════════════════════════════════════════════════════════════

Write-Host "Mode: Live API Comparison" -ForegroundColor Yellow
Write-Host ""

# Load configurations
$bundlePath = Resolve-Path $BundleConfig -ErrorAction Stop
$routerPath = Resolve-Path $RouterConfig -ErrorAction Stop
$bundle = Get-JsonAsHashtable -Path $bundlePath
$router = Get-JsonAsHashtable -Path $routerPath

Write-Host "Bundle: $($bundle.name)" -ForegroundColor White
Write-Host "Router: $($router.strategy)" -ForegroundColor White
Write-Host "Frontier Models:" -ForegroundColor White
foreach ($fm in $FrontierModels) {
    Write-Host "  - $fm" -ForegroundColor DarkGray
}

# Parse frontier models
$parsedFrontiers = @()
foreach ($fm in $FrontierModels) {
    $parts = $fm -split ":"
    if ($parts.Count -eq 2) {
        $parsedFrontiers += @{ provider = $parts[0]; model = $parts[1] }
    } else {
        Write-Warning "Invalid frontier model format: $fm (expected provider:model)"
    }
}

# Load test suite
Write-Host "`nLoading test suite..." -ForegroundColor Yellow

$testCases = @()
$testSuitePath = Resolve-Path $TestSuite -ErrorAction Stop

if (Test-Path $testSuitePath -PathType Container) {
    $suiteFiles = Get-ChildItem $testSuitePath -Filter "*.json" -Recurse
    foreach ($file in $suiteFiles) {
        $suite = Get-JsonAsHashtable -Path $file.FullName
        foreach ($case in $suite.cases) {
            $case.domain = $suite.domain
            $testCases += $case
        }
    }
} else {
    $suite = Get-JsonAsHashtable -Path $testSuitePath
    foreach ($case in $suite.cases) {
        $case.domain = $suite.domain
        $testCases += $case
    }
}

# Limit test cases if specified
if ($MaxTestCases -gt 0 -and $testCases.Count -gt $MaxTestCases) {
    Write-Host "  Limiting to $MaxTestCases test cases (of $($testCases.Count))" -ForegroundColor DarkGray
    $testCases = $testCases | Get-Random -Count $MaxTestCases
}

Write-Host "  Test cases: $($testCases.Count)" -ForegroundColor Cyan

# Calculate total parameters
$totalParams = ($bundle.specialists | Measure-Object -Property parameters_b -Sum).Sum

# Warm up bundle models
Write-Host "`nWarming up bundle models..." -ForegroundColor Yellow
$models = $bundle.specialists | ForEach-Object { $_.model } | Sort-Object -Unique
foreach ($model in $models) {
    ollama run $model "Hello" 2>&1 | Out-Null
}

# ═══════════════════════════════════════════════════════════════
# RUN COMPARISON
# ═══════════════════════════════════════════════════════════════

Write-Host "`n$('═' * 60)" -ForegroundColor Cyan
Write-Host "RUNNING LIVE COMPARISON" -ForegroundColor Cyan
Write-Host "$('═' * 60)`n" -ForegroundColor Cyan

$results = @()
$bundleStats = @{ correct = 0; total = 0; latencies = @(); costs = @() }
$frontierStats = @{}
foreach ($pf in $parsedFrontiers) {
    $key = "$($pf.provider):$($pf.model)"
    $frontierStats[$key] = @{ correct = 0; total = 0; latencies = @(); costs = @() }
}

$currentCase = 0
$totalCases = $testCases.Count

foreach ($testCase in $testCases) {
    $currentCase++
    Write-Host "`n[$currentCase/$totalCases] Test: $($testCase.id)" -ForegroundColor Yellow

    $caseResult = @{
        test_id = $testCase.id
        domain = $testCase.domain
        bundle_result = $null
        frontier_results = @{}
    }

    # ─────────────────────────────────────────────────────────────
    # Test Bundle
    # ─────────────────────────────────────────────────────────────

    # Route query
    $routingResult = Get-RoutingDecision -Query $testCase.prompt -BundleConfig $bundle -RouterConfig $router -ExpectedSpecialist $testCase.expected_specialist
    $specialistModel = Get-SpecialistModel -SpecialistId $routingResult.specialist_id -BundleConfig $bundle
    $specialistParams = Get-SpecialistParameters -SpecialistId $routingResult.specialist_id -BundleConfig $bundle

    # Invoke specialist
    $bundleStart = Get-Date
    try {
        $bundleResponse = ollama run $specialistModel $testCase.prompt 2>&1 | Out-String
        $bundleResponse = $bundleResponse.Trim()
    } catch {
        $bundleResponse = "ERROR"
    }
    $bundleEnd = Get-Date
    $bundleLatency = [math]::Round(($bundleEnd - $bundleStart).TotalMilliseconds + $routingResult.latency_ms, 2)

    # Evaluate bundle response
    $bundlePass = $false
    if ($testCase.expected_response_contains) {
        foreach ($expected in $testCase.expected_response_contains) {
            if ($bundleResponse -match [regex]::Escape($expected)) {
                $bundlePass = $true
                break
            }
        }
    } elseif ($testCase.expected_response_regex) {
        $bundlePass = $bundleResponse -match $testCase.expected_response_regex
    } else {
        $bundlePass = $routingResult.routing_correct
    }

    if ($bundlePass) { $bundleStats.correct++ }
    $bundleStats.total++
    $bundleStats.latencies += $bundleLatency
    # Estimate bundle cost (very rough: based on VRAM-time)
    $bundleCostEstimate = $specialistParams * 0.0001 * ($bundleLatency / 1000)  # Very rough estimate
    $bundleStats.costs += $bundleCostEstimate

    $caseResult.bundle_result = @{
        specialist = $routingResult.specialist_id
        response = $bundleResponse.Substring(0, [Math]::Min(200, $bundleResponse.Length))
        pass = $bundlePass
        latency_ms = $bundleLatency
        active_params_b = $specialistParams
        cost_estimate = $bundleCostEstimate
    }

    $bundleIcon = if ($bundlePass) { "[OK]" } else { "[X]" }
    $bundleColor = if ($bundlePass) { "Green" } else { "Red" }
    Write-Host "  Bundle: " -NoNewline
    Write-Host $bundleIcon -ForegroundColor $bundleColor -NoNewline
    Write-Host " ($('{0:N0}' -f $bundleLatency)ms, $($specialistParams)B params)" -ForegroundColor DarkGray

    # ─────────────────────────────────────────────────────────────
    # Test Frontier Models
    # ─────────────────────────────────────────────────────────────

    foreach ($pf in $parsedFrontiers) {
        $key = "$($pf.provider):$($pf.model)"

        $frontierResult = Invoke-FrontierCompletion -Prompt $testCase.prompt -Provider $pf.provider -Model $pf.model -MaxTokens 500

        if ($frontierResult.error) {
            Write-Host "  $key : ERROR - $($frontierResult.error)" -ForegroundColor Red
            $caseResult.frontier_results[$key] = @{ error = $frontierResult.error }
            continue
        }

        # Evaluate frontier response
        $frontierPass = $false
        if ($testCase.expected_response_contains) {
            foreach ($expected in $testCase.expected_response_contains) {
                if ($frontierResult.response -match [regex]::Escape($expected)) {
                    $frontierPass = $true
                    break
                }
            }
        } elseif ($testCase.expected_response_regex) {
            $frontierPass = $frontierResult.response -match $testCase.expected_response_regex
        } else {
            $frontierPass = $true  # No validation criteria, assume pass
        }

        if ($frontierPass) { $frontierStats[$key].correct++ }
        $frontierStats[$key].total++
        $frontierStats[$key].latencies += $frontierResult.latency_ms
        $frontierStats[$key].costs += $frontierResult.cost_usd

        $caseResult.frontier_results[$key] = @{
            response = $frontierResult.response.Substring(0, [Math]::Min(200, $frontierResult.response.Length))
            pass = $frontierPass
            latency_ms = $frontierResult.latency_ms
            cost_usd = $frontierResult.cost_usd
            tokens_input = $frontierResult.tokens_input
            tokens_output = $frontierResult.tokens_output
        }

        $frontierIcon = if ($frontierPass) { "[OK]" } else { "[X]" }
        $frontierColor = if ($frontierPass) { "Green" } else { "Red" }
        Write-Host "  $($key.PadRight(25)) " -NoNewline
        Write-Host $frontierIcon -ForegroundColor $frontierColor -NoNewline
        Write-Host " ($('{0:N0}' -f $frontierResult.latency_ms)ms, `$$($frontierResult.cost_usd))" -ForegroundColor DarkGray
    }

    # Determine winner for this case
    $bundleWins = $bundlePass -and (-not ($caseResult.frontier_results.Values | Where-Object { $_.pass }))
    $caseResult.bundle_wins = $bundleWins

    $results += $caseResult
}

# ═══════════════════════════════════════════════════════════════
# EXPORT RESULTS
# ═══════════════════════════════════════════════════════════════

Write-Host "`n$('═' * 60)" -ForegroundColor Cyan
Write-Host "EXPORTING RESULTS" -ForegroundColor Cyan
Write-Host "$('═' * 60)`n" -ForegroundColor Cyan

$timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
$filename = "{0}_frontier_comparison.json" -f (Get-Date -Format "yyyy-MM-dd_HHmmss")

$output = @{
    meta = @{
        timestamp = $timestamp
        hostname = $env:COMPUTERNAME
        hardware = Get-HardwareProfile
        schema_version = "1.0"
    }
    test = @{
        name = "frontier_comparison"
        category = "frontier_comparison"
        version = "1.0"
        bundle_config = $bundlePath.Path
        router_config = $routerPath.Path
        frontier_models = $FrontierModels
    }
    summary = @{
        total_cases = $totalCases
        bundle = @{
            accuracy = [math]::Round(($bundleStats.correct / $bundleStats.total) * 100, 1)
            avg_latency_ms = [math]::Round(($bundleStats.latencies | Measure-Object -Average).Average, 1)
            total_cost_estimate = [math]::Round(($bundleStats.costs | Measure-Object -Sum).Sum, 6)
        }
        frontiers = @{}
    }
    results = $results
}

foreach ($key in $frontierStats.Keys) {
    $stats = $frontierStats[$key]
    if ($stats.total -gt 0) {
        $output.summary.frontiers[$key] = @{
            accuracy = [math]::Round(($stats.correct / $stats.total) * 100, 1)
            avg_latency_ms = [math]::Round(($stats.latencies | Measure-Object -Average).Average, 1)
            total_cost_usd = [math]::Round(($stats.costs | Measure-Object -Sum).Sum, 4)
        }
    }
}

$rawDir = Join-Path $OutputDir "raw"
if (-not (Test-Path $rawDir)) {
    New-Item -ItemType Directory -Path $rawDir -Force | Out-Null
}

$fullPath = Join-Path $rawDir $filename
$output | ConvertTo-Json -Depth 15 | Out-File $fullPath -Encoding UTF8

Write-Host "JSON saved: $fullPath" -ForegroundColor Green

# ═══════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════

Write-Host "`n$('═' * 60)" -ForegroundColor Cyan
Write-Host "FRONTIER COMPARISON SUMMARY" -ForegroundColor Cyan
Write-Host "$('═' * 60)`n" -ForegroundColor Cyan

# Bundle stats
$bundleAcc = [math]::Round(($bundleStats.correct / $bundleStats.total) * 100, 1)
$bundleAvgLatency = [math]::Round(($bundleStats.latencies | Measure-Object -Average).Average, 1)
$bundleTotalCost = [math]::Round(($bundleStats.costs | Measure-Object -Sum).Sum, 6)

$bundleColor = if ($bundleAcc -ge 80) { "Green" } elseif ($bundleAcc -ge 60) { "Yellow" } else { "Red" }

Write-Host "BUNDLE ($($bundle.name)):" -ForegroundColor Cyan
Write-Host "  Accuracy:    " -NoNewline
Write-Host "$($bundleStats.correct)/$($bundleStats.total) ($bundleAcc%)" -ForegroundColor $bundleColor
Write-Host "  Avg Latency: $('{0:N0}' -f $bundleAvgLatency) ms" -ForegroundColor DarkGray
Write-Host "  Total Params: $($totalParams)B" -ForegroundColor DarkGray
Write-Host ""

# Frontier stats
Write-Host "FRONTIER MODELS:" -ForegroundColor Cyan

foreach ($key in $frontierStats.Keys) {
    $stats = $frontierStats[$key]
    if ($stats.total -eq 0) { continue }

    $acc = [math]::Round(($stats.correct / $stats.total) * 100, 1)
    $avgLatency = [math]::Round(($stats.latencies | Measure-Object -Average).Average, 1)
    $totalCost = [math]::Round(($stats.costs | Measure-Object -Sum).Sum, 4)

    $color = if ($acc -ge 80) { "Green" } elseif ($acc -ge 60) { "Yellow" } else { "Red" }

    Write-Host "  $key :" -ForegroundColor Yellow
    Write-Host "    Accuracy:    " -NoNewline
    Write-Host "$($stats.correct)/$($stats.total) ($acc%)" -ForegroundColor $color
    Write-Host "    Avg Latency: $('{0:N0}' -f $avgLatency) ms" -ForegroundColor DarkGray
    Write-Host "    Total Cost:  `$$totalCost" -ForegroundColor DarkGray
}

Write-Host ""

# Overall verdict
$bundleWinsCount = ($results | Where-Object { $_.bundle_wins }).Count
$bundleWinsPercent = [math]::Round(($bundleWinsCount / $totalCases) * 100, 1)

Write-Host "VERDICT:" -ForegroundColor Cyan
Write-Host "  Bundle outperformed frontier on $bundleWinsCount/$totalCases cases ($bundleWinsPercent%)" -ForegroundColor White

# Cost comparison
foreach ($key in $frontierStats.Keys) {
    $stats = $frontierStats[$key]
    if ($stats.total -eq 0) { continue }
    $frontierCost = ($stats.costs | Measure-Object -Sum).Sum
    if ($frontierCost -gt 0 -and $bundleTotalCost -gt 0) {
        $costRatio = [math]::Round($frontierCost / $bundleTotalCost, 1)
        Write-Host "  Cost ratio ($key / bundle): ${costRatio}x" -ForegroundColor DarkGray
    }
}

Write-Host ""
