#!/usr/bin/env python3
"""
Create a mixed benchmark suite that samples from all domains.

This tests BOTH routing accuracy AND specialist capabilities in a single run.
"""

import json
import random
import os
from pathlib import Path

# Configuration
BASE_DIR = Path("C:/Users/14104/llm-benchmarks/test-suites")
OUTPUT_FILE = BASE_DIR / "mixed" / "mixed-benchmark.json"

# Sampling configuration - 500+ tests for statistical significance
SAMPLES = {
    "reasoning": {
        "files": ["reasoning/gsm8k-001.json", "reasoning/gsm8k-002.json"],
        "count": 150,  # ~150 math word problems
        "specialist": "reasoning-specialist"
    },
    "code": {
        "files": ["code/humaneval.json"],
        "count": 150,  # ~150 code completion tasks
        "specialist": "code-specialist"
    },
    "knowledge": {
        "files": [
            "knowledge/mmlu-biology.json",
            "knowledge/mmlu-physics.json",
            "knowledge/mmlu-history.json",
            "knowledge/mmlu-law.json",
            "knowledge/mmlu-computer-science.json"
        ],
        "count": 150,  # ~150 multiple choice knowledge questions
        "specialist": "knowledge-specialist"
    },
    "science": {
        "files": ["science/arc-001.json", "science/arc-002.json"],
        "count": 100,  # ~100 science multiple-choice
        "specialist": "knowledge-specialist"  # ARC is multiple-choice science knowledge
    },
    "general": {
        "files": [
            "general/reasoning.json",
            "general/code.json",
            "general/knowledge.json",
            "general/creative.json"
        ],
        "count": None,  # Include all 23 original tests
        "specialist": None  # Keep original
    }
}


def load_cases_from_files(file_patterns):
    """Load test cases from multiple files."""
    cases = []
    for pattern in file_patterns:
        filepath = BASE_DIR / pattern
        if filepath.exists():
            with open(filepath, 'r', encoding='utf-8') as f:
                data = json.load(f)
                for case in data.get('cases', []):
                    case['_source_file'] = pattern
                    cases.append(case)
            print(f"  Loaded {len(data.get('cases', []))} cases from {pattern}")
        else:
            print(f"  WARNING: File not found: {pattern}")
    return cases


def sample_cases(cases, count, domain, specialist_override=None):
    """Sample cases and optionally override the specialist."""
    if count is None or count >= len(cases):
        sampled = cases
    else:
        sampled = random.sample(cases, count)

    # Renumber IDs and optionally override specialist
    result = []
    for i, case in enumerate(sampled):
        new_case = case.copy()
        new_case['id'] = f"mixed-{domain}-{i+1:03d}"
        new_case['_original_id'] = case.get('id', '')

        if specialist_override:
            new_case['expected_specialist'] = specialist_override

        # Add domain tag
        tags = new_case.get('tags', [])
        if domain not in tags:
            tags.append(domain)
        new_case['tags'] = tags

        # Remove internal field
        if '_source_file' in new_case:
            del new_case['_source_file']

        result.append(new_case)

    return result


def main():
    print("=" * 60)
    print("CREATING MIXED BENCHMARK SUITE")
    print("=" * 60)

    random.seed(42)  # Reproducible sampling

    all_cases = []

    for domain, config in SAMPLES.items():
        print(f"\n{domain.upper()}:")

        # Load cases
        cases = load_cases_from_files(config['files'])

        if not cases:
            print(f"  No cases found for {domain}, skipping")
            continue

        # Sample
        sampled = sample_cases(
            cases,
            config['count'],
            domain,
            config['specialist']
        )

        print(f"  Sampled: {len(sampled)} cases")
        all_cases.extend(sampled)

    # Shuffle all cases to mix domains
    random.shuffle(all_cases)

    # Create output suite
    suite = {
        "domain": "mixed",
        "subdomain": "multi-domain",
        "version": "1.0",
        "description": "Mixed benchmark suite sampling from all domains to test routing + specialist accuracy",
        "metadata": {
            "sources": list(SAMPLES.keys()),
            "total_cases": len(all_cases),
            "sampling_seed": 42,
            "breakdown": {
                domain: sum(1 for c in all_cases if domain in c.get('tags', []))
                for domain in SAMPLES.keys()
            }
        },
        "cases": all_cases
    }

    # Create output directory
    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)

    # Write output
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        json.dump(suite, f, indent=2, ensure_ascii=False)

    print(f"\n{'=' * 60}")
    print(f"MIXED SUITE CREATED")
    print(f"{'=' * 60}")
    print(f"Total cases: {len(all_cases)}")
    print(f"Output: {OUTPUT_FILE}")
    print(f"\nBreakdown:")
    for domain in SAMPLES.keys():
        count = sum(1 for c in all_cases if domain in c.get('tags', []))
        print(f"  {domain}: {count}")

    # Show expected specialist distribution
    print(f"\nExpected Specialist Distribution:")
    specialist_counts = {}
    for case in all_cases:
        spec = case.get('expected_specialist', 'unknown')
        specialist_counts[spec] = specialist_counts.get(spec, 0) + 1
    for spec, count in sorted(specialist_counts.items()):
        print(f"  {spec}: {count}")


if __name__ == "__main__":
    main()
