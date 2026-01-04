<#
.SYNOPSIS
    LLM Bundle Benchmark Script
.DESCRIPTION
    Tests specialist model bundles against test suites, measuring:
    - Routing accuracy (did the right specialist get selected?)
    - Response quality (domain-specific correctness)
    - Latency (routing + inference time)
    - Cost efficiency (active parameters per query)
.PARAMETER BundleConfig
    Path to bundle configuration JSON file
.PARAMETER RouterConfig
    Path to router configuration JSON file
.PARAMETER TestSuite
    Path to test suite JSON file or directory containing test suites
.PARAMETER OutputDir
    Directory to save results. Default: C:\Users\14104\llm-benchmarks\results
.PARAMETER SkipPull
    Skip model pulling (if already downloaded)
.PARAMETER Verbose
    Show detailed output during execution
.EXAMPLE
    .\benchmark-bundle.ps1 -BundleConfig ".\configs\bundles\general-bundle.json" -RouterConfig ".\configs\routers\semantic-router.json" -TestSuite ".\test-suites\general"
.EXAMPLE
    .\benchmark-bundle.ps1 -BundleConfig ".\configs\bundles\legal-florida-bundle.json" -RouterConfig ".\configs\routers\orchestrator-router.json" -TestSuite ".\test-suites\legal\florida" -SkipPull
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$BundleConfig,

    [Parameter(Mandatory=$true)]
    [string]$RouterConfig,

    [Parameter(Mandatory=$true)]
    [string]$TestSuite,

    [string]$OutputDir = "C:\Users\14104\llm-benchmarks\results",

    [switch]$SkipPull,

    [switch]$VerboseOutput
)

# Import utility functions (includes Get-JsonAsHashtable for PS 5.1 compatibility)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptDir\utils\Export-BenchmarkResult.ps1"
. "$scriptDir\utils\Invoke-BundleRouter.ps1"

# ═══════════════════════════════════════════════════════════════
# HELPER FUNCTIONS FOR TOKEN METRICS
# ═══════════════════════════════════════════════════════════════

function Invoke-OllamaWithMetrics {
    <#
    .SYNOPSIS
        Runs ollama with --verbose and parses token metrics from output.
    .OUTPUTS
        Hashtable with: response, tokens_generated, tokens_per_second, prompt_tokens, prompt_eval_ms
    #>
    param(
        [string]$Model,
        [string]$Prompt
    )

    $result = @{
        response = ""
        tokens_generated = 0
        tokens_per_second = 0
        prompt_tokens = 0
        prompt_eval_ms = 0
        eval_duration_ms = 0
    }

    try {
        $output = $Prompt | ollama run $Model --verbose 2>&1 | Out-String

        # Extract response: everything before "ollama :" or "total duration:"
        # The response is clean text at the start, before ollama's status output
        $responseText = $output

        # Cut at "ollama :" which marks start of status/escape codes
        if ($responseText -match "(?s)^(.*?)ollama\s*:") {
            $responseText = $Matches[1]
        }
        # Or cut at "total duration:" if "ollama :" not found
        elseif ($responseText -match "(?s)^(.*?)total duration:") {
            $responseText = $Matches[1]
        }

        # Clean up the response
        $responseText = $responseText -replace '\[[\?\d]+[hlGK]', ''  # Escape codes like [?25h
        $responseText = $responseText -replace '\[\d*[GK]', ''        # Cursor codes like [1G, [K
        $responseText = $responseText -replace '\[2K', ''             # Clear line
        $responseText = $responseText -replace '[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏Γáá╕ÖáÖ]', ''  # Spinner chars
        $responseText = $responseText.Trim()

        $result.response = $responseText

        # For metrics, clean the full output
        $cleanOutput = $output -replace '\[[\?\d]+[hlGK]', ''
        $cleanOutput = $cleanOutput -replace '\[\d*[GK]', ''

        # Parse eval count (tokens generated) - last occurrence (after prompt eval count)
        $evalMatches = [regex]::Matches($cleanOutput, "eval count:\s+(\d+)")
        if ($evalMatches.Count -gt 0) {
            $result.tokens_generated = [int]$evalMatches[$evalMatches.Count - 1].Groups[1].Value
        }

        # Parse eval rate (tokens per second) - last occurrence
        $rateMatches = [regex]::Matches($cleanOutput, "eval rate:\s+([\d\.]+)")
        if ($rateMatches.Count -gt 0) {
            $result.tokens_per_second = [double]$rateMatches[$rateMatches.Count - 1].Groups[1].Value
        }

        # Parse prompt eval count
        if ($cleanOutput -match "prompt eval count:\s+(\d+)") {
            $result.prompt_tokens = [int]$Matches[1]
        }

        # Parse prompt eval duration (time-to-first-token)
        if ($cleanOutput -match "prompt eval duration:\s+([\d\.]+)ms") {
            $result.prompt_eval_ms = [double]$Matches[1]
        } elseif ($cleanOutput -match "prompt eval duration:\s+([\d\.]+)s") {
            $result.prompt_eval_ms = [double]$Matches[1] * 1000
        }

        # Parse eval duration
        if ($cleanOutput -match "(?<!prompt )eval duration:\s+([\d\.]+)") {
            $result.eval_duration_ms = [double]$Matches[1]
        }
    } catch {
        $result.response = "ERROR: $($_.Exception.Message)"
    }

    return $result
}

function Get-ModelVramUsage {
    <#
    .SYNOPSIS
        Gets VRAM usage for a model from ollama ps.
    .OUTPUTS
        VRAM in GB as double, or 0 if not found
    #>
    param([string]$Model)

    try {
        $psOutput = ollama ps 2>&1 | Out-String
        # Match the model name and extract size
        $modelBase = $Model -replace ':.*', ''  # Remove tag
        if ($psOutput -match "$modelBase.*?(\d+\.?\d*)\s*GB") {
            return [double]$Matches[1]
        }
    } catch {}

    return 0
}

function Get-EfficiencyScore {
    <#
    .SYNOPSIS
        Calculates efficiency score: (accuracy * 100) / (params_b * latency_s)
        Higher is better.
    #>
    param(
        [double]$Accuracy,      # 0-1
        [double]$ParametersB,   # in billions
        [double]$LatencyMs      # in milliseconds
    )

    if ($ParametersB -le 0 -or $LatencyMs -le 0) { return 0 }

    $latencyS = $LatencyMs / 1000
    $score = ($Accuracy * 100) / ($ParametersB * $latencyS)
    return [math]::Round($score, 3)
}

Write-Host @"

╔═══════════════════════════════════════════════════════════════╗
║           LLM BUNDLE BENCHMARK SUITE v1.0                     ║
║           Testing Specialist Model Bundles                    ║
╚═══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# ═══════════════════════════════════════════════════════════════
# LOAD CONFIGURATIONS
# ═══════════════════════════════════════════════════════════════

Write-Host "Loading configurations..." -ForegroundColor Yellow

# Resolve paths
$bundlePath = Resolve-Path $BundleConfig -ErrorAction Stop
$routerPath = Resolve-Path $RouterConfig -ErrorAction Stop

$bundle = Get-JsonAsHashtable -Path $bundlePath
$router = Get-JsonAsHashtable -Path $routerPath

Write-Host "  Bundle: $($bundle.name) (v$($bundle.version))" -ForegroundColor White
Write-Host "  Specialists: $($bundle.specialists.Count)" -ForegroundColor White
Write-Host "  Router: $($router.strategy)" -ForegroundColor White

# Calculate total parameters in bundle (PS 5.1 compatible)
$totalParams = 0
foreach ($s in $bundle.specialists) {
    $totalParams += $s.parameters_b
}
Write-Host "  Total Parameters: $($totalParams)B" -ForegroundColor White

# ═══════════════════════════════════════════════════════════════
# LOAD TEST SUITE(S)
# ═══════════════════════════════════════════════════════════════

Write-Host "`nLoading test suite(s)..." -ForegroundColor Yellow

$testCases = @()
$testSuitePath = Resolve-Path $TestSuite -ErrorAction Stop

if (Test-Path $testSuitePath -PathType Container) {
    # Directory - load all JSON files
    $suiteFiles = Get-ChildItem $testSuitePath -Filter "*.json" -Recurse
    foreach ($file in $suiteFiles) {
        $suite = Get-JsonAsHashtable -Path $file.FullName
        foreach ($case in $suite.cases) {
            $case.domain = $suite.domain
            $case.subdomain = $suite.subdomain
            $case.jurisdiction = $suite.jurisdiction
            $testCases += $case
        }
        Write-Host "  Loaded: $($file.Name) ($($suite.cases.Count) cases)" -ForegroundColor White
    }
} else {
    # Single file
    $suite = Get-JsonAsHashtable -Path $testSuitePath
    foreach ($case in $suite.cases) {
        $case.domain = $suite.domain
        $case.subdomain = $suite.subdomain
        $case.jurisdiction = $suite.jurisdiction
        $testCases += $case
    }
    Write-Host "  Loaded: $(Split-Path $testSuitePath -Leaf) ($($suite.cases.Count) cases)" -ForegroundColor White
}

Write-Host "  Total test cases: $($testCases.Count)" -ForegroundColor Cyan

if ($testCases.Count -eq 0) {
    Write-Error "No test cases found in $TestSuite"
    exit 1
}

# ═══════════════════════════════════════════════════════════════
# PULL MODELS (if needed)
# ═══════════════════════════════════════════════════════════════

if (-not $SkipPull) {
    Write-Host "`nEnsuring models are available..." -ForegroundColor Yellow

    $models = $bundle.specialists | ForEach-Object { $_.model } | Sort-Object -Unique

    foreach ($model in $models) {
        Write-Host "  Pulling: $model" -ForegroundColor DarkGray
        ollama pull $model 2>&1 | Out-Null
    }

    # Also pull router model if needed
    $routerModel = $null
    switch ($router.strategy) {
        "classifier" { $routerModel = $router.classifier_config.classifier_model }
        "orchestrator" { $routerModel = $router.orchestrator_config.orchestrator_model }
        "hierarchical_moe" { $routerModel = $router.hierarchical_config.gating_model }
    }

    if ($routerModel) {
        Write-Host "  Pulling router: $routerModel" -ForegroundColor DarkGray
        ollama pull $routerModel 2>&1 | Out-Null
    }

    Write-Host "  Models ready!" -ForegroundColor Green
}

# ═══════════════════════════════════════════════════════════════
# WARM UP MODELS
# ═══════════════════════════════════════════════════════════════

Write-Host "`nWarming up models..." -ForegroundColor Yellow

$models = $bundle.specialists | ForEach-Object { $_.model } | Sort-Object -Unique
foreach ($model in $models) {
    Write-Host "  Warming: $model" -ForegroundColor DarkGray
    ollama run $model "Hello" 2>&1 | Out-Null
}

# ═══════════════════════════════════════════════════════════════
# RUN BENCHMARK
# ═══════════════════════════════════════════════════════════════

Write-Host "`n$('═' * 60)" -ForegroundColor Cyan
Write-Host "RUNNING BUNDLE BENCHMARK" -ForegroundColor Cyan
Write-Host "$('═' * 60)`n" -ForegroundColor Cyan

$results = @()
$totalCases = $testCases.Count
$currentCase = 0
$routingCorrect = 0
$responseCorrect = 0

foreach ($testCase in $testCases) {
    $currentCase++
    $progress = [math]::Round(($currentCase / $totalCases) * 100, 0)

    Write-Host "`n[$currentCase/$totalCases] Test: $($testCase.id)" -ForegroundColor Yellow
    if ($VerboseOutput) {
        Write-Host "  Query: $($testCase.prompt.Substring(0, [Math]::Min(60, $testCase.prompt.Length)))..." -ForegroundColor DarkGray
    }

    # ─────────────────────────────────────────────────────────────
    # STEP 1: Route the query
    # ─────────────────────────────────────────────────────────────

    $routingResult = Get-RoutingDecision -Query $testCase.prompt -BundleConfig $bundle -RouterConfig $router -ExpectedSpecialist $testCase.expected_specialist

    $routingIsCorrect = $routingResult.routing_correct
    if ($routingIsCorrect) { $routingCorrect++ }

    $routingColor = if ($routingIsCorrect) { "Green" } else { "Red" }
    Write-Host "  Routing: $($routingResult.specialist_id)" -NoNewline
    Write-Host " [Expected: $($testCase.expected_specialist)]" -ForegroundColor $routingColor -NoNewline
    Write-Host " ($('{0:N0}' -f $routingResult.latency_ms)ms, conf: $($routingResult.confidence))" -ForegroundColor DarkGray

    # ─────────────────────────────────────────────────────────────
    # STEP 2: Get specialist model and invoke
    # ─────────────────────────────────────────────────────────────

    $specialistModel = Get-SpecialistModel -SpecialistId $routingResult.specialist_id -BundleConfig $bundle
    $specialistParams = Get-SpecialistParameters -SpecialistId $routingResult.specialist_id -BundleConfig $bundle

    if (-not $specialistModel) {
        Write-Warning "  No model found for specialist: $($routingResult.specialist_id)"
        $specialistModel = $bundle.specialists[0].model  # Fallback to first specialist
        $specialistParams = $bundle.specialists[0].parameters_b
    }

    $inferenceStart = Get-Date

    # Build full prompt with context if provided
    $fullPrompt = $testCase.prompt
    if ($testCase.context) {
        $fullPrompt = "$($testCase.context)`n`n$($testCase.prompt)"
    }

    # Run inference with metrics collection
    $inferenceResult = Invoke-OllamaWithMetrics -Model $specialistModel -Prompt $fullPrompt
    $response = $inferenceResult.response

    $inferenceEnd = Get-Date
    $inferenceMs = [math]::Round(($inferenceEnd - $inferenceStart).TotalMilliseconds, 2)
    $totalLatencyMs = $routingResult.latency_ms + $inferenceMs

    # Get VRAM usage
    $vramGb = Get-ModelVramUsage -Model $specialistModel

    # ─────────────────────────────────────────────────────────────
    # STEP 3: Evaluate response quality
    # ─────────────────────────────────────────────────────────────

    $responsePass = $false
    $matchDetails = @()

    # Check expected_response_contains
    if ($testCase.expected_response_contains) {
        $containsCount = 0
        foreach ($expected in $testCase.expected_response_contains) {
            if ($response -match [regex]::Escape($expected)) {
                $containsCount++
                $matchDetails += "contains:'$expected'"
            }
        }
        $responsePass = $containsCount -gt 0
    }

    # Check expected_response_regex
    if ($testCase.expected_response_regex) {
        if ($response -match $testCase.expected_response_regex) {
            $responsePass = $true
            $matchDetails += "regex:match"
        }
    }

    # Check expected_response_not_contains
    if ($testCase.expected_response_not_contains) {
        foreach ($notExpected in $testCase.expected_response_not_contains) {
            if ($response -match [regex]::Escape($notExpected)) {
                $responsePass = $false
                $matchDetails += "NOT:'$notExpected'"
            }
        }
    }

    # If no validation criteria, consider routing correctness as pass
    if (-not $testCase.expected_response_contains -and -not $testCase.expected_response_regex) {
        $responsePass = $routingIsCorrect
    }

    if ($responsePass) { $responseCorrect++ }

    $responseColor = if ($responsePass) { "Green" } else { "Red" }
    $responseStatus = if ($responsePass) { "PASS" } else { "FAIL" }
    Write-Host "  Response: " -NoNewline
    Write-Host $responseStatus -ForegroundColor $responseColor -NoNewline
    Write-Host " ($('{0:N0}' -f $inferenceMs)ms inference, $('{0:N0}' -f $totalLatencyMs)ms total)" -ForegroundColor DarkGray

    if ($VerboseOutput -and $matchDetails.Count -gt 0) {
        Write-Host "  Matches: $($matchDetails -join ', ')" -ForegroundColor DarkGray
    }

    # ─────────────────────────────────────────────────────────────
    # STEP 4: Build result object
    # ─────────────────────────────────────────────────────────────

    $result = @{
        model = $specialistModel
        test_name = $testCase.id
        pass = $responsePass
        response = $response.Substring(0, [Math]::Min(400, $response.Length))

        bundle_config = @{
            bundle_name = $bundle.name
            bundle_version = $bundle.version
            total_parameters_b = $totalParams
            active_parameters_b = $specialistParams
        }

        routing = @{
            strategy = $router.strategy
            selected_specialist = $routingResult.specialist_id
            expected_specialist = $testCase.expected_specialist
            routing_latency_ms = $routingResult.latency_ms
            routing_confidence = $routingResult.confidence
            routing_correct = $routingIsCorrect
        }

        domain = @{
            name = $testCase.domain
            subdomain = $testCase.subdomain
            jurisdiction = $testCase.jurisdiction
            difficulty = $testCase.difficulty
        }

        cost_efficiency = @{
            active_parameters_b = $specialistParams
            inference_time_ms = $inferenceMs
            total_latency_ms = $totalLatencyMs
            tokens_generated = $inferenceResult.tokens_generated
            tokens_per_second = $inferenceResult.tokens_per_second
            prompt_tokens = $inferenceResult.prompt_tokens
            time_to_first_token_ms = $inferenceResult.prompt_eval_ms
            vram_usage_gb = $vramGb
            efficiency_score = (Get-EfficiencyScore -Accuracy $(if ($responsePass) { 1.0 } else { 0.0 }) -ParametersB $specialistParams -LatencyMs $inferenceMs)
        }

        metrics = @{
            routing_latency_ms = $routingResult.latency_ms
            inference_latency_ms = $inferenceMs
            total_latency_ms = $totalLatencyMs
            routing_correct = $routingIsCorrect
            response_correct = $responsePass
        }
    }

    if ($routingResult.router_model) {
        $result.routing.router_model = $routingResult.router_model
    }
    if ($routingResult.alternatives) {
        $result.routing.alternative_specialists = $routingResult.alternatives
    }

    $results += $result
}

# ═══════════════════════════════════════════════════════════════
# EXPORT RESULTS
# ═══════════════════════════════════════════════════════════════

Write-Host "`n$('═' * 60)" -ForegroundColor Cyan
Write-Host "EXPORTING RESULTS" -ForegroundColor Cyan
Write-Host "$('═' * 60)`n" -ForegroundColor Cyan

# Use extended export for bundle category
$testName = "bundle_benchmark_$($bundle.name)_$($router.strategy)"

# Manually build output since Export-JsonResult only supports hardware/cognitive
$timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
$filename = "{0}_{1}.json" -f (Get-Date -Format "yyyy-MM-dd_HHmmss"), $testName

$output = @{
    meta = @{
        timestamp = $timestamp
        hostname = $env:COMPUTERNAME
        hardware = Get-HardwareProfile
        schema_version = "1.0"
    }
    test = @{
        name = $testName
        category = "bundle"
        version = "1.0"
        bundle_config = $bundlePath.Path
        router_config = $routerPath.Path
    }
    results = $results
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
Write-Host "BUNDLE BENCHMARK SUMMARY" -ForegroundColor Cyan
Write-Host "$('═' * 60)`n" -ForegroundColor Cyan

$routingAccuracy = [math]::Round(($routingCorrect / $totalCases) * 100, 1)
$responseAccuracy = [math]::Round(($responseCorrect / $totalCases) * 100, 1)

# Calculate averages manually for PS 5.1 compatibility with hashtables
$sumRoutingLatency = 0
$sumInferenceLatency = 0
$sumTotalLatency = 0
foreach ($r in $results) {
    $sumRoutingLatency += $r.routing.routing_latency_ms
    $sumInferenceLatency += $r.cost_efficiency.inference_time_ms
    $sumTotalLatency += $r.cost_efficiency.total_latency_ms
}
$avgRoutingLatency = if ($results.Count -gt 0) { [math]::Round($sumRoutingLatency / $results.Count, 1) } else { 0 }
$avgInferenceLatency = if ($results.Count -gt 0) { [math]::Round($sumInferenceLatency / $results.Count, 1) } else { 0 }
$avgTotalLatency = if ($results.Count -gt 0) { [math]::Round($sumTotalLatency / $results.Count, 1) } else { 0 }

Write-Host "Bundle: $($bundle.name)" -ForegroundColor White
Write-Host "Router: $($router.strategy)" -ForegroundColor White
Write-Host "Test Cases: $totalCases" -ForegroundColor White
Write-Host ""

$routingColor = if ($routingAccuracy -ge 80) { "Green" } elseif ($routingAccuracy -ge 60) { "Yellow" } else { "Red" }
$responseColor = if ($responseAccuracy -ge 80) { "Green" } elseif ($responseAccuracy -ge 60) { "Yellow" } else { "Red" }

Write-Host "Routing Accuracy:  " -NoNewline
Write-Host "$routingCorrect / $totalCases ($routingAccuracy%)" -ForegroundColor $routingColor

Write-Host "Response Accuracy: " -NoNewline
Write-Host "$responseCorrect / $totalCases ($responseAccuracy%)" -ForegroundColor $responseColor

Write-Host ""
Write-Host "Average Latencies:" -ForegroundColor White
Write-Host "  Routing:   $('{0:N0}' -f $avgRoutingLatency) ms" -ForegroundColor DarkGray
Write-Host "  Inference: $('{0:N0}' -f $avgInferenceLatency) ms" -ForegroundColor DarkGray
Write-Host "  Total:     $('{0:N0}' -f $avgTotalLatency) ms" -ForegroundColor DarkGray

Write-Host ""
Write-Host "Parameters:" -ForegroundColor White
Write-Host "  Total Bundle: $($totalParams)B" -ForegroundColor DarkGray

# Calculate averages manually for PS 5.1 compatibility
$sumActiveParams = 0
$sumTokensGenerated = 0
$sumTokensPerSec = 0
$sumTtft = 0
$sumEfficiency = 0
$countWithTokens = 0

foreach ($r in $results) {
    $sumActiveParams += $r.bundle_config.active_parameters_b
    if ($r.cost_efficiency.tokens_generated -gt 0) {
        $sumTokensGenerated += $r.cost_efficiency.tokens_generated
        $sumTokensPerSec += $r.cost_efficiency.tokens_per_second
        $sumTtft += $r.cost_efficiency.time_to_first_token_ms
        $sumEfficiency += $r.cost_efficiency.efficiency_score
        $countWithTokens++
    }
}

$avgActiveParams = if ($results.Count -gt 0) { [math]::Round($sumActiveParams / $results.Count, 1) } else { 0 }
$avgTokensGenerated = if ($countWithTokens -gt 0) { [math]::Round($sumTokensGenerated / $countWithTokens, 0) } else { 0 }
$avgTokensPerSec = if ($countWithTokens -gt 0) { [math]::Round($sumTokensPerSec / $countWithTokens, 1) } else { 0 }
$avgTtft = if ($countWithTokens -gt 0) { [math]::Round($sumTtft / $countWithTokens, 1) } else { 0 }
$avgEfficiency = if ($countWithTokens -gt 0) { [math]::Round($sumEfficiency / $countWithTokens, 3) } else { 0 }

Write-Host "  Avg Active:   $($avgActiveParams)B" -ForegroundColor DarkGray

Write-Host ""
Write-Host "Token Metrics:" -ForegroundColor White
Write-Host "  Avg Tokens Generated: $avgTokensGenerated" -ForegroundColor DarkGray
Write-Host "  Avg Tokens/sec:       $avgTokensPerSec" -ForegroundColor DarkGray
Write-Host "  Avg TTFT:             $('{0:N1}' -f $avgTtft) ms" -ForegroundColor DarkGray

Write-Host ""
Write-Host "Efficiency Score:" -ForegroundColor White
$effColor = if ($avgEfficiency -ge 1) { "Green" } elseif ($avgEfficiency -ge 0.5) { "Yellow" } else { "Red" }
Write-Host "  Bundle Avg:   $avgEfficiency" -ForegroundColor $effColor
Write-Host "  Formula:      (accuracy% * 100) / (params_B * latency_s)" -ForegroundColor DarkGray

Write-Host ""
