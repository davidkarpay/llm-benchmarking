#!/usr/bin/env python3
"""
Clean extraction of Florida Statutes from NXT infobase files.
Strips HTML tags and extracts statute section numbers and content.
"""

import html
import re
import sys
from pathlib import Path


def strip_html_tags(text: str) -> str:
    """Remove HTML tags and decode entities."""
    # Decode HTML entities
    text = html.unescape(text)

    # Extract content from specific patterns
    # Statute section IDs like FS20250061.13
    section_pattern = r'#ID=FS2025(\d+)\.(\d+)'
    sections = re.findall(section_pattern, text)

    # Catchline content
    catchline_pattern = r'<div class="Catchline">([^<]+)#?</div>'
    catchlines = re.findall(catchline_pattern, text)

    # Remove all HTML tags
    text = re.sub(r'<[^>]+>', ' ', text)

    # Remove hex entities
    text = re.sub(r'&#x[0-9a-fA-F]+;', ' ', text)
    text = re.sub(r'&[a-z]+;', ' ', text)

    # Remove control characters and binary garbage
    text = re.sub(r'[\x00-\x1f\x7f-\x9f]', ' ', text)
    text = re.sub(r'7[%&\'(#!]', '', text)  # NXT markup artifacts

    # Normalize whitespace
    text = re.sub(r'[ \t]+', ' ', text)
    text = re.sub(r'\n{3,}', '\n\n', text)

    return text.strip()


def extract_statute_sections(data: bytes) -> list[dict]:
    """
    Extract statute sections with metadata.
    Returns list of {section: str, title: str, content: str}
    """
    sections = []
    seen = set()

    # Try to decode with latin-1 (covers full byte range)
    try:
        text = data.decode('latin-1', errors='ignore')
    except:
        return sections

    # Find statute section patterns
    # Format: <a href="#!-- #ID=FS2025CHAPTER.SECTION --#">CHAPTER.SECTION</a>...<div class="Catchline">TITLE</div>
    pattern = r'<a href="#!-- #ID=FS2025(\d{2,4})\.(\d{1,5}[^"]*) --#">[\d.]+</a>[^<]*<div class="Catchline">([^<7]+)'

    for match in re.finditer(pattern, text):
        chapter = match.group(1)
        section = match.group(2)
        title = match.group(3).strip().rstrip('#')

        full_section = f"{chapter}.{section}"

        if full_section not in seen and len(title) > 3:
            seen.add(full_section)
            sections.append({
                'section': full_section,
                'chapter': chapter,
                'title': title
            })

    return sections


def is_legal_text(text: str) -> bool:
    """Check if text appears to be substantive legal content."""
    if len(text) < 50:
        return False

    # Skip if too much binary garbage
    alphanum = sum(1 for c in text if c.isalnum() or c.isspace())
    if alphanum / len(text) < 0.7:
        return False

    # Legal terminology check
    lower_text = text.lower()
    legal_terms = [
        'shall', 'section', 'subsection', 'chapter', 'statute',
        'court', 'attorney', 'law', 'florida', 'pursuant',
        'thereof', 'herein', 'provision', 'violation', 'penalty',
        'department', 'agency', 'board', 'commission', 'act',
        'person', 'means', 'include', 'require', 'provide',
        'notice', 'hearing', 'rule', 'order', 'license', 'permit'
    ]

    term_count = sum(1 for term in legal_terms if term in lower_text)
    return term_count >= 2


def extract_nxt_clean(filepath: Path, output_path: Path, index_path: Path = None):
    """
    Extract clean text from NXT file.

    Args:
        filepath: Input NXT file
        output_path: Output text file
        index_path: Optional output for statute index
    """
    file_size = filepath.stat().st_size
    print(f"Reading {filepath} ({file_size / 1024 / 1024:.1f} MB)...")

    with open(filepath, 'rb') as f:
        data = f.read()

    print("Extracting statute sections...")
    sections = extract_statute_sections(data)
    print(f"  Found {len(sections)} statute sections")

    # Write index if requested
    if index_path and sections:
        with open(index_path, 'w', encoding='utf-8') as f:
            f.write("# Florida Statutes 2025 - Section Index\n\n")
            current_chapter = None
            for s in sorted(sections, key=lambda x: (int(x['chapter']), x['section'])):
                if s['chapter'] != current_chapter:
                    current_chapter = s['chapter']
                    f.write(f"\n## Chapter {current_chapter}\n\n")
                f.write(f"- § {s['section']}: {s['title']}\n")
        print(f"  Wrote index to {index_path}")

    print("Extracting text content...")

    # Extract clean text blocks
    all_blocks = []
    seen_hashes = set()

    # Split on null byte runs
    parts = re.split(rb'\x00{2,}', data)

    for part in parts:
        if len(part) < 50:
            continue

        # Check printability
        printable = sum(1 for b in part if 0x20 <= b <= 0x7e or 0xa0 <= b <= 0xff)
        if printable / len(part) < 0.5:
            continue

        try:
            text = part.decode('latin-1', errors='ignore')
        except:
            continue

        # Clean the text
        text = strip_html_tags(text)

        # Skip if not legal content
        if not is_legal_text(text):
            continue

        # Deduplicate
        block_hash = hash(text[:200])
        if block_hash not in seen_hashes:
            seen_hashes.add(block_hash)
            all_blocks.append(text)

    print(f"  Found {len(all_blocks)} clean text blocks")

    # Sort by length (longer = more complete)
    all_blocks.sort(key=len, reverse=True)

    # Write output
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write("# Florida Statutes 2025 - Extracted Text\n")
        f.write(f"# Source: {filepath.name}\n")
        f.write(f"# Blocks: {len(all_blocks)}\n\n")

        total_chars = 0
        for i, block in enumerate(all_blocks):
            if total_chars > 50_000_000:  # 50MB limit
                break
            f.write(f"\n{'='*60}\n")
            f.write(f"BLOCK {i+1}\n")
            f.write(f"{'='*60}\n\n")
            f.write(block)
            f.write('\n')
            total_chars += len(block)

    print(f"Wrote {total_chars:,} characters to {output_path}")
    return len(all_blocks), total_chars


def main():
    if len(sys.argv) < 3:
        print("Usage: python extract-nxt-clean.py <input.nxt> <output.txt> [index.md]")
        print("\nExample:")
        print("  python extract-nxt-clean.py fs2025.nxt statutes.txt index.md")
        sys.exit(1)

    input_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2])
    index_path = Path(sys.argv[3]) if len(sys.argv) > 3 else None

    if not input_path.exists():
        print(f"Error: {input_path} not found")
        sys.exit(1)

    blocks, chars = extract_nxt_clean(input_path, output_path, index_path)
    print(f"\nSummary: Extracted {blocks:,} blocks ({chars:,} characters)")


if __name__ == '__main__':
    main()
