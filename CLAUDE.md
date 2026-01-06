# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

PowerShell-based LLM benchmarking suite with **two primary purposes**:

1. **Single-Model Testing**: Hardware performance (speed, memory) and cognitive capabilities (reasoning, memory, context handling) for individual models via Ollama.

2. **Specialist Bundle Research**: Testing the hypothesis that bundles of small post-trained (LoRA/QLoRA) specialist models can compete with frontier models through intelligent routing and domain specialization.

## Commands

### Single-Model Benchmarks

```powershell
# Speed benchmarks
.\scripts\benchmark-speed.ps1 -Models @("llama3.1:8b", "qwen2.5:32b")

# Cognitive tests
.\scripts\benchmark-cognitive.ps1 -Model "qwen2.5:32b"
.\scripts\benchmark-cognitive.ps1 -Tests @("needle", "multihop") -Model "qwen2.5:32b"

# Vision tests
.\scripts\benchmark-vision.ps1 -Models @("llava:7b")

# Context stress test
.\scripts\test-context-length.ps1 -Sizes @(1000, 5000, 10000, 20000)
```

### Specialist Bundle Benchmarks

```powershell
# Parallel bundle benchmark (preferred - 4x faster)
.\scripts\benchmark-bundle-parallel.ps1 `
    -BundleConfig ".\configs\bundles\general-bundle.json" `
    -RouterConfig ".\configs\routers\semantic-router.json" `
    -TestSuite ".\test-suites\mixed\mixed-benchmark.json" `
    -Parallelism 4

# Sequential bundle benchmark
.\scripts\benchmark-bundle.ps1 `
    -BundleConfig ".\configs\bundles\general-bundle.json" `
    -RouterConfig ".\configs\routers\semantic-router.json" `
    -TestSuite ".\test-suites\general"

# Compare routing strategies
.\scripts\benchmark-routing.ps1 `
    -BundleConfig ".\configs\bundles\general-bundle.json" `
    -RouterConfigs @(".\configs\routers\semantic-router.json", ".\configs\routers\classifier-router.json") `
    -TestSuite ".\test-suites\general" `
    -IncludeOracle

# Analyze results
.\scripts\analyze-routing-failures.ps1
.\scripts\aggregate-results.ps1 -ResultDir "results/raw" -ShowDetails
```

### Test Suite Management

```powershell
# Import public datasets from HuggingFace
python scripts/import-datasets.py --all --limit 100

# Generate mixed benchmark suite
python scripts/create-mixed-suite.py

# Count tests
python scripts/count-tests.py
```

## Architecture

### Data Flow

```
Query → Router (semantic/classifier/orchestrator) → Specialist Selection → Ollama → Response
                                ↓
              ┌─────────────────┼─────────────────┐
              │                 │                 │
       code-specialist   reasoning-specialist   knowledge-specialist
        (codellama:7b)       (qwen2.5:14b)        (llama3.1:8b)
```

### Key Components

**Utility Modules** (dot-source these in scripts):
- `scripts/utils/Export-BenchmarkResult.ps1`: Hardware detection, JSON/CSV export, speed grading
- `scripts/utils/Invoke-BundleRouter.ps1`: All routing strategies (`Get-RoutingDecision` is main entry point)
- `scripts/utils/Invoke-FrontierAPI.ps1`: OpenAI/Anthropic/Google API clients

**Configuration Files**:
- `configs/bundles/*.json`: Specialist model definitions with keywords and domains
- `configs/routers/*.json`: Routing strategy settings (semantic, classifier, orchestrator, hierarchical-moe)
- `schemas/*.json`: JSON Schema validation for all config/result formats

**Test Suites**:
- `test-suites/general/`: Hand-crafted domain tests (reasoning, code, knowledge, creative)
- `test-suites/mixed/mixed-benchmark.json`: 573-test comprehensive suite
- `test-suites/{code,reasoning,knowledge,science}/`: Imported from GSM8K, HumanEval, MMLU, ARC

### PowerShell Patterns

All scripts are PowerShell 5.1+ compatible. Common patterns:

```powershell
# Import utilities at script start
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptDir\utils\Export-BenchmarkResult.ps1"
. "$scriptDir\utils\Invoke-BundleRouter.ps1"

# PS 5.1 JSON handling (use ConvertTo-Hashtable for nested objects)
$config = Get-JsonAsHashtable -Path $configPath

# Ollama invocation
$body = @{ model = $model; prompt = $prompt; stream = $false } | ConvertTo-Json
$response = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method Post -Body $body -ContentType "application/json"
```

## Routing Strategies

| Strategy | Speed | Best For |
|----------|-------|----------|
| semantic | Fast | Clear domain keywords (82.7% accuracy achieved) |
| classifier | Medium | Trained classification (not yet implemented) |
| orchestrator | Slow | Ambiguous/complex queries |

## Florida Legal RAG Pipeline

Extracted from FLLawDL2025 (Folio Views NXT format):
- **Extraction**: `scripts/extract-nxt-clean.py` (handles NXT binary format)
- **Chunking**: `scripts/chunk-statutes-structured.py` (statute section detection)
- **Output**: `extracted-statutes/chunks/florida-statutes.jsonl` (7,842 sections)
- **Embedding**: `scripts/embed-statutes.py` (SQLite + ChromaDB)

## Dependencies

- **Ollama** running locally (http://localhost:11434)
- **nvidia-smi** for GPU metrics
- **PowerShell 5.1+** (Windows built-in) or PowerShell 7+
- **Python 3.8+** with `datasets`, `chromadb`, `sentence-transformers` for dataset import/embedding
- **Optional**: OPENAI_API_KEY, ANTHROPIC_API_KEY, GOOGLE_API_KEY for frontier comparison

## Known Issues

- **Dollar sign in prompts**: Use single-quoted here-strings (`@'...'@`) to avoid variable expansion
- **Large prompts**: Windows 8191 char limit; pipe via stdin for larger inputs
- **ANSI escape codes**: May appear in JSON snippets from Ollama responses; strip with regex if needed
- **Parallel execution**: Runspaces share Ollama endpoint; limit parallelism to avoid timeouts

## Current Benchmark Results (573-Test Suite)

| Metric | Value |
|--------|-------|
| Routing Accuracy | 82.7% |
| Response Accuracy | 95.8% |
| Avg Active Params | 9.2B (vs 39.8B total) |

Main routing failures: Knowledge ↔ Reasoning overlap (CS/physics questions), Knowledge → Code (MMLU CS looks like code)
