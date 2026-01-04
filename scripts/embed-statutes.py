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
    """Get embedding from Ollama API."""
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


def embed_chunks(
    jsonl_path: Path,
    db_path: Path,
    embed_model: str = DEFAULT_EMBED_MODEL,
    batch_size: int = 10,
    skip_embeddings: bool = False
):
    """Embed all chunks and store in database."""
    print(f"Loading chunks from {jsonl_path}...")
    chunks = load_chunks(jsonl_path)
    print(f"Loaded {len(chunks)} chunks")

    print(f"Creating database at {db_path}...")
    conn = create_database(db_path)
    cursor = conn.cursor()

    # Check existing
    cursor.execute("SELECT COUNT(*) FROM chunks")
    existing = cursor.fetchone()[0]
    if existing > 0:
        print(f"Database already has {existing} chunks")
        response = input("Clear and re-embed? [y/N]: ").strip().lower()
        if response == 'y':
            cursor.execute("DELETE FROM chunks")
            cursor.execute("DELETE FROM chunks_fts")
            conn.commit()
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
                    # Could add pull here, but let's proceed
        except urllib.error.URLError:
            print("Warning: Cannot connect to Ollama. Will skip embeddings.")
            skip_embeddings = True

    # Process chunks
    embedded_count = 0
    for i, chunk in enumerate(chunks):
        chunk_id = chunk.get('id', f'chunk-{i}')
        citation = chunk.get('citation', '')
        hierarchy = chunk.get('hierarchy', {})
        chapter = hierarchy.get('chapter', {}).get('number', '')
        section = hierarchy.get('section', {}).get('number', '')
        title = hierarchy.get('section', {}).get('title', '')
        content = chunk.get('content', '')
        tokens = chunk.get('tokens', 0)

        # Get embedding
        embedding_blob = None
        if not skip_embeddings:
            # Use citation + first 500 chars for embedding
            embed_text = f"{citation}\n\n{content[:2000]}"
            embedding = get_ollama_embedding(embed_text, embed_model)
            if embedding:
                embedding_blob = encode_embedding(embedding)
                embedded_count += 1

        # Insert
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

        if (i + 1) % 100 == 0:
            conn.commit()
            emb_status = f", {embedded_count} embedded" if not skip_embeddings else ""
            print(f"  Processed {i + 1}/{len(chunks)}{emb_status}")

    conn.commit()

    # Final stats
    cursor.execute("SELECT COUNT(*) FROM chunks WHERE embedding IS NOT NULL")
    with_embeddings = cursor.fetchone()[0]

    print(f"\n=== Database Summary ===")
    print(f"Total chunks: {len(chunks)}")
    print(f"With embeddings: {with_embeddings}")
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
        embed_chunks(args.input, args.db, args.model, skip_embeddings=args.skip_embeddings)

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
