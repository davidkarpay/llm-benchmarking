# Scripts

PowerShell and Python scripts for LLM benchmarking and Florida legal data processing.

## Benchmarking Scripts (PowerShell)

### Single-Model Tests

| Script | Purpose |
|--------|---------|
| `benchmark-speed.ps1` | Tokens/second, memory usage, GPU utilization |
| `benchmark-cognitive.ps1` | Reasoning, memory, context handling tests |
| `benchmark-vision.ps1` | OCR, object recognition, chart reading |
| `test-context-length.ps1` | Context window stress testing |

### Specialist Bundle Tests

| Script | Purpose |
|--------|---------|
| `benchmark-bundle.ps1` | Test bundle with routing strategy |
| `benchmark-routing.ps1` | Compare routing strategies |
| `compare-frontier.ps1` | Bundle vs frontier model comparison |

### Utilities

| Script | Purpose |
|--------|---------|
| `utils/Export-BenchmarkResult.ps1` | Shared output functions |
| `utils/Invoke-BundleRouter.ps1` | Routing strategy implementations |
| `utils/Invoke-FrontierAPI.ps1` | OpenAI/Anthropic/Google API clients |

## Extraction Scripts (Python)

### NXT Infobase Extraction

| Script | Purpose |
|--------|---------|
| `extract-nxt.py` | Basic extraction with legal pattern matching |
| `extract-nxt-fast.py` | Chunked streaming for large files (240MB+) |
| `extract-nxt-clean.py` | Clean extraction with HTML stripping |

**Usage:**
```bash
python extract-nxt-clean.py input.nxt output.txt [index.md]
```

### Structure-Aware Chunking

| Script | Purpose |
|--------|---------|
| `chunk-statutes-structured.py` | Florida Statutes chunking for RAG |

**Usage:**
```bash
python chunk-statutes-structured.py input.txt output.jsonl --stats stats.json
```

### Embedding & Search

| Script | Purpose |
|--------|---------|
| `embed-statutes.py` | SQLite FTS5 + Ollama semantic embeddings |

**Usage:**
```bash
# Create database with FTS (fast, no embeddings)
python embed-statutes.py embed chunks/florida-statutes.jsonl --skip-embeddings

# Create database with semantic embeddings (slow, requires Ollama)
python embed-statutes.py embed chunks/florida-statutes.jsonl --model nomic-embed-text

# Search using FTS
python embed-statutes.py search "condominium bylaws" --mode fts

# Search using semantic similarity
python embed-statutes.py search "HOA assessment dispute" --mode semantic
```

## Data Models

### `models/florida_statute.py`

Dataclass preserving Florida legal hierarchy:

```
Title (I-XLIX) → Chapter (1-999) → Section (XXX.XXX) → Subsection ((1), (2)) → Paragraph ((a), (b))
```

**Exports:**
- `FloridaStatute` - Main statute section dataclass
- `Subsection` - Nested subsection dataclass
- `extract_cross_references()` - Extract statute/rule/constitutional refs
- `parse_subsections()` - Parse (1), (a), 1. patterns
- `clean_text()` - Remove HTML artifacts
- `get_title_for_chapter()` - Chapter-to-title mapping
- `FLORIDA_TITLES` - Roman numeral title names
- `CROSS_REF_PATTERNS` - Regex patterns for cross-refs

## Dependencies

**Python:**
- Python 3.8+
- Standard library only (no pip dependencies)

**PowerShell:**
- PowerShell 5.1+ or 7+
- Ollama (for model inference)
- nvidia-smi (for GPU metrics)
