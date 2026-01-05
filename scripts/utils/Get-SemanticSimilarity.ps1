<#
.SYNOPSIS
    Semantic similarity scoring using embedding models.
.DESCRIPTION
    Provides functions for calculating cosine similarity between text using
    Ollama embedding models (e.g., nomic-embed-text).
.NOTES
    Requires: Ollama with an embedding model installed (ollama pull nomic-embed-text)
#>

function Get-TextEmbedding {
    <#
    .SYNOPSIS
        Get embedding vector for text using Ollama API.
    .PARAMETER Text
        The text to embed.
    .PARAMETER Model
        The embedding model to use. Default: nomic-embed-text
    .OUTPUTS
        Array of doubles representing the embedding vector.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Text,

        [string]$Model = "nomic-embed-text"
    )

    # Use Ollama API for embeddings
    $body = @{
        model = $Model
        prompt = $Text
    } | ConvertTo-Json -Compress

    try {
        $response = Invoke-RestMethod -Uri "http://localhost:11434/api/embeddings" -Method Post -Body $body -ContentType "application/json"
        return $response.embedding
    }
    catch {
        Write-Warning "Failed to get embedding: $($_.Exception.Message)"
        return $null
    }
}

function Get-CosineSimilarity {
    <#
    .SYNOPSIS
        Calculate cosine similarity between two vectors.
    .PARAMETER Vector1
        First embedding vector.
    .PARAMETER Vector2
        Second embedding vector.
    .OUTPUTS
        Double representing similarity from -1 to 1 (higher = more similar).
    #>
    param(
        [Parameter(Mandatory=$true)]
        [double[]]$Vector1,

        [Parameter(Mandatory=$true)]
        [double[]]$Vector2
    )

    if ($Vector1.Count -ne $Vector2.Count) {
        Write-Warning "Vector dimensions don't match: $($Vector1.Count) vs $($Vector2.Count)"
        return 0
    }

    $dotProduct = 0.0
    $magnitude1 = 0.0
    $magnitude2 = 0.0

    for ($i = 0; $i -lt $Vector1.Count; $i++) {
        $dotProduct += $Vector1[$i] * $Vector2[$i]
        $magnitude1 += $Vector1[$i] * $Vector1[$i]
        $magnitude2 += $Vector2[$i] * $Vector2[$i]
    }

    $magnitude1 = [Math]::Sqrt($magnitude1)
    $magnitude2 = [Math]::Sqrt($magnitude2)

    if ($magnitude1 -eq 0 -or $magnitude2 -eq 0) {
        return 0
    }

    return $dotProduct / ($magnitude1 * $magnitude2)
}

function Get-SemanticSimilarity {
    <#
    .SYNOPSIS
        Calculate semantic similarity between two texts.
    .PARAMETER Text1
        First text to compare.
    .PARAMETER Text2
        Second text to compare.
    .PARAMETER Model
        Embedding model to use. Default: nomic-embed-text
    .OUTPUTS
        Double from 0 to 1 representing semantic similarity.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Text1,

        [Parameter(Mandatory=$true)]
        [string]$Text2,

        [string]$Model = "nomic-embed-text"
    )

    # Get embeddings for both texts
    $embedding1 = Get-TextEmbedding -Text $Text1 -Model $Model
    $embedding2 = Get-TextEmbedding -Text $Text2 -Model $Model

    if ($null -eq $embedding1 -or $null -eq $embedding2) {
        Write-Warning "Failed to get embeddings, falling back to keyword matching"
        return -1  # Signal to use fallback
    }

    # Calculate cosine similarity
    $similarity = Get-CosineSimilarity -Vector1 $embedding1 -Vector2 $embedding2

    # Normalize from [-1, 1] to [0, 1] for easier interpretation
    $normalized = ($similarity + 1) / 2

    return [Math]::Round($normalized, 4)
}

function Test-ResponseSemantic {
    <#
    .SYNOPSIS
        Test if a response is semantically similar to a reference answer.
    .PARAMETER Response
        The model's response.
    .PARAMETER ReferenceAnswer
        The expected/reference answer.
    .PARAMETER Threshold
        Minimum similarity score to pass. Default: 0.7
    .PARAMETER Model
        Embedding model to use. Default: nomic-embed-text
    .OUTPUTS
        Hashtable with: passed, similarity, threshold
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Response,

        [Parameter(Mandatory=$true)]
        [string]$ReferenceAnswer,

        [double]$Threshold = 0.7,

        [string]$Model = "nomic-embed-text"
    )

    $similarity = Get-SemanticSimilarity -Text1 $Response -Text2 $ReferenceAnswer -Model $Model

    if ($similarity -lt 0) {
        # Embedding failed, return null to signal fallback needed
        return $null
    }

    return @{
        passed = $similarity -ge $Threshold
        similarity = $similarity
        threshold = $Threshold
    }
}

function Test-ResponseHybrid {
    <#
    .SYNOPSIS
        Test response using both keyword and semantic matching.
    .PARAMETER Response
        The model's response.
    .PARAMETER ExpectedContains
        Array of keywords that should appear in response.
    .PARAMETER ReferenceAnswer
        Optional reference answer for semantic comparison.
    .PARAMETER SemanticThreshold
        Minimum semantic similarity. Default: 0.7
    .PARAMETER KeywordWeight
        Weight for keyword matching (0-1). Default: 0.5
    .OUTPUTS
        Hashtable with: passed, keyword_score, semantic_score, combined_score
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Response,

        [string[]]$ExpectedContains = @(),

        [string]$ReferenceAnswer = "",

        [double]$SemanticThreshold = 0.7,

        [double]$KeywordWeight = 0.5
    )

    $result = @{
        passed = $false
        keyword_score = 0.0
        semantic_score = 0.0
        combined_score = 0.0
        keyword_matches = @()
        keyword_misses = @()
    }

    # Keyword matching
    if ($ExpectedContains.Count -gt 0) {
        $matchCount = 0
        foreach ($keyword in $ExpectedContains) {
            if ($Response -match [regex]::Escape($keyword)) {
                $matchCount++
                $result.keyword_matches += $keyword
            } else {
                $result.keyword_misses += $keyword
            }
        }
        $result.keyword_score = $matchCount / $ExpectedContains.Count
    } else {
        $result.keyword_score = 1.0  # No keywords to match = pass
    }

    # Semantic matching
    if ($ReferenceAnswer -and $ReferenceAnswer.Length -gt 0) {
        $semantic = Get-SemanticSimilarity -Text1 $Response -Text2 $ReferenceAnswer
        if ($semantic -ge 0) {
            $result.semantic_score = $semantic
        } else {
            # Embedding failed, weight keyword score more
            $KeywordWeight = 1.0
        }
    } else {
        $result.semantic_score = 1.0  # No reference = pass
        $KeywordWeight = 1.0
    }

    # Combined score
    $semanticWeight = 1.0 - $KeywordWeight
    $result.combined_score = ($result.keyword_score * $KeywordWeight) + ($result.semantic_score * $semanticWeight)

    # Pass if combined score meets threshold
    $result.passed = $result.combined_score -ge $SemanticThreshold

    return $result
}

# Functions are automatically available when dot-sourced
