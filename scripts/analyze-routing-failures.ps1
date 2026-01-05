# Analyze routing failures from most recent benchmark
param(
    [string]$ResultFile = ""
)

if (-not $ResultFile) {
    # Find most recent result file
    $ResultFile = Get-ChildItem "C:\Users\14104\llm-benchmarks\results\raw\*parallel*.json" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}

Write-Host "Analyzing: $ResultFile" -ForegroundColor Cyan

$results = Get-Content $ResultFile -Raw | ConvertFrom-Json

$failures = $results.results | Where-Object { -not $_.routing.routing_correct }

Write-Host "`nTotal Tests: $($results.results.Count)" -ForegroundColor White
Write-Host "Routing Failures: $($failures.Count)" -ForegroundColor Red
Write-Host "`n--- Failure Breakdown by Expected Specialist ---" -ForegroundColor Yellow

$byExpected = $failures | Group-Object { $_.routing.expected_specialist }
foreach ($group in $byExpected) {
    Write-Host "`n$($group.Name): $($group.Count) failures" -ForegroundColor Cyan

    $byActual = $group.Group | Group-Object { $_.routing.selected_specialist }
    foreach ($actual in $byActual) {
        Write-Host "  -> Routed to $($actual.Name): $($actual.Count)" -ForegroundColor DarkGray
    }
}

Write-Host "`n--- Sample Failures ---" -ForegroundColor Yellow

$failures | Select-Object -First 5 | ForEach-Object {
    Write-Host "`n---" -ForegroundColor DarkGray
    Write-Host "Test: $($_.test_name)" -ForegroundColor White
    Write-Host "Expected: $($_.routing.expected_specialist)" -ForegroundColor Green
    Write-Host "Got: $($_.routing.selected_specialist)" -ForegroundColor Red
    $queryPreview = if ($_.response.Length -gt 150) { $_.response.Substring(0, 150) + "..." } else { $_.response }
    # Get the prompt from test_name lookup if available
    Write-Host "Confidence: $($_.routing.routing_confidence)" -ForegroundColor DarkGray
}
