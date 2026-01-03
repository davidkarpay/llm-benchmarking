<#
.SYNOPSIS
    LLM Routing Strategy Comparison Benchmark
.DESCRIPTION
    Compares multiple routing strategies head-to-head on identical queries.
    Measures routing accuracy, latency overhead, and agreement between routers.
.PARAMETER BundleConfig
    Path to bundle configuration JSON file
.PARAMETER RouterConfigs
    Array of paths to router configuration JSON files to compare
.PARAMETER TestSuite
    Path to test suite JSON file or directory
.PARAMETER OutputDir
    Directory to save results. Default: C:\Users\14104\llm-benchmarks\results
.PARAMETER IncludeOracle
    Include oracle (perfect) routing as a baseline
.EXAMPLE
    .\benchmark-routing.ps1 -BundleConfig ".\configs\bundles\general-bundle.json" -RouterConfigs @(".\configs\routers\semantic-router.json", ".\configs\routers\classifier-router.json") -TestSuite ".\test-suites\general"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$BundleConfig,

    [Parameter(Mandatory=$true)]
    [string[]]$RouterConfigs,

    [Parameter(Mandatory=$true)]
    [string]$TestSuite,

    [string]$OutputDir = "C:\Users\14104\llm-benchmarks\results",

    [switch]$IncludeOracle
)

# Import utility functions
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptDir\utils\Export-BenchmarkResult.ps1"
. "$scriptDir\utils\Invoke-BundleRouter.ps1"

Write-Host @"

╔═══════════════════════════════════════════════════════════════╗
║           LLM ROUTING STRATEGY COMPARISON v1.0                ║
║           Comparing Router Performance Head-to-Head           ║
╚═══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# ═══════════════════════════════════════════════════════════════
# LOAD CONFIGURATIONS
# ═══════════════════════════════════════════════════════════════

Write-Host "Loading configurations..." -ForegroundColor Yellow

$bundlePath = Resolve-Path $BundleConfig -ErrorAction Stop
$bundle = Get-JsonAsHashtable -Path $bundlePath

Write-Host "  Bundle: $($bundle.name)" -ForegroundColor White

# Load all router configs
$routers = @()
foreach ($routerPath in $RouterConfigs) {
    $resolvedPath = Resolve-Path $routerPath -ErrorAction Stop
    $router = Get-JsonAsHashtable -Path $resolvedPath
    $router._path = $resolvedPath.Path
    $routers += $router
    Write-Host "  Router: $($router.strategy)" -ForegroundColor White
}

if ($IncludeOracle) {
    $routers += @{ strategy = "oracle"; _path = "oracle" }
    Write-Host "  Router: oracle (baseline)" -ForegroundColor White
}

# ═══════════════════════════════════════════════════════════════
# LOAD TEST SUITE(S)
# ═══════════════════════════════════════════════════════════════

Write-Host "`nLoading test suite(s)..." -ForegroundColor Yellow

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

Write-Host "  Total test cases: $($testCases.Count)" -ForegroundColor Cyan

# ═══════════════════════════════════════════════════════════════
# PULL ROUTER MODELS
# ═══════════════════════════════════════════════════════════════

Write-Host "`nEnsuring router models are available..." -ForegroundColor Yellow

foreach ($router in $routers) {
    $routerModel = $null
    switch ($router.strategy) {
        "classifier" { $routerModel = $router.classifier_config.classifier_model }
        "orchestrator" { $routerModel = $router.orchestrator_config.orchestrator_model }
        "hierarchical_moe" { $routerModel = $router.hierarchical_config.gating_model }
    }
    if ($routerModel) {
        Write-Host "  Pulling: $routerModel" -ForegroundColor DarkGray
        ollama pull $routerModel 2>&1 | Out-Null
    }
}

# ═══════════════════════════════════════════════════════════════
# RUN ROUTING COMPARISON
# ═══════════════════════════════════════════════════════════════

Write-Host "`n$('═' * 60)" -ForegroundColor Cyan
Write-Host "RUNNING ROUTING COMPARISON" -ForegroundColor Cyan
Write-Host "$('═' * 60)`n" -ForegroundColor Cyan

$results = @()
$routerStats = @{}

foreach ($router in $routers) {
    $routerStats[$router.strategy] = @{
        correct = 0
        total = 0
        latencies = @()
    }
}

$totalCases = $testCases.Count
$currentCase = 0

foreach ($testCase in $testCases) {
    $currentCase++
    Write-Host "`n[$currentCase/$totalCases] Test: $($testCase.id)" -ForegroundColor Yellow
    Write-Host "  Expected: $($testCase.expected_specialist)" -ForegroundColor DarkGray

    $caseResults = @{
        test_id = $testCase.id
        expected_specialist = $testCase.expected_specialist
        domain = $testCase.domain
        router_decisions = @{}
    }

    foreach ($router in $routers) {
        $decision = Get-RoutingDecision -Query $testCase.prompt -BundleConfig $bundle -RouterConfig $router -ExpectedSpecialist $testCase.expected_specialist

        $caseResults.router_decisions[$router.strategy] = @{
            selected = $decision.specialist_id
            correct = $decision.routing_correct
            confidence = $decision.confidence
            latency_ms = $decision.latency_ms
        }

        $routerStats[$router.strategy].total++
        $routerStats[$router.strategy].latencies += $decision.latency_ms

        if ($decision.routing_correct) {
            $routerStats[$router.strategy].correct++
        }

        $statusIcon = if ($decision.routing_correct) { "[OK]" } else { "[X]" }
        $statusColor = if ($decision.routing_correct) { "Green" } else { "Red" }

        Write-Host "    $($router.strategy.PadRight(18)) -> $($decision.specialist_id.PadRight(22))" -NoNewline
        Write-Host " $statusIcon" -ForegroundColor $statusColor -NoNewline
        Write-Host " ($('{0:N0}' -f $decision.latency_ms)ms)" -ForegroundColor DarkGray
    }

    $results += $caseResults
}

# ═══════════════════════════════════════════════════════════════
# CALCULATE AGREEMENT MATRIX
# ═══════════════════════════════════════════════════════════════

Write-Host "`n$('═' * 60)" -ForegroundColor Cyan
Write-Host "ROUTER AGREEMENT MATRIX" -ForegroundColor Cyan
Write-Host "$('═' * 60)`n" -ForegroundColor Cyan

$agreementMatrix = @{}
$routerNames = $routers | ForEach-Object { $_.strategy }

foreach ($r1 in $routerNames) {
    $agreementMatrix[$r1] = @{}
    foreach ($r2 in $routerNames) {
        $agreements = 0
        foreach ($result in $results) {
            if ($result.router_decisions[$r1].selected -eq $result.router_decisions[$r2].selected) {
                $agreements++
            }
        }
        $agreementMatrix[$r1][$r2] = [math]::Round(($agreements / $totalCases) * 100, 1)
    }
}

# Print matrix header
Write-Host ("".PadRight(20)) -NoNewline
foreach ($name in $routerNames) {
    Write-Host ($name.PadRight(15)) -NoNewline -ForegroundColor Cyan
}
Write-Host ""

# Print matrix rows
foreach ($r1 in $routerNames) {
    Write-Host ($r1.PadRight(20)) -NoNewline -ForegroundColor Yellow
    foreach ($r2 in $routerNames) {
        $pct = $agreementMatrix[$r1][$r2]
        $color = if ($pct -ge 80) { "Green" } elseif ($pct -ge 60) { "Yellow" } else { "Red" }
        Write-Host ("$pct%".PadRight(15)) -NoNewline -ForegroundColor $color
    }
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════════
# EXPORT RESULTS
# ═══════════════════════════════════════════════════════════════

Write-Host "`n$('═' * 60)" -ForegroundColor Cyan
Write-Host "EXPORTING RESULTS" -ForegroundColor Cyan
Write-Host "$('═' * 60)`n" -ForegroundColor Cyan

$timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
$filename = "{0}_routing_comparison.json" -f (Get-Date -Format "yyyy-MM-dd_HHmmss")

$output = @{
    meta = @{
        timestamp = $timestamp
        hostname = $env:COMPUTERNAME
        hardware = Get-HardwareProfile
        schema_version = "1.0"
    }
    test = @{
        name = "routing_comparison"
        category = "routing"
        version = "1.0"
        bundle_config = $bundlePath.Path
        router_configs = $RouterConfigs
    }
    summary = @{
        total_cases = $totalCases
        router_accuracy = @{}
        router_latency = @{}
        agreement_matrix = $agreementMatrix
    }
    results = $results
}

foreach ($router in $routers) {
    $stats = $routerStats[$router.strategy]
    $accuracy = [math]::Round(($stats.correct / $stats.total) * 100, 1)
    $avgLatency = [math]::Round(($stats.latencies | Measure-Object -Average).Average, 1)

    $output.summary.router_accuracy[$router.strategy] = $accuracy
    $output.summary.router_latency[$router.strategy] = $avgLatency
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
Write-Host "ROUTING COMPARISON SUMMARY" -ForegroundColor Cyan
Write-Host "$('═' * 60)`n" -ForegroundColor Cyan

Write-Host "Accuracy by Router:" -ForegroundColor White
Write-Host ""

# Sort by accuracy descending
$sortedStats = $routerStats.GetEnumerator() | Sort-Object { $_.Value.correct / $_.Value.total } -Descending

foreach ($entry in $sortedStats) {
    $strategy = $entry.Key
    $stats = $entry.Value
    $accuracy = [math]::Round(($stats.correct / $stats.total) * 100, 1)
    $avgLatency = [math]::Round(($stats.latencies | Measure-Object -Average).Average, 1)

    $color = if ($accuracy -ge 80) { "Green" } elseif ($accuracy -ge 60) { "Yellow" } else { "Red" }

    Write-Host "  $($strategy.PadRight(20))" -NoNewline
    Write-Host "$($stats.correct)/$($stats.total) ($accuracy%)" -ForegroundColor $color -NoNewline
    Write-Host "  avg latency: $('{0:N0}' -f $avgLatency)ms" -ForegroundColor DarkGray
}

Write-Host ""

# Determine winner
$winner = $sortedStats | Select-Object -First 1
Write-Host "Best Router: " -NoNewline
Write-Host $winner.Key -ForegroundColor Green -NoNewline
$winnerAcc = [math]::Round(($winner.Value.correct / $winner.Value.total) * 100, 1)
Write-Host " ($winnerAcc% accuracy)" -ForegroundColor DarkGray

Write-Host ""
