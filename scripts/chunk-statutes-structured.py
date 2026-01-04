#!/usr/bin/env python3
"""
Structure-aware chunking of Florida Statutes for RAG ingestion.

Preserves the hierarchical structure:
Title → Chapter → Section → Subsection → Paragraph

Based on approach from davidkarpay's Statutes and FactualLM repositories.
"""

import json
import re
import sys
from pathlib import Path
from typing import List, Generator, Optional
from collections import defaultdict

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent))

from models.florida_statute import (
    FloridaStatute,
    Subsection,
    extract_cross_references,
    parse_subsections,
    clean_text,
    get_title_for_chapter,
)


# Patterns for parsing statute structure
SECTION_HEADER_PATTERN = re.compile(
    r'(?:^|\n)\s*(\d{1,3})\.(\d{2,5})\s+([A-Z][^.\n]+?)(?:\.|—|$)',
    re.MULTILINE
)

# Alternative pattern for sections like "718.112 Bylaws."
SECTION_ALT_PATTERN = re.compile(
    r'(\d{1,3}\.\d{2,5})\s+([A-Z][A-Za-z\s,;]+?)(?:\.—|\.\s*$|—)',
    re.MULTILINE
)

# Pattern for chapter headers
CHAPTER_HEADER_PATTERN = re.compile(
    r'CHAPTER\s+(\d+)\s*\n\s*([A-Z][A-Z\s,;]+)',
    re.MULTILINE
)


def parse_blocks(filepath: Path) -> Generator[str, None, None]:
    """
    Parse the extracted statute file into individual blocks.

    The clean extraction uses '=====' delimiters between blocks.
    """
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Split on block delimiters
    blocks = re.split(r'={50,}', content)

    for block in blocks:
        # Skip header blocks and very short blocks
        if 'BLOCK' in block[:50]:
            continue
        if len(block.strip()) < 100:
            continue

        yield clean_text(block)


def identify_section_number(text: str) -> Optional[tuple]:
    """
    Try to identify a section number from text.

    Returns tuple of (chapter, section, title) or None.
    """
    # Try primary pattern
    match = SECTION_HEADER_PATTERN.search(text[:500])
    if match:
        chapter = match.group(1)
        section = f"{match.group(1)}.{match.group(2)}"
        title = match.group(3).strip()
        return chapter, section, title

    # Try alternative pattern
    match = SECTION_ALT_PATTERN.search(text[:500])
    if match:
        section = match.group(1)
        chapter = section.split('.')[0]
        title = match.group(2).strip()
        return chapter, section, title

    # Try to find any section number pattern
    simple_match = re.search(r'(\d{1,3})\.(\d{2,5})', text[:200])
    if simple_match:
        chapter = simple_match.group(1)
        section = f"{simple_match.group(1)}.{simple_match.group(2)}"
        return chapter, section, ""

    return None


def create_statute_from_block(block: str, block_id: int) -> Optional[FloridaStatute]:
    """
    Create a FloridaStatute object from a text block.
    """
    # Try to identify section
    section_info = identify_section_number(block)

    if not section_info:
        # Can't identify section, create generic chunk
        return None

    chapter, section, title = section_info

    # Get title info based on chapter
    try:
        chapter_num = int(chapter)
        title_num, title_name = get_title_for_chapter(chapter_num)
    except ValueError:
        title_num, title_name = "", ""

    # Extract cross-references
    refs = extract_cross_references(block)

    # Parse subsections
    subsections = parse_subsections(block)

    # Create statute object
    statute = FloridaStatute(
        title_number=title_num,
        title_name=title_name,
        chapter_number=chapter,
        chapter_name="",  # Would need chapter index to populate
        section_number=section,
        section_title=title,
        full_text=block,
        subsections=subsections,
        source_url=f"https://www.leg.state.fl.us/statutes/index.cfm?mode=View%20Statutes&SubMenu=1&App_mode=Display_Statute&Search_String=&URL={chapter.zfill(4)}-{chapter.zfill(4)}/{chapter}/{section}.html",
        statute_refs=refs['statutes'],
        rule_refs=refs['rules'],
        constitutional_refs=refs['constitution'],
    )

    return statute


def chunk_statutes(input_file: Path, output_file: Path) -> dict:
    """
    Process extracted statutes into structured JSONL chunks.

    Returns statistics about the chunking process.
    """
    stats = {
        'total_blocks': 0,
        'parsed_sections': 0,
        'skipped_blocks': 0,
        'chapters_seen': set(),
        'cross_refs': {
            'statutes': 0,
            'rules': 0,
            'constitution': 0
        },
        'avg_tokens': 0,
        'total_tokens': 0
    }

    seen_sections = set()
    chunks = []

    print(f"Processing {input_file}...")

    for block_id, block in enumerate(parse_blocks(input_file)):
        stats['total_blocks'] += 1

        if stats['total_blocks'] % 1000 == 0:
            print(f"  Processed {stats['total_blocks']} blocks...")

        statute = create_statute_from_block(block, block_id)

        if statute is None:
            stats['skipped_blocks'] += 1
            continue

        # Deduplicate by section number
        if statute.section_number in seen_sections:
            continue
        seen_sections.add(statute.section_number)

        # Generate chunk
        chunk = statute.to_chunk()
        chunks.append(chunk)

        # Update stats
        stats['parsed_sections'] += 1
        stats['chapters_seen'].add(statute.chapter_number)
        stats['cross_refs']['statutes'] += len(statute.statute_refs)
        stats['cross_refs']['rules'] += len(statute.rule_refs)
        stats['cross_refs']['constitution'] += len(statute.constitutional_refs)
        stats['total_tokens'] += chunk['tokens']

    # Calculate averages
    if stats['parsed_sections'] > 0:
        stats['avg_tokens'] = stats['total_tokens'] // stats['parsed_sections']

    # Convert set to count
    stats['unique_chapters'] = len(stats['chapters_seen'])
    stats['chapters_seen'] = sorted(list(stats['chapters_seen']))[:20]  # First 20 for display

    # Write JSONL output
    print(f"Writing {len(chunks)} chunks to {output_file}...")
    with open(output_file, 'w', encoding='utf-8') as f:
        for chunk in chunks:
            f.write(json.dumps(chunk, ensure_ascii=False) + '\n')

    return stats


def main():
    """Main entry point."""
    import argparse

    parser = argparse.ArgumentParser(
        description='Structure-aware chunking of Florida Statutes for RAG'
    )
    parser.add_argument(
        'input',
        type=Path,
        help='Input extracted statutes file'
    )
    parser.add_argument(
        'output',
        type=Path,
        help='Output JSONL file'
    )
    parser.add_argument(
        '--stats',
        type=Path,
        help='Optional: Write statistics to JSON file'
    )

    args = parser.parse_args()

    if not args.input.exists():
        print(f"Error: {args.input} not found")
        sys.exit(1)

    # Create output directory if needed
    args.output.parent.mkdir(parents=True, exist_ok=True)

    # Process
    stats = chunk_statutes(args.input, args.output)

    # Print summary
    print("\n=== Chunking Summary ===")
    print(f"Total blocks processed: {stats['total_blocks']}")
    print(f"Parsed sections: {stats['parsed_sections']}")
    print(f"Skipped blocks: {stats['skipped_blocks']}")
    print(f"Unique chapters: {stats['unique_chapters']}")
    print(f"Average tokens per chunk: {stats['avg_tokens']}")
    print(f"Cross-references found:")
    print(f"  - Statute refs: {stats['cross_refs']['statutes']}")
    print(f"  - Rule refs: {stats['cross_refs']['rules']}")
    print(f"  - Constitutional refs: {stats['cross_refs']['constitution']}")

    # Write stats if requested
    if args.stats:
        with open(args.stats, 'w', encoding='utf-8') as f:
            json.dump(stats, f, indent=2)
        print(f"\nStatistics written to {args.stats}")


if __name__ == '__main__':
    main()
