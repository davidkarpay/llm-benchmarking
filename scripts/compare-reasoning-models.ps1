# compare-reasoning-models.ps1
# Quick comparison of reasoning models on reasoning test suite

param(
    [string[]]$Models = @("qwen2.5:14b", "qwen2.5:32b"),
    [int]$MaxTokens = 200
)

$tests = @(
    @{id="001"; prompt="If all roses are flowers, and all flowers need water, what can we conclude about roses?"; check=@("water","need"); difficulty="easy"},
    @{id="002"; prompt="A train leaves Station A at 9:00 AM traveling at 60 mph. Another train leaves Station B (120 miles away) at 10:00 AM traveling toward Station A at 40 mph. At what time will they meet?"; check=@("11"); difficulty="medium"},
    @{id="003"; prompt="In a room of 23 people, what is the approximate probability that at least two people share a birthday?"; check=@("50"); difficulty="hard"},
    @{id="004"; prompt="If it takes 5 machines 5 minutes to make 5 widgets, how long would it take 100 machines to make 100 widgets?"; check=@("5"); difficulty="medium"},
    @{id="005"; prompt="Calculate the sum of all integers from 1 to 100."; check=@("5050"); difficulty="easy"}
)

$allResults = @{}

foreach ($model in $Models) {
    Write-Host "`n===== Testing $model =====" -ForegroundColor Cyan
    $modelResults = @{passed=0; total=5; times=@(); details=@()}

    foreach ($test in $tests) {
        $start = Get-Date
        $response = $test.prompt | ollama run $model --nowordwrap 2>&1 | Out-String
        $elapsed = ((Get-Date) - $start).TotalMilliseconds

        # Check for expected keywords
        $pass = $true
        foreach ($keyword in $test.check) {
            if ($response -notmatch [regex]::Escape($keyword)) {
                $pass = $false
                break
            }
        }

        if ($pass) { $modelResults.passed++ }
        $modelResults.times += $elapsed

        # Store details
        $modelResults.details += @{
            id = $test.id
            difficulty = $test.difficulty
            pass = $pass
            time_ms = [math]::Round($elapsed)
            response_preview = $response.Substring(0, [Math]::Min(150, $response.Length)).Trim()
        }

        $status = if ($pass) { "PASS" } else { "FAIL" }
        $color = if ($pass) { "Green" } else { "Red" }
        Write-Host "  [$status] reasoning-$($test.id) ($($test.difficulty)): $([math]::Round($elapsed))ms" -ForegroundColor $color
    }

    $allResults[$model] = $modelResults
}

# Summary comparison
Write-Host "`n" + "=" * 60 -ForegroundColor Yellow
Write-Host "COMPARISON SUMMARY" -ForegroundColor Yellow
Write-Host "=" * 60 -ForegroundColor Yellow

$summaryTable = @()
foreach ($model in $Models) {
    $r = $allResults[$model]
    $avgTime = [math]::Round(($r.times | Measure-Object -Average).Average)
    $totalTime = [math]::Round(($r.times | Measure-Object -Sum).Sum)

    $summaryTable += [PSCustomObject]@{
        Model = $model
        Accuracy = "$($r.passed)/5 ($([math]::Round($r.passed/5*100))%)"
        "Avg Time" = "${avgTime}ms"
        "Total Time" = "${totalTime}ms"
    }

    # Extract parameter count for efficiency calc
    $params = if ($model -match "(\d+)b") { [int]$Matches[1] } else { 0 }
    $efficiency = if ($params -gt 0 -and $avgTime -gt 0) {
        [math]::Round(($r.passed / 5 * 100) / ($params * $avgTime / 1000), 2)
    } else { 0 }

    Write-Host "`n$model :" -ForegroundColor Cyan
    Write-Host "  Accuracy:   $($r.passed)/5 ($([math]::Round($r.passed/5*100))%)"
    Write-Host "  Avg Time:   ${avgTime}ms"
    Write-Host "  Total Time: ${totalTime}ms"
    Write-Host "  Params:     ${params}B"
    Write-Host "  Efficiency: $efficiency (accuracy% / (params * seconds))"
}

# Per-test breakdown
Write-Host "`n" + "=" * 60 -ForegroundColor Yellow
Write-Host "PER-TEST BREAKDOWN" -ForegroundColor Yellow
Write-Host "=" * 60 -ForegroundColor Yellow

foreach ($test in $tests) {
    Write-Host "`nreasoning-$($test.id) ($($test.difficulty)):" -ForegroundColor Cyan
    foreach ($model in $Models) {
        $detail = $allResults[$model].details | Where-Object { $_.id -eq $test.id }
        $status = if ($detail.pass) { "PASS" } else { "FAIL" }
        $color = if ($detail.pass) { "Green" } else { "Red" }
        Write-Host "  $model : [$status] $($detail.time_ms)ms" -ForegroundColor $color
    }
}
