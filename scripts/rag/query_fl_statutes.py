#!/usr/bin/env python3
"""
Query Florida Statutes from SQLite FTS5 database.

Returns statute chunks matching the query for RAG context injection.
Uses only Python standard library (sqlite3).

Usage:
    python query_fl_statutes.py "speedy trial" --limit 5 --max-tokens 1500
    python query_fl_statutes.py "summary judgment" --format json
    python query_fl_statutes.py "hearsay exception" --chapter 90
"""

import argparse
import json
import sqlite3
import sys
from pathlib import Path
from typing import List, Dict, Optional


# Default database path (relative to script location)
DEFAULT_DB_PATH = Path(__file__).parent.parent.parent / "extracted-statutes" / "florida-statutes.db"


def search_statutes(
    db_path: Path,
    query: str,
    limit: int = 5,
    chapter_filter: Optional[str] = None
) -> List[Dict]:
    """
    Search Florida statutes using FTS5 full-text search.

    Args:
        db_path: Path to SQLite database
        query: Search query string
        limit: Maximum number of results
        chapter_filter: Optional chapter number to filter by

    Returns:
        List of matching statute chunks with metadata
    """
    if not db_path.exists():
        raise FileNotFoundError(f"Database not found: {db_path}")

    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    # Escape special FTS5 characters by quoting terms
    # FTS5 special chars: AND OR NOT ( ) " * : ^
    safe_query = ' '.join(f'"{term}"' for term in query.split() if term)

    # Build query with optional chapter filter
    if chapter_filter:
        sql = """
            SELECT
                c.id,
                c.citation,
                c.chapter,
                c.section,
                c.title,
                c.content,
                c.tokens,
                snippet(chunks_fts, 2, '>>>', '<<<', '...', 64) as snippet
            FROM chunks_fts
            JOIN chunks c ON chunks_fts.rowid = c.rowid
            WHERE chunks_fts MATCH ?
            AND c.chapter = ?
            ORDER BY rank
            LIMIT ?
        """
        cursor.execute(sql, (safe_query, chapter_filter, limit))
    else:
        sql = """
            SELECT
                c.id,
                c.citation,
                c.chapter,
                c.section,
                c.title,
                c.content,
                c.tokens,
                snippet(chunks_fts, 2, '>>>', '<<<', '...', 64) as snippet
            FROM chunks_fts
            JOIN chunks c ON chunks_fts.rowid = c.rowid
            WHERE chunks_fts MATCH ?
            ORDER BY rank
            LIMIT ?
        """
        cursor.execute(sql, (safe_query, limit))

    results = []
    for row in cursor.fetchall():
        results.append({
            "id": row["id"],
            "citation": row["citation"],
            "chapter": row["chapter"],
            "section": row["section"],
            "title": row["title"],
            "content": row["content"],
            "tokens": row["tokens"],
            "snippet": row["snippet"]
        })

    conn.close()
    return results


def format_for_rag(
    results: List[Dict],
    max_tokens: int = 1500,
    include_full_content: bool = False
) -> str:
    """
    Format search results for RAG context injection.

    Args:
        results: List of statute chunks
        max_tokens: Maximum approximate tokens in output
        include_full_content: If True, include full content; otherwise use snippets

    Returns:
        Formatted string suitable for LLM context
    """
    if not results:
        return "No matching Florida statutes found for this query."

    output_lines = []
    total_tokens = 0

    for i, result in enumerate(results, 1):
        citation = result.get("citation", "Unknown citation")
        title = result.get("title", "")

        if include_full_content:
            text = result.get("content", "")
        else:
            text = result.get("snippet", result.get("content", "")[:500])

        # Estimate tokens (rough: 1 token ≈ 4 chars)
        entry_tokens = len(text) // 4

        if total_tokens + entry_tokens > max_tokens and i > 1:
            output_lines.append(f"\n[{len(results) - i + 1} additional results truncated due to token limit]")
            break

        entry = f"[{i}] {citation}"
        if title:
            entry += f" - {title}"
        entry += f"\n{text}\n"

        output_lines.append(entry)
        total_tokens += entry_tokens

    return "\n".join(output_lines)


def format_as_json(results: List[Dict]) -> str:
    """Format results as JSON for programmatic consumption."""
    return json.dumps({
        "count": len(results),
        "results": results
    }, indent=2)


def main():
    # Set stdout to UTF-8 for Windows compatibility
    import io
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    elif hasattr(sys.stdout, 'buffer'):
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

    parser = argparse.ArgumentParser(
        description="Query Florida Statutes database for RAG context"
    )
    parser.add_argument(
        "query",
        help="Search query (e.g., 'speedy trial', 'hearsay exception')"
    )
    parser.add_argument(
        "--db",
        type=Path,
        default=DEFAULT_DB_PATH,
        help=f"Path to SQLite database (default: {DEFAULT_DB_PATH})"
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=5,
        help="Maximum number of results (default: 5)"
    )
    parser.add_argument(
        "--max-tokens",
        type=int,
        default=1500,
        help="Maximum tokens in RAG output (default: 1500)"
    )
    parser.add_argument(
        "--chapter",
        type=str,
        help="Filter by chapter number (e.g., '90' for Evidence Code)"
    )
    parser.add_argument(
        "--format",
        choices=["rag", "json"],
        default="rag",
        help="Output format: 'rag' for LLM context, 'json' for structured data"
    )
    parser.add_argument(
        "--full",
        action="store_true",
        help="Include full content instead of snippets"
    )

    args = parser.parse_args()

    try:
        results = search_statutes(
            db_path=args.db,
            query=args.query,
            limit=args.limit,
            chapter_filter=args.chapter
        )

        if args.format == "json":
            output = format_as_json(results)
        else:
            output = format_for_rag(
                results,
                max_tokens=args.max_tokens,
                include_full_content=args.full
            )

        # Handle Windows console encoding issues
        try:
            print(output)
        except UnicodeEncodeError:
            # Fallback: replace non-encodable chars
            print(output.encode('ascii', errors='replace').decode('ascii'))

    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        print("Run 'python scripts/embed-statutes.py embed ...' first to create the database.", file=sys.stderr)
        sys.exit(1)
    except sqlite3.Error as e:
        print(f"Database error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
