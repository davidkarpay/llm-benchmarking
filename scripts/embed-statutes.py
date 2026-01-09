#!/usr/bin/env python3
"""
Embed Florida Statute chunks into a SQLite FTS5 database with Ollama embeddings.

Uses built-in SQLite full-text search + Ollama for semantic embeddings.
No external dependencies required beyond standard library.
"""

import json
import sqlite3
import struct
import sys
import urllib.request
import urllib.error
from pathlib import Path
from typing import List, Optional


OLLAMA_URL = "http://localhost:11434"
DEFAULT_EMBED_MODEL = "nomic-embed-text"
DB_FILE = "florida-statutes.db"


def get_ollama_embedding(text: str, model: str = DEFAULT_EMBED_MODEL) -> Optional[List[float]]:
    """Get embedding from Ollama API (single text)."""
    url = f"{OLLAMA_URL}/api/embed"
    data = json.dumps({
        "model": model,
        "input": text
    }).encode('utf-8')

    req = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json"}
    )

    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            result = json.loads(response.read().decode('utf-8'))
            if "embeddings" in result and len(result["embeddings"]) > 0:
                return result["embeddings"][0]
            return None
    except urllib.error.URLError as e:
        print(f"Error connecting to Ollama: {e}")
        return None
    except json.JSONDecodeError:
        print("Invalid JSON response from Ollama")
        return None


def get_ollama_embeddings_batch(
    texts: List[str],
    model: str = DEFAULT_EMBED_MODEL,
    batch_size: int = 25
) -> List[Optional[List[float]]]:
    """
    Get embeddings for multiple texts in batches.

    CUDA Optimization: Reduces HTTP overhead by batching requests.
    Instead of 7842 individual requests, uses ~314 batch requests.

    Args:
        texts: List of texts to embed
        model: Ollama embedding model name
        batch_size: Number of texts per API request (default 25)

    Returns:
        List of embeddings (or None for failed items)
    """
    all_embeddings: List[Optional[List[float]]] = []
    total_batches = (len(texts) + batch_size - 1) // batch_size

    for batch_idx in range(0, len(texts), batch_size):
        batch = texts[batch_idx:batch_idx + batch_size]
        batch_num = batch_idx // batch_size + 1

        url = f"{OLLAMA_URL}/api/embed"
        data = json.dumps({
            "model": model,
            "input": batch  # Ollama accepts array of texts
        }).encode('utf-8')

        req = urllib.request.Request(
            url,
            data=data,
            headers={"Content-Type": "application/json"}
        )

        try:
            # Longer timeout for batch requests
            with urllib.request.urlopen(req, timeout=120) as response:
                result = json.loads(response.read().decode('utf-8'))
                if "embeddings" in result:
                    all_embeddings.extend(result["embeddings"])
                else:
                    # If no embeddings returned, fill with None
                    all_embeddings.extend([None] * len(batch))
                    print(f"  Batch {batch_num}/{total_batches}: No embeddings returned")
        except urllib.error.URLError as e:
            print(f"  Batch {batch_num}/{total_batches} error: {e}")
            all_embeddings.extend([None] * len(batch))
        except json.JSONDecodeError:
            print(f"  Batch {batch_num}/{total_batches}: Invalid JSON response")
            all_embeddings.extend([None] * len(batch))

        # Progress update every 10 batches
        if batch_num % 10 == 0 or batch_num == total_batches:
            print(f"  Embedding progress: {batch_num}/{total_batches} batches ({len(all_embeddings)}/{len(texts)} texts)")

    return all_embeddings


def encode_embedding(embedding: List[float]) -> bytes:
    """Encode embedding as binary blob for SQLite storage."""
    return struct.pack(f'{len(embedding)}f', *embedding)


def decode_embedding(blob: bytes) -> List[float]:
    """Decode embedding from SQLite binary blob."""
    count = len(blob) // 4
    return list(struct.unpack(f'{count}f', blob))


def cosine_similarity(a: List[float], b: List[float]) -> float:
    """Calculate cosine similarity between two vectors."""
    if len(a) != len(b):
        return 0.0
    dot = sum(x * y for x, y in zip(a, b))
    norm_a = sum(x * x for x in a) ** 0.5
    norm_b = sum(x * x for x in b) ** 0.5
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return dot / (norm_a * norm_b)


def create_database(db_path: Path):
    """Create SQLite database with FTS5 and embedding storage."""
    conn = sqlite3.connect(str(db_path))
    cursor = conn.cursor()

    # Main table for chunks
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS chunks (
            id TEXT PRIMARY KEY,
            citation TEXT,
            chapter TEXT,
            section TEXT,
            title TEXT,
            content TEXT,
            metadata TEXT,
            embedding BLOB,
            tokens INTEGER
        )
    """)

    # FTS5 virtual table for full-text search
    cursor.execute("""
        CREATE VIRTUAL TABLE IF NOT EXISTS chunks_fts USING fts5(
            id,
            citation,
            content,
            content='chunks',
            content_rowid='rowid'
        )
    """)

    # Triggers to keep FTS in sync
    cursor.execute("""
        CREATE TRIGGER IF NOT EXISTS chunks_ai AFTER INSERT ON chunks BEGIN
            INSERT INTO chunks_fts(rowid, id, citation, content)
            VALUES (new.rowid, new.id, new.citation, new.content);
        END
    """)

    cursor.execute("""
        CREATE TRIGGER IF NOT EXISTS chunks_ad AFTER DELETE ON chunks BEGIN
            INSERT INTO chunks_fts(chunks_fts, rowid, id, citation, content)
            VALUES('delete', old.rowid, old.id, old.citation, old.content);
        END
    """)

    conn.commit()
    return conn


def load_chunks(jsonl_path: Path) -> List[dict]:
    """Load chunks from JSONL file."""
    chunks = []
    with open(jsonl_path, 'r', encoding='utf-8') as f:
        for line in f:
            if line.strip():
                chunks.append(json.loads(line))
    return chunks


def get_last_processed_index(db_path: Path) -> int:
    """Get the index of the last processed chunk for resume functionality."""
    if not db_path.exists():
        return -1
    try:
        conn = sqlite3.connect(str(db_path))
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM chunks WHERE embedding IS NOT NULL")
        count = cursor.fetchone()[0]
        conn.close()
        return count - 1  # Return 0-based index
    except:
        return -1


def embed_chunks(
    jsonl_path: Path,
    db_path: Path,
    embed_model: str = DEFAULT_EMBED_MODEL,
    batch_size: int = 25,  # Fixed: was 10, now unified to 25
    skip_embeddings: bool = False,
    resume: bool = False,
    commit_interval: int = 100
):
    """
    Embed all chunks and store in database using streaming pattern.

    STREAMING ARCHITECTURE (prevents memory pressure):
    - Process in batches: read batch → embed batch → insert batch → commit
    - Releases memory between batches
    - Supports --resume for interrupted runs
    """
    import time

    print(f"Loading chunks from {jsonl_path}...")
    chunks = load_chunks(jsonl_path)
    total_chunks = len(chunks)
    print(f"Loaded {total_chunks} chunks")

    print(f"Creating database at {db_path}...")
    conn = create_database(db_path)
    cursor = conn.cursor()

    # Check existing and handle resume
    cursor.execute("SELECT COUNT(*) FROM chunks")
    existing = cursor.fetchone()[0]
    start_index = 0

    if existing > 0:
        if resume:
            # Resume from last successful position
            cursor.execute("SELECT COUNT(*) FROM chunks WHERE embedding IS NOT NULL")
            start_index = cursor.fetchone()[0]
            print(f"Resuming from chunk {start_index} (of {total_chunks})")
        else:
            print(f"Database already has {existing} chunks")
            response = input("Clear and re-embed? [y/N]: ").strip().lower()
            if response == 'y':
                cursor.execute("DELETE FROM chunks")
                cursor.execute("DELETE FROM chunks_fts")
                conn.commit()
                start_index = 0
            else:
                print("Skipping embedding, database intact")
                conn.close()
                return

    if not skip_embeddings:
        # Check Ollama availability
        try:
            test_url = f"{OLLAMA_URL}/api/tags"
            with urllib.request.urlopen(test_url, timeout=5) as response:
                models = json.loads(response.read().decode('utf-8'))
                available = [m['name'] for m in models.get('models', [])]
                if embed_model not in available and f"{embed_model}:latest" not in available:
                    print(f"Warning: {embed_model} not found. Available: {available[:5]}")
                    print(f"Pulling {embed_model}...")
        except urllib.error.URLError:
            print("Warning: Cannot connect to Ollama. Will skip embeddings.")
            skip_embeddings = True

    # STREAMING ARCHITECTURE: Process in batches to avoid memory pressure
    # Pattern: read batch → embed batch → insert batch → commit → release memory
    print(f"\nStreaming embed (batch_size={batch_size}, commit_interval={commit_interval})...")
    start_time = time.time()
    embedded_count = 0
    total_to_process = total_chunks - start_index

    for batch_start in range(start_index, total_chunks, batch_size):
        batch_end = min(batch_start + batch_size, total_chunks)
        batch_chunks = chunks[batch_start:batch_end]

        # Step 1: Prepare texts for this batch only
        embed_texts = []
        for chunk in batch_chunks:
            citation = chunk.get('citation', '')
            content = chunk.get('content', '')
            embed_text = f"{citation}\n\n{content[:2000]}"
            embed_texts.append(embed_text)

        # Step 2: Embed this batch
        batch_embeddings = []
        if not skip_embeddings:
            batch_embeddings = get_ollama_embeddings_batch(embed_texts, embed_model, batch_size)

        # Step 3: Insert this batch into database
        for i, chunk in enumerate(batch_chunks):
            global_idx = batch_start + i
            chunk_id = chunk.get('id', f'chunk-{global_idx}')
            citation = chunk.get('citation', '')
            hierarchy = chunk.get('hierarchy', {})
            chapter = hierarchy.get('chapter', {}).get('number', '')
            section = hierarchy.get('section', {}).get('number', '')
            title = hierarchy.get('section', {}).get('title', '')
            content = chunk.get('content', '')
            tokens = chunk.get('tokens', 0)

            # Get embedding from batch
            embedding_blob = None
            if not skip_embeddings and i < len(batch_embeddings) and batch_embeddings[i] is not None:
                embedding_blob = encode_embedding(batch_embeddings[i])
                embedded_count += 1

            cursor.execute("""
                INSERT OR REPLACE INTO chunks
                (id, citation, chapter, section, title, content, metadata, embedding, tokens)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                chunk_id,
                citation,
                chapter,
                section,
                title,
                content,
                json.dumps(chunk),
                embedding_blob,
                tokens
            ))

        # Step 4: Commit at intervals (for resume-on-failure)
        if (batch_end - start_index) % commit_interval < batch_size or batch_end == total_chunks:
            conn.commit()

        # Progress update
        processed = batch_end - start_index
        pct = (processed / total_to_process) * 100 if total_to_process > 0 else 100
        elapsed = time.time() - start_time
        rate = processed / elapsed if elapsed > 0 else 0
        eta = (total_to_process - processed) / rate if rate > 0 else 0
        print(f"\r  Progress: {batch_end}/{total_chunks} ({pct:.1f}%) | {rate:.1f} chunks/s | ETA: {eta:.0f}s   ", end='')

        # Step 5: Release batch memory (Python GC will clean up)
        del embed_texts
        del batch_embeddings
        del batch_chunks

    print()  # Newline after progress
    conn.commit()

    # Final stats
    elapsed = time.time() - start_time
    cursor.execute("SELECT COUNT(*) FROM chunks WHERE embedding IS NOT NULL")
    with_embeddings = cursor.fetchone()[0]

    print(f"\n=== Database Summary ===")
    print(f"Total chunks: {total_chunks}")
    print(f"With embeddings: {with_embeddings}")
    print(f"Time elapsed: {elapsed:.1f}s ({total_to_process / elapsed:.1f} chunks/s)")
    print(f"Database: {db_path}")

    conn.close()


def search_fts(db_path: Path, query: str, limit: int = 10):
    """Search using SQLite FTS5."""
    conn = sqlite3.connect(str(db_path))
    cursor = conn.cursor()

    # Escape special FTS5 characters by quoting terms
    # FTS5 special chars: AND OR NOT ( ) " * : ^
    safe_query = ' '.join(f'"{term}"' for term in query.split())

    cursor.execute("""
        SELECT c.id, c.citation, snippet(chunks_fts, 2, '>>>', '<<<', '...', 50) as snippet
        FROM chunks_fts
        JOIN chunks c ON chunks_fts.rowid = c.rowid
        WHERE chunks_fts MATCH ?
        ORDER BY rank
        LIMIT ?
    """, (safe_query, limit))

    results = cursor.fetchall()
    conn.close()
    return results


def search_semantic(
    db_path: Path,
    query: str,
    limit: int = 10,
    embed_model: str = DEFAULT_EMBED_MODEL
):
    """Search using cosine similarity of embeddings."""
    # Get query embedding
    query_embedding = get_ollama_embedding(query, embed_model)
    if not query_embedding:
        print("Could not get query embedding")
        return []

    conn = sqlite3.connect(str(db_path))
    cursor = conn.cursor()

    # Get all chunks with embeddings
    cursor.execute("SELECT id, citation, content, embedding FROM chunks WHERE embedding IS NOT NULL")
    rows = cursor.fetchall()

    # Calculate similarities
    scored = []
    for row in rows:
        chunk_id, citation, content, embedding_blob = row
        chunk_embedding = decode_embedding(embedding_blob)
        similarity = cosine_similarity(query_embedding, chunk_embedding)
        scored.append((similarity, chunk_id, citation, content[:200]))

    # Sort by similarity
    scored.sort(reverse=True)

    conn.close()
    return scored[:limit]


def safe_print(text: str):
    """Print with fallback for encoding issues."""
    try:
        print(text)
    except UnicodeEncodeError:
        print(text.encode('ascii', 'replace').decode('ascii'))


def main():
    import argparse

    parser = argparse.ArgumentParser(description='Embed Florida Statutes into SQLite')
    subparsers = parser.add_subparsers(dest='command', help='Commands')

    # Embed command
    embed_parser = subparsers.add_parser('embed', help='Embed chunks into database')
    embed_parser.add_argument('input', type=Path, help='Input JSONL file')
    embed_parser.add_argument('--db', type=Path, default=Path(DB_FILE), help='Database path')
    embed_parser.add_argument('--model', default=DEFAULT_EMBED_MODEL, help='Embedding model')
    embed_parser.add_argument('--batch-size', type=int, default=25,
                              help='Texts per embedding API request (default: 25)')
    embed_parser.add_argument('--resume', action='store_true',
                              help='Resume from last successful position (for interrupted runs)')
    embed_parser.add_argument('--commit-interval', type=int, default=100,
                              help='Commit to DB every N chunks (default: 100)')
    embed_parser.add_argument('--skip-embeddings', action='store_true',
                              help='Skip Ollama embeddings (FTS only)')

    # Search command
    search_parser = subparsers.add_parser('search', help='Search the database')
    search_parser.add_argument('query', help='Search query')
    search_parser.add_argument('--db', type=Path, default=Path(DB_FILE), help='Database path')
    search_parser.add_argument('--mode', choices=['fts', 'semantic', 'hybrid'],
                               default='fts', help='Search mode')
    search_parser.add_argument('--limit', type=int, default=5, help='Max results')
    search_parser.add_argument('--model', default=DEFAULT_EMBED_MODEL, help='Embedding model')

    args = parser.parse_args()

    if args.command == 'embed':
        if not args.input.exists():
            print(f"Error: {args.input} not found")
            sys.exit(1)
        embed_chunks(
            args.input,
            args.db,
            args.model,
            batch_size=args.batch_size,
            skip_embeddings=args.skip_embeddings,
            resume=args.resume,
            commit_interval=args.commit_interval
        )

    elif args.command == 'search':
        if not args.db.exists():
            print(f"Error: Database {args.db} not found. Run 'embed' first.")
            sys.exit(1)

        if args.mode == 'fts':
            safe_print(f"\n=== FTS Search: {args.query} ===\n")
            results = search_fts(args.db, args.query, args.limit)
            for chunk_id, citation, snippet in results:
                safe_print(f"[{citation}]")
                safe_print(f"  {snippet}\n")

        elif args.mode == 'semantic':
            safe_print(f"\n=== Semantic Search: {args.query} ===\n")
            results = search_semantic(args.db, args.query, args.limit, args.model)
            for similarity, chunk_id, citation, preview in results:
                safe_print(f"[{citation}] (score: {similarity:.4f})")
                safe_print(f"  {preview}...\n")

        elif args.mode == 'hybrid':
            safe_print(f"\n=== Hybrid Search: {args.query} ===\n")
            fts_results = search_fts(args.db, args.query, args.limit)
            safe_print("--- FTS Results ---")
            for chunk_id, citation, snippet in fts_results:
                safe_print(f"[{citation}]: {snippet[:100]}...")

            safe_print("\n--- Semantic Results ---")
            semantic_results = search_semantic(args.db, args.query, args.limit, args.model)
            for similarity, chunk_id, citation, preview in semantic_results:
                safe_print(f"[{citation}] ({similarity:.4f}): {preview[:100]}...")
    else:
        parser.print_help()


if __name__ == '__main__':
    main()
