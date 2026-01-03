# Invoke-FrontierAPI.ps1
# Utility functions for calling frontier model APIs
# Version: 1.1

<#
.SYNOPSIS
    Utility module for invoking frontier model APIs for comparison.
.DESCRIPTION
    Provides functions for:
    - OpenAI API calls
    - Anthropic API calls
    - Google AI API calls
    - Published benchmark score retrieval
#>

# ═══════════════════════════════════════════════════════════════
# PowerShell 5.1 Compatibility
# ═══════════════════════════════════════════════════════════════

if (-not (Get-Command ConvertTo-HashtableFrontier -ErrorAction SilentlyContinue)) {
    function script:ConvertTo-HashtableFrontier {
        param([Parameter(ValueFromPipeline)]$InputObject)
        process {
            if ($null -eq $InputObject) { return $null }
            if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
                $collection = @(foreach ($object in $InputObject) { ConvertTo-HashtableFrontier $object })
                return ,$collection
            } elseif ($InputObject -is [psobject]) {
                $hash = @{}
                foreach ($property in $InputObject.PSObject.Properties) {
                    $hash[$property.Name] = ConvertTo-HashtableFrontier $property.Value
                }
                return $hash
            } else {
                return $InputObject
            }
        }
    }
}

function Get-FrontierConfig {
    <#
    .SYNOPSIS
        Loads frontier configuration from JSON.
    .PARAMETER ConfigPath
        Path to frontiers.json configuration file
    .OUTPUTS
        Hashtable with frontier configuration
    #>
    param(
        [string]$ConfigPath = "C:\Users\14104\llm-benchmarks\configs\frontiers.json"
    )

    if (-not (Test-Path $ConfigPath)) {
        Write-Warning "Frontier config not found: $ConfigPath"
        return $null
    }

    # Use Get-JsonAsHashtable if available (from Export-BenchmarkResult.ps1), otherwise local conversion
    if (Get-Command Get-JsonAsHashtable -ErrorAction SilentlyContinue) {
        return Get-JsonAsHashtable -Path $ConfigPath
    } else {
        $json = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        return ConvertTo-HashtableFrontier $json
    }
}

function Invoke-OpenAICompletion {
    <#
    .SYNOPSIS
        Calls OpenAI API for completion.
    .PARAMETER Prompt
        The prompt to send
    .PARAMETER Model
        Model ID (e.g., "gpt-4o", "gpt-4o-mini")
    .PARAMETER ApiKey
        API key (uses env var if not provided)
    .PARAMETER MaxTokens
        Maximum tokens to generate
    .OUTPUTS
        Hashtable with: response, latency_ms, tokens_input, tokens_output, cost_usd
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Prompt,

        [string]$Model = "gpt-4o-mini",

        [string]$ApiKey = $null,

        [int]$MaxTokens = 1000
    )

    $config = Get-FrontierConfig
    if (-not $config) { return @{ error = "Config not found" } }

    if (-not $ApiKey) {
        $envVar = $config.endpoints.openai.api_key_env
        $ApiKey = [Environment]::GetEnvironmentVariable($envVar)
    }

    if (-not $ApiKey) {
        return @{ error = "OpenAI API key not found. Set OPENAI_API_KEY environment variable." }
    }

    $modelConfig = $config.endpoints.openai.models[$Model]
    if (-not $modelConfig) {
        $modelConfig = @{ model_id = $Model; cost_per_1k_input = 0.005; cost_per_1k_output = 0.015 }
    }

    $startTime = Get-Date

    $body = @{
        model = $modelConfig.model_id
        messages = @(
            @{ role = "user"; content = $Prompt }
        )
        max_tokens = $MaxTokens
    } | ConvertTo-Json -Depth 5

    $headers = @{
        "Authorization" = "Bearer $ApiKey"
        "Content-Type" = "application/json"
    }

    try {
        $response = Invoke-RestMethod -Uri $config.endpoints.openai.base_url -Method POST -Headers $headers -Body $body
        $endTime = Get-Date
        $latencyMs = [math]::Round(($endTime - $startTime).TotalMilliseconds, 2)

        $tokensIn = $response.usage.prompt_tokens
        $tokensOut = $response.usage.completion_tokens
        $costUsd = ($tokensIn / 1000 * $modelConfig.cost_per_1k_input) + ($tokensOut / 1000 * $modelConfig.cost_per_1k_output)

        return @{
            response = $response.choices[0].message.content
            latency_ms = $latencyMs
            tokens_input = $tokensIn
            tokens_output = $tokensOut
            cost_usd = [math]::Round($costUsd, 6)
            model = $Model
            provider = "openai"
        }
    } catch {
        return @{
            error = $_.Exception.Message
            model = $Model
            provider = "openai"
        }
    }
}

function Invoke-AnthropicCompletion {
    <#
    .SYNOPSIS
        Calls Anthropic API for completion.
    .PARAMETER Prompt
        The prompt to send
    .PARAMETER Model
        Model ID (e.g., "claude-opus-4.5", "claude-sonnet-4")
    .PARAMETER ApiKey
        API key (uses env var if not provided)
    .PARAMETER MaxTokens
        Maximum tokens to generate
    .OUTPUTS
        Hashtable with: response, latency_ms, tokens_input, tokens_output, cost_usd
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Prompt,

        [string]$Model = "claude-sonnet-4",

        [string]$ApiKey = $null,

        [int]$MaxTokens = 1000
    )

    $config = Get-FrontierConfig
    if (-not $config) { return @{ error = "Config not found" } }

    if (-not $ApiKey) {
        $envVar = $config.endpoints.anthropic.api_key_env
        $ApiKey = [Environment]::GetEnvironmentVariable($envVar)
    }

    if (-not $ApiKey) {
        return @{ error = "Anthropic API key not found. Set ANTHROPIC_API_KEY environment variable." }
    }

    $modelConfig = $config.endpoints.anthropic.models[$Model]
    if (-not $modelConfig) {
        $modelConfig = @{ model_id = $Model; cost_per_1k_input = 0.003; cost_per_1k_output = 0.015 }
    }

    $startTime = Get-Date

    $body = @{
        model = $modelConfig.model_id
        messages = @(
            @{ role = "user"; content = $Prompt }
        )
        max_tokens = $MaxTokens
    } | ConvertTo-Json -Depth 5

    $headers = @{
        "x-api-key" = $ApiKey
        "Content-Type" = "application/json"
        "anthropic-version" = "2023-06-01"
    }

    try {
        $response = Invoke-RestMethod -Uri $config.endpoints.anthropic.base_url -Method POST -Headers $headers -Body $body
        $endTime = Get-Date
        $latencyMs = [math]::Round(($endTime - $startTime).TotalMilliseconds, 2)

        $tokensIn = $response.usage.input_tokens
        $tokensOut = $response.usage.output_tokens
        $costUsd = ($tokensIn / 1000 * $modelConfig.cost_per_1k_input) + ($tokensOut / 1000 * $modelConfig.cost_per_1k_output)

        return @{
            response = $response.content[0].text
            latency_ms = $latencyMs
            tokens_input = $tokensIn
            tokens_output = $tokensOut
            cost_usd = [math]::Round($costUsd, 6)
            model = $Model
            provider = "anthropic"
        }
    } catch {
        return @{
            error = $_.Exception.Message
            model = $Model
            provider = "anthropic"
        }
    }
}

function Invoke-GoogleCompletion {
    <#
    .SYNOPSIS
        Calls Google AI API for completion.
    .PARAMETER Prompt
        The prompt to send
    .PARAMETER Model
        Model ID (e.g., "gemini-3-pro", "gemini-2-flash")
    .PARAMETER ApiKey
        API key (uses env var if not provided)
    .PARAMETER MaxTokens
        Maximum tokens to generate
    .OUTPUTS
        Hashtable with: response, latency_ms, tokens_input, tokens_output, cost_usd
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Prompt,

        [string]$Model = "gemini-2-flash",

        [string]$ApiKey = $null,

        [int]$MaxTokens = 1000
    )

    $config = Get-FrontierConfig
    if (-not $config) { return @{ error = "Config not found" } }

    if (-not $ApiKey) {
        $envVar = $config.endpoints.google.api_key_env
        $ApiKey = [Environment]::GetEnvironmentVariable($envVar)
    }

    if (-not $ApiKey) {
        return @{ error = "Google API key not found. Set GOOGLE_API_KEY environment variable." }
    }

    $modelConfig = $config.endpoints.google.models[$Model]
    if (-not $modelConfig) {
        $modelConfig = @{ model_id = $Model; cost_per_1k_input = 0.0001; cost_per_1k_output = 0.0004 }
    }

    $startTime = Get-Date

    $url = "$($config.endpoints.google.base_url)/$($modelConfig.model_id):generateContent?key=$ApiKey"

    $body = @{
        contents = @(
            @{
                parts = @(
                    @{ text = $Prompt }
                )
            }
        )
        generationConfig = @{
            maxOutputTokens = $MaxTokens
        }
    } | ConvertTo-Json -Depth 5

    try {
        $response = Invoke-RestMethod -Uri $url -Method POST -Body $body -ContentType "application/json"
        $endTime = Get-Date
        $latencyMs = [math]::Round(($endTime - $startTime).TotalMilliseconds, 2)

        $tokensIn = $response.usageMetadata.promptTokenCount
        $tokensOut = $response.usageMetadata.candidatesTokenCount
        $costUsd = ($tokensIn / 1000 * $modelConfig.cost_per_1k_input) + ($tokensOut / 1000 * $modelConfig.cost_per_1k_output)

        return @{
            response = $response.candidates[0].content.parts[0].text
            latency_ms = $latencyMs
            tokens_input = $tokensIn
            tokens_output = $tokensOut
            cost_usd = [math]::Round($costUsd, 6)
            model = $Model
            provider = "google"
        }
    } catch {
        return @{
            error = $_.Exception.Message
            model = $Model
            provider = "google"
        }
    }
}

function Invoke-FrontierCompletion {
    <#
    .SYNOPSIS
        Unified function to call any frontier model.
    .PARAMETER Prompt
        The prompt to send
    .PARAMETER Provider
        Provider name: "openai", "anthropic", "google"
    .PARAMETER Model
        Model ID specific to the provider
    .PARAMETER MaxTokens
        Maximum tokens to generate
    .OUTPUTS
        Hashtable with: response, latency_ms, tokens_input, tokens_output, cost_usd, provider, model
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Prompt,

        [Parameter(Mandatory=$true)]
        [string]$Provider,

        [Parameter(Mandatory=$true)]
        [string]$Model,

        [int]$MaxTokens = 1000
    )

    switch ($Provider.ToLower()) {
        "openai" { return Invoke-OpenAICompletion -Prompt $Prompt -Model $Model -MaxTokens $MaxTokens }
        "anthropic" { return Invoke-AnthropicCompletion -Prompt $Prompt -Model $Model -MaxTokens $MaxTokens }
        "google" { return Invoke-GoogleCompletion -Prompt $Prompt -Model $Model -MaxTokens $MaxTokens }
        default { return @{ error = "Unknown provider: $Provider" } }
    }
}

function Get-PublishedBenchmarkScores {
    <#
    .SYNOPSIS
        Retrieves published benchmark scores for a model.
    .PARAMETER Model
        Model identifier
    .PARAMETER Benchmarks
        Array of benchmark names to retrieve (optional, returns all if not specified)
    .OUTPUTS
        Hashtable with benchmark scores
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Model,

        [string[]]$Benchmarks = $null
    )

    $config = Get-FrontierConfig
    if (-not $config) { return @{ error = "Config not found" } }

    if (-not $config.published_benchmarks.ContainsKey($Model)) {
        return @{ error = "No published benchmarks found for: $Model" }
    }

    $scores = $config.published_benchmarks[$Model]

    if ($Benchmarks) {
        $filtered = @{}
        foreach ($bench in $Benchmarks) {
            if ($scores.ContainsKey($bench)) {
                $filtered[$bench] = $scores[$bench]
            }
        }
        return $filtered
    }

    return $scores
}

function Get-AvailableFrontierModels {
    <#
    .SYNOPSIS
        Lists all available frontier models from configuration.
    .OUTPUTS
        Array of model info hashtables
    #>

    $config = Get-FrontierConfig
    if (-not $config) { return @() }

    $models = @()

    foreach ($provider in $config.endpoints.Keys) {
        foreach ($modelKey in $config.endpoints[$provider].models.Keys) {
            $modelInfo = $config.endpoints[$provider].models[$modelKey]
            $models += @{
                provider = $provider
                key = $modelKey
                model_id = $modelInfo.model_id
                cost_per_1k_input = $modelInfo.cost_per_1k_input
                cost_per_1k_output = $modelInfo.cost_per_1k_output
            }
        }
    }

    return $models
}

# Export functions when dot-sourced
# Available: Invoke-FrontierCompletion, Invoke-OpenAICompletion, Invoke-AnthropicCompletion,
#            Invoke-GoogleCompletion, Get-PublishedBenchmarkScores, Get-AvailableFrontierModels
