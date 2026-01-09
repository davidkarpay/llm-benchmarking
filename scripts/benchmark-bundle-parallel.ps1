<#
.SYNOPSIS
    Parallel LLM Bundle Benchmark Script
.DESCRIPTION
    Tests specialist model bundles with parallel test execution for faster benchmarking.
    Supports batching tests to reduce overhead and concurrent model invocations.
.PARAMETER BundleConfig
    Path to bundle configuration JSON file
.PARAMETER RouterConfig
    Path to router configuration JSON file
.PARAMETER TestSuite
    Path to test suite JSON file or directory containing test suites
.PARAMETER Parallelism
    Number of concurrent test executions. Default: 4
.PARAMETER BatchSize
    Number of tests per batch for progress reporting. Default: 10
.PARAMETER OutputDir
    Directory to save results. Default: results
.PARAMETER SkipPull
    Skip model pulling (if already downloaded)
.PARAMETER MaxTests
    Limit the number of tests to run (for quick validation)
.EXAMPLE
    .\benchmark-bundle-parallel.ps1 -BundleConfig ".\configs\bundles\general-bundle.json" -RouterConfig ".\configs\routers\semantic-router.json" -TestSuite ".\test-suites\mixed" -Parallelism 4
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$BundleConfig,

    [Parameter(Mandatory=$true)]
    [string]$RouterConfig,

    [Parameter(Mandatory=$true)]
    [string]$TestSuite,

    [int]$Parallelism = 4,

    [int]$MaxConcurrentOllama = 2,  # CUDA Optimization: Limit concurrent GPU requests

    [int]$MaxClientConcurrency = 0,  # Override client-side concurrency (0 = use MaxConcurrentOllama)

    [int]$BatchSize = 10,

    [string]$OutputDir = "C:\Users\14104\llm-benchmarks\results",

    [switch]$SkipPull,

    [switch]$SkipWarmup,  # Skip model warmup (for cold-start measurements)

    [switch]$DisableSemaphore,  # Disable GPU semaphore for A/B testing

    [int]$MaxTests = 0,

    [switch]$VerboseOutput
)

# Import utility functions
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptDir\utils\Export-BenchmarkResult.ps1"
. "$scriptDir\utils\Invoke-BundleRouter.ps1"

# Configure GPU for maximum utilization
Set-OllamaGpuConfig -NumGpu 999 -NumThread 8

Write-Host @"

╔═══════════════════════════════════════════════════════════════╗
║        PARALLEL LLM BUNDLE BENCHMARK SUITE v1.0               ║
║        Multi-Threaded Specialist Model Testing                ║
╚═══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# ═══════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════

function Invoke-OllamaWithMetrics {
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

        $responseText = $output
        if ($responseText -match "(?s)^(.*?)ollama\s*:") {
            $responseText = $Matches[1]
        }
        elseif ($responseText -match "(?s)^(.*?)total duration:") {
            $responseText = $Matches[1]
        }

        $responseText = $responseText -replace '\[[\?\d]+[hlGK]', ''
        $responseText = $responseText -replace '\[\d*[GK]', ''
        $responseText = $responseText -replace '\[2K', ''
        $responseText = $responseText -replace '[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏]', ''
        $responseText = $responseText.Trim()

        $result.response = $responseText

        $cleanOutput = $output -replace '\[[\?\d]+[hlGK]', ''
        $cleanOutput = $cleanOutput -replace '\[\d*[GK]', ''

        $evalMatches = [regex]::Matches($cleanOutput, "eval count:\s+(\d+)")
        if ($evalMatches.Count -gt 0) {
            $result.tokens_generated = [int]$evalMatches[$evalMatches.Count - 1].Groups[1].Value
        }

        $rateMatches = [regex]::Matches($cleanOutput, "eval rate:\s+([\d\.]+)")
        if ($rateMatches.Count -gt 0) {
            $result.tokens_per_second = [double]$rateMatches[$rateMatches.Count - 1].Groups[1].Value
        }

        if ($cleanOutput -match "prompt eval count:\s+(\d+)") {
            $result.prompt_tokens = [int]$Matches[1]
        }

        if ($cleanOutput -match "prompt eval duration:\s+([\d\.]+)ms") {
            $result.prompt_eval_ms = [double]$Matches[1]
        } elseif ($cleanOutput -match "prompt eval duration:\s+([\d\.]+)s") {
            $result.prompt_eval_ms = [double]$Matches[1] * 1000
        }
    } catch {
        $result.response = "ERROR: $($_.Exception.Message)"
    }

    return $result
}

function Get-EfficiencyScore {
    param(
        [double]$Accuracy,
        [double]$ParametersB,
        [double]$LatencyMs
    )

    if ($ParametersB -le 0 -or $LatencyMs -le 0) { return 0 }

    $latencyS = $LatencyMs / 1000
    $score = ($Accuracy * 100) / ($ParametersB * $latencyS)
    return [math]::Round($score, 3)
}

function Run-SingleTest {
    param(
        [hashtable]$TestCase,
        [hashtable]$Bundle,
        [hashtable]$Router,
        [double]$TotalParams
    )

    $routingResult = Get-RoutingDecision -Query $TestCase.prompt -BundleConfig $Bundle -RouterConfig $Router -ExpectedSpecialist $TestCase.expected_specialist

    $routingIsCorrect = $routingResult.routing_correct

    $specialistModel = Get-SpecialistModel -SpecialistId $routingResult.specialist_id -BundleConfig $Bundle
    $specialistParams = Get-SpecialistParameters -SpecialistId $routingResult.specialist_id -BundleConfig $Bundle

    if (-not $specialistModel) {
        $specialistModel = $Bundle.specialists[0].model
        $specialistParams = $Bundle.specialists[0].parameters_b
    }

    $inferenceStart = Get-Date

    $fullPrompt = $TestCase.prompt
    if ($TestCase.context) {
        $fullPrompt = "$($TestCase.context)`n`n$($TestCase.prompt)"
    }

    $inferenceResult = Invoke-OllamaWithMetrics -Model $specialistModel -Prompt $fullPrompt
    $response = $inferenceResult.response

    $inferenceEnd = Get-Date
    $inferenceMs = [math]::Round(($inferenceEnd - $inferenceStart).TotalMilliseconds, 2)
    $totalLatencyMs = $routingResult.latency_ms + $inferenceMs

    # Evaluate response
    $responsePass = $false
    $matchDetails = @()

    if ($TestCase.expected_response_contains) {
        $containsCount = 0
        foreach ($expected in $TestCase.expected_response_contains) {
            if ($response -match [regex]::Escape($expected)) {
                $containsCount++
                $matchDetails += "contains:'$expected'"
            }
        }
        $responsePass = $containsCount -gt 0
    }

    if ($TestCase.expected_response_regex) {
        if ($response -match $TestCase.expected_response_regex) {
            $responsePass = $true
            $matchDetails += "regex:match"
        }
    }

    if ($TestCase.expected_response_not_contains) {
        foreach ($notExpected in $TestCase.expected_response_not_contains) {
            if ($response -match [regex]::Escape($notExpected)) {
                $responsePass = $false
                $matchDetails += "NOT:'$notExpected'"
            }
        }
    }

    if (-not $TestCase.expected_response_contains -and -not $TestCase.expected_response_regex) {
        $responsePass = $routingIsCorrect
    }

    return @{
        model = $specialistModel
        test_name = $TestCase.id
        pass = $responsePass
        response = $response.Substring(0, [Math]::Min(400, $response.Length))

        bundle_config = @{
            bundle_name = $Bundle.name
            bundle_version = $Bundle.version
            total_parameters_b = $TotalParams
            active_parameters_b = $specialistParams
        }

        routing = @{
            strategy = $Router.strategy
            selected_specialist = $routingResult.specialist_id
            expected_specialist = $TestCase.expected_specialist
            routing_latency_ms = $routingResult.latency_ms
            routing_confidence = $routingResult.confidence
            routing_correct = $routingIsCorrect
        }

        domain = @{
            name = $TestCase.domain
            subdomain = $TestCase.subdomain
            jurisdiction = $TestCase.jurisdiction
            difficulty = $TestCase.difficulty
        }

        cost_efficiency = @{
            active_parameters_b = $specialistParams
            inference_time_ms = $inferenceMs
            total_latency_ms = $totalLatencyMs
            tokens_generated = $inferenceResult.tokens_generated
            tokens_per_second = $inferenceResult.tokens_per_second
            prompt_tokens = $inferenceResult.prompt_tokens
            time_to_first_token_ms = $inferenceResult.prompt_eval_ms
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
}

# ═══════════════════════════════════════════════════════════════
# LOAD CONFIGURATIONS
# ═══════════════════════════════════════════════════════════════

Write-Host "Loading configurations..." -ForegroundColor Yellow

$bundlePath = Resolve-Path $BundleConfig -ErrorAction Stop
$routerPath = Resolve-Path $RouterConfig -ErrorAction Stop

$bundle = Get-JsonAsHashtable -Path $bundlePath
$router = Get-JsonAsHashtable -Path $routerPath

Write-Host "  Bundle: $($bundle.name) (v$($bundle.version))" -ForegroundColor White
Write-Host "  Specialists: $($bundle.specialists.Count)" -ForegroundColor White
Write-Host "  Router: $($router.strategy)" -ForegroundColor White
Write-Host "  Parallelism: $Parallelism concurrent tests" -ForegroundColor Cyan
Write-Host "  Max Concurrent Ollama: $MaxConcurrentOllama (GPU coordination)" -ForegroundColor Cyan

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
    $suite = Get-JsonAsHashtable -Path $testSuitePath
    foreach ($case in $suite.cases) {
        $case.domain = $suite.domain
        $case.subdomain = $suite.subdomain
        $case.jurisdiction = $suite.jurisdiction
        $testCases += $case
    }
    Write-Host "  Loaded: $(Split-Path $testSuitePath -Leaf) ($($suite.cases.Count) cases)" -ForegroundColor White
}

# Apply MaxTests limit if specified
if ($MaxTests -gt 0 -and $MaxTests -lt $testCases.Count) {
    Write-Host "  Limiting to first $MaxTests tests" -ForegroundColor Yellow
    $testCases = $testCases[0..($MaxTests-1)]
}

Write-Host "  Total test cases: $($testCases.Count)" -ForegroundColor Cyan

if ($testCases.Count -eq 0) {
    Write-Error "No test cases found in $TestSuite"
    exit 1
}

# ═══════════════════════════════════════════════════════════════
# PULL AND WARM UP MODELS
# ═══════════════════════════════════════════════════════════════

if (-not $SkipPull) {
    Write-Host "`nEnsuring models are available..." -ForegroundColor Yellow
    $models = $bundle.specialists | ForEach-Object { $_.model } | Sort-Object -Unique

    foreach ($model in $models) {
        Write-Host "  Pulling: $model" -ForegroundColor DarkGray
        ollama pull $model 2>&1 | Out-Null
    }
    Write-Host "  Models ready!" -ForegroundColor Green
}

# Build unique model list once
$models = $bundle.specialists | ForEach-Object { $_.model } | Sort-Object -Unique

# Self-verifying environment capture (version, ollama ps, git commit)
Write-Host "`nCapturing Ollama environment (self-verifying benchmark)..." -ForegroundColor Yellow
$environmentModel = $models | Select-Object -First 1
$ollamaEnvironment = Get-OllamaEnvironment -Model $environmentModel -SkipWarmup:$SkipWarmup

if (-not $SkipWarmup) {
    Write-Host "`nWarming up remaining models..." -ForegroundColor Yellow
    foreach ($model in ($models | Select-Object -Skip 1)) {
        Write-Host "  Warming: $model" -ForegroundColor DarkGray
        $warmupResult = Invoke-OllamaWarmup -Model $model
        if (-not $warmupResult.success) {
            Write-Host "    Warmup failed: $($warmupResult.error)" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "`nSkipping warmup (-SkipWarmup set)" -ForegroundColor Yellow
}

# ═══════════════════════════════════════════════════════════════
# RUN PARALLEL BENCHMARK
# ═══════════════════════════════════════════════════════════════

Write-Host "`n$('═' * 60)" -ForegroundColor Cyan
Write-Host "RUNNING PARALLEL BUNDLE BENCHMARK" -ForegroundColor Cyan
Write-Host "Parallelism: $Parallelism | Tests: $($testCases.Count) | Batch Size: $BatchSize" -ForegroundColor Yellow
Write-Host "$('═' * 60)`n" -ForegroundColor Cyan

$startTime = Get-Date
$results = [System.Collections.Concurrent.ConcurrentBag[object]]::new()
$completed = [ref]0
$totalCases = $testCases.Count

# CUDA Optimization: Create semaphore to limit concurrent Ollama GPU requests
# This prevents GPU contention when Parallelism > MaxConcurrentOllama
$effectiveConcurrency = if ($MaxClientConcurrency -gt 0) { $MaxClientConcurrency } else { $MaxConcurrentOllama }
$ollamaSemaphore = $null
$semaphoreEnabled = -not $DisableSemaphore

if ($semaphoreEnabled) {
    $ollamaSemaphore = [System.Threading.Semaphore]::new($effectiveConcurrency, $effectiveConcurrency)
    Write-Host "GPU Semaphore: Limiting to $effectiveConcurrency concurrent Ollama calls" -ForegroundColor DarkGray
} else {
    Write-Host "GPU Semaphore: DISABLED (for A/B testing)" -ForegroundColor Yellow
}

# Create runspace pool
$runspacePool = [runspacefactory]::CreateRunspacePool(1, $Parallelism)
$runspacePool.Open()

# Import functions into runspaces via script block
$testScriptBlock = {
    param($TestCase, $Bundle, $Router, $TotalParams, $ScriptDir, $Semaphore)

    # Re-import utilities in the runspace
    . "$ScriptDir\utils\Export-BenchmarkResult.ps1"
    . "$ScriptDir\utils\Invoke-BundleRouter.ps1"

    function Invoke-OllamaWithMetrics {
        param([string]$Model, [string]$Prompt, $GpuSemaphore)

        $result = @{
            response = ""
            tokens_generated = 0
            tokens_per_second = 0
            prompt_tokens = 0
            prompt_eval_ms = 0
            semaphore_wait_ms = 0
            semaphore_timeout = $false
            server_503 = $false
            error_type = $null
        }

        try {
            # CUDA Optimization: Acquire semaphore to limit concurrent GPU requests
            $semaphoreStart = Get-Date
            $acquired = $false
            if ($null -ne $GpuSemaphore) {
                $acquired = $GpuSemaphore.WaitOne(60000)  # 60s timeout
                if (-not $acquired) {
                    $result.response = "ERROR: GPU semaphore timeout (60s)"
                    $result.semaphore_timeout = $true
                    $result.error_type = "semaphore_timeout"
                    return $result
                }
            }
            $result.semaphore_wait_ms = [math]::Round(((Get-Date) - $semaphoreStart).TotalMilliseconds, 2)

            try {
                $output = $Prompt | ollama run $Model --verbose 2>&1 | Out-String

                # Check for 503 server overload
                if ($output -match "503" -or $output -match "service unavailable" -or $output -match "server is busy") {
                    $result.server_503 = $true
                    $result.error_type = "server_503"
                    $result.response = "ERROR: Server 503 (overloaded)"
                    return $result
                }

                $responseText = $output
                if ($responseText -match "(?s)^(.*?)ollama\s*:") {
                    $responseText = $Matches[1]
                }
                elseif ($responseText -match "(?s)^(.*?)total duration:") {
                    $responseText = $Matches[1]
                }

                $responseText = $responseText -replace '\[[\?\d]+[hlGK]', ''
                $responseText = $responseText -replace '\[\d*[GK]', ''
                $responseText = $responseText -replace '\[2K', ''
                $responseText = $responseText.Trim()

                $result.response = $responseText

                $cleanOutput = $output -replace '\[[\?\d]+[hlGK]', ''
                $cleanOutput = $cleanOutput -replace '\[\d*[GK]', ''

                $evalMatches = [regex]::Matches($cleanOutput, "eval count:\s+(\d+)")
                if ($evalMatches.Count -gt 0) {
                    $result.tokens_generated = [int]$evalMatches[$evalMatches.Count - 1].Groups[1].Value
                }

                $rateMatches = [regex]::Matches($cleanOutput, "eval rate:\s+([\d\.]+)")
                if ($rateMatches.Count -gt 0) {
                    $result.tokens_per_second = [double]$rateMatches[$rateMatches.Count - 1].Groups[1].Value
                }

                if ($cleanOutput -match "prompt eval count:\s+(\d+)") {
                    $result.prompt_tokens = [int]$Matches[1]
                }

                if ($cleanOutput -match "prompt eval duration:\s+([\d\.]+)ms") {
                    $result.prompt_eval_ms = [double]$Matches[1]
                }
            } finally {
                # Release semaphore
                if ($null -ne $GpuSemaphore -and $acquired) {
                    $null = $GpuSemaphore.Release()
                }
            }
        } catch {
            $result.response = "ERROR: $($_.Exception.Message)"
            $result.error_type = "exception"
        }

        return $result
    }

    function Get-EfficiencyScore {
        param([double]$Accuracy, [double]$ParametersB, [double]$LatencyMs)
        if ($ParametersB -le 0 -or $LatencyMs -le 0) { return 0 }
        return [math]::Round(($Accuracy * 100) / ($ParametersB * ($LatencyMs / 1000)), 3)
    }

    # Execute the test
    $routingResult = Get-RoutingDecision -Query $TestCase.prompt -BundleConfig $Bundle -RouterConfig $Router -ExpectedSpecialist $TestCase.expected_specialist
    $routingIsCorrect = $routingResult.routing_correct

    $specialistModel = Get-SpecialistModel -SpecialistId $routingResult.specialist_id -BundleConfig $Bundle
    $specialistParams = Get-SpecialistParameters -SpecialistId $routingResult.specialist_id -BundleConfig $Bundle

    if (-not $specialistModel) {
        $specialistModel = $Bundle.specialists[0].model
        $specialistParams = $Bundle.specialists[0].parameters_b
    }

    $inferenceStart = Get-Date
    $fullPrompt = if ($TestCase.context) { "$($TestCase.context)`n`n$($TestCase.prompt)" } else { $TestCase.prompt }
    $inferenceResult = Invoke-OllamaWithMetrics -Model $specialistModel -Prompt $fullPrompt -GpuSemaphore $Semaphore
    $response = $inferenceResult.response
    $inferenceMs = [math]::Round(((Get-Date) - $inferenceStart).TotalMilliseconds, 2)
    $totalLatencyMs = $routingResult.latency_ms + $inferenceMs

    # Evaluate response
    $responsePass = $false
    if ($TestCase.expected_response_contains) {
        foreach ($expected in $TestCase.expected_response_contains) {
            if ($response -match [regex]::Escape($expected)) {
                $responsePass = $true
                break
            }
        }
    }
    if ($TestCase.expected_response_regex -and ($response -match $TestCase.expected_response_regex)) {
        $responsePass = $true
    }
    if ($TestCase.expected_response_not_contains) {
        foreach ($notExpected in $TestCase.expected_response_not_contains) {
            if ($response -match [regex]::Escape($notExpected)) {
                $responsePass = $false
            }
        }
    }
    if (-not $TestCase.expected_response_contains -and -not $TestCase.expected_response_regex) {
        $responsePass = $routingIsCorrect
    }

    return @{
        model = $specialistModel
        test_name = $TestCase.id
        pass = $responsePass
        response = $response.Substring(0, [Math]::Min(400, $response.Length))
        bundle_config = @{
            bundle_name = $Bundle.name
            bundle_version = $Bundle.version
            total_parameters_b = $TotalParams
            active_parameters_b = $specialistParams
        }
        routing = @{
            strategy = $Router.strategy
            selected_specialist = $routingResult.specialist_id
            expected_specialist = $TestCase.expected_specialist
            routing_latency_ms = $routingResult.latency_ms
            routing_confidence = $routingResult.confidence
            routing_correct = $routingIsCorrect
        }
        domain = @{
            name = $TestCase.domain
            subdomain = $TestCase.subdomain
            jurisdiction = $TestCase.jurisdiction
            difficulty = $TestCase.difficulty
        }
        cost_efficiency = @{
            active_parameters_b = $specialistParams
            inference_time_ms = $inferenceMs
            total_latency_ms = $totalLatencyMs
            tokens_generated = $inferenceResult.tokens_generated
            tokens_per_second = $inferenceResult.tokens_per_second
            prompt_tokens = $inferenceResult.prompt_tokens
            time_to_first_token_ms = $inferenceResult.prompt_eval_ms
            efficiency_score = (Get-EfficiencyScore -Accuracy $(if ($responsePass) { 1.0 } else { 0.0 }) -ParametersB $specialistParams -LatencyMs $inferenceMs)
        }
        metrics = @{
            routing_latency_ms = $routingResult.latency_ms
            inference_latency_ms = $inferenceMs
            total_latency_ms = $totalLatencyMs
            routing_correct = $routingIsCorrect
            response_correct = $responsePass
        }
        # Semaphore metrics for decision-grade analysis
        concurrency = @{
            semaphore_wait_ms = $inferenceResult.semaphore_wait_ms
            semaphore_timeout = $inferenceResult.semaphore_timeout
            server_503 = $inferenceResult.server_503
            error_type = $inferenceResult.error_type
        }
    }
}

# Queue all tests (suppress all output during setup)
$runspaces = @()
$testIndex = 0

foreach ($testCase in $testCases) {
    $powershell = [powershell]::Create()
    $null = $powershell.AddScript($testScriptBlock)
    $null = $powershell.AddArgument($testCase)
    $null = $powershell.AddArgument($bundle)
    $null = $powershell.AddArgument($router)
    $null = $powershell.AddArgument($totalParams)
    $null = $powershell.AddArgument($scriptDir)
    $null = $powershell.AddArgument($ollamaSemaphore)  # CUDA Optimization: Pass GPU semaphore

    $powershell.RunspacePool = $runspacePool

    $handle = $powershell.BeginInvoke()
    $runspaces += @{
        PowerShell = $powershell
        Handle = $handle
        TestId = $testCase.id
        Index = $testIndex++
    }
}

Write-Host "Queued $($runspaces.Count) tests across $Parallelism workers..." -ForegroundColor Yellow
Write-Host ""

# Process results as they complete
$allResults = @()
$routingCorrect = 0
$responseCorrect = 0
$completedCount = 0

while ($runspaces.Count -gt 0) {
    $completedRunspaces = $runspaces | Where-Object { $_.Handle.IsCompleted }

    foreach ($rs in $completedRunspaces) {
        try {
            $endResult = $rs.PowerShell.EndInvoke($rs.Handle)
            # Get last hashtable result (filter out debug output)
            $result = $endResult | Where-Object { $_ -is [hashtable] -and $_.test_name } | Select-Object -Last 1
            if ($result) {
                $allResults += $result
                if ($result.routing.routing_correct) { $routingCorrect++ }
                if ($result.pass) { $responseCorrect++ }
            }
        } catch {
            Write-Warning "Test $($rs.TestId) failed: $($_.Exception.Message)"
        } finally {
            $null = $rs.PowerShell.Dispose()
        }

        $completedCount++

        # Progress update every BatchSize tests
        if ($completedCount % $BatchSize -eq 0 -or $completedCount -eq $totalCases) {
            $elapsed = (Get-Date) - $startTime
            $testsPerSec = [math]::Round($completedCount / $elapsed.TotalSeconds, 1)
            $eta = if ($testsPerSec -gt 0) { [math]::Round(($totalCases - $completedCount) / $testsPerSec, 0) } else { "?" }

            $routingPct = [math]::Round(($routingCorrect / $completedCount) * 100, 1)
            $responsePct = [math]::Round(($responseCorrect / $completedCount) * 100, 1)

            Write-Host "`r[$completedCount/$totalCases] " -NoNewline
            Write-Host "Routing: $routingPct% " -NoNewline -ForegroundColor $(if ($routingPct -ge 80) { "Green" } else { "Yellow" })
            Write-Host "| Response: $responsePct% " -NoNewline -ForegroundColor $(if ($responsePct -ge 80) { "Green" } else { "Yellow" })
            Write-Host "| $testsPerSec tests/s | ETA: ${eta}s   " -NoNewline -ForegroundColor DarkGray
        }

        $runspaces = $runspaces | Where-Object { $_ -ne $rs }
    }

    if ($runspaces.Count -gt 0) {
        Start-Sleep -Milliseconds 100
    }
}

Write-Host "`n"

# Cleanup
$runspacePool.Close()
$runspacePool.Dispose()

# Dispose semaphore (prevent resource leak)
if ($null -ne $ollamaSemaphore) {
    $ollamaSemaphore.Dispose()
}

$endTime = Get-Date
$totalDuration = ($endTime - $startTime).TotalSeconds

# ═══════════════════════════════════════════════════════════════
# EXPORT RESULTS
# ═══════════════════════════════════════════════════════════════

Write-Host "$('═' * 60)" -ForegroundColor Cyan
Write-Host "EXPORTING RESULTS" -ForegroundColor Cyan
Write-Host "$('═' * 60)`n" -ForegroundColor Cyan

$testName = "bundle_benchmark_parallel_$($bundle.name)_$($router.strategy)"
$timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
$filename = "{0}_{1}.json" -f (Get-Date -Format "yyyy-MM-dd_HHmmss"), $testName

# Calculate summary stats
$routingAccuracy = if ($allResults.Count -gt 0) { $routingCorrect / $allResults.Count } else { 0 }
$responseAccuracy = if ($allResults.Count -gt 0) { $responseCorrect / $allResults.Count } else { 0 }

$sumLatency = 0
$sumActiveParams = 0
$sumTokensPerSec = 0
$countWithTokens = 0

# Collect semaphore wait times for P95 calculation
$semaphoreWaitTimes = @()
$semaphoreTimeoutCount = 0
$server503Count = 0

foreach ($r in $allResults) {
    $sumLatency += $r.cost_efficiency.total_latency_ms
    $sumActiveParams += $r.bundle_config.active_parameters_b
    if ($r.cost_efficiency.tokens_per_second -gt 0) {
        $sumTokensPerSec += $r.cost_efficiency.tokens_per_second
        $countWithTokens++
    }

    # Collect concurrency metrics
    if ($r.concurrency) {
        $semaphoreWaitTimes += $r.concurrency.semaphore_wait_ms
        if ($r.concurrency.semaphore_timeout) { $semaphoreTimeoutCount++ }
        if ($r.concurrency.server_503) { $server503Count++ }
    }
}

$avgLatency = if ($allResults.Count -gt 0) { $sumLatency / $allResults.Count } else { 0 }
$avgActiveParams = if ($allResults.Count -gt 0) { $sumActiveParams / $allResults.Count } else { 0 }
$avgTokensPerSec = if ($countWithTokens -gt 0) { $sumTokensPerSec / $countWithTokens } else { 0 }

# Calculate semaphore statistics (P95 using nearest-rank method)
$avgSemaphoreWait = 0
$maxSemaphoreWait = 0
$p95SemaphoreWait = 0

if ($semaphoreWaitTimes.Count -gt 0) {
    $avgSemaphoreWait = [math]::Round(($semaphoreWaitTimes | Measure-Object -Sum).Sum / $semaphoreWaitTimes.Count, 2)
    $maxSemaphoreWait = [math]::Round(($semaphoreWaitTimes | Measure-Object -Maximum).Maximum, 2)

    # P95 using nearest-rank method: sort ascending, index = ceiling(0.95 * N) - 1, clamp to range
    $sorted = $semaphoreWaitTimes | Sort-Object
    $p95Index = [math]::Ceiling(0.95 * $sorted.Count) - 1
    $p95Index = [math]::Max(0, [math]::Min($p95Index, $sorted.Count - 1))
    $p95SemaphoreWait = [math]::Round($sorted[$p95Index], 2)
}

$output = @{
    meta = @{
        timestamp = $timestamp
        hostname = $env:COMPUTERNAME
        hardware = Get-HardwareProfile
        schema_version = "1.0"
        bundle_name = $bundle.name
        parallelism = $Parallelism
        total_duration_seconds = [math]::Round($totalDuration, 1)
        tests_per_second = [math]::Round($allResults.Count / $totalDuration, 2)
    }
    environment = $ollamaEnvironment
    test = @{
        name = $testName
        category = "bundle"
        version = "1.0"
        bundle_config = $bundlePath.Path
        router_config = $routerPath.Path
        execution_mode = "parallel"
    }
    summary = @{
        total_tests = $allResults.Count
        routing_accuracy = [math]::Round($routingAccuracy, 4)
        response_accuracy = [math]::Round($responseAccuracy, 4)
        routing_correct = $routingCorrect
        response_correct = $responseCorrect
        avg_latency_ms = [math]::Round($avgLatency, 1)
        avg_active_parameters_b = [math]::Round($avgActiveParams, 2)
        avg_tokens_per_second = [math]::Round($avgTokensPerSec, 1)
        efficiency_score = (Get-EfficiencyScore -Accuracy $responseAccuracy -ParametersB $avgActiveParams -LatencyMs $avgLatency)
    }
    # Concurrency metrics (decision-grade: two separate overload signals)
    concurrency_summary = @{
        semaphore_enabled = $semaphoreEnabled
        effective_concurrency = $effectiveConcurrency
        # Client-side throttle metrics
        client_throttle = @{
            avg_semaphore_wait_ms = $avgSemaphoreWait
            max_semaphore_wait_ms = $maxSemaphoreWait
            p95_semaphore_wait_ms = $p95SemaphoreWait
            semaphore_timeout_count = $semaphoreTimeoutCount
        }
        # Server-side overload metrics
        server_overload = @{
            server_503_count = $server503Count
        }
        # Combined overload rate
        total_overload_count = $semaphoreTimeoutCount + $server503Count
        overload_rate = if ($allResults.Count -gt 0) { [math]::Round(($semaphoreTimeoutCount + $server503Count) / $allResults.Count, 4) } else { 0 }
    }
    results = $allResults
}

$rawDir = Join-Path $OutputDir "raw"
if (-not (Test-Path $rawDir)) {
    New-Item -ItemType Directory -Path $rawDir -Force | Out-Null
}

$fullPath = Join-Path $rawDir $filename
$output | ConvertTo-Json -Depth 15 | Out-File $fullPath -Encoding UTF8

Write-Host "JSON saved: $fullPath" -ForegroundColor Green

# Save environment audit trail alongside JSON (self-verifying proof)
if ($null -ne $ollamaEnvironment) {
    $envFilename = "{0}_{1}_ollama-environment.txt" -f (Get-Date -Format "yyyy-MM-dd_HHmmss"), $testName
    $envPath = Join-Path $rawDir $envFilename

    $envLines = @()
    $envLines += "timestamp_utc: $($ollamaEnvironment.timestamp_utc)"
    $envLines += "ollama_version: $($ollamaEnvironment.ollama_version)"
    $envLines += "git_commit: $($ollamaEnvironment.git_commit)"
    $envLines += ""
    $envLines += "ollama ps (raw):"
    $envLines += $ollamaEnvironment.ollama_ps_raw

    $envLines | Out-File $envPath -Encoding UTF8
    Write-Host "Environment saved: $envPath" -ForegroundColor Green
}

# ═══════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════

Write-Host "`n$('═' * 60)" -ForegroundColor Cyan
Write-Host "PARALLEL BENCHMARK SUMMARY" -ForegroundColor Cyan
Write-Host "$('═' * 60)`n" -ForegroundColor Cyan

$routingAccuracyPct = [math]::Round($routingAccuracy * 100, 1)
$responseAccuracyPct = [math]::Round($responseAccuracy * 100, 1)

Write-Host "Bundle: $($bundle.name)" -ForegroundColor White
Write-Host "Router: $($router.strategy)" -ForegroundColor White
Write-Host "Test Cases: $($allResults.Count)" -ForegroundColor White
Write-Host "Parallelism: $Parallelism workers" -ForegroundColor White
Write-Host ""

$routingColor = if ($routingAccuracyPct -ge 80) { "Green" } elseif ($routingAccuracyPct -ge 60) { "Yellow" } else { "Red" }
$responseColor = if ($responseAccuracyPct -ge 80) { "Green" } elseif ($responseAccuracyPct -ge 60) { "Yellow" } else { "Red" }

Write-Host "Routing Accuracy:  " -NoNewline
Write-Host "$routingCorrect / $($allResults.Count) ($routingAccuracyPct%)" -ForegroundColor $routingColor

Write-Host "Response Accuracy: " -NoNewline
Write-Host "$responseCorrect / $($allResults.Count) ($responseAccuracyPct%)" -ForegroundColor $responseColor

Write-Host ""
Write-Host "Performance:" -ForegroundColor White
Write-Host "  Total Duration:  $([math]::Round($totalDuration, 1)) seconds" -ForegroundColor DarkGray
Write-Host "  Throughput:      $([math]::Round($allResults.Count / $totalDuration, 2)) tests/second" -ForegroundColor DarkGray
Write-Host "  Avg Latency:     $('{0:N0}' -f $avgLatency) ms per test" -ForegroundColor DarkGray

Write-Host ""
Write-Host "Parameters:" -ForegroundColor White
Write-Host "  Total Bundle: $($totalParams)B" -ForegroundColor DarkGray
Write-Host "  Avg Active:   $([math]::Round($avgActiveParams, 1))B" -ForegroundColor DarkGray

Write-Host ""
Write-Host "Efficiency Score: " -NoNewline
$effScore = $output.summary.efficiency_score
$effColor = if ($effScore -ge 1) { "Green" } elseif ($effScore -ge 0.5) { "Yellow" } else { "Red" }
Write-Host "$effScore" -ForegroundColor $effColor

Write-Host ""
Write-Host "Concurrency Metrics:" -ForegroundColor White
Write-Host "  Semaphore Enabled: $semaphoreEnabled" -ForegroundColor DarkGray
if ($semaphoreEnabled) {
    Write-Host "  Effective Concurrency: $effectiveConcurrency" -ForegroundColor DarkGray
    Write-Host "  Avg Semaphore Wait:    $avgSemaphoreWait ms" -ForegroundColor DarkGray
    Write-Host "  P95 Semaphore Wait:    $p95SemaphoreWait ms" -ForegroundColor DarkGray
    Write-Host "  Max Semaphore Wait:    $maxSemaphoreWait ms" -ForegroundColor DarkGray
}
$overloadColor = if ($semaphoreTimeoutCount + $server503Count -eq 0) { "Green" } else { "Yellow" }
Write-Host "  Semaphore Timeouts:    $semaphoreTimeoutCount" -ForegroundColor $overloadColor
Write-Host "  Server 503 Errors:     $server503Count" -ForegroundColor $overloadColor

Write-Host ""
