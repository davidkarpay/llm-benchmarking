# Invoke-BundleRouter.ps1
# Routing utility functions for specialist model bundles
# Version: 1.1

<#
.SYNOPSIS
    Utility module for routing queries to specialist models in a bundle.
.DESCRIPTION
    Provides routing functions for:
    - Semantic (keyword/embedding-based) routing
    - Classifier-based routing
    - Orchestrator LLM routing
    - Hierarchical MoE routing
    - Oracle routing (for baseline comparison)
#>

# ═══════════════════════════════════════════════════════════════
# PowerShell 5.1 Compatibility (local fallback if not loaded from Export-BenchmarkResult.ps1)
# ═══════════════════════════════════════════════════════════════

if (-not (Get-Command ConvertTo-HashtableLocal -ErrorAction SilentlyContinue)) {
    function script:ConvertTo-HashtableLocal {
        param([Parameter(ValueFromPipeline)]$InputObject)
        process {
            if ($null -eq $InputObject) { return $null }
            if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
                $collection = @(foreach ($object in $InputObject) { ConvertTo-HashtableLocal $object })
                return ,$collection
            } elseif ($InputObject -is [psobject]) {
                $hash = @{}
                foreach ($property in $InputObject.PSObject.Properties) {
                    $hash[$property.Name] = ConvertTo-HashtableLocal $property.Value
                }
                return $hash
            } else {
                return $InputObject
            }
        }
    }
}

# ═══════════════════════════════════════════════════════════════
# Routing Functions
# ═══════════════════════════════════════════════════════════════

function Get-KeywordScore {
    <#
    .SYNOPSIS
        Calculates keyword match score between query and specialist keywords.
    .PARAMETER Query
        The user query
    .PARAMETER Keywords
        Array of keywords to match against
    .OUTPUTS
        Score from 0 to 1
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Query,

        [Parameter(Mandatory=$true)]
        [array]$Keywords
    )

    $queryLower = $Query.ToLower()
    $matchedKeywords = 0
    $matchScore = 0

    foreach ($keyword in $Keywords) {
        $keywordLower = $keyword.ToLower()

        if ($queryLower -match [regex]::Escape($keywordLower)) {
            $matchedKeywords++
            # Longer keyword matches are more specific/valuable
            $matchScore += [math]::Min(1, $keywordLower.Length / 6)
        }
    }

    if ($matchedKeywords -eq 0) { return 0 }

    # Boost score based on number of matches (multiple keyword matches = higher relevance)
    # 1 match = base score, 2 matches = 1.5x, 3+ matches = 2x
    $matchBonus = 1
    if ($matchedKeywords -ge 2) { $matchBonus = 1.5 }
    if ($matchedKeywords -ge 3) { $matchBonus = 2 }

    # Normalize: avg match score * match bonus, capped at 1
    $avgMatchScore = $matchScore / $matchedKeywords
    $finalScore = [math]::Min(1, $avgMatchScore * $matchBonus)

    return [math]::Round($finalScore, 3)
}

function Get-DomainSignatureScore {
    <#
    .SYNOPSIS
        Calculates domain signature match score.
    .PARAMETER Query
        The user query
    .PARAMETER DomainSignatures
        Hashtable of domain -> signature phrases
    .PARAMETER TargetDomains
        Domains to check against
    .OUTPUTS
        Score from 0 to 1
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Query,

        [hashtable]$DomainSignatures,

        [array]$TargetDomains
    )

    if (-not $DomainSignatures) { return 0 }

    $queryLower = $Query.ToLower()
    $totalScore = 0
    $matchCount = 0

    foreach ($domain in $TargetDomains) {
        if ($DomainSignatures.ContainsKey($domain)) {
            $signatures = $DomainSignatures[$domain]
            foreach ($sig in $signatures) {
                $sigLower = $sig.ToLower()
                if ($queryLower -match [regex]::Escape($sigLower)) {
                    # Longer phrases are more specific = higher value
                    $score = $sigLower.Length / 20
                    $totalScore += $score
                    $matchCount++
                }
            }
        }
    }

    # Multiple matches = strong domain signal, apply bonus
    if ($matchCount -ge 2) { $totalScore *= 1.5 }
    if ($matchCount -ge 3) { $totalScore *= 1.5 }

    return [math]::Min(1, $totalScore)
}

function Invoke-SemanticRoute {
    <#
    .SYNOPSIS
        Routes query using semantic (keyword + signature) matching.
    .PARAMETER Query
        The user query to route
    .PARAMETER BundleConfig
        Bundle configuration hashtable
    .PARAMETER RouterConfig
        Router configuration hashtable
    .OUTPUTS
        Hashtable with: specialist_id, confidence, latency_ms, alternatives
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Query,

        [Parameter(Mandatory=$true)]
        [hashtable]$BundleConfig,

        [Parameter(Mandatory=$true)]
        [hashtable]$RouterConfig
    )

    $startTime = Get-Date
    $scores = @{}
    $semanticConfig = $RouterConfig.semantic_config
    $threshold = if ($semanticConfig.similarity_threshold) { $semanticConfig.similarity_threshold } else { 0.4 }

    foreach ($specialist in $BundleConfig.specialists) {
        $keywordScore = 0
        $signatureScore = 0

        # Keyword matching
        if ($semanticConfig.use_keywords -and $specialist.keywords) {
            $keywordScore = Get-KeywordScore -Query $Query -Keywords $specialist.keywords
        }

        # Domain signature matching
        if ($semanticConfig.domain_signatures) {
            $signatureScore = Get-DomainSignatureScore -Query $Query -DomainSignatures $semanticConfig.domain_signatures -TargetDomains $specialist.domains
        }

        # Combined score (weighted average)
        $combinedScore = ($keywordScore * 0.6) + ($signatureScore * 0.4)
        $scores[$specialist.id] = $combinedScore
    }

    # Sort by score descending
    $sorted = $scores.GetEnumerator() | Sort-Object -Property Value -Descending
    $bestMatch = $sorted | Select-Object -First 1
    $alternatives = ($sorted | Select-Object -Skip 1 -First 3 | ForEach-Object { $_.Key })

    $endTime = Get-Date
    $latencyMs = [math]::Round(($endTime - $startTime).TotalMilliseconds, 2)

    # Check if best match meets threshold
    $selectedId = $null
    $confidence = 0

    if ($bestMatch.Value -ge $threshold) {
        $selectedId = $bestMatch.Key
        $confidence = $bestMatch.Value
    } else {
        # Use fallback specialist if available
        $fallback = $BundleConfig.specialists | Where-Object { $_.fallback -eq $true } | Select-Object -First 1
        if ($fallback) {
            $selectedId = $fallback.id
            $confidence = 0.1  # Low confidence for fallback
        }
    }

    return @{
        specialist_id = $selectedId
        confidence = [math]::Round($confidence, 3)
        latency_ms = $latencyMs
        alternatives = $alternatives
        strategy = "semantic"
        all_scores = $scores
    }
}

function Invoke-ClassifierRoute {
    <#
    .SYNOPSIS
        Routes query using a small classifier model.
    .PARAMETER Query
        The user query to route
    .PARAMETER BundleConfig
        Bundle configuration hashtable
    .PARAMETER RouterConfig
        Router configuration hashtable
    .OUTPUTS
        Hashtable with: specialist_id, confidence, latency_ms, router_model
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Query,

        [Parameter(Mandatory=$true)]
        [hashtable]$BundleConfig,

        [Parameter(Mandatory=$true)]
        [hashtable]$RouterConfig
    )

    $startTime = Get-Date
    $classifierConfig = $RouterConfig.classifier_config
    $model = if ($classifierConfig.classifier_model) { $classifierConfig.classifier_model } else { "phi3:3.8b" }

    # Build domain list from specialists
    $domains = ($BundleConfig.specialists | ForEach-Object { $_.domains } | Sort-Object -Unique) -join ", "

    # Build prompt
    $promptTemplate = if ($classifierConfig.classification_prompt) {
        $classifierConfig.classification_prompt
    } else {
        "Classify the following query into exactly ONE category. Categories: {domains}`n`nQuery: {query}`n`nRespond with ONLY the category name, nothing else."
    }

    $prompt = $promptTemplate -replace '\{domains\}', $domains -replace '\{query\}', $Query

    # Call classifier model
    try {
        $response = ollama run $model $prompt 2>&1 | Out-String
        $response = $response.Trim().ToLower()
    } catch {
        $response = ""
    }

    $endTime = Get-Date
    $latencyMs = [math]::Round(($endTime - $startTime).TotalMilliseconds, 2)

    # Match response to specialist
    $selectedId = $null
    $confidence = 0

    foreach ($specialist in $BundleConfig.specialists) {
        foreach ($domain in $specialist.domains) {
            if ($response -match $domain.ToLower()) {
                $selectedId = $specialist.id
                $confidence = 0.8  # Classifier confidence
                break
            }
        }
        if ($selectedId) { break }
    }

    # Fallback if no match
    if (-not $selectedId) {
        $fallback = $BundleConfig.specialists | Where-Object { $_.fallback -eq $true } | Select-Object -First 1
        if ($fallback) {
            $selectedId = $fallback.id
            $confidence = 0.1
        }
    }

    return @{
        specialist_id = $selectedId
        confidence = $confidence
        latency_ms = $latencyMs
        router_model = $model
        raw_response = $response
        strategy = "classifier"
    }
}

function Invoke-OrchestratorRoute {
    <#
    .SYNOPSIS
        Routes query using a small orchestrator LLM.
    .PARAMETER Query
        The user query to route
    .PARAMETER BundleConfig
        Bundle configuration hashtable
    .PARAMETER RouterConfig
        Router configuration hashtable
    .OUTPUTS
        Hashtable with: specialist_id, confidence, latency_ms, router_model
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Query,

        [Parameter(Mandatory=$true)]
        [hashtable]$BundleConfig,

        [Parameter(Mandatory=$true)]
        [hashtable]$RouterConfig
    )

    $startTime = Get-Date
    $orchestratorConfig = $RouterConfig.orchestrator_config
    $model = if ($orchestratorConfig.orchestrator_model) { $orchestratorConfig.orchestrator_model } else { "phi3:3.8b" }

    # Build specialist list for prompt
    $specialistList = ($BundleConfig.specialists | ForEach-Object {
        "- $($_.id): $($_.specialization)"
    }) -join "`n"

    # Build prompt
    $promptTemplate = if ($orchestratorConfig.routing_prompt_template) {
        $orchestratorConfig.routing_prompt_template
    } else {
        "Available specialists:`n{specialists}`n`nUser query: {query}`n`nWhich specialist should handle this query? Respond with ONLY the specialist ID:"
    }

    $prompt = $promptTemplate -replace '\{specialists\}', $specialistList -replace '\{query\}', $Query

    # Call orchestrator model
    try {
        $response = ollama run $model $prompt 2>&1 | Out-String
        $response = $response.Trim()
    } catch {
        $response = ""
    }

    $endTime = Get-Date
    $latencyMs = [math]::Round(($endTime - $startTime).TotalMilliseconds, 2)

    # Match response to specialist ID
    $selectedId = $null
    $confidence = 0

    foreach ($specialist in $BundleConfig.specialists) {
        if ($response -match $specialist.id) {
            $selectedId = $specialist.id
            $confidence = 0.85  # Orchestrator confidence
            break
        }
    }

    # Fallback if no match
    if (-not $selectedId) {
        $fallback = $BundleConfig.specialists | Where-Object { $_.fallback -eq $true } | Select-Object -First 1
        if ($fallback) {
            $selectedId = $fallback.id
            $confidence = 0.1
        }
    }

    return @{
        specialist_id = $selectedId
        confidence = $confidence
        latency_ms = $latencyMs
        router_model = $model
        raw_response = $response
        strategy = "orchestrator"
    }
}

function Invoke-HierarchicalMoERoute {
    <#
    .SYNOPSIS
        Routes query using hierarchical MoE-style gating.
    .PARAMETER Query
        The user query to route
    .PARAMETER BundleConfig
        Bundle configuration hashtable
    .PARAMETER RouterConfig
        Router configuration hashtable
    .OUTPUTS
        Hashtable with: specialist_id, confidence, latency_ms, top_k_specialists
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Query,

        [Parameter(Mandatory=$true)]
        [hashtable]$BundleConfig,

        [Parameter(Mandatory=$true)]
        [hashtable]$RouterConfig
    )

    $startTime = Get-Date
    $moeConfig = $RouterConfig.hierarchical_config
    $model = if ($moeConfig.gating_model) { $moeConfig.gating_model } else { "phi3:3.8b" }
    $topK = if ($moeConfig.top_k) { $moeConfig.top_k } else { 2 }

    # Build specialist list for gating
    $specialistList = ($BundleConfig.specialists | ForEach-Object {
        "- $($_.id): $($_.specialization)"
    }) -join "`n"

    # Build gating prompt
    $prompt = @"
Rate the relevance of each specialist (0-10) for handling this query:

Query: $Query

Specialists:
$specialistList

Respond with ONLY a relevance score (0-10) for each specialist, one per line in format: specialist_id: score
"@

    # Call gating model
    try {
        $response = ollama run $model $prompt 2>&1 | Out-String
    } catch {
        $response = ""
    }

    $endTime = Get-Date
    $latencyMs = [math]::Round(($endTime - $startTime).TotalMilliseconds, 2)

    # Parse scores from response
    $scores = @{}
    foreach ($specialist in $BundleConfig.specialists) {
        $pattern = "$($specialist.id).*?(\d+)"
        if ($response -match $pattern) {
            $scores[$specialist.id] = [int]$matches[1]
        } else {
            $scores[$specialist.id] = 0
        }
    }

    # Sort and get top-k
    $sorted = $scores.GetEnumerator() | Sort-Object -Property Value -Descending
    $topKSpecialists = $sorted | Select-Object -First $topK | ForEach-Object { $_.Key }
    $bestMatch = $sorted | Select-Object -First 1

    $selectedId = $bestMatch.Key
    $confidence = [math]::Round($bestMatch.Value / 10, 2)

    # Fallback if no good match
    if ($bestMatch.Value -lt 3) {
        $fallback = $BundleConfig.specialists | Where-Object { $_.fallback -eq $true } | Select-Object -First 1
        if ($fallback) {
            $selectedId = $fallback.id
            $confidence = 0.1
        }
    }

    return @{
        specialist_id = $selectedId
        confidence = $confidence
        latency_ms = $latencyMs
        router_model = $model
        top_k_specialists = $topKSpecialists
        all_scores = $scores
        raw_response = $response
        strategy = "hierarchical_moe"
    }
}

function Invoke-OracleRoute {
    <#
    .SYNOPSIS
        Returns the expected specialist (perfect routing baseline).
    .PARAMETER ExpectedSpecialist
        The specialist ID that should be selected
    .OUTPUTS
        Hashtable with: specialist_id, confidence, latency_ms
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ExpectedSpecialist
    )

    return @{
        specialist_id = $ExpectedSpecialist
        confidence = 1.0
        latency_ms = 0
        strategy = "oracle"
    }
}

function Get-RoutingDecision {
    <#
    .SYNOPSIS
        Main routing dispatcher that calls appropriate routing function.
    .PARAMETER Query
        The user query to route
    .PARAMETER BundleConfig
        Bundle configuration (hashtable or path to JSON)
    .PARAMETER RouterConfig
        Router configuration (hashtable or path to JSON)
    .PARAMETER ExpectedSpecialist
        Expected specialist for oracle routing (optional)
    .OUTPUTS
        Hashtable with routing decision details
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Query,

        [Parameter(Mandatory=$true)]
        $BundleConfig,

        [Parameter(Mandatory=$true)]
        $RouterConfig,

        [string]$ExpectedSpecialist = $null
    )

    # Load configs if paths provided (using Get-JsonAsHashtable for PS 5.1 compatibility)
    if ($BundleConfig -is [string]) {
        if (Get-Command Get-JsonAsHashtable -ErrorAction SilentlyContinue) {
            $BundleConfig = Get-JsonAsHashtable -Path $BundleConfig
        } else {
            $json = Get-Content $BundleConfig -Raw | ConvertFrom-Json
            $BundleConfig = ConvertTo-HashtableLocal $json
        }
    }
    if ($RouterConfig -is [string]) {
        if (Get-Command Get-JsonAsHashtable -ErrorAction SilentlyContinue) {
            $RouterConfig = Get-JsonAsHashtable -Path $RouterConfig
        } else {
            $json = Get-Content $RouterConfig -Raw | ConvertFrom-Json
            $RouterConfig = ConvertTo-HashtableLocal $json
        }
    }

    $strategy = $RouterConfig.strategy

    $result = switch ($strategy) {
        "semantic" { Invoke-SemanticRoute -Query $Query -BundleConfig $BundleConfig -RouterConfig $RouterConfig }
        "classifier" { Invoke-ClassifierRoute -Query $Query -BundleConfig $BundleConfig -RouterConfig $RouterConfig }
        "orchestrator" { Invoke-OrchestratorRoute -Query $Query -BundleConfig $BundleConfig -RouterConfig $RouterConfig }
        "hierarchical_moe" { Invoke-HierarchicalMoERoute -Query $Query -BundleConfig $BundleConfig -RouterConfig $RouterConfig }
        "oracle" {
            if ($ExpectedSpecialist) {
                Invoke-OracleRoute -ExpectedSpecialist $ExpectedSpecialist
            } else {
                Write-Warning "Oracle routing requires ExpectedSpecialist parameter"
                @{ specialist_id = $null; confidence = 0; latency_ms = 0; strategy = "oracle"; error = "No expected specialist provided" }
            }
        }
        default {
            Write-Warning "Unknown routing strategy: $strategy"
            @{ specialist_id = $null; confidence = 0; latency_ms = 0; strategy = $strategy; error = "Unknown strategy" }
        }
    }

    # Add routing correctness if expected specialist provided
    if ($ExpectedSpecialist) {
        $result.expected_specialist = $ExpectedSpecialist
        $result.routing_correct = ($result.specialist_id -eq $ExpectedSpecialist)
    }

    return $result
}

function Get-SpecialistModel {
    <#
    .SYNOPSIS
        Gets the model name for a specialist ID from bundle config.
    .PARAMETER SpecialistId
        The specialist ID to look up
    .PARAMETER BundleConfig
        Bundle configuration hashtable
    .OUTPUTS
        Model name string
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$SpecialistId,

        [Parameter(Mandatory=$true)]
        [hashtable]$BundleConfig
    )

    $specialist = $BundleConfig.specialists | Where-Object { $_.id -eq $SpecialistId } | Select-Object -First 1
    if ($specialist) {
        return $specialist.model
    }
    return $null
}

function Get-SpecialistParameters {
    <#
    .SYNOPSIS
        Gets the parameter count for a specialist ID from bundle config.
    .PARAMETER SpecialistId
        The specialist ID to look up
    .PARAMETER BundleConfig
        Bundle configuration hashtable
    .OUTPUTS
        Parameter count in billions
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$SpecialistId,

        [Parameter(Mandatory=$true)]
        [hashtable]$BundleConfig
    )

    $specialist = $BundleConfig.specialists | Where-Object { $_.id -eq $SpecialistId } | Select-Object -First 1
    if ($specialist -and $specialist.parameters_b) {
        return $specialist.parameters_b
    }
    return 0
}

function Invoke-EnsembleRoute {
    <#
    .SYNOPSIS
        Routes query using multiple strategies and combines results.
    .PARAMETER Query
        The user query to route
    .PARAMETER BundleConfig
        Bundle configuration hashtable
    .PARAMETER Strategies
        Array of routing strategies to use
    .PARAMETER VotingMethod
        How to combine results: "majority", "weighted", "unanimous"
    .OUTPUTS
        Hashtable with: specialist_id, confidence, latency_ms, votes
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Query,

        [Parameter(Mandatory=$true)]
        [hashtable]$BundleConfig,

        [string[]]$Strategies = @("semantic", "classifier", "orchestrator"),

        [string]$VotingMethod = "majority"
    )

    $startTime = Get-Date
    $votes = @{}
    $decisions = @{}
    $totalConfidence = 0

    # Run each routing strategy
    foreach ($strategy in $Strategies) {
        $routerConfig = @{ strategy = $strategy }

        # Add default configs for each strategy
        switch ($strategy) {
            "semantic" {
                $routerConfig.semantic_config = @{
                    use_keywords = $true
                    similarity_threshold = 0.4
                }
            }
            "classifier" {
                $routerConfig.classifier_config = @{
                    classifier_model = "phi3:3.8b"
                }
            }
            "orchestrator" {
                $routerConfig.orchestrator_config = @{
                    orchestrator_model = "phi3:3.8b"
                }
            }
        }

        $decision = switch ($strategy) {
            "semantic" { Invoke-SemanticRoute -Query $Query -BundleConfig $BundleConfig -RouterConfig $routerConfig }
            "classifier" { Invoke-ClassifierRoute -Query $Query -BundleConfig $BundleConfig -RouterConfig $routerConfig }
            "orchestrator" { Invoke-OrchestratorRoute -Query $Query -BundleConfig $BundleConfig -RouterConfig $routerConfig }
            default { @{ specialist_id = $null; confidence = 0 } }
        }

        if ($decision.specialist_id) {
            $decisions[$strategy] = $decision
            $totalConfidence += $decision.confidence

            if (-not $votes.ContainsKey($decision.specialist_id)) {
                $votes[$decision.specialist_id] = @{
                    count = 0
                    weighted_score = 0
                    voters = @()
                }
            }
            $votes[$decision.specialist_id].count++
            $votes[$decision.specialist_id].weighted_score += $decision.confidence
            $votes[$decision.specialist_id].voters += $strategy
        }
    }

    $endTime = Get-Date
    $latencyMs = [math]::Round(($endTime - $startTime).TotalMilliseconds, 2)

    # Determine winner based on voting method
    $selectedId = $null
    $confidence = 0

    if ($votes.Count -eq 0) {
        # No votes, use fallback
        $fallback = $BundleConfig.specialists | Where-Object { $_.fallback -eq $true } | Select-Object -First 1
        if ($fallback) {
            $selectedId = $fallback.id
            $confidence = 0.1
        }
    } else {
        switch ($VotingMethod) {
            "majority" {
                # Most votes wins
                $winner = $votes.GetEnumerator() | Sort-Object { $_.Value.count } -Descending | Select-Object -First 1
                $selectedId = $winner.Key
                $confidence = $winner.Value.count / $Strategies.Count
            }
            "weighted" {
                # Highest weighted score wins
                $winner = $votes.GetEnumerator() | Sort-Object { $_.Value.weighted_score } -Descending | Select-Object -First 1
                $selectedId = $winner.Key
                $confidence = $winner.Value.weighted_score / $totalConfidence
            }
            "unanimous" {
                # All must agree
                if ($votes.Count -eq 1 -and $votes.Values[0].count -eq $Strategies.Count) {
                    $selectedId = $votes.Keys[0]
                    $confidence = 1.0
                } else {
                    # No unanimity, use fallback
                    $fallback = $BundleConfig.specialists | Where-Object { $_.fallback -eq $true } | Select-Object -First 1
                    if ($fallback) {
                        $selectedId = $fallback.id
                        $confidence = 0.1
                    }
                }
            }
        }
    }

    return @{
        specialist_id = $selectedId
        confidence = [math]::Round($confidence, 3)
        latency_ms = $latencyMs
        votes = $votes
        decisions = $decisions
        voting_method = $VotingMethod
        strategies_used = $Strategies
        strategy = "ensemble"
    }
}

# Export functions when dot-sourced
# Available: Get-RoutingDecision, Invoke-SemanticRoute, Invoke-ClassifierRoute,
#            Invoke-OrchestratorRoute, Invoke-HierarchicalMoERoute, Invoke-OracleRoute,
#            Invoke-EnsembleRoute, Get-SpecialistModel, Get-SpecialistParameters
