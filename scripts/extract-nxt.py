#!/usr/bin/env python3
"""
Extract readable text from Folio Views/Rocket Software NXT infobase files.

NXT files are proprietary binary format. This script attempts to extract
readable text content using pattern matching for legal document structures.
"""

import html
import re
import sys
import struct
from pathlib import Path
from typing import Generator


def clean_text(text: str) -> str:
    """Clean extracted text by decoding HTML entities and normalizing whitespace."""
    # Decode HTML entities (&#x2003; etc.)
    text = html.unescape(text)
    # Remove common junk patterns
    text = re.sub(r'&#x[0-9a-fA-F]+;', ' ', text)  # Any remaining hex entities
    text = re.sub(r'&[a-z]+;', ' ', text)  # Named entities
    # Normalize whitespace
    text = re.sub(r'[ \t]+', ' ', text)
    text = re.sub(r'\n{3,}', '\n\n', text)
    return text.strip()


def extract_printable_strings(data: bytes, min_length: int = 10) -> Generator[str, None, None]:
    """Extract printable ASCII/Latin-1 strings from binary data."""
    # Pattern for printable characters (space to tilde + common extended)
    pattern = rb'[\x20-\x7e\xa0-\xff]{' + str(min_length).encode() + rb',}'

    for match in re.finditer(pattern, data):
        text = match.group().decode('latin-1', errors='ignore')
        # Filter out likely binary garbage
        if not re.search(r'[\x00-\x1f]', text):
            yield clean_text(text)


def extract_legal_content(data: bytes) -> Generator[str, None, None]:
    """
    Extract legal document content using Florida-specific patterns.
    Looks for statute sections, article references, etc.
    """
    # Common Florida legal patterns
    patterns = [
        # Statute sections: "90.001", "720.301", etc.
        rb'(\d{1,3}\.\d{2,4}[^<>\x00-\x1f]{10,500})',
        # Article/Section headers
        rb'(ARTICLE\s+[IVXLC]+[^<>\x00-\x1f]{5,200})',
        rb'(SECTION\s+\d+[^<>\x00-\x1f]{5,200})',
        # Chapter references
        rb'(CHAPTER\s+\d+[^<>\x00-\x1f]{5,500})',
        # Definition patterns
        rb'("[A-Z][a-z]+"\s+means[^<>\x00-\x1f]{10,500})',
    ]

    seen = set()
    for pattern in patterns:
        for match in re.finditer(pattern, data):
            text = match.group(1).decode('latin-1', errors='ignore').strip()
            # Clean up whitespace
            text = re.sub(r'\s+', ' ', text)
            if text not in seen and len(text) > 20:
                seen.add(text)
                yield text


def find_content_blocks(data: bytes) -> Generator[tuple[int, bytes], None, None]:
    """
    Find content blocks in NXT file by looking for common delimiters.
    NXT files often have structured blocks with length prefixes.
    """
    # Look for HTML-like content (NXT often stores formatted content)
    html_pattern = rb'<[^>]+>[^<]*</[^>]+>'
    for match in re.finditer(html_pattern, data):
        yield match.start(), match.group()

    # Look for plain text blocks between null bytes
    text_blocks = re.split(rb'\x00{2,}', data)
    for block in text_blocks:
        if len(block) > 50:
            # Check if mostly printable
            printable = sum(1 for b in block if 0x20 <= b <= 0x7e or 0xa0 <= b <= 0xff)
            if printable / len(block) > 0.7:
                yield 0, block


def extract_nxt_to_text(filepath: Path, output_path: Path = None) -> str:
    """
    Main extraction function for NXT infobase files.

    Args:
        filepath: Path to .nxt file
        output_path: Optional output file path

    Returns:
        Extracted text content
    """
    print(f"Reading {filepath} ({filepath.stat().st_size / 1024 / 1024:.1f} MB)...")

    with open(filepath, 'rb') as f:
        data = f.read()

    print(f"Analyzing {len(data):,} bytes...")

    # Collect extracted content
    extracted = []

    # Method 1: Extract legal-pattern content
    print("Extracting legal content patterns...")
    legal_content = list(extract_legal_content(data))
    print(f"  Found {len(legal_content)} legal content matches")
    extracted.extend(legal_content)

    # Method 2: Extract long printable strings
    print("Extracting printable strings...")
    strings = list(extract_printable_strings(data, min_length=50))

    # Filter strings that look like legal content
    legal_strings = []
    for s in strings:
        # Keep strings with legal terminology
        if any(term in s.lower() for term in [
            'shall', 'section', 'subsection', 'chapter', 'statute',
            'article', 'amendment', 'constitution', 'florida',
            'court', 'judge', 'attorney', 'defendant', 'plaintiff',
            'evidence', 'witness', 'trial', 'appeal', 'jurisdiction'
        ]):
            legal_strings.append(s)

    print(f"  Found {len(legal_strings)} legal-relevant strings")
    extracted.extend(legal_strings)

    # Deduplicate and sort by length (longer = more complete)
    seen = set()
    unique = []
    for text in sorted(extracted, key=len, reverse=True):
        # Skip if this is a substring of something we already have
        normalized = text.strip()
        if normalized and normalized not in seen:
            # Check if it's not a substring of existing content
            is_substring = any(normalized in existing for existing in seen)
            if not is_substring:
                seen.add(normalized)
                unique.append(normalized)

    print(f"Total unique content blocks: {len(unique)}")

    # Join with section separators and final cleanup
    result = '\n\n---\n\n'.join(unique)
    result = clean_text(result)

    # Write to output file if specified
    if output_path:
        output_path.write_text(result, encoding='utf-8')
        print(f"Wrote {len(result):,} characters to {output_path}")

    return result


def main():
    """Command line interface."""
    if len(sys.argv) < 2:
        print("Usage: python extract-nxt.py <input.nxt> [output.txt]")
        print("\nExample:")
        print("  python extract-nxt.py flcnst2025.nxt florida_constitution.txt")
        sys.exit(1)

    input_path = Path(sys.argv[1])
    if not input_path.exists():
        print(f"Error: {input_path} not found")
        sys.exit(1)

    output_path = Path(sys.argv[2]) if len(sys.argv) > 2 else None

    result = extract_nxt_to_text(input_path, output_path)

    if not output_path:
        # Print preview
        preview = result[:2000]
        print("\n=== PREVIEW (first 2000 chars) ===\n")
        print(preview)
        if len(result) > 2000:
            print(f"\n... [{len(result) - 2000:,} more characters]")


if __name__ == '__main__':
    main()
