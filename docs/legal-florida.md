# Florida Legal Specialist Benchmarks

Guide for running Florida legal domain benchmarks with specialist model bundles.

## Quick Start

```powershell
# Run criminal law benchmark (5 tests, quick validation)
.\scripts\benchmark-bundle-parallel.ps1 `
    -BundleConfig ".\configs\bundles\legal-florida-criminal-bundle.json" `
    -RouterConfig ".\configs\routers\legal-florida-semantic-router.json" `
    -TestSuite ".\test-suites\legal\florida\florida-criminal.json" `
    -MaxTests 5 -Parallelism 2 -SkipPull

# Run full suite for a practice area
.\scripts\benchmark-bundle-parallel.ps1 `
    -BundleConfig ".\configs\bundles\legal-florida-civil-bundle.json" `
    -RouterConfig ".\configs\routers\legal-florida-semantic-router.json" `
    -TestSuite ".\test-suites\legal\florida\florida-civil.json" `
    -Parallelism 4 -SkipPull
```

## Bundle Configurations

Three practice-area bundles available:

| Bundle | File | Specialists | Total Params |
|--------|------|-------------|--------------|
| Criminal | `legal-florida-criminal-bundle.json` | 7 | 61.8B |
| Civil | `legal-florida-civil-bundle.json` | 6 | 54.8B |
| Family | `legal-florida-family-bundle.json` | 6 | 54.8B |

### Specialist Roles

| Role | Model | Purpose |
|------|-------|---------|
| authority | llama3.1:8b | Citations, statutes, rules |
| procedure | qwen2.5:14b | Deadlines, computation, process |
| analysis | qwen2.5:14b | Legal issue analysis, case assessment |
| drafting | mistral:7b-instruct | Motions, pleadings, briefs |
| intake | phi3:3.8b | Client intake, jurisdiction check |
| ops | codellama:7b-instruct | Legal ops automation |
| fallback | qwen2.5:32b | Escalation for complex issues |

## Router Configuration

The router uses intent-based semantic routing:

```
legal-florida-semantic-router.json
```

**Domain Signatures:**
- **authority**: "cite", "Fla. Stat.", "what is the rule"
- **procedure**: "deadline", "how many days", "within"
- **drafting**: "draft", "write a motion", "memorandum"
- **intake**: "new client", "what happened", "jurisdiction"

## RAG Integration

### Python Query Script

```bash
# Search statutes
python scripts/rag/query_fl_statutes.py "speedy trial" --limit 5

# Filter by chapter (e.g., Evidence Code)
python scripts/rag/query_fl_statutes.py "hearsay" --chapter 90

# JSON output for programmatic use
python scripts/rag/query_fl_statutes.py "summary judgment" --format json
```

### PowerShell Functions

```powershell
# Import functions
. .\scripts\utils\Get-FloridaLegalContext.ps1

# Get RAG context
Get-FloridaLegalContext -Query "speedy trial" -Limit 5

# Get chapter-specific context
Get-FloridaChapterContext -Chapter 90 -Query "hearsay"

# Build complete RAG prompt
Get-FloridaRAGPrompt -Query "What is the speedy trial deadline for felonies?"
```

### Database Location

```
extracted-statutes/florida-statutes.db
```

- 7,842 statute sections
- FTS5 full-text search
- Chapters 1-999 (Florida Statutes 2025)

## Test Suites

| Suite | Tests | Topics |
|-------|-------|--------|
| `florida-criminal.json` | 18 | Speedy trial, bail, evidence, sentencing, Stand Your Ground |
| `florida-civil.json` | 18 | Summary judgment, discovery, SOL, service, pleading |
| `florida-family.json` | 18 | Dissolution, custody, support, alimony, relocation |

### Test Format

```json
{
  "id": "fl-crim-001",
  "prompt": "What is the speedy trial deadline for a felony in Florida?",
  "expected_specialist": "fl-crim-procedure",
  "expected_response_contains": ["175", "days", "3.191"],
  "difficulty": "easy",
  "tags": ["speedy-trial", "felony", "deadline"]
}
```

## Prompt Contracts

Prompt contracts enforce guardrails:

| Contract | Key Rules |
|----------|-----------|
| `authority-contract.md` | H-FL-001: cite-or-decline, never fabricate |
| `procedure-contract.md` | Must cite rule number, compute deadlines |
| `analysis-contract.md` | H-FL-020: Pardo statewide binding |
| `drafting-contract.md` | Use `[CITATION NEEDED]` placeholders |
| `intake-contract.md` | H-FL-008: require locality for ordinances |

### System Prompts

```powershell
# Import prompts module
. .\prompts\legal\florida\system-prompts.ps1

# Get specialist prompt
$prompt = Get-FloridaSystemPrompt -SpecialistType "authority"

# Build RAG-augmented prompt
$ragPrompt = Get-FloridaRAGPrompt -Context $context -Query $userQuery
```

## Heuristics Reference

Key Florida legal heuristics implemented:

| ID | Name | Description |
|----|------|-------------|
| H-FL-001 | Cite-or-Decline | Never fabricate citations |
| H-FL-002 | Court Explicit | Always specify court and district |
| H-FL-004 | Hierarchy First | Apply authority hierarchy before analysis |
| H-FL-005 | DCA Conflict Flag | Explicitly flag inter-district conflicts |
| H-FL-008 | Ordinance Locality | Never provide ordinance info without locality |
| H-FL-019 | No Intra-District | Supreme Court jurisdiction limited to inter-district |
| H-FL-020 | Pardo Binding | DCA decisions bind all FL trial courts statewide |
| H-FL-021 | No Agency Deference | Art. V, Sec. 21 requires de novo interpretation |

## Results Directory

```
results/raw/
  2026-01-06_*_bundle_benchmark_parallel_legal-florida-*.json
```

## Troubleshooting

**Low routing accuracy?**
- Router signatures may need tuning for specific legal terminology
- Check `legal-florida-semantic-router.json` domain signatures

**Unicode errors on Windows?**
- The RAG script has been patched for Windows console encoding
- If issues persist, use `--format json` output

**Models not found?**
- Run without `-SkipPull` to pull required models
- Verify models with `ollama list`

## Next Steps

1. **Tune Router**: Add more Florida-specific keywords to domain signatures
2. **Expand Tests**: Add tests for local rules, ethics, appeals
3. **RAG Augmentation**: Enable RAG by default for authority specialists
4. **Evidence Code**: Re-extract Chapter 90 for complete coverage
