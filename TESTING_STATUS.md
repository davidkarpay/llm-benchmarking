# Testing Status - LLM Benchmarking Suite

**Last Updated**: 2026-01-03
**Machine**: TITAN
**Current Session Operator**: David (user)

---

## Research Framework Status (Bundle Benchmarking)

A new research framework has been implemented to test the hypothesis that **specialist model bundles can compete with frontier models** through intelligent routing.

### Implementation Status

| Phase | Description | Status |
|-------|-------------|--------|
| **Phase 1** | Foundation (schemas, configs, bundle benchmark script) | ✅ Complete |
| **Phase 2** | Routing strategies (all 5 strategies + comparison script) | ✅ Complete |
| **Phase 3** | Florida domain specialization (legal/medical test suites) | ⏳ Pending User Data |
| **Phase 4** | Frontier comparison (API clients, compare script) | ✅ Complete |
| **Phase 5** | Advanced features (ensemble voting, templates) | ✅ Partial (dashboard pending) |

### Files Created This Session

**Schemas:**
- `schemas/bundle-config.schema.json` - Bundle definition schema
- `schemas/router-config.schema.json` - Routing strategy schema
- `schemas/test-suite.schema.json` - Test case format schema
- `schemas/benchmark-result.schema.json` - Extended with bundle/routing fields

**Configs:**
- `configs/bundles/general-bundle.json` - 5-specialist general bundle (39.8B total)
- `configs/bundles/legal-florida-bundle.json` - Placeholder for FL specialists
- `configs/routers/semantic-router.json` - Keyword-based routing
- `configs/routers/classifier-router.json` - LLM classifier routing
- `configs/routers/orchestrator-router.json` - LLM orchestrator routing
- `configs/routers/hierarchical-moe-router.json` - MoE-style gating
- `configs/frontiers.json` - Frontier API endpoints and benchmark scores

**Scripts:**
- `scripts/benchmark-bundle.ps1` - Main bundle benchmark
- `scripts/benchmark-routing.ps1` - Routing strategy comparison
- `scripts/compare-frontier.ps1` - Frontier model comparison
- `scripts/utils/Invoke-BundleRouter.ps1` - All routing strategies (~730 lines)
- `scripts/utils/Invoke-FrontierAPI.ps1` - OpenAI/Anthropic/Google clients

**Test Suites:**
- `test-suites/general/reasoning.json` - 5 logic/math cases
- `test-suites/general/knowledge.json` - 7 factual cases
- `test-suites/general/code.json` - 6 programming cases
- `test-suites/general/creative.json` - 5 writing cases
- `test-suites/_templates/legal-template.json` - Jurisdiction-agnostic legal template
- `test-suites/_templates/medical-template.json` - Jurisdiction-agnostic medical template

### Phase 3 - Pending User Data

User will provide Florida-specific data for domain specialist test suites:
- Florida Evidence Code
- Florida Civil Procedure
- Florida Criminal Procedure
- Jurisdictional/Local Rules
- Rules Governing the Bar
- Florida Statutes
- Decisional law (FL Supreme Court, SCOTUS, FL DCAs)

**Expected output:** `test-suites/legal/florida/` with 50+ test cases

### Outstanding Work

- [ ] Dashboard extensions for bundle comparison visualization
- [ ] Florida domain test suites (pending user data)
- [ ] Train/fine-tune actual specialist models (LoRA/QLoRA)
- [ ] Run baseline bundle benchmarks

---

## Previous Session (Not David)

**Operator**: David Karpay
**Date**: 2026-01-02
**Comprehensive Report**: `results/reports/2026-01-02_comprehensive_benchmark_report.md`

### Tests Completed by David Karpay

| Test | Models Tested | Key Findings |
|------|---------------|--------------|
| Speed Benchmark | llama3.1:8b, qwen2.5:14b, qwen2.5:32b, gpt-oss:120b | qwen2.5:14b optimal (55 tok/s, 100% GPU) |
| Cognitive Benchmark | gpt-oss:120b | 5/6 passed (selective forgetting had script bug) |
| Context Stress Test | gpt-oss:120b | Effective context ~2K tokens (severe degradation beyond) |

### Critical Bug Found
- **Selective Forgetting Test**: PowerShell variable interpolation bug caused `$8.3 million` to become `.3 million`
- **Root Cause**: `$8` is a PowerShell automatic variable (regex capture group)
- **Status**: FIXED in current session

---

## Current Session Progress (2026-01-03)

### Tests Completed This Session

| Timestamp | Test | Models | Results |
|-----------|------|--------|---------|
| 00:45:11 | Cognitive | llama3.1:8b | 6/6 PASS |
| 00:45:35 | Cognitive | qwen2.5:14b | 6/6 PASS |
| 00:47:22 | Cognitive | qwen2.5:32b | 6/6 PASS |
| 01:06:56 | Cognitive (forgetting only) | gpt-oss:120b | PASS (re-test after bug fix) |
| 01:07:50 | Cognitive (forgetting only) | gpt-oss:120b | PASS (confirmation) |
| 01:27:51 | Vision | moondream | 0/6 (syntax issue) |
| 01:30:28 | Vision | moondream | 0/6 (syntax issue) |
| 01:33:02 | Vision | llava:7b | 2/6 PASS |

### Bug Fixes Applied

1. **Selective Forgetting Test** (`benchmark-cognitive.ps1:357-367`)
   - Changed from double-quoted here-string (`@"..."@`) to single-quoted (`@'...'@`)
   - Prevents PowerShell variable interpolation of `$8.3`

2. **Vision Benchmark Image Syntax** (`benchmark-vision.ps1`)
   - Fixed `--image` flag (not supported) to inline path in prompt
   - Ollama expects: `ollama run model "prompt /path/to/image.png"`

### New Features Added

1. **Vision Benchmark Suite** (`scripts/benchmark-vision.ps1`)
   - OCR (clear and small text)
   - Object counting (shapes)
   - Color recognition
   - Spatial reasoning
   - Chart reading
   - Auto-generates test images using .NET System.Drawing

---

## Current Test Coverage

### Cognitive Benchmarks

| Model | Needle | Multi-Hop | Memory-10 | Memory-30 | Temporal | Forgetting | Total |
|-------|--------|-----------|-----------|-----------|----------|------------|-------|
| llama3.1:8b | PASS | 100% | 100% | 100% | PASS | PASS | **6/6** |
| qwen2.5:14b | PASS | 100% | 100% | 100% | PASS | PASS | **6/6** |
| qwen2.5:32b | PASS | 100% | 100% | 100% | PASS | PASS | **6/6** |
| gpt-oss:120b | PASS | 100% | 100% | 100% | PASS | PASS* | **6/6** |

*Re-tested after bug fix

### Vision Benchmarks

| Model | OCR-Clear | OCR-Small | Counting | Colors | Spatial | Chart | Total |
|-------|-----------|-----------|----------|--------|---------|-------|-------|
| llava:7b | FAIL | FAIL | Partial | PASS | PASS | Partial | **2/6** |

### Context Stress Tests

| Model | 2K | 8K | 16K | 32K | 64K |
|-------|----|----|-----|-----|-----|
| gpt-oss:120b | PASS | FAIL | FAIL | FAIL | FAIL |

---

## Pending Tests

### Not Yet Run
- [ ] Vision benchmark on additional models (llava:13b, qwen2.5vl:7b, minicpm-v)
- [ ] Context stress tests on smaller models
- [ ] Speed benchmark on vision models

### Recommended Next Steps
1. Run vision benchmark on `llava:13b` for better OCR accuracy
2. Test `deepseek-r1:70b` for advanced reasoning (recommended for "ChatGPT Pro" level)
3. Pull and test `qwq:32b` (Alibaba's reasoning model)

---

## Models Available on System

```
NAME            SIZE
gpt-oss:120b    65 GB
qwen2.5:32b     19 GB
qwen2.5:14b     9.0 GB
llama3.1:8b     4.9 GB
gpt-oss:20b     13 GB
moondream       1.8 GB
llava:7b        4.7 GB
```

---

## File Manifest

### Result Files from Previous Session (David Karpay)
- `results/raw/2026-01-02_005430_speed_benchmark.json`
- `results/raw/2026-01-02_010135_cognitive_benchmark.json`
- `results/raw/2026-01-02_010357_context_stress.json`
- `results/raw/2026-01-02_011451_context_stress.json`
- `results/reports/2026-01-02_comprehensive_benchmark_report.md`

### Result Files from Current Session
- `results/raw/2026-01-03_004511_cognitive_benchmark.json` (llama3.1:8b)
- `results/raw/2026-01-03_004535_cognitive_benchmark.json` (qwen2.5:14b)
- `results/raw/2026-01-03_004722_cognitive_benchmark.json` (qwen2.5:32b)
- `results/raw/2026-01-03_010656_cognitive_benchmark.json` (gpt-oss:120b forgetting re-test)
- `results/raw/2026-01-03_010750_cognitive_benchmark.json` (gpt-oss:120b confirmation)
- `results/raw/2026-01-03_013302_vision_benchmark.json` (llava:7b)
