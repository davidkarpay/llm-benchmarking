<#
.SYNOPSIS
    LLM Cognitive Benchmark Script
.DESCRIPTION
    Tests LLM cognitive capabilities including:
    - Needle-in-a-Haystack (information retrieval from context)
    - Multi-Hop Reasoning (connecting facts across context)
    - Working Memory (tracking multiple entities)
    - Temporal Reasoning (understanding event sequences)
    - Selective Forgetting (following corrections)
.PARAMETER OutputDir
    Directory to save results. Default: C:\Users\14104\llm-benchmarks\results
.PARAMETER Model
    Model to benchmark. Default: gpt-oss:120b
.PARAMETER Tests
    Specific tests to run. Default: all tests
.EXAMPLE
    .\benchmark-cognitive.ps1
    Runs all cognitive tests on default model
.EXAMPLE
    .\benchmark-cognitive.ps1 -Model "qwen2.5:32b" -Tests @("needle", "multihop")
    Runs specific tests on specified model
#>

param(
    [string]$OutputDir = "C:\Users\14104\llm-benchmarks\results",
    [string]$Model = "gpt-oss:120b",
    [string[]]$Tests = @("needle", "multihop", "memory10", "memory30", "temporal", "forgetting")
)

# Import utility functions
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptDir\utils\Export-BenchmarkResult.ps1"

Write-Host @"

╔═══════════════════════════════════════════════════════════════╗
║           LLM COGNITIVE BENCHMARK SUITE v1.0                  ║
║           Testing Understanding, Memory & Reasoning           ║
╚═══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

Write-Host "Model: $Model" -ForegroundColor Yellow
Write-Host "Tests: $($Tests -join ', ')`n" -ForegroundColor Yellow

$results = @()

# ═══════════════════════════════════════════════════════════════
# TEST 1: NEEDLE IN HAYSTACK
# ═══════════════════════════════════════════════════════════════
if ("needle" -in $Tests) {
    Write-Host "`n$('─' * 60)" -ForegroundColor DarkGray
    Write-Host "TEST: Needle-in-a-Haystack" -ForegroundColor Cyan
    Write-Host "Purpose: Can the model retrieve specific info from context?" -ForegroundColor DarkGray
    Write-Host "$('─' * 60)" -ForegroundColor DarkGray

    $needle = "DELTA-SUNRISE-4821"
    $needlePrompt = @"
Here is a collection of random facts:

The Great Wall of China is approximately 13,171 miles long. Honey never spoils and archaeologists have found 3000-year-old honey in Egyptian tombs that was still edible. The shortest war in history was between Britain and Zanzibar in 1896, lasting only 38 minutes. Octopuses have three hearts and blue blood. The Eiffel Tower can grow up to 6 inches taller during summer due to thermal expansion.

The secret access code for Project Nightingale is: $needle

Venus is the hottest planet in our solar system despite Mercury being closer to the Sun. A group of flamingos is called a "flamboyance." The inventor of the Pringles can is buried in one. Scotland's national animal is the unicorn. Bananas are berries, but strawberries aren't.

The Amazon River dolphin is pink. Cleopatra lived closer in time to the Moon landing than to the construction of the Great Pyramid. A jiffy is an actual unit of time equal to 1/100th of a second. The longest hiccuping spree lasted 68 years.

Question: What is the secret access code for Project Nightingale? Reply with ONLY the code, nothing else.
"@

    Write-Host "  Running test..." -ForegroundColor DarkGray
    $response = ollama run $Model $needlePrompt 2>&1 | Out-String
    $needlePass = $response -match [regex]::Escape($needle)

    $results += @{
        test_name = "needle_in_haystack"
        model = $Model
        metrics = @{
            needle_position = "middle"
            context_tokens = 500
            found = $needlePass
        }
        pass = $needlePass
        response = $response.Trim().Substring(0, [Math]::Min(200, $response.Trim().Length))
    }

    $color = if ($needlePass) { "Green" } else { "Red" }
    $status = if ($needlePass) { "PASS" } else { "FAIL" }
    Write-Host "  Result: " -NoNewline; Write-Host $status -ForegroundColor $color
    Write-Host "  Expected: $needle"
    Write-Host "  Got: $($response.Trim().Substring(0, [Math]::Min(50, $response.Trim().Length)))..."
}

# ═══════════════════════════════════════════════════════════════
# TEST 2: MULTI-HOP REASONING
# ═══════════════════════════════════════════════════════════════
if ("multihop" -in $Tests) {
    Write-Host "`n$('─' * 60)" -ForegroundColor DarkGray
    Write-Host "TEST: Multi-Hop Reasoning" -ForegroundColor Cyan
    Write-Host "Purpose: Can the model connect facts across context?" -ForegroundColor DarkGray
    Write-Host "$('─' * 60)" -ForegroundColor DarkGray

    $multihopPrompt = @"
Read the following facts carefully:

1. Sarah works at Quantum Dynamics Corporation.
2. Quantum Dynamics Corporation is headquartered in Austin, Texas.
3. The CEO of Quantum Dynamics Corporation is Marcus Webb.
4. Marcus Webb graduated from MIT in 1995.
5. Marcus Webb's wife is named Elena.
6. Elena is a professional violinist with the Boston Symphony Orchestra.
7. The Boston Symphony Orchestra performs at Symphony Hall.

Answer these questions with brief answers:
A) In what city is Sarah's company headquartered?
B) What year did Sarah's CEO graduate from MIT?
C) What instrument does the wife of Sarah's CEO play?
D) Where does Sarah's CEO's wife perform?
"@

    Write-Host "  Running test..." -ForegroundColor DarkGray
    $response = ollama run $Model $multihopPrompt 2>&1 | Out-String

    # Check for correct answers
    $correctAnswers = @{
        "A" = "Austin"
        "B" = "1995"
        "C" = "violin"
        "D" = "Symphony Hall"
    }

    $correctCount = 0
    foreach ($key in $correctAnswers.Keys) {
        if ($response -match $correctAnswers[$key]) {
            $correctCount++
        }
    }

    $accuracy = [math]::Round($correctCount / 4 * 100, 1)
    $multihopPass = $correctCount -ge 3  # Pass if 3+ correct

    $results += @{
        test_name = "multi_hop_reasoning"
        model = $Model
        metrics = @{
            hops_required = 2
            questions = 4
            correct = $correctCount
            accuracy = $accuracy
        }
        pass = $multihopPass
        response = $response.Trim().Substring(0, [Math]::Min(300, $response.Trim().Length))
    }

    $color = if ($multihopPass) { "Green" } else { "Red" }
    $status = if ($multihopPass) { "PASS" } else { "FAIL" }
    Write-Host "  Result: " -NoNewline; Write-Host "$status ($correctCount/4 correct, $accuracy%)" -ForegroundColor $color
}

# ═══════════════════════════════════════════════════════════════
# TEST 3: WORKING MEMORY (10 Entities)
# ═══════════════════════════════════════════════════════════════
if ("memory10" -in $Tests) {
    Write-Host "`n$('─' * 60)" -ForegroundColor DarkGray
    Write-Host "TEST: Working Memory (10 entities)" -ForegroundColor Cyan
    Write-Host "Purpose: How many facts can the model track?" -ForegroundColor DarkGray
    Write-Host "$('─' * 60)" -ForegroundColor DarkGray

    $memory10Prompt = @"
Remember these facts exactly:
- Alice has a RED hat
- Bob drives a BLUE car
- Carol lives in PARIS
- David owns a GOLDEN retriever
- Emma works as a DOCTOR
- Frank plays the PIANO
- Grace speaks JAPANESE
- Henry collects STAMPS
- Ivy grows ROSES
- Jack writes POETRY

Answer these questions with ONE word each:
1. What color is Alice's hat?
2. What does Henry collect?
3. What language does Grace speak?
4. What does Ivy grow?
5. What instrument does Frank play?
"@

    Write-Host "  Running test..." -ForegroundColor DarkGray
    $response = ollama run $Model $memory10Prompt 2>&1 | Out-String

    $expectedAnswers = @("RED", "STAMPS", "JAPANESE", "ROSES", "PIANO")
    $memCorrect = ($expectedAnswers | Where-Object { $response -match $_ }).Count
    $accuracy = [math]::Round($memCorrect / 5 * 100, 1)
    $memoryPass = $memCorrect -eq 5

    $results += @{
        test_name = "working_memory_10"
        model = $Model
        metrics = @{
            entities = 10
            questions = 5
            correct = $memCorrect
            accuracy = $accuracy
        }
        pass = $memoryPass
        response = $response.Trim().Substring(0, [Math]::Min(200, $response.Trim().Length))
    }

    $color = if ($memoryPass) { "Green" } elseif ($memCorrect -ge 3) { "Yellow" } else { "Red" }
    $status = if ($memoryPass) { "PASS" } else { "FAIL" }
    Write-Host "  Result: " -NoNewline; Write-Host "$status ($memCorrect/5 correct, $accuracy%)" -ForegroundColor $color
}

# ═══════════════════════════════════════════════════════════════
# TEST 4: WORKING MEMORY (30 Entities) - Challenging
# ═══════════════════════════════════════════════════════════════
if ("memory30" -in $Tests) {
    Write-Host "`n$('─' * 60)" -ForegroundColor DarkGray
    Write-Host "TEST: Working Memory (30 entities) - CHALLENGING" -ForegroundColor Cyan
    Write-Host "Purpose: Stress test entity tracking capacity" -ForegroundColor DarkGray
    Write-Host "$('─' * 60)" -ForegroundColor DarkGray

    $memory30Prompt = @"
Remember these facts about 30 people:
Alice: red hat, age 25, from Boston | Bob: blue car, age 34, from Denver
Carol: lives in Paris, age 28, loves hiking | David: golden retriever, age 41, works in finance
Emma: doctor, age 37, drives a Tesla | Frank: plays piano, age 52, from Seattle
Grace: speaks Japanese, age 29, vegetarian | Henry: collects stamps, age 63, retired teacher
Ivy: grows roses, age 44, marathon runner | Jack: writes poetry, age 31, coffee lover
Kate: silver bracelet, age 26, from Miami | Leo: owns a bakery, age 48, early riser
Maya: teaches yoga, age 33, from Portland | Noah: builds robots, age 27, PhD student
Olivia: black cat, age 39, works remotely | Pete: rides motorcycles, age 45, from Austin
Quinn: plays chess, age 22, math major | Rosa: paints murals, age 36, from Chicago
Sam: brews beer, age 42, bearded | Tina: flies drones, age 24, engineer
Uma: reads tarot, age 55, from New Orleans | Victor: raises bees, age 61, organic farmer
Wendy: surfs waves, age 30, from San Diego | Xavier: fixes clocks, age 58, antique dealer
Yuki: makes sushi, age 35, from Tokyo | Zara: designs games, age 28, streams online
Aaron: climbs mountains, age 40, from Boulder | Beth: trains horses, age 47, ranch owner
Chris: codes apps, age 23, startup founder | Diana: sculpts clay, age 51, art professor

Answer with brief responses:
1. What does Xavier fix?
2. How old is Quinn?
3. What pet does Olivia have?
4. Where is Yuki from?
5. What does Victor raise?
6. Who is the marathon runner?
7. What does Leo own?
8. What does Noah build?
9. What does Uma read?
10. What does Pete ride?
"@

    Write-Host "  Running test..." -ForegroundColor DarkGray
    $response = ollama run $Model $memory30Prompt 2>&1 | Out-String

    # Check answers (case-insensitive)
    $expectedPatterns = @(
        "clock",      # Xavier fixes clocks
        "22",         # Quinn is 22
        "(black\s*)?cat",   # Olivia has a black cat
        "Tokyo",      # Yuki is from Tokyo
        "bees?",      # Victor raises bees
        "Ivy",        # Ivy is the marathon runner
        "bakery",     # Leo owns a bakery
        "robots?",    # Noah builds robots
        "tarot",      # Uma reads tarot
        "motorcycle"  # Pete rides motorcycles
    )

    $memCorrect = 0
    foreach ($pattern in $expectedPatterns) {
        if ($response -match $pattern) {
            $memCorrect++
        }
    }

    $accuracy = [math]::Round($memCorrect / 10 * 100, 1)
    $memoryPass = $memCorrect -ge 8  # Pass if 80%+ correct

    $results += @{
        test_name = "working_memory_30"
        model = $Model
        metrics = @{
            entities = 30
            questions = 10
            correct = $memCorrect
            accuracy = $accuracy
        }
        pass = $memoryPass
        response = $response.Trim().Substring(0, [Math]::Min(400, $response.Trim().Length))
    }

    $color = if ($memoryPass) { "Green" } elseif ($memCorrect -ge 5) { "Yellow" } else { "Red" }
    $status = if ($memoryPass) { "PASS" } else { "FAIL" }
    Write-Host "  Result: " -NoNewline; Write-Host "$status ($memCorrect/10 correct, $accuracy%)" -ForegroundColor $color
}

# ═══════════════════════════════════════════════════════════════
# TEST 5: TEMPORAL REASONING
# ═══════════════════════════════════════════════════════════════
if ("temporal" -in $Tests) {
    Write-Host "`n$('─' * 60)" -ForegroundColor DarkGray
    Write-Host "TEST: Temporal Reasoning" -ForegroundColor Cyan
    Write-Host "Purpose: Can the model order events correctly?" -ForegroundColor DarkGray
    Write-Host "$('─' * 60)" -ForegroundColor DarkGray

    $temporalPrompt = @"
Put these events in chronological order (first to last):

- Event D happened immediately after Event B
- Event A was the first thing that occurred
- Event C happened sometime after Event A but before Event B
- Event E was the very last thing to happen
- Event B occurred in the middle of the sequence

List the correct order as: A, B, C, D, E (using commas)
"@

    Write-Host "  Running test..." -ForegroundColor DarkGray
    $response = ollama run $Model $temporalPrompt 2>&1 | Out-String

    # Correct order: A, C, B, D, E
    $temporalPass = $response -match "A.*C.*B.*D.*E"

    $results += @{
        test_name = "temporal_reasoning"
        model = $Model
        metrics = @{
            events = 5
            correct = $temporalPass
        }
        pass = $temporalPass
        response = $response.Trim().Substring(0, [Math]::Min(150, $response.Trim().Length))
    }

    $color = if ($temporalPass) { "Green" } else { "Red" }
    $status = if ($temporalPass) { "PASS" } else { "FAIL" }
    Write-Host "  Result: " -NoNewline; Write-Host $status -ForegroundColor $color
    Write-Host "  Expected: A, C, B, D, E"
    Write-Host "  Got: $($response.Trim().Substring(0, [Math]::Min(30, $response.Trim().Length)))..."
}

# ═══════════════════════════════════════════════════════════════
# TEST 6: SELECTIVE FORGETTING
# ═══════════════════════════════════════════════════════════════
if ("forgetting" -in $Tests) {
    Write-Host "`n$('─' * 60)" -ForegroundColor DarkGray
    Write-Host "TEST: Selective Forgetting" -ForegroundColor Cyan
    Write-Host "Purpose: Can the model follow corrections?" -ForegroundColor DarkGray
    Write-Host "$('─' * 60)" -ForegroundColor DarkGray

    $forgetPrompt = @'
INITIAL FACT: The company's revenue last year was $5 million.

The company operates in the software industry and has been growing steadily. They have offices in three countries and employ about 200 people. Their main product is a cloud-based analytics platform.

CORRECTION: Please disregard the earlier revenue figure. The ACTUAL revenue was $8.3 million. The $5 million figure was from a preliminary draft report that contained errors.

The company expects continued growth next year based on their expanding customer base.

Question: What was the company's actual revenue last year? Provide just the number.
'@

    Write-Host "  Running test..." -ForegroundColor DarkGray
    $response = ollama run $Model $forgetPrompt 2>&1 | Out-String

    # Should mention 8.3 million, not 5 million
    $mentionsCorrect = $response -match "8\.3"
    $mentionsWrong = $response -match "5\s*million" -and -not ($response -match "not\s+5|incorrect|wrong|disregard")
    $forgetPass = $mentionsCorrect -and -not $mentionsWrong

    $results += @{
        test_name = "selective_forgetting"
        model = $Model
        metrics = @{
            followed_correction = $forgetPass
            mentioned_correct_value = $mentionsCorrect
            mentioned_old_value = $mentionsWrong
        }
        pass = $forgetPass
        response = $response.Trim().Substring(0, [Math]::Min(150, $response.Trim().Length))
    }

    $color = if ($forgetPass) { "Green" } else { "Red" }
    $status = if ($forgetPass) { "PASS" } else { "FAIL" }
    Write-Host "  Result: " -NoNewline; Write-Host $status -ForegroundColor $color
    Write-Host "  Expected: 8.3 million"
    Write-Host "  Got: $($response.Trim().Substring(0, [Math]::Min(50, $response.Trim().Length)))..."
}

# ═══════════════════════════════════════════════════════════════
# EXPORT RESULTS
# ═══════════════════════════════════════════════════════════════
Write-Host "`n$('═' * 60)" -ForegroundColor Cyan
Write-Host "EXPORTING RESULTS" -ForegroundColor Cyan
Write-Host "$('═' * 60)`n" -ForegroundColor Cyan

Export-JsonResult -TestName "cognitive_benchmark" -Category "cognitive" -Results $results -OutputDir "$OutputDir\raw"

# Console summary
Write-Host "`n$('═' * 60)" -ForegroundColor Cyan
Write-Host "COGNITIVE BENCHMARK SUMMARY" -ForegroundColor Cyan
Write-Host "$('═' * 60)`n" -ForegroundColor Cyan

$passCount = ($results | Where-Object { $_.pass }).Count
$totalCount = $results.Count

foreach ($r in $results) {
    $status = if ($r.pass) { "PASS" } else { "FAIL" }
    $color = if ($r.pass) { "Green" } else { "Red" }
    $detail = ""
    if ($r.metrics.accuracy) { $detail = " ($($r.metrics.accuracy)%)" }
    Write-Host "  $($r.test_name): " -NoNewline
    Write-Host "$status$detail" -ForegroundColor $color
}

Write-Host ""
$overallColor = if ($passCount -eq $totalCount) { "Green" } elseif ($passCount -ge $totalCount/2) { "Yellow" } else { "Red" }
Write-Host "Overall: " -NoNewline
Write-Host "$passCount / $totalCount tests passed" -ForegroundColor $overallColor
Write-Host ""
