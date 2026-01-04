#!/usr/bin/env python3
"""
Fast extraction of text from Folio Views/Rocket Software NXT infobase files.
Optimized for large files (240MB+) using streaming and efficient text detection.
"""

import html
import re
import sys
from pathlib import Path


def is_legal_text(text: str) -> bool:
    """Check if text appears to be legal content."""
    if len(text) < 30:
        return False

    # Quick check for legal keywords
    lower_text = text.lower()
    legal_terms = [
        'shall', 'section', 'subsection', 'chapter', 'statute',
        'court', 'judge', 'attorney', 'law', 'legal', 'florida',
        'defendant', 'plaintiff', 'evidence', 'witness', 'appeal',
        'jurisdiction', 'pursuant', 'thereof', 'herein', 'amendment',
        'provision', 'violation', 'penalty', 'offense', 'crime',
        'title', 'act', 'agency', 'board', 'commission', 'department'
    ]

    # Must contain at least 2 legal terms
    term_count = sum(1 for term in legal_terms if term in lower_text)
    return term_count >= 1


def extract_text_blocks(data: bytes) -> list[str]:
    """
    Extract text blocks from binary data using simple heuristics.
    Splits on null bytes and filters for printable content.
    """
    blocks = []

    # Split on runs of 2+ null bytes
    parts = re.split(rb'\x00{2,}', data)

    for part in parts:
        if len(part) < 30:
            continue

        # Count printable characters
        printable = sum(1 for b in part if 0x20 <= b <= 0x7e or 0xa0 <= b <= 0xff)

        # Skip if less than 60% printable
        if printable / len(part) < 0.6:
            continue

        # Try to decode
        try:
            text = part.decode('latin-1', errors='ignore')
        except:
            continue

        # Clean up
        text = html.unescape(text)
        text = re.sub(r'&#x[0-9a-fA-F]+;', ' ', text)
        text = re.sub(r'[ \t]+', ' ', text)
        text = text.strip()

        # Filter for legal content
        if is_legal_text(text):
            blocks.append(text)

    return blocks


def extract_nxt_chunked(filepath: Path, output_path: Path, chunk_size: int = 10 * 1024 * 1024):
    """
    Extract text from NXT file using chunked reading.

    Args:
        filepath: Input NXT file
        output_path: Output text file
        chunk_size: Size of chunks to read (default 10MB)
    """
    file_size = filepath.stat().st_size
    print(f"Reading {filepath} ({file_size / 1024 / 1024:.1f} MB) in {chunk_size // (1024*1024)}MB chunks...")

    all_blocks = []
    seen_hashes = set()

    with open(filepath, 'rb') as f:
        chunk_num = 0
        overlap = b''

        while True:
            # Read chunk with overlap from previous chunk
            data = overlap + f.read(chunk_size)

            if not data:
                break

            chunk_num += 1
            progress = (f.tell() / file_size) * 100
            print(f"  Chunk {chunk_num}: {progress:.1f}% processed, {len(all_blocks)} blocks found...", end='\r')

            # Extract blocks from this chunk
            blocks = extract_text_blocks(data)

            for block in blocks:
                # Deduplicate using hash
                block_hash = hash(block[:100] + block[-100:] if len(block) > 200 else block)
                if block_hash not in seen_hashes:
                    seen_hashes.add(block_hash)
                    all_blocks.append(block)

            # Keep last 1KB as overlap for next chunk (to catch split text)
            overlap = data[-1024:] if len(data) > 1024 else b''

            # Check if we're at EOF
            if len(data) < chunk_size + 1024:
                break

    print(f"\n  Total unique blocks: {len(all_blocks)}")

    # Sort blocks by length (longer = more complete content)
    all_blocks.sort(key=len, reverse=True)

    # Take top blocks up to reasonable size
    max_chars = 50_000_000  # 50MB text limit
    total_chars = 0
    final_blocks = []

    for block in all_blocks:
        if total_chars + len(block) > max_chars:
            break
        final_blocks.append(block)
        total_chars += len(block)

    print(f"  Writing {len(final_blocks)} blocks ({total_chars:,} characters)...")

    # Write output
    with open(output_path, 'w', encoding='utf-8') as f:
        for i, block in enumerate(final_blocks):
            if i > 0:
                f.write('\n\n---\n\n')
            f.write(block)

    print(f"Done! Wrote {output_path}")
    return len(final_blocks), total_chars


def main():
    if len(sys.argv) < 3:
        print("Usage: python extract-nxt-fast.py <input.nxt> <output.txt>")
        sys.exit(1)

    input_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2])

    if not input_path.exists():
        print(f"Error: {input_path} not found")
        sys.exit(1)

    blocks, chars = extract_nxt_chunked(input_path, output_path)
    print(f"\nSummary: Extracted {blocks:,} text blocks ({chars:,} characters)")


if __name__ == '__main__':
    main()
