# LLM Benchmarking Suite

Comprehensive benchmarking framework for local LLM inference via Ollama, with a research focus on specialist model bundles competing against frontier models.

## Overview

This suite tests four dimensions of LLM capability:

1. **Hardware Performance** - Speed, memory usage, GPU/CPU utilization
2. **Cognitive Capabilities** - Understanding, memory, reasoning, following corrections
3. **Vision Capabilities** - OCR, object counting, color recognition, chart reading
4. **Specialist Bundles** - Domain-specific model ensembles with intelligent routing

## Research Hypothesis

**Can bundles of small post-trained (LoRA/QLoRA) specialist models compete with or outperform frontier models through intelligent routing and domain specialization?**

Target frontier models for comparison:
- GPT-5.2 Pro, GPT-4o
- Claude Opus 4.5, Claude Sonnet 4
- Gemini 3 Pro, Gemini 2 Flash
- Grok 4, Llama 4, DeepSeek-R1, Mistral Large 2, Qwen 3

## Quick Start

```powershell
cd C:\Users\14104\llm-benchmarks

# Run speed benchmarks across multiple models
.\scripts\benchmark-speed.ps1

# Run cognitive tests on a specific model
.\scripts\benchmark-cognitive.ps1 -Model "gpt-oss:120b"

# Run vision tests on vision-capable models
.\scripts\benchmark-vision.ps1

# Test context length limits
.\scripts\test-context-length.ps1

# --- Bundle Benchmarking (New) ---

# Run bundle benchmark with routing
.\scripts\benchmark-bundle.ps1 -BundleConfig configs/bundles/general-bundle.json `
    -RouterConfig configs/routers/semantic-router.json `
    -TestSuite test-suites/general/reasoning.json

# Compare routing strategies
.\scripts\benchmark-routing.ps1 -BundleConfig configs/bundles/general-bundle.json `
    -RouterConfigs @("configs/routers/semantic-router.json", "configs/routers/classifier-router.json") `
    -TestSuite test-suites/general/reasoning.json

# Compare bundle vs frontier models
.\scripts\compare-frontier.ps1 -BundleConfig configs/bundles/general-bundle.json `
    -FrontierAPIs @("openai", "anthropic") `
    -TestSuite test-suites/general/knowledge.json
```

## Directory Structure

```
llm-benchmarks/
├── scripts/
│   ├── benchmark-speed.ps1         # Hardware speed tests
│   ├── benchmark-cognitive.ps1     # Cognitive capability tests
│   ├── benchmark-vision.ps1        # Vision capability tests
│   ├── test-context-length.ps1     # Context window stress test
│   ├── benchmark-bundle.ps1        # Bundle benchmark (NEW)
│   ├── benchmark-routing.ps1       # Routing strategy comparison (NEW)
│   ├── compare-frontier.ps1        # Frontier model comparison (NEW)
│   └── utils/
│       ├── Export-BenchmarkResult.ps1    # Shared output functions
│       ├── Invoke-BundleRouter.ps1       # Routing utilities (NEW)
│       └── Invoke-FrontierAPI.ps1        # Frontier API clients (NEW)
├── configs/
│   ├── bundles/                    # Bundle configuration files
│   │   ├── general-bundle.json
│   │   └── legal-florida-bundle.json
│   ├── routers/                    # Routing strategy configs
│   │   ├── semantic-router.json
│   │   ├── classifier-router.json
│   │   ├── orchestrator-router.json
│   │   └── hierarchical-moe-router.json
│   └── frontiers.json              # Frontier API/benchmark config
├── test-suites/
│   ├── _templates/                 # Jurisdiction-agnostic templates
│   │   ├── legal-template.json
│   │   └── medical-template.json
│   └── general/                    # General domain test cases
│       ├── reasoning.json
│       ├── knowledge.json
│       ├── code.json
│       └── creative.json
├── test-assets/
│   └── vision/
│       ├── generated/              # Auto-generated test images
│       └── static/                 # Pre-bundled test images
├── results/
│   ├── raw/                        # JSON (machine-readable)
│   ├── csv/                        # Tabular data
│   └── reports/                    # Markdown reports
├── schemas/
│   ├── benchmark-result.schema.json    # Main result schema
│   ├── bundle-config.schema.json       # Bundle definition (NEW)
│   ├── router-config.schema.json       # Router config (NEW)
│   └── test-suite.schema.json          # Test suite format (NEW)
└── README.md
```

## Output Formats

| Format | Location | Purpose |
|--------|----------|---------|
| JSON | `results/raw/*.json` | Machine-readable, schema-validated |
| CSV | `results/csv/*.csv` | Spreadsheet/pandas analysis |
| Console | Terminal | Real-time feedback |

## Benchmark Tests

### Hardware Tests (`benchmark-speed.ps1`)

Tests inference speed across model sizes:

| Metric | Description |
|--------|-------------|
| Tokens/second | Generation speed |
| GPU% | Model layers on GPU |
| VRAM Used | GPU memory consumption |
| Total Time | End-to-end response time |

**Speed Grades:**
- **A**: >30 tok/s (Interactive - real-time chat)
- **B**: 10-30 tok/s (Usable - slight delay)
- **C**: 3-10 tok/s (Slow - noticeable wait)
- **D**: <3 tok/s (Batch only - background tasks)

### Cognitive Tests (`benchmark-cognitive.ps1`)

| Test | Purpose | Pass Criteria |
|------|---------|---------------|
| Needle-in-Haystack | Information retrieval | Find exact phrase |
| Multi-Hop Reasoning | Connect facts across context | 3+/4 correct |
| Working Memory (10) | Track 10 entities | 5/5 correct |
| Working Memory (30) | Track 30 entities | 8/10 correct |
| Temporal Reasoning | Order events correctly | Exact sequence |
| Selective Forgetting | Follow corrections | Use updated info |

### Vision Tests (`benchmark-vision.ps1`)

Tests vision model capabilities with auto-generated test images:

| Test | Purpose | Pass Criteria |
|------|---------|---------------|
| OCR (Clear) | Read large clear text | Exact match |
| OCR (Small) | Read smaller text | Exact match |
| Counting | Count colored shapes | Correct counts |
| Colors | Identify colors in order | All 4 correct |
| Spatial | Understand positions | Correct location |
| Chart | Extract data from bar chart | Month + value |

**Default Models:** llava:7b, llava:13b, moondream

### Context Stress Test (`test-context-length.ps1`)

Tests performance at increasing context lengths:
- 2K, 8K, 16K, 32K, 64K tokens (configurable)
- Measures time degradation
- Tests recall accuracy ("lost in the middle" effect)

---

## Specialist Bundle Benchmarks (Research Framework)

### Core Concept

A **bundle** is a collection of domain-specialist models that work together through intelligent routing. Instead of one large general-purpose model, queries are routed to the most appropriate small specialist.

```
Query → Router → [Specialist Selection] → Response
                         ↓
           ┌─────────────┼─────────────┐
           │             │             │
    Code Expert   Reasoning Expert   Knowledge Expert
      (7B)           (14B)              (8B)
```

### Bundle Benchmark (`benchmark-bundle.ps1`)

Tests a bundle configuration end-to-end:

```powershell
.\scripts\benchmark-bundle.ps1 `
    -BundleConfig configs/bundles/general-bundle.json `
    -RouterConfig configs/routers/semantic-router.json `
    -TestSuite test-suites/general/reasoning.json `
    -SkipPull  # Use existing models
```

**Metrics collected:**
- Routing accuracy (did it pick the right specialist?)
- Routing latency (ms overhead)
- Inference latency
- Response quality score
- Cost efficiency (active parameters per query)

### Routing Strategies

| Strategy | Description | Speed | Accuracy |
|----------|-------------|-------|----------|
| **Semantic** | Keyword/embedding matching | Fastest | Good for clear domains |
| **Classifier** | Small model predicts domain | Fast | High for trained domains |
| **Orchestrator** | LLM analyzes and routes | Medium | Best for ambiguous queries |
| **Hierarchical MoE** | Top-K gating, weighted combination | Slowest | Best for complex queries |
| **Ensemble** | Multiple strategies vote | Variable | Most robust |

### Routing Comparison (`benchmark-routing.ps1`)

Compare routing strategies head-to-head:

```powershell
.\scripts\benchmark-routing.ps1 `
    -BundleConfig configs/bundles/general-bundle.json `
    -RouterConfigs @(
        "configs/routers/semantic-router.json",
        "configs/routers/classifier-router.json",
        "configs/routers/orchestrator-router.json"
    ) `
    -TestSuite test-suites/general/knowledge.json `
    -IncludeOracle  # Include perfect routing baseline
```

**Outputs:**
- Per-router accuracy
- Agreement matrix (which routers agree?)
- Latency comparison
- Oracle gap (how far from perfect routing?)

### Frontier Comparison (`compare-frontier.ps1`)

Compare bundle performance against frontier models:

```powershell
# Live API comparison (requires API keys)
.\scripts\compare-frontier.ps1 `
    -BundleConfig configs/bundles/general-bundle.json `
    -FrontierAPIs @("openai", "anthropic") `
    -TestSuite test-suites/general/reasoning.json

# Use published benchmarks as proxy
.\scripts\compare-frontier.ps1 `
    -BundleConfig configs/bundles/general-bundle.json `
    -TestSuite test-suites/general/reasoning.json `
    -UsePublishedBenchmarks
```

**Comparison metrics:**
- Quality delta (bundle vs frontier)
- Cost ratio (tokens pricing vs VRAM-hours)
- Latency comparison
- Win rate by category

### Creating Bundles

Bundle configuration example (`configs/bundles/general-bundle.json`):

```json
{
  "name": "general-purpose-bundle",
  "specialists": [
    {
      "id": "code-specialist",
      "model": "codellama:7b",
      "domains": ["programming"],
      "size_class": "small",
      "keywords": ["code", "function", "bug", "implement"]
    },
    {
      "id": "reasoning-specialist",
      "model": "qwen2.5:14b",
      "domains": ["reasoning", "logic"],
      "size_class": "medium"
    }
  ],
  "ensemble_strategy": "single",
  "overlap_handling": "confidence_weighted"
}
```

### Test Suite Format

Test suites specify queries with expected routing:

```json
{
  "domain": "general",
  "cases": [
    {
      "id": "test-001",
      "prompt": "What is the time complexity of quicksort?",
      "expected_specialist": "code-specialist",
      "expected_response_contains": ["O(n log n)", "average"],
      "difficulty": "medium"
    }
  ]
}
```

---

## Usage Examples

### Custom Model Set
```powershell
.\scripts\benchmark-speed.ps1 -Models @("llama3.1:8b", "mistral:7b")
```

### Specific Cognitive Tests
```powershell
.\scripts\benchmark-cognitive.ps1 -Tests @("needle", "multihop") -Model "qwen2.5:32b"
```

### Custom Context Sizes
```powershell
.\scripts\test-context-length.ps1 -Sizes @(1000, 5000, 10000, 20000)
```

### Skip Model Download
```powershell
.\scripts\benchmark-speed.ps1 -SkipPull
```

### Vision Tests with Specific Models
```powershell
.\scripts\benchmark-vision.ps1 -Models @("llava:13b", "qwen2.5vl:7b")
```

### Run Only OCR Vision Tests
```powershell
.\scripts\benchmark-vision.ps1 -Tests @("ocr_clear", "ocr_small")
```

### Regenerate Vision Test Images
```powershell
.\scripts\benchmark-vision.ps1 -RegenerateImages
```

## JSON Schema

Results conform to `schemas/benchmark-result.schema.json`. Validate with:

```powershell
# PowerShell 7+
$schema = Get-Content .\schemas\benchmark-result.schema.json | ConvertFrom-Json
$result = Get-Content .\results\raw\<file>.json | ConvertFrom-Json
# Manual validation or use a JSON schema validator
```

## Interpreting Results

### Hardware Results

**Good setup for interactive use:**
- Model fits in VRAM (100% GPU)
- >15 tok/s generation speed
- <5s time to first token

**Acceptable for async/batch:**
- Partial CPU offload OK
- 3-10 tok/s acceptable
- Model runs without OOM errors

### Cognitive Results

**Red flags:**
- Needle-in-Haystack fails at short contexts
- Multi-hop reasoning <50% accuracy
- Working memory degrades below 10 entities

**Expected behavior:**
- Recall degrades in middle of long contexts
- Memory accuracy drops with entity count
- Larger models generally perform better

## Hardware Requirements

Tested on:
- **GPU**: NVIDIA RTX A4500 (20GB VRAM)
- **RAM**: 128GB system memory
- **Storage**: NVMe SSD (fast model loading)

Minimum recommended:
- 16GB+ VRAM for 32B models at full GPU
- 64GB+ RAM for CPU offloading of 70B+ models
- SSD for reasonable model loading times

## Environment Variables (for Frontier Comparison)

Set these for live API comparison with frontier models:

```powershell
$env:OPENAI_API_KEY = "sk-..."
$env:ANTHROPIC_API_KEY = "sk-ant-..."
$env:GOOGLE_API_KEY = "..."
```

Without API keys, use `-UsePublishedBenchmarks` flag for proxy comparison.

## Troubleshooting

### "Out of memory" errors
- Reduce model size or try higher quantization (Q4 vs Q8)
- Close other GPU applications
- Check `nvidia-smi` for memory usage

### Slow inference
- Check `ollama ps` for CPU/GPU split
- Reduce context length
- Try different quantization levels

### Tests failing unexpectedly
- Verify model is fully loaded (`ollama ps`)
- Check for model-specific prompt format requirements
- Some models need specific system prompts

## Contributing

To add new tests:
1. Add test function to appropriate benchmark script
2. Update results schema if new metrics needed
3. Add test to README documentation

## License

MIT - Use freely for personal and commercial purposes.

---
*Generated by LLM Benchmarking Suite v1.0*
