# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

PowerShell-based LLM benchmarking suite with **two primary purposes**:

1. **Single-Model Testing**: Hardware performance (speed, memory) and cognitive capabilities (reasoning, memory, context handling) for individual models via Ollama.

2. **Specialist Bundle Research**: Testing the hypothesis that bundles of small post-trained (LoRA/QLoRA) specialist models can compete with frontier models through intelligent routing and domain specialization.

## Commands

### Quick Status Checks

```powershell
# Check Ollama and loaded models
ollama ps                    # Show running models
ollama list                  # Show all available models

# GPU status
nvidia-smi                   # VRAM usage, temperature, utilization
```

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

| Strategy | Speed | General Domain | Florida Legal | Best For |
|----------|-------|----------------|---------------|----------|
| semantic | Fast (<50ms) | 82.7% | 35.2% | Clear domain keywords |
| classifier | Medium (~200ms) | ~88% (est) | - | Trained classification (planned) |
| orchestrator | Slow (~400ms) | - | **64.8%** | Ambiguous/complex queries |
| hierarchical_moe | Slowest (~1.5s) | - | 61.1% | Multi-expert queries |

**Key Finding**: LLM-based orchestrator routing significantly outperforms semantic routing for specialized domains like legal (64.8% vs 35.2%).

## Florida Legal Domain

### RAG Pipeline

Extracted from FLLawDL2025 (Folio Views NXT format):
- **Extraction**: `scripts/extract-nxt-clean.py` (handles NXT binary format)
- **Chunking**: `scripts/chunk-statutes-structured.py` (statute section detection)
- **Output**: `extracted-statutes/chunks/florida-statutes.jsonl` (7,842 sections)
- **Embedding**: `scripts/embed-statutes.py` (SQLite + ChromaDB)

### Legal Bundle Architecture

6 specialists by function (not domain): Authority, Procedure, Analysis, Drafting, Intake, Ops

```powershell
# Compare routing strategies for Florida legal
.\scripts\benchmark-routing.ps1 `
    -BundleConfig ".\configs\bundles\legal-florida-criminal-bundle.json" `
    -RouterConfigs @(
        ".\configs\routers\legal-florida-criminal-semantic-router.json",
        ".\configs\routers\legal-florida-orchestrator-router.json",
        ".\configs\routers\legal-florida-hierarchical-moe-router.json"
    ) `
    -TestSuite ".\test-suites\legal\florida\florida-criminal.json" `
    -IncludeOracle
```

### Florida Legal Routing Results (54 tests)

| Router | Criminal | Civil | Family | Overall |
|--------|----------|-------|--------|---------|
| Semantic | 38.9% | 44.4% | 22.2% | **35.2%** |
| Orchestrator | 77.8% | 44.4% | 72.2% | **64.8%** |
| Hierarchical MoE | 77.8% | 55.6% | 50.0% | **61.1%** |

**Why legal routing is harder**: Authority vs procedure distinction requires domain knowledge (e.g., "statute of limitations" is a statute lookup, not a deadline question).

## Dependencies

- **Ollama** running locally (http://localhost:11434)
- **nvidia-smi** for GPU metrics
- **PowerShell 5.1+** (Windows built-in) or PowerShell 7+
- **Python 3.8+** for dataset import/embedding:
  ```powershell
  pip install datasets chromadb sentence-transformers
  ```
- **Optional**: OPENAI_API_KEY, ANTHROPIC_API_KEY, GOOGLE_API_KEY for frontier comparison

## Known Issues

- **Dollar sign in prompts**: Use single-quoted here-strings (`@'...'@`) to avoid variable expansion
- **Large prompts**: Windows 8191 char limit; pipe via stdin for larger inputs
- **ANSI escape codes**: May appear in JSON snippets from Ollama responses; strip with regex if needed
- **Parallel execution**: Runspaces share Ollama endpoint; limit parallelism to avoid timeouts

## Current Benchmark Results

See `RESEARCH.md` and `RESEARCH.html` for detailed benchmark analysis. Summary:

- **General Domain (573 tests)**: 82.7% routing accuracy, 95.8% response accuracy
- **Florida Legal (54 tests)**: Semantic 35.2%, Orchestrator 64.8%, MoE 61.1%

Key insight: LLM-based orchestrator routing dramatically outperforms keyword-based semantic routing for specialized domains.
