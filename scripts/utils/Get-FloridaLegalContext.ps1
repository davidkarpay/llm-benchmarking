<#
.SYNOPSIS
    PowerShell wrapper for Florida legal RAG context retrieval.
.DESCRIPTION
    Queries the Florida Statutes FTS5 database and returns context
    suitable for injection into LLM prompts. Wraps query_fl_statutes.py.
#>

function Get-FloridaLegalContext {
    <#
    .SYNOPSIS
        Retrieve relevant Florida statute context for a legal query.
    .PARAMETER Query
        The search query (e.g., "speedy trial", "hearsay exception").
    .PARAMETER Limit
        Maximum number of statute chunks to return. Default: 5
    .PARAMETER MaxTokens
        Maximum approximate tokens in output. Default: 1500
    .PARAMETER Chapter
        Optional chapter filter (e.g., "90" for Evidence Code).
    .PARAMETER Format
        Output format: "rag" for LLM context, "json" for structured data. Default: rag
    .PARAMETER FullContent
        If specified, include full content instead of snippets.
    .PARAMETER DatabasePath
        Path to SQLite database. Default: extracted-statutes/florida-statutes.db
    .OUTPUTS
        String containing formatted statute context for RAG injection.
    .EXAMPLE
        Get-FloridaLegalContext -Query "speedy trial" -Limit 3
    .EXAMPLE
        Get-FloridaLegalContext -Query "hearsay exception" -Chapter 90 -Format json
    #>
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Query,

        [int]$Limit = 5,

        [int]$MaxTokens = 1500,

        [string]$Chapter,

        [ValidateSet("rag", "json")]
        [string]$Format = "rag",

        [switch]$FullContent,

        [string]$DatabasePath
    )

    # Locate the Python script relative to this script
    $scriptDir = Split-Path -Parent $PSScriptRoot
    $pythonScript = Join-Path $scriptDir "rag\query_fl_statutes.py"

    if (-not (Test-Path $pythonScript)) {
        throw "RAG query script not found: $pythonScript"
    }

    # Build command arguments
    $args = @(
        $pythonScript,
        "`"$Query`"",
        "--limit", $Limit,
        "--max-tokens", $MaxTokens,
        "--format", $Format
    )

    if ($Chapter) {
        $args += @("--chapter", $Chapter)
    }

    if ($FullContent) {
        $args += "--full"
    }

    if ($DatabasePath) {
        $args += @("--db", $DatabasePath)
    }

    # Execute Python script
    try {
        $result = & python @args 2>&1

        if ($LASTEXITCODE -ne 0) {
            $errorMsg = $result | Out-String
            throw "RAG query failed: $errorMsg"
        }

        return $result | Out-String
    }
    catch {
        Write-Warning "Florida RAG query failed: $_"
        return "No matching Florida statutes found for this query."
    }
}

function Get-FloridaRAGPrompt {
    <#
    .SYNOPSIS
        Build a complete RAG-augmented prompt for Florida legal queries.
    .PARAMETER Query
        The user's legal question.
    .PARAMETER Context
        Pre-retrieved context (if already obtained). If not provided, will query database.
    .PARAMETER Limit
        Number of statute chunks if querying. Default: 5
    .PARAMETER Chapter
        Optional chapter filter for context retrieval.
    .OUTPUTS
        String with context block + query, ready for LLM.
    .EXAMPLE
        Get-FloridaRAGPrompt -Query "What is the speedy trial deadline for felonies?"
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Query,

        [string]$Context,

        [int]$Limit = 5,

        [string]$Chapter
    )

    # Get context if not provided
    if (-not $Context) {
        $contextParams = @{
            Query = $Query
            Limit = $Limit
            Format = "rag"
        }
        if ($Chapter) {
            $contextParams.Chapter = $Chapter
        }
        $Context = Get-FloridaLegalContext @contextParams
    }

    # Build the RAG prompt using template
    $ragPrompt = @"
=== FLORIDA LEGAL AUTHORITY CONTEXT ===
The following Florida statutes are relevant to your query:

$Context

=== END CONTEXT ===

Using the above authority context AND your knowledge of Florida law, please answer the following:

$Query
"@

    return $ragPrompt
}

function Test-FloridaRAGConnection {
    <#
    .SYNOPSIS
        Test that the Florida RAG database is accessible.
    .PARAMETER DatabasePath
        Optional path to database. Uses default if not specified.
    .OUTPUTS
        Boolean indicating whether database is accessible.
    #>
    param(
        [string]$DatabasePath
    )

    try {
        $params = @{
            Query = "test"
            Limit = 1
            Format = "json"
        }
        if ($DatabasePath) {
            $params.DatabasePath = $DatabasePath
        }

        $result = Get-FloridaLegalContext @params
        return $result -match '"count":'
    }
    catch {
        return $false
    }
}

function Get-FloridaChapterContext {
    <#
    .SYNOPSIS
        Get context from a specific Florida Statutes chapter.
    .PARAMETER Chapter
        The chapter number (e.g., "90" for Evidence Code, "61" for Family Law).
    .PARAMETER Query
        Optional query to filter within the chapter. If not specified, returns top sections.
    .PARAMETER Limit
        Maximum sections to return. Default: 10
    .OUTPUTS
        String containing formatted chapter context.
    .EXAMPLE
        Get-FloridaChapterContext -Chapter 90 -Query "hearsay"
    .EXAMPLE
        Get-FloridaChapterContext -Chapter 61 -Limit 5
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Chapter,

        [string]$Query = "*",

        [int]$Limit = 10
    )

    return Get-FloridaLegalContext -Query $Query -Chapter $Chapter -Limit $Limit -FullContent
}

# Common chapter shortcuts
$script:FloridaChapters = @{
    "evidence" = "90"
    "family" = "61"
    "paternity" = "742"
    "criminal_procedure" = "900"
    "statute_of_limitations" = "95"
    "service_of_process" = "48"
    "civil_practice" = "1"
}

function Get-FloridaChapterNumber {
    <#
    .SYNOPSIS
        Convert common chapter names to chapter numbers.
    .PARAMETER Name
        The chapter name (e.g., "evidence", "family").
    .OUTPUTS
        String chapter number.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )

    $key = $Name.ToLower() -replace '\s+', '_'
    if ($script:FloridaChapters.ContainsKey($key)) {
        return $script:FloridaChapters[$key]
    }
    return $Name
}

# Export functions when dot-sourced
