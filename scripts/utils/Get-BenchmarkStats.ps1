<#
.SYNOPSIS
    Statistical functions for benchmark result aggregation.
.DESCRIPTION
    Provides functions for calculating statistics across multiple benchmark runs,
    including mean, standard deviation, confidence intervals, and trend analysis.
#>

function Get-StandardDeviation {
    <#
    .SYNOPSIS
        Calculate standard deviation of a set of values.
    .PARAMETER Values
        Array of numeric values.
    .OUTPUTS
        Double representing standard deviation.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [double[]]$Values
    )

    if ($Values.Count -lt 2) {
        return 0
    }

    $mean = ($Values | Measure-Object -Average).Average
    $sumSquares = 0

    foreach ($val in $Values) {
        $sumSquares += ($val - $mean) * ($val - $mean)
    }

    return [Math]::Sqrt($sumSquares / ($Values.Count - 1))
}

function Get-ConfidenceInterval {
    <#
    .SYNOPSIS
        Calculate confidence interval for a set of values.
    .PARAMETER Values
        Array of numeric values.
    .PARAMETER Confidence
        Confidence level (0.95 = 95% CI). Default: 0.95
    .OUTPUTS
        Hashtable with: lower, upper, margin
    #>
    param(
        [Parameter(Mandatory=$true)]
        [double[]]$Values,

        [double]$Confidence = 0.95
    )

    if ($Values.Count -lt 2) {
        $mean = if ($Values.Count -eq 1) { $Values[0] } else { 0 }
        return @{
            lower = $mean
            upper = $mean
            margin = 0
        }
    }

    $mean = ($Values | Measure-Object -Average).Average
    $stdDev = Get-StandardDeviation -Values $Values
    $n = $Values.Count

    # Z-scores for common confidence levels
    $zScores = @{
        0.90 = 1.645
        0.95 = 1.96
        0.99 = 2.576
    }

    $z = if ($zScores.ContainsKey($Confidence)) { $zScores[$Confidence] } else { 1.96 }

    $margin = $z * ($stdDev / [Math]::Sqrt($n))

    return @{
        lower = [Math]::Round($mean - $margin, 4)
        upper = [Math]::Round($mean + $margin, 4)
        margin = [Math]::Round($margin, 4)
    }
}

function Get-BenchmarkStats {
    <#
    .SYNOPSIS
        Calculate comprehensive statistics for a set of values.
    .PARAMETER Values
        Array of numeric values.
    .PARAMETER Label
        Optional label for the metric.
    .OUTPUTS
        Hashtable with: mean, std_dev, min, max, median, count, ci_95
    #>
    param(
        [Parameter(Mandatory=$true)]
        [double[]]$Values,

        [string]$Label = ""
    )

    if ($Values.Count -eq 0) {
        return @{
            mean = 0
            std_dev = 0
            min = 0
            max = 0
            median = 0
            count = 0
            ci_95 = @{ lower = 0; upper = 0; margin = 0 }
        }
    }

    $sorted = $Values | Sort-Object
    $median = if ($sorted.Count % 2 -eq 0) {
        ($sorted[$sorted.Count/2 - 1] + $sorted[$sorted.Count/2]) / 2
    } else {
        $sorted[[Math]::Floor($sorted.Count/2)]
    }

    $stats = ($Values | Measure-Object -Average -Minimum -Maximum)

    return @{
        label = $Label
        mean = [Math]::Round($stats.Average, 4)
        std_dev = [Math]::Round((Get-StandardDeviation -Values $Values), 4)
        min = $stats.Minimum
        max = $stats.Maximum
        median = [Math]::Round($median, 4)
        count = $Values.Count
        ci_95 = Get-ConfidenceInterval -Values $Values -Confidence 0.95
    }
}

function Get-PercentileValue {
    <#
    .SYNOPSIS
        Get the value at a specific percentile.
    .PARAMETER Values
        Array of numeric values.
    .PARAMETER Percentile
        Percentile to calculate (0-100).
    .OUTPUTS
        Double at the specified percentile.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [double[]]$Values,

        [Parameter(Mandatory=$true)]
        [double]$Percentile
    )

    if ($Values.Count -eq 0) { return 0 }

    $sorted = $Values | Sort-Object
    $index = [Math]::Ceiling(($Percentile / 100) * $sorted.Count) - 1
    $index = [Math]::Max(0, [Math]::Min($index, $sorted.Count - 1))

    return $sorted[$index]
}

function Merge-BenchmarkResults {
    <#
    .SYNOPSIS
        Merge multiple benchmark result files into aggregated statistics.
    .PARAMETER ResultFiles
        Array of paths to benchmark result JSON files.
    .OUTPUTS
        Hashtable with aggregated statistics per test case.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$ResultFiles
    )

    $aggregated = @{}

    foreach ($file in $ResultFiles) {
        if (-not (Test-Path $file)) {
            Write-Warning "File not found: $file"
            continue
        }

        $content = Get-Content $file -Raw | ConvertFrom-Json

        foreach ($result in $content.results) {
            $testId = $result.test_id

            if (-not $aggregated.ContainsKey($testId)) {
                $aggregated[$testId] = @{
                    test_id = $testId
                    runs = @()
                    routing_correct = @()
                    response_correct = @()
                    latency_ms = @()
                    tokens_per_second = @()
                    similarity_score = @()
                }
            }

            $aggregated[$testId].runs += $result
            $aggregated[$testId].routing_correct += [int]$result.routing_correct
            $aggregated[$testId].response_correct += [int]$result.response_correct

            if ($result.latency_ms) {
                $aggregated[$testId].latency_ms += $result.latency_ms
            }
            if ($result.tokens_per_second) {
                $aggregated[$testId].tokens_per_second += $result.tokens_per_second
            }
            if ($result.similarity_score) {
                $aggregated[$testId].similarity_score += $result.similarity_score
            }
        }
    }

    # Calculate statistics for each test
    $stats = @{}
    foreach ($testId in $aggregated.Keys) {
        $data = $aggregated[$testId]

        $stats[$testId] = @{
            test_id = $testId
            run_count = $data.runs.Count
            routing_accuracy = @{
                mean = if ($data.routing_correct.Count -gt 0) { ($data.routing_correct | Measure-Object -Average).Average } else { 0 }
                total_correct = ($data.routing_correct | Where-Object { $_ -eq 1 }).Count
            }
            response_accuracy = @{
                mean = if ($data.response_correct.Count -gt 0) { ($data.response_correct | Measure-Object -Average).Average } else { 0 }
                total_correct = ($data.response_correct | Where-Object { $_ -eq 1 }).Count
            }
            latency_ms = if ($data.latency_ms.Count -gt 0) { Get-BenchmarkStats -Values $data.latency_ms -Label "latency_ms" } else { $null }
            tokens_per_second = if ($data.tokens_per_second.Count -gt 0) { Get-BenchmarkStats -Values $data.tokens_per_second -Label "tok/s" } else { $null }
            similarity_score = if ($data.similarity_score.Count -gt 0) { Get-BenchmarkStats -Values $data.similarity_score -Label "similarity" } else { $null }
        }
    }

    return $stats
}

function Get-TrendAnalysis {
    <#
    .SYNOPSIS
        Analyze trends across timestamped results.
    .PARAMETER Results
        Array of result objects with timestamp property.
    .PARAMETER Metric
        The metric to analyze (e.g., 'accuracy', 'latency_ms').
    .OUTPUTS
        Hashtable with trend direction, slope, and data points.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [array]$Results,

        [Parameter(Mandatory=$true)]
        [string]$Metric
    )

    if ($Results.Count -lt 2) {
        return @{
            trend = "insufficient_data"
            data_points = $Results.Count
        }
    }

    # Sort by timestamp
    $sorted = $Results | Sort-Object { $_.timestamp }

    # Extract metric values
    $values = @()
    $timestamps = @()

    foreach ($r in $sorted) {
        if ($r.$Metric) {
            $values += $r.$Metric
            $timestamps += [DateTime]::Parse($r.timestamp)
        }
    }

    if ($values.Count -lt 2) {
        return @{
            trend = "insufficient_data"
            data_points = $values.Count
        }
    }

    # Simple linear regression
    $n = $values.Count
    $sumX = 0; $sumY = 0; $sumXY = 0; $sumX2 = 0
    $baseTime = $timestamps[0]

    for ($i = 0; $i -lt $n; $i++) {
        $x = ($timestamps[$i] - $baseTime).TotalHours
        $y = $values[$i]
        $sumX += $x
        $sumY += $y
        $sumXY += $x * $y
        $sumX2 += $x * $x
    }

    $slope = ($n * $sumXY - $sumX * $sumY) / ($n * $sumX2 - $sumX * $sumX)

    $trend = if ($slope -gt 0.001) { "improving" }
             elseif ($slope -lt -0.001) { "degrading" }
             else { "stable" }

    return @{
        trend = $trend
        slope = [Math]::Round($slope, 6)
        data_points = $n
        first_value = $values[0]
        last_value = $values[-1]
        change_percent = [Math]::Round((($values[-1] - $values[0]) / $values[0]) * 100, 2)
    }
}

# Functions are automatically available when dot-sourced
