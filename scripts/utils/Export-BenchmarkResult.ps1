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
# GPU Configuration (EXPERIMENTAL - requires verification)
# ═══════════════════════════════════════════════════════════════

function Set-OllamaGpuConfig {
    <#
    .SYNOPSIS
        Configures Ollama environment variables for GPU utilization (EXPERIMENTAL).
    .DESCRIPTION
        Sets OLLAMA_NUM_GPU and OLLAMA_NUM_THREAD environment variables.

        ⚠️ CRITICAL: These variables only affect NEW Ollama server instances!
        If Ollama is already running, these settings have NO EFFECT.

        To apply settings:
        - Windows: Quit and restart the Ollama application
        - macOS: launchctl unload/load the service
        - Linux: systemctl restart ollama
        - Or: Stop Ollama, run 'ollama serve' from this shell

        EXPERIMENTAL STATUS:
        - OLLAMA_NUM_GPU: May be ignored by runner (upstream reports)
        - OLLAMA_NUM_THREAD: May not be supported (requested as feature)

        Always verify with Get-OllamaEnvironment after warmup!
    .PARAMETER NumGpu
        Number of GPU layers to offload. Use 999 for maximum.
    .PARAMETER NumThread
        Number of CPU threads for non-GPU work.
    .PARAMETER Quiet
        Suppress output message.
    #>
    param(
        [int]$NumGpu = 999,
        [int]$NumThread = 8,
        [switch]$Quiet
    )

    $env:OLLAMA_NUM_GPU = $NumGpu
    $env:OLLAMA_NUM_THREAD = $NumThread

    if (-not $Quiet) {
        Write-Host ""
        Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
        Write-Host "║  ⚠️  GPU CONFIG SET (EXPERIMENTAL - REQUIRES VERIFICATION)   ║" -ForegroundColor Yellow
        Write-Host "╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Yellow
        Write-Host "║  OLLAMA_NUM_GPU=$NumGpu (may be ignored by runner)            " -ForegroundColor Yellow
        Write-Host "║  OLLAMA_NUM_THREAD=$NumThread (may not be supported)             " -ForegroundColor Yellow
        Write-Host "╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Yellow
        Write-Host "║  These settings ONLY affect NEW Ollama instances!            ║" -ForegroundColor Yellow
        Write-Host "║  If Ollama is already running, restart it to apply.          ║" -ForegroundColor Yellow
        Write-Host "║                                                              ║" -ForegroundColor Yellow
        Write-Host "║  Verify with: Get-OllamaEnvironment -Model <model>           ║" -ForegroundColor Yellow
        Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
        Write-Host ""
    }

    # Return intent for logging
    return @{
        OLLAMA_NUM_GPU = $NumGpu.ToString()
        OLLAMA_NUM_THREAD = $NumThread.ToString()
        warning = "These settings only affect new Ollama instances. Restart required."
    }
}

# ═══════════════════════════════════════════════════════════════
# Ollama Environment Capture (Self-Verifying Benchmarks)
# ═══════════════════════════════════════════════════════════════

function Invoke-OllamaWarmup {
    <#
    .SYNOPSIS
        Preloads a model into Ollama using documented warmup method.
    .DESCRIPTION
        Sends empty request to /api/generate to preload model (Ollama-documented method).
        Waits for model to be loaded before returning.
    .PARAMETER Model
        The model name to preload (e.g., "llama3.1:8b")
    .PARAMETER TimeoutSeconds
        Maximum time to wait for warmup (default 120)
    .OUTPUTS
        Hashtable with method, model, success, duration_ms
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Model,

        [int]$TimeoutSeconds = 120
    )

    $startTime = Get-Date
    $result = @{
        method = "api_generate_empty"
        model = $Model
        success = $false
        duration_ms = 0
        error = $null
    }

    try {
        # Ollama-documented warmup: empty request to /api/generate
        $body = @{
            model = $Model
            prompt = ""
            stream = $false
        } | ConvertTo-Json

        $response = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" `
            -Method Post `
            -Body $body `
            -ContentType "application/json" `
            -TimeoutSec $TimeoutSeconds

        $result.success = $true
    }
    catch {
        $result.error = $_.Exception.Message
    }

    $result.duration_ms = [math]::Round(((Get-Date) - $startTime).TotalMilliseconds)
    return $result
}

function Get-OllamaPsOutput {
    <#
    .SYNOPSIS
        Captures and parses 'ollama ps' output.
    .DESCRIPTION
        Runs 'ollama ps' and returns both raw output (audit trail) and parsed rows.
        Parsing rule: split on 2+ spaces to survive spacing changes.
    .OUTPUTS
        Hashtable with raw (string), rows (array), parse_warnings (array)
    #>

    $result = @{
        raw = ""
        rows = @()
        parse_warnings = @()
    }

    try {
        $result.raw = & ollama ps 2>&1 | Out-String

        # Parse output: split on 2+ consecutive spaces
        $lines = $result.raw -split "`n" | Where-Object { $_.Trim() -ne "" }

        if ($lines.Count -gt 0) {
            # First line is header
            $headerLine = $lines[0]

            # Parse data rows (skip header)
            for ($i = 1; $i -lt $lines.Count; $i++) {
                $line = $lines[$i]
                if ($line.Trim() -eq "") { continue }

                # Split on 2+ spaces
                $parts = $line -split '\s{2,}' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }

                if ($parts.Count -ge 4) {
                    $result.rows += @{
                        name = $parts[0]
                        id = $parts[1]
                        size = $parts[2]
                        processor = $parts[3]
                        until = if ($parts.Count -ge 5) { $parts[4] } else { "" }
                    }
                }
                else {
                    $result.parse_warnings += "Could not parse line $i`: '$line' (got $($parts.Count) parts)"
                }
            }
        }
    }
    catch {
        $result.parse_warnings += "Failed to run ollama ps: $($_.Exception.Message)"
    }

    return $result
}

function Get-OllamaVersion {
    <#
    .SYNOPSIS
        Gets the Ollama version string.
    .OUTPUTS
        Version string or error message
    #>
    try {
        $version = & ollama --version 2>&1
        return ($version | Out-String).Trim()
    }
    catch {
        return "unknown (error: $($_.Exception.Message))"
    }
}

function Get-GitCommitHash {
    <#
    .SYNOPSIS
        Gets the current git commit hash for reproducibility.
    .OUTPUTS
        Commit hash string or "not a git repo"
    #>
    try {
        $hash = & git rev-parse HEAD 2>&1
        if ($LASTEXITCODE -eq 0) {
            return ($hash | Out-String).Trim()
        }
        return "not a git repo"
    }
    catch {
        return "git not available"
    }
}

function Get-OllamaEnvironment {
    <#
    .SYNOPSIS
        Captures complete Ollama environment for self-verifying benchmarks.
    .DESCRIPTION
        Performs warmup, captures ollama ps, and returns structured environment data.
        This is the ONLY way to prove GPU config had any effect.

        Follows Ollama-documented behavior:
        - Preload via empty /api/generate request
        - Processor column in 'ollama ps' shows GPU vs CPU split
    .PARAMETER Model
        The model to warmup and verify (e.g., "llama3.1:8b")
    .PARAMETER SkipWarmup
        Skip the warmup step (for cold-start measurements)
    .PARAMETER ExpectedGpuPercent
        Expected GPU percentage for verification (default 90)
    .OUTPUTS
        Hashtable matching the documented environment schema
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Model,

        [switch]$SkipWarmup,

        [int]$ExpectedGpuPercent = 90
    )

    $env = @{
        ollama_version = Get-OllamaVersion
        git_commit = Get-GitCommitHash
        timestamp_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        warmup = @{
            method = "skipped"
            model = $Model
            success = $false
            duration_ms = 0
        }
        ollama_ps_raw = ""
        ollama_ps_rows = @()
        ollama_env_intent = @{
            OLLAMA_NUM_GPU = if ($env:OLLAMA_NUM_GPU) { $env:OLLAMA_NUM_GPU } else { "not set" }
            OLLAMA_NUM_THREAD = if ($env:OLLAMA_NUM_THREAD) { $env:OLLAMA_NUM_THREAD } else { "not set" }
        }
        verification = @{
            gpu_config_verified = $false
            gpu_config_evidence = ""
        }
        parse_warnings = @()
    }

    # Step 1: Warmup (unless skipped)
    if (-not $SkipWarmup) {
        Write-Host "Warming up model: $Model..." -ForegroundColor DarkGray
        $env.warmup = Invoke-OllamaWarmup -Model $Model
        if ($env.warmup.success) {
            Write-Host "  Warmup complete in $($env.warmup.duration_ms)ms" -ForegroundColor DarkGray
        }
        else {
            Write-Host "  Warmup failed: $($env.warmup.error)" -ForegroundColor Yellow
        }
    }

    # Step 2: Capture ollama ps
    Write-Host "Capturing ollama ps..." -ForegroundColor DarkGray
    $psOutput = Get-OllamaPsOutput
    $env.ollama_ps_raw = $psOutput.raw
    $env.ollama_ps_rows = $psOutput.rows
    $env.parse_warnings = $psOutput.parse_warnings

    # Step 3: Verify GPU config
    $modelRow = $env.ollama_ps_rows | Where-Object { $_.name -like "$Model*" } | Select-Object -First 1

    if ($modelRow) {
        $processor = $modelRow.processor

        # Parse GPU percentage from processor column (e.g., "100% GPU", "89% GPU/11% CPU")
        if ($processor -match '(\d+)%\s*GPU') {
            $gpuPercent = [int]$Matches[1]

            if ($gpuPercent -ge $ExpectedGpuPercent) {
                $env.verification.gpu_config_verified = $true
                $env.verification.gpu_config_evidence = "processor column shows $gpuPercent% GPU (>= $ExpectedGpuPercent% threshold)"
            }
            else {
                $env.verification.gpu_config_verified = $false
                $env.verification.gpu_config_evidence = "processor column shows $gpuPercent% GPU (< $ExpectedGpuPercent% expected)"
            }
        }
        elseif ($processor -match '(\d+)%\s*CPU') {
            $cpuPercent = [int]$Matches[1]
            $env.verification.gpu_config_verified = $false
            $env.verification.gpu_config_evidence = "processor column shows $cpuPercent% CPU (model running on system memory)"
        }
        else {
            $env.verification.gpu_config_verified = $false
            $env.verification.gpu_config_evidence = "could not parse processor column: '$processor'"
        }
    }
    else {
        $env.verification.gpu_config_verified = $false
        $env.verification.gpu_config_evidence = "model '$Model' not found in ollama ps output"
    }

    # Print verification result
    if ($env.verification.gpu_config_verified) {
        Write-Host "  ✓ GPU config verified: $($env.verification.gpu_config_evidence)" -ForegroundColor Green
    }
    else {
        Write-Host "  ⚠️ UNVERIFIED: $($env.verification.gpu_config_evidence)" -ForegroundColor Yellow
    }

    return $env
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
# Available:
#   - Set-OllamaGpuConfig: Set GPU env vars (EXPERIMENTAL - requires verification)
#   - Get-OllamaEnvironment: Capture complete environment for self-verifying benchmarks
#   - Invoke-OllamaWarmup: Preload model using documented method
#   - Get-OllamaPsOutput: Capture and parse 'ollama ps' output
#   - Get-OllamaVersion: Get Ollama version string
#   - Get-GitCommitHash: Get current git commit for reproducibility
#   - Get-HardwareProfile: Detect GPU, VRAM, RAM, CPU
#   - Export-JsonResult, Export-CsvResult: Export results to files
#   - Get-SpeedGrade, Write-ConsoleReport, Write-MarkdownReport: Reporting utilities
