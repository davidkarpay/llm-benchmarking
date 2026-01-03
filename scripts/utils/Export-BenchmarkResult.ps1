# Export-BenchmarkResult.ps1
# Shared utility functions for LLM benchmark output
# Version: 1.1

<#
.SYNOPSIS
    Utility module for exporting LLM benchmark results in multiple formats.
.DESCRIPTION
    Provides functions for:
    - Hardware profile detection (GPU, VRAM, RAM, CPU)
    - JSON export with full metadata
    - CSV export for spreadsheet analysis
    - Console reporting with grading
    - PowerShell 5.1/7+ compatibility helpers
#>

# ═══════════════════════════════════════════════════════════════
# PowerShell 5.1 Compatibility Helpers
# ═══════════════════════════════════════════════════════════════

function ConvertTo-Hashtable {
    <#
    .SYNOPSIS
        Converts PSCustomObject to Hashtable recursively.
    .DESCRIPTION
        PowerShell 5.1 doesn't support -AsHashtable on ConvertFrom-Json.
        This function provides cross-version compatibility.
    #>
    param([Parameter(ValueFromPipeline)]$InputObject)
    process {
        if ($null -eq $InputObject) { return $null }
        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
            $collection = @(foreach ($object in $InputObject) { ConvertTo-Hashtable $object })
            return ,$collection
        } elseif ($InputObject -is [psobject]) {
            $hash = @{}
            foreach ($property in $InputObject.PSObject.Properties) {
                $hash[$property.Name] = ConvertTo-Hashtable $property.Value
            }
            return $hash
        } else {
            return $InputObject
        }
    }
}

function Get-JsonAsHashtable {
    <#
    .SYNOPSIS
        Reads JSON file and returns as Hashtable (PS 5.1/7+ compatible).
    .PARAMETER Path
        Path to JSON file
    .OUTPUTS
        Hashtable with JSON content
    #>
    param([string]$Path)
    $json = Get-Content $Path -Raw | ConvertFrom-Json
    return ConvertTo-Hashtable $json
}

# ═══════════════════════════════════════════════════════════════
# Hardware Detection
# ═══════════════════════════════════════════════════════════════

function Get-HardwareProfile {
    <#
    .SYNOPSIS
        Detects current hardware configuration.
    .OUTPUTS
        Hashtable with gpu, vram_gb, ram_gb, cpu, hostname
    #>

    try {
        $gpuInfo = (nvidia-smi --query-gpu=name,memory.total --format=csv,noheader) -split ','
        $gpuName = $gpuInfo[0].Trim()
        $vramMB = [int]($gpuInfo[1] -replace '[^0-9]','')
        $vramGB = [math]::Round($vramMB / 1024, 1)
    } catch {
        $gpuName = "Unknown"
        $vramGB = 0
    }

    try {
        $ramBytes = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
        $ramGB = [math]::Round($ramBytes / 1GB, 0)
    } catch {
        $ramGB = 0
    }

    try {
        $cpuName = (Get-CimInstance Win32_Processor).Name
    } catch {
        $cpuName = "Unknown"
    }

    return @{
        gpu = $gpuName
        vram_gb = $vramGB
        ram_gb = $ramGB
        cpu = $cpuName
        hostname = $env:COMPUTERNAME
    }
}

function Export-JsonResult {
    <#
    .SYNOPSIS
        Exports benchmark results to JSON with full metadata.
    .PARAMETER TestName
        Name of the test (e.g., "speed_benchmark", "cognitive_benchmark")
    .PARAMETER Category
        Test category: "hardware" or "cognitive"
    .PARAMETER Results
        Array of result objects
    .PARAMETER OutputDir
        Directory to save JSON files
    .OUTPUTS
        Path to created JSON file
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TestName,

        [Parameter(Mandatory=$true)]
        [ValidateSet("hardware", "cognitive")]
        [string]$Category,

        [Parameter(Mandatory=$true)]
        [array]$Results,

        [string]$OutputDir = ".\results\raw"
    )

    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    $filename = "{0}_{1}.json" -f (Get-Date -Format "yyyy-MM-dd_HHmmss"), $TestName

    $output = @{
        meta = @{
            timestamp = $timestamp
            hostname = $env:COMPUTERNAME
            hardware = Get-HardwareProfile
            schema_version = "1.0"
        }
        test = @{
            name = $TestName
            category = $Category
            version = "1.0"
        }
        results = $Results
    }

    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }

    $fullPath = Join-Path $OutputDir $filename
    $output | ConvertTo-Json -Depth 10 | Out-File $fullPath -Encoding UTF8

    Write-Host "JSON saved: $fullPath" -ForegroundColor Green
    return $fullPath
}

function Export-CsvResult {
    <#
    .SYNOPSIS
        Appends benchmark results to a CSV file.
    .PARAMETER TestName
        Name of the test (used for filename)
    .PARAMETER Results
        Array of PSCustomObject results (flat structure)
    .PARAMETER OutputDir
        Directory to save CSV files
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TestName,

        [Parameter(Mandatory=$true)]
        [array]$Results,

        [string]$OutputDir = ".\results\csv"
    )

    $filename = "{0}_results.csv" -f $TestName

    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }

    $fullPath = Join-Path $OutputDir $filename
    $Results | Export-Csv $fullPath -NoTypeInformation -Append

    Write-Host "CSV appended: $fullPath" -ForegroundColor Green
}

function Get-SpeedGrade {
    <#
    .SYNOPSIS
        Returns a letter grade based on tokens/second.
    .PARAMETER TokensPerSecond
        The measured tokens per second
    .OUTPUTS
        Letter grade: A, B, C, or D
    #>
    param([double]$TokensPerSecond)

    switch ($true) {
        ($TokensPerSecond -ge 30) { return "A" }
        ($TokensPerSecond -ge 10) { return "B" }
        ($TokensPerSecond -ge 3)  { return "C" }
        default { return "D" }
    }
}

function Write-ConsoleReport {
    <#
    .SYNOPSIS
        Writes a formatted report to the console.
    .PARAMETER Results
        Array of result objects with metrics
    .PARAMETER Title
        Report title
    #>
    param(
        [Parameter(Mandatory=$true)]
        [array]$Results,

        [Parameter(Mandatory=$true)]
        [string]$Title
    )

    Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host "$('=' * 60)`n" -ForegroundColor Cyan

    foreach ($r in $Results) {
        if ($r.metrics.tokens_per_second) {
            $tps = [math]::Round($r.metrics.tokens_per_second, 1)
            $grade = Get-SpeedGrade -TokensPerSecond $tps
            $color = switch ($grade) {
                "A" { "Green" }
                "B" { "Yellow" }
                "C" { "DarkYellow" }
                default { "Red" }
            }
            Write-Host ("{0,-25} {1,8} tok/s  [{2}]" -f $r.model, $tps, $grade) -ForegroundColor $color
        } elseif ($null -ne $r.pass) {
            $status = if ($r.pass) { "PASS" } else { "FAIL" }
            $color = if ($r.pass) { "Green" } else { "Red" }
            Write-Host ("{0,-25} {1}" -f $r.test_name, $status) -ForegroundColor $color
        }
    }

    Write-Host ""
}

function Write-MarkdownReport {
    <#
    .SYNOPSIS
        Generates a human-readable Markdown report.
    .PARAMETER HardwareResults
        Array of hardware benchmark results
    .PARAMETER CognitiveResults
        Array of cognitive test results
    .PARAMETER OutputDir
        Directory to save report
    .OUTPUTS
        Path to created Markdown file
    #>
    param(
        [array]$HardwareResults = @(),
        [array]$CognitiveResults = @(),
        [string]$OutputDir = ".\results\reports"
    )

    $hardware = Get-HardwareProfile
    $date = Get-Date -Format "yyyy-MM-dd"
    $filename = "{0}_benchmark_report.md" -f $date

    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }

    $report = @"
# LLM Benchmark Report
**Date**: $date
**Machine**: $($hardware.hostname)

---

## Hardware Profile
| Component | Specification |
|-----------|--------------|
| GPU | $($hardware.gpu) ($($hardware.vram_gb)GB VRAM) |
| RAM | $($hardware.ram_gb)GB |
| CPU | $($hardware.cpu) |

---

## Speed Benchmark Results

| Model | Tok/s | GPU% | Grade |
|-------|-------|------|-------|
"@

    foreach ($r in $HardwareResults) {
        $tps = if ($r.metrics.tokens_per_second) { [math]::Round($r.metrics.tokens_per_second, 1) } else { "N/A" }
        $gpu = if ($r.metrics.gpu_percent) { "$($r.metrics.gpu_percent)%" } else { "N/A" }
        $grade = if ($r.metrics.tokens_per_second) { Get-SpeedGrade -TokensPerSecond $r.metrics.tokens_per_second } else { "N/A" }
        $report += "| $($r.model) | $tps | $gpu | $grade |`n"
    }

    $report += @"

**Grading Scale**: A (>30 tok/s), B (10-30), C (3-10), D (<3)

---

## Cognitive Test Results

| Test | Result | Details |
|------|--------|---------|
"@

    foreach ($r in $CognitiveResults) {
        $result = if ($r.pass) { "PASS" } else { "FAIL" }
        $details = if ($r.metrics.accuracy) { "$($r.metrics.accuracy)% accuracy" } else { "" }
        $report += "| $($r.test_name) | $result | $details |`n"
    }

    $report += @"

---

## Raw Data Location
- JSON: ``results/raw/$date_*.json``
- CSV: ``results/csv/*_results.csv``

---
*Generated by LLM Benchmarking Suite v1.0*
"@

    $fullPath = Join-Path $OutputDir $filename
    $report | Out-File $fullPath -Encoding UTF8

    Write-Host "Report saved: $fullPath" -ForegroundColor Green
    return $fullPath
}

# Functions are automatically available when dot-sourced
# Available: Get-HardwareProfile, Export-JsonResult, Export-CsvResult, Get-SpeedGrade, Write-ConsoleReport, Write-MarkdownReport
