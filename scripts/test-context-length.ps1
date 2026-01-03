<#
.SYNOPSIS
    LLM Context Length Stress Test
.DESCRIPTION
    Tests model performance degradation as context length increases.
    Measures time to respond and quality at various context sizes.
.PARAMETER OutputDir
    Directory to save results. Default: C:\Users\14104\llm-benchmarks\results
.PARAMETER Model
    Model to test. Default: gpt-oss:120b
.PARAMETER Sizes
    Array of token counts to test. Default: 2K to 64K
.EXAMPLE
    .\test-context-length.ps1
    Runs context stress test with default sizes
.EXAMPLE
    .\test-context-length.ps1 -Sizes @(1000, 5000, 10000) -Model "qwen2.5:32b"
    Tests specific context sizes on specified model
#>

param(
    [string]$OutputDir = "C:\Users\14104\llm-benchmarks\results",
    [string]$Model = "gpt-oss:120b",
    [int[]]$Sizes = @(2000, 8000, 16000, 32000, 64000)
)

# Import utility functions
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptDir\utils\Export-BenchmarkResult.ps1"

Write-Host @"

╔═══════════════════════════════════════════════════════════════╗
║           LLM CONTEXT LENGTH STRESS TEST v1.0                 ║
║           Finding Your Effective Context Window               ║
╚═══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

Write-Host "Model: $Model" -ForegroundColor Yellow
Write-Host "Context sizes to test: $($Sizes -join ', ') tokens`n" -ForegroundColor Yellow

# Generate filler text (encyclopedia-style content)
function Get-FillerText {
    param([int]$ApproxTokens)

    # Each fact is roughly 15-20 tokens
    $facts = @(
        "The Amazon rainforest produces approximately 20% of the world's oxygen supply and contains about 10% of all species on Earth."
        "Mount Everest grows about 4 millimeters taller each year due to geological uplift caused by the collision of tectonic plates."
        "The human brain contains approximately 86 billion neurons, each connected to thousands of other neurons through synapses."
        "Light from the Sun takes about 8 minutes and 20 seconds to reach Earth, traveling at approximately 299,792 kilometers per second."
        "The Great Barrier Reef is the world's largest living structure, visible from space, spanning over 2,300 kilometers."
        "Honey never spoils because its low moisture content and acidic pH create an environment where bacteria cannot survive."
        "Octopuses have three hearts and blue blood, with two hearts pumping blood to the gills and one to the rest of the body."
        "The Sahara Desert was once a lush green savanna with lakes, rivers, and abundant wildlife about 5,000 to 11,000 years ago."
        "A single bolt of lightning contains enough energy to toast about 100,000 slices of bread if it could be harnessed efficiently."
        "The deepest part of the ocean, the Challenger Deep, is about 11 kilometers below sea level in the Mariana Trench."
        "Diamonds can be made from peanut butter under extreme pressure, as both contain carbon atoms that can be rearranged."
        "The shortest war in history was between Britain and Zanzibar in 1896, lasting only 38 to 45 minutes before Zanzibar surrendered."
        "Bananas are technically berries while strawberries are not, according to botanical definitions based on seed placement."
        "The Eiffel Tower can grow up to 15 centimeters taller during summer due to thermal expansion of its iron structure."
        "Cows have best friends and experience stress when separated from them, showing measurable increases in cortisol levels."
        "The average person walks about 100,000 miles in their lifetime, equivalent to walking around the Earth four times."
        "Venus rotates so slowly that a day on Venus is longer than its year, taking 243 Earth days to complete one rotation."
        "The inventor of the Pringles can is buried in one, as per his request, in Cincinnati, Ohio."
        "Cleopatra lived closer in time to the Moon landing than to the construction of the Great Pyramid of Giza."
        "A jiffy is an actual unit of time, defined in electronics as 1/60th of a second or in physics as the time for light to travel one centimeter."
    )

    $factsNeeded = [math]::Ceiling($ApproxTokens / 20)
    $result = @()

    for ($i = 0; $i -lt $factsNeeded; $i++) {
        $result += $facts[$i % $facts.Count]
    }

    return $result -join " "
}

$results = @()

foreach ($size in $Sizes) {
    Write-Host "`n$('─' * 60)" -ForegroundColor DarkGray
    Write-Host "Testing ~$size token context" -ForegroundColor Cyan
    Write-Host "$('─' * 60)" -ForegroundColor DarkGray

    # Generate context with a hidden needle
    $needle = "SECRET-CODE-" + (Get-Random -Maximum 9999)
    $fillerBefore = Get-FillerText -ApproxTokens ([math]::Floor($size * 0.4))
    $fillerAfter = Get-FillerText -ApproxTokens ([math]::Floor($size * 0.4))

    $prompt = @"
$fillerBefore

IMPORTANT: The secret verification code is: $needle

$fillerAfter

Based on all the information above, what is the secret verification code? Reply with ONLY the code.
"@

    $charCount = $prompt.Length
    $estimatedTokens = [math]::Round($charCount / 4)

    Write-Host "  Estimated tokens: ~$estimatedTokens" -ForegroundColor DarkGray
    Write-Host "  Needle position: middle (40%)" -ForegroundColor DarkGray
    Write-Host "  Running..." -ForegroundColor DarkGray

    # Write prompt to temp file to avoid Windows command line length limit
    $tempFile = [System.IO.Path]::GetTempFileName()
    $prompt | Out-File -FilePath $tempFile -Encoding UTF8 -NoNewline

    # Measure response time - use file input to avoid cmd line limits
    $startTime = Get-Date
    $response = Get-Content $tempFile -Raw | ollama run $Model 2>&1 | Out-String
    $endTime = Get-Date
    $totalSeconds = ($endTime - $startTime).TotalSeconds

    # Cleanup temp file
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue

    # Check if needle was found
    $needleFound = $response -match [regex]::Escape($needle)

    # Calculate metrics
    $timePerKToken = if ($estimatedTokens -gt 0) { [math]::Round($totalSeconds / ($estimatedTokens / 1000), 2) } else { 0 }

    $result = @{
        model = $Model
        test_name = "context_length_$size"
        metrics = @{
            target_tokens = $size
            estimated_tokens = $estimatedTokens
            total_time_seconds = [math]::Round($totalSeconds, 2)
            time_per_1k_tokens = $timePerKToken
            needle_position = "middle"
            needle_found = $needleFound
        }
        pass = $needleFound
        response = $response.Trim().Substring(0, [Math]::Min(100, $response.Trim().Length))
    }

    $results += $result

    # Display result
    $color = if ($needleFound) { "Green" } else { "Red" }
    $status = if ($needleFound) { "FOUND" } else { "NOT FOUND" }

    Write-Host ""
    Write-Host "  Results:" -ForegroundColor White
    Write-Host "    Time:         $([math]::Round($totalSeconds, 1))s"
    Write-Host "    Time/1K tok:  $($timePerKToken)s"
    Write-Host "    Needle:       " -NoNewline; Write-Host $status -ForegroundColor $color
}

# ═══════════════════════════════════════════════════════════════
# EXPORT RESULTS
# ═══════════════════════════════════════════════════════════════
Write-Host "`n$('═' * 60)" -ForegroundColor Cyan
Write-Host "EXPORTING RESULTS" -ForegroundColor Cyan
Write-Host "$('═' * 60)`n" -ForegroundColor Cyan

Export-JsonResult -TestName "context_stress" -Category "cognitive" -Results $results -OutputDir "$OutputDir\raw"

# Build CSV results
$csvResults = $results | ForEach-Object {
    [PSCustomObject]@{
        timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        model = $_.model
        target_tokens = $_.metrics.target_tokens
        estimated_tokens = $_.metrics.estimated_tokens
        total_time_seconds = $_.metrics.total_time_seconds
        time_per_1k_tokens = $_.metrics.time_per_1k_tokens
        needle_found = $_.metrics.needle_found
    }
}
Export-CsvResult -TestName "context_stress" -Results $csvResults -OutputDir "$OutputDir\csv"

# Console summary
Write-Host "`n$('═' * 60)" -ForegroundColor Cyan
Write-Host "CONTEXT LENGTH STRESS TEST SUMMARY" -ForegroundColor Cyan
Write-Host "$('═' * 60)`n" -ForegroundColor Cyan

Write-Host "  Context Size | Time     | Time/1K  | Recall" -ForegroundColor White
Write-Host "  $('-' * 50)" -ForegroundColor DarkGray

foreach ($r in $results) {
    $status = if ($r.pass) { "PASS" } else { "FAIL" }
    $color = if ($r.pass) { "Green" } else { "Red" }
    $size = "{0,12}" -f "$($r.metrics.target_tokens) tok"
    $time = "{0,8}" -f "$($r.metrics.total_time_seconds)s"
    $timePer1K = "{0,8}" -f "$($r.metrics.time_per_1k_tokens)s"

    Write-Host "  $size | $time | $timePer1K | " -NoNewline
    Write-Host $status -ForegroundColor $color
}

# Find effective context window
$passedSizes = $results | Where-Object { $_.pass } | ForEach-Object { $_.metrics.target_tokens }
$failedSizes = $results | Where-Object { -not $_.pass } | ForEach-Object { $_.metrics.target_tokens }

Write-Host ""
if ($passedSizes.Count -gt 0) {
    $maxPassed = ($passedSizes | Measure-Object -Maximum).Maximum
    Write-Host "  Effective context window: " -NoNewline
    Write-Host "~$maxPassed tokens" -ForegroundColor Green

    if ($failedSizes.Count -gt 0) {
        $firstFailed = ($failedSizes | Measure-Object -Minimum).Minimum
        Write-Host "  Recall degradation starts at: ~$firstFailed tokens" -ForegroundColor Yellow
    }
} else {
    Write-Host "  WARNING: No context sizes passed the recall test" -ForegroundColor Red
}

Write-Host ""
