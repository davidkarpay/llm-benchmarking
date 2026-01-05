# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

PowerShell-based LLM benchmarking suite with **two primary purposes**:

1. **Single-Model Testing**: Hardware performance (speed, memory) and cognitive capabilities (reasoning, memory, context handling) for individual models via Ollama.

2. **Specialist Bundle Research**: Testing the hypothesis that bundles of small post-trained (LoRA/QLoRA) specialist models can compete with frontier models through intelligent routing and domain specialization.

## Research Hypothesis

**Core Question**: Can bundles of small specialist models (7B-14B each) outperform or compete with frontier models (GPT-4.5, Claude Opus 4.5, Gemini 3 Pro) through intelligent routing?

**Approach**: Test multiple routing strategies, model sizes, and bundle configurations against standardized test suites and frontier model baselines.

## Commands

### Single-Model Benchmarks (Original)

```powershell
# Speed benchmarks
.\scripts\benchmark-speed.ps1 -Models @("llama3.1:8b", "qwen2.5:32b")

# Cognitive tests
.\scripts\benchmark-cognitive.ps1 -Model "gpt-oss:120b"
.\scripts\benchmark-cognitive.ps1 -Tests @("needle", "multihop") -Model "qwen2.5:32b"

# Vision tests
.\scripts\benchmark-vision.ps1 -Models @("llava:7b")

# Context stress test
.\scripts\test-context-length.ps1 -Sizes @(1000, 5000, 10000, 20000)
```

### Specialist Bundle Benchmarks (New)

```powershell
# Test a bundle with a routing strategy
.\scripts\benchmark-bundle.ps1 `
    -BundleConfig ".\configs\bundles\general-bundle.json" `
    -RouterConfig ".\configs\routers\semantic-router.json" `
    -TestSuite ".\test-suites\general"

# Compare routing strategies head-to-head
.\scripts\benchmark-routing.ps1 `
    -BundleConfig ".\configs\bundles\general-bundle.json" `
    -RouterConfigs @(".\configs\routers\semantic-router.json", ".\configs\routers\classifier-router.json", ".\configs\routers\orchestrator-router.json") `
    -TestSuite ".\test-suites\general" `
    -IncludeOracle

# Compare bundle vs frontier (published benchmarks)
.\scripts\compare-frontier.ps1 `
    -BundleConfig ".\configs\bundles\general-bundle.json" `
    -UsePublishedBenchmarks

# Compare bundle vs frontier (live API - requires API keys)
.\scripts\compare-frontier.ps1 `
    -BundleConfig ".\configs\bundles\general-bundle.json" `
    -FrontierModels @("openai:gpt-4o-mini", "anthropic:claude-haiku-3.5") `
    -TestSuite ".\test-suites\general" `
    -MaxTestCases 10
```

## Architecture

### Directory Structure

```
llm-benchmarks/
├── scripts/
│   ├── benchmark-speed.ps1         # Single-model speed tests
│   ├── benchmark-cognitive.ps1     # Single-model cognitive tests
│   ├── benchmark-vision.ps1        # Vision model tests
│   ├── test-context-length.ps1     # Context window stress
│   ├── benchmark-bundle.ps1        # NEW: Bundle benchmark
│   ├── benchmark-routing.ps1       # NEW: Router comparison
│   ├── compare-frontier.ps1        # NEW: Bundle vs frontier
│   └── utils/
│       ├── Export-BenchmarkResult.ps1   # Shared output functions
│       ├── Invoke-BundleRouter.ps1      # NEW: Routing strategies
│       └── Invoke-FrontierAPI.ps1       # NEW: Frontier API clients
├── configs/
│   ├── bundles/                    # Bundle definitions
│   ├── routers/                    # Routing strategy configs
│   └── frontiers.json              # API endpoints + published scores
├── test-suites/
│   ├── _templates/                 # Jurisdiction-agnostic templates
│   └── general/                    # General domain tests (23 cases)
├── schemas/                        # JSON schemas for validation
└── results/
```

### Utility Modules

**Export-BenchmarkResult.ps1**:
- `Get-HardwareProfile`, `Export-JsonResult`, `Export-CsvResult`, `Get-SpeedGrade`

**Invoke-BundleRouter.ps1** (NEW):
- `Invoke-SemanticRoute`: Keyword/signature matching
- `Invoke-ClassifierRoute`: Small model classification
- `Invoke-OrchestratorRoute`: LLM-based routing
- `Invoke-HierarchicalMoERoute`: Token-level gating
- `Invoke-EnsembleRoute`: Multi-strategy voting
- `Get-RoutingDecision`: Main dispatcher

**Invoke-FrontierAPI.ps1** (NEW):
- `Invoke-OpenAICompletion`, `Invoke-AnthropicCompletion`, `Invoke-GoogleCompletion`
- `Get-PublishedBenchmarkScores`: MMLU, HumanEval, GPQA, etc.

## Routing Strategies

| Strategy | Speed | Accuracy | Use Case |
|----------|-------|----------|----------|
| semantic | Fast | Medium | Simple domain matching |
| classifier | Medium | High | When training data available |
| orchestrator | Slow | Highest | Complex/ambiguous queries |
| hierarchical_moe | Slowest | Variable | Multi-expert queries |
| ensemble | Slowest | Best | Critical applications |

## Current State (2026-01-05)

### Benchmark Results (573-Test Suite)

| Metric | Value | Notes |
|--------|-------|-------|
| **Routing Accuracy** | 82.7% | Semantic router with improved signatures |
| **Response Accuracy** | 95.8% | Specialists perform well even with imperfect routing |
| **Test Cases** | 573 | Statistically significant (±3.3% margin at 95% CI) |
| **Avg Active Params** | 9.2B | vs 39.8B total bundle |

### Routing Failure Analysis
- **Knowledge ↔ Reasoning overlap**: ~56 failures (CS/physics questions are ambiguous)
- **Knowledge → Code**: 22 failures (MMLU CS looks like code questions)
- Remaining ~17% failures are inherently ambiguous cases

### Expanded Test Suite Infrastructure

```powershell
# Import public datasets from HuggingFace (3,378 tests)
python scripts/import-datasets.py

# Generate mixed benchmark suite (573 tests across all domains)
python scripts/create-mixed-suite.py

# Run parallel benchmark (4x faster than sequential)
.\scripts\benchmark-bundle-parallel.ps1 `
    -BundleConfig ".\configs\bundles\general-bundle.json" `
    -RouterConfig ".\configs\routers\semantic-router.json" `
    -TestSuite ".\test-suites\mixed\mixed-benchmark.json" `
    -Parallelism 4

# Analyze routing failures
.\scripts\analyze-routing-failures.ps1

# Aggregate results across multiple runs
.\scripts\aggregate-results.ps1 -ResultDir "results/raw" -ShowDetails
```

### Test Suite Breakdown
| Domain | Tests | Source | Expected Specialist |
|--------|-------|--------|---------------------|
| Reasoning | 150 | GSM8K | reasoning-specialist |
| Code | 150 | HumanEval | code-specialist |
| Knowledge | 150 | MMLU-Pro | knowledge-specialist |
| Science | 100 | ARC | knowledge-specialist |
| General | 23 | Hand-crafted | Mixed |

### New Utility Scripts
| Script | Purpose |
|--------|---------|
| `scripts/benchmark-bundle-parallel.ps1` | Parallel test execution using runspaces |
| `scripts/import-datasets.py` | Import GSM8K, HumanEval, ARC, MMLU from HuggingFace |
| `scripts/create-mixed-suite.py` | Generate mixed benchmark suite |
| `scripts/aggregate-results.ps1` | Multi-run statistical aggregation |
| `scripts/analyze-routing-failures.ps1` | Routing failure breakdown |
| `scripts/utils/Get-BenchmarkStats.ps1` | Statistical functions (mean, stddev, CI) |
| `scripts/utils/Get-SemanticSimilarity.ps1` | Embedding-based similarity scoring |

### Florida Legal RAG Pipeline
- **Source**: FLLawDL2025 (Folio Views NXT infobases)
- **Extracted**: 72MB text (Constitution, Statutes, Laws of Florida)
- **Chunked**: 7,842 statute sections in structured JSONL
- **Location**: `extracted-statutes/chunks/florida-statutes.jsonl`

### Key Learnings
1. **Semantic routing works**: 82.7% accuracy with keyword/signature matching
2. **Response accuracy > routing accuracy**: Specialists handle queries well even when misrouted
3. **Domain overlap is the main challenge**: CS knowledge vs code, physics vs math reasoning
4. **500+ tests needed**: Provides statistical confidence for benchmark results
5. **Parallel execution essential**: 4 workers = ~4x throughput for large test suites

### Next Steps
1. Implement ML-based classifier router for higher accuracy
2. Embed Florida statute chunks to ChromaDB
3. Create FL legal specialist bundle
4. Test retrieval with Authority Pack prompts

---

## Phase 3 Florida Data (Completed)

Florida legal domain data has been extracted and chunked:
- Florida Evidence Code (Chapter 90)
- Florida Rules of Civil Procedure
- Florida Rules of Criminal Procedure
- Florida Statutes (7,842 sections)
- Florida/Federal case law references

Template format in `test-suites/_templates/legal-template.json`

## Output Schema

Results conform to `schemas/benchmark-result.schema.json`:
- Categories: hardware, cognitive, vision, bundle, routing, frontier_comparison
- Bundle results include: bundle_config, routing, frontier_comparison, cost_efficiency

## Dashboard

`index.html` provides a web dashboard:
```powershell
python -m http.server 8000
```

## Dependencies

- Ollama (models available)
- nvidia-smi (GPU metrics)
- PowerShell 5.1+ or 7+
- Optional: OPENAI_API_KEY, ANTHROPIC_API_KEY, GOOGLE_API_KEY for frontier comparison

## Known Issues

- **Dollar sign in prompts**: Use single-quoted here-strings (`@'...'@`)
- **Large prompts**: Windows 8191 char limit; use stdin piping
- **ANSI escape codes**: May pollute JSON response snippets
