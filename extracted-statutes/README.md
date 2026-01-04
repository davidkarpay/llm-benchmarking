# Florida Legal Text Extractions

Text extracted from FLLawDL2025 (Folio Views NXT infobases) for RAG ingestion.

## Source

**FLLawDL2025** - Official Florida legal database distributed by Florida Legislature in Folio Views/Rocket Software NXT format.

## Files

| File | Size | Description |
|------|------|-------------|
| `florida-statutes-2025-clean.txt` | 53MB | Cleaned extracted statutes text |
| `florida-statutes-2025.txt` | 9.5MB | Raw extraction (includes artifacts) |
| `florida-constitution-2025.txt` | 337KB | Florida Constitution |
| `laws-of-florida-2025.txt` | 8.8MB | Session laws |
| `chunks/florida-statutes.jsonl` | 22MB | 7,842 structured chunks |
| `chunks/stats.json` | 516B | Chunking statistics |
| `florida-statutes.db` | - | SQLite FTS5 database for search |

## Chunk Schema

Each JSONL line contains a `FloridaStatute` chunk:

```json
{
  "id": "fla-stat-718-112",
  "type": "statute_section",
  "citation": "Fla. Stat. § 718.112 (2025)",
  "hierarchy": {
    "title": {"number": "XL", "name": "REAL AND PERSONAL PROPERTY"},
    "chapter": {"number": "718", "name": ""},
    "section": {"number": "718.112", "title": "Bylaws"}
  },
  "content": "...",
  "subsections": [
    {"number": "(1)", "text": "...", "parent": null}
  ],
  "cross_refs": {
    "statutes": ["§ 720.301", "ch. 617"],
    "rules": [],
    "constitution": ["Fla. Const. art. I, § 2"]
  },
  "content_hash": "a1b2c3...",
  "tokens": 847
}
```

## Statistics (from stats.json)

- **Total blocks processed**: 19,489
- **Parsed sections**: 7,842
- **Unique chapters**: 586
- **Statute cross-references**: 22,423
- **Constitutional references**: 21
- **Average tokens per chunk**: 406
- **Total tokens**: 3,184,809

## Extraction Scripts

See `scripts/` directory:
- `extract-nxt-clean.py` - Primary extraction script
- `chunk-statutes-structured.py` - Structure-aware chunking
- `models/florida_statute.py` - Dataclass definition

## Usage

```bash
# Re-extract from source NXT files
python scripts/extract-nxt-clean.py path/to/fs2025.nxt extracted-statutes/florida-statutes.txt

# Re-chunk extracted text
python scripts/chunk-statutes-structured.py \
    extracted-statutes/florida-statutes-2025-clean.txt \
    extracted-statutes/chunks/florida-statutes.jsonl \
    --stats extracted-statutes/chunks/stats.json
```
